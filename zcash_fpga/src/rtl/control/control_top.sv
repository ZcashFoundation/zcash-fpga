/*
  This module is the top level for the FPGA interface to SW. It takes in commands
  from SW, running the commands, and then building the replies back to SW.
  
  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

module control_top
  import zcash_fpga_pkg::*, equihash_pkg::*;
#(
  parameter        DAT_BYTS = 8, // Only tested at 8 byte data width
  parameter [63:0] BUILD_HOST = "test",
  parameter [63:0] BUILD_DATE = "20180311"
)(
  input i_clk, i_rst,
  // User is able to reset custom logic on FPGA
  output logic o_usr_rst,
  // Interface inputs and outputs
  if_axi_stream.sink   rx_if,
  if_axi_stream.source tx_if,
  
  // Used when verifying equihash soltion
  if_axi_stream.source o_equihash_if,
  input equihash_bm_t  i_equihash_mask,
  input                i_equihash_mask_val,
  
  // Driving secp256k1 core
  if_axi_stream.source o_secp256k1_if,
  if_axi_stream.sink   i_secp256k1_if
);

localparam DAT_BITS = DAT_BYTS*8;
localparam MAX_BYT_MSG = 256; // Max bytes in a reply message

logic rst_int;
always_comb rst_int = i_rst || o_usr_rst;

// When a command comes in it is put through a clock crossing, and then stored in a command
// FIFO to be processed. There are two FIFOS - one for processing status / reset commands (msg_type == 0),
// and one for everything else. This is so we can process these messages even if we are 
// running something else.

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BYTS(1)) rx_int0_if (i_clk);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BYTS(1)) rx_int1_if (i_clk);

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BYTS(1)) rx_typ0_if (i_clk);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BYTS(1)) rx_typ1_if (i_clk);

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BYTS(1)) tx_arb_in_if [2] (i_clk);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BYTS(1)) tx_int_if (i_clk);


typedef enum {TYP0_IDLE = 0,
      TYP0_SEND_STATUS = 1,
      TYP0_RESET_FPGA = 2,
      TYP0_SEND_IGNORE = 3,
      TYP0_IGNORE = 4} typ0_msg_state_t;

typ0_msg_state_t typ0_msg_state;

typedef enum {TYP1_IDLE = 0,
      TYP1_VERIFY_EQUIHASH = 1,
      TYP1_VERIFY_SECP256K1 = 2,
      TYP1_SEND_IGNORE = 3,
      TYP1_IGNORE = 4} typ1_msg_state_t;
      
typ1_msg_state_t typ1_msg_state;

header_t header, header0, header1, header0_l, header1_l;
logic verify_equihash_rpl_val;

logic [7:0] reset_cnt;
logic [$clog2(MAX_BYT_MSG) -1:0] typ0_wrd_cnt, typ1_wrd_cnt;
logic [MAX_BYT_MSG*8 -1:0] typ0_msg, typ1_msg;
logic [63:0] equihash_index;
logic equihash_index_val, rx_typ1_if_rdy;
logic sop_l, eop_l;
logic eop_typ0_l, eop_typ1_l;

fpga_state_t fpga_state;
always_comb begin
  fpga_state = 0;
  fpga_state.error = 0;
  fpga_state.typ1_state = typ1_msg_state;
  header = rx_if.dat;
  header0 = rx_typ0_if.dat;
  header1 = rx_typ1_if.dat;
end

// Logic for processing msg_type == 0 messages
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    rx_typ0_if.rdy <= 0;
    typ0_msg_state <= TYP0_IDLE;
    header0_l <= 0;
    tx_arb_in_if[0].reset_source();
    typ0_wrd_cnt <= 0;
    o_usr_rst <= 0;
    reset_cnt <= 0;
    eop_typ0_l <= 0;
    typ0_msg <= 0;
  end else begin
    rx_typ0_if.rdy <= 1;
    
    if (tx_arb_in_if[0].rdy) tx_arb_in_if[0].val <= 0;
    
    case (typ0_msg_state)
      
      TYP0_IDLE: begin      
        if (rx_typ0_if.val && rx_typ0_if.rdy) begin
          header0_l <= header0;
          rx_typ0_if.rdy <= 0;
          case(header0.cmd)
            RESET_FPGA: begin
              typ0_msg <= get_fpga_reset_rpl();
              typ0_wrd_cnt <= $bits(fpga_reset_rpl_t)/8;
              typ0_msg_state <= TYP0_RESET_FPGA;
              o_usr_rst <= 1;
              reset_cnt <= -1;
            end
            FPGA_STATUS: begin
              typ0_msg <= get_fpga_status_rpl(BUILD_HOST, BUILD_DATE, fpga_state);
              typ0_wrd_cnt <= $bits(fpga_status_rpl_t)/8;
              typ0_msg_state <= TYP0_SEND_STATUS;
            end
            default: begin
              typ0_msg <= get_fpga_ignore_rpl(header0);
              typ0_wrd_cnt <= $bits(fpga_ignore_rpl_t)/8;
              eop_typ0_l <= rx_typ0_if.eop;
              typ0_msg_state <= TYP0_SEND_IGNORE;
            end
          endcase
        end
      end
      TYP0_SEND_STATUS: begin
        send_typ0_message($bits(fpga_status_rpl_t)/8);
      end
      TYP0_RESET_FPGA: begin
        rx_typ0_if.rdy <= 0;  
        if (reset_cnt != 0)
          reset_cnt <= reset_cnt - 1;
        if (reset_cnt >> 4 == 0)
          o_usr_rst <= 0;
        if (reset_cnt == 0) begin
          send_typ0_message($bits(fpga_reset_rpl_t)/8);
        end
      end
      TYP0_SEND_IGNORE: begin
        send_typ0_message($bits(fpga_ignore_rpl_t)/8, eop_typ0_l ? TYP0_IDLE : TYP0_IGNORE);
      end      
      TYP0_IGNORE: begin
        rx_typ0_if.rdy <= 1;
        if (rx_typ0_if.rdy && rx_typ0_if.eop && rx_typ0_if.val)
          typ0_msg_state <= TYP0_IDLE;
      end
    endcase
  end
end

// Task to help build reply messages. Assume no message will be more than MAX_BYT_MSG bytes
task send_typ0_message(input logic [$clog2(MAX_BYT_MSG)-1:0] msg_size,
                       input typ0_msg_state_t nxt_state = TYP0_IDLE);
  rx_typ0_if.rdy <= 0;
  if (~tx_arb_in_if[0].val || (tx_arb_in_if[0].rdy && tx_arb_in_if[0].val)) begin
    tx_arb_in_if[0].dat <= typ0_msg;
    tx_arb_in_if[0].val <= 1;
    tx_arb_in_if[0].sop <= typ0_wrd_cnt == msg_size;
    tx_arb_in_if[0].eop <= typ0_wrd_cnt <= DAT_BYTS;
    tx_arb_in_if[0].mod <= typ0_wrd_cnt < DAT_BYTS ? typ0_wrd_cnt : 0;
    typ0_wrd_cnt <= (typ0_wrd_cnt > DAT_BYTS) ? (typ0_wrd_cnt - DAT_BYTS) : 0;
    typ0_msg <= typ0_msg >> DAT_BITS;
    if (typ0_wrd_cnt == 0) begin
      tx_arb_in_if[0].val <= 0;
      typ0_msg_state <= nxt_state;
    end
  end
endtask

always_comb begin
  case(typ1_msg_state)
    TYP1_IDLE:       rx_typ1_if.rdy = rx_typ1_if_rdy;
    VERIFY_EQUIHASH: rx_typ1_if.rdy = rx_typ1_if_rdy && o_equihash_if.rdy;
    default:         rx_typ1_if.rdy = rx_typ1_if_rdy;
  endcase
end

always_comb begin
  i_secp256k1_if.rdy = (typ1_msg_state == TYP1_VERIFY_SECP256K1) && (~tx_arb_in_if[1].val || (tx_arb_in_if[1].rdy && tx_arb_in_if[1].val));
end
// Logic for processing msg_type == 1 messages
always_ff @ (posedge i_clk) begin
  if (rst_int) begin
    rx_typ1_if_rdy <= 0;
    typ1_msg_state <= TYP1_IDLE;
    header1_l <= 0;
    tx_arb_in_if[1].reset_source();
    o_equihash_if.reset_source();
    typ1_wrd_cnt <= 0;
    equihash_index <= 0;
    verify_equihash_rpl_val <= 0;
    equihash_index_val <= 0;
    sop_l <= 0;
    eop_typ1_l <= 0;
    typ1_msg <= 0;
    o_secp256k1_if.reset_source();
    eop_l <= 0;
  end else begin
  
    if (tx_arb_in_if[1].rdy) tx_arb_in_if[1].val <= 0;
    
    case (typ1_msg_state)
      TYP1_IDLE: begin
        rx_typ1_if_rdy <= 1;
        verify_equihash_rpl_val <= 0;
        equihash_index_val <= 0;
        sop_l <= 0;
        if (rx_typ1_if.val && rx_typ1_if.rdy) begin
          header1_l <= header1;
          rx_typ1_if_rdy <= 0;
          case(header1.cmd)
            VERIFY_EQUIHASH: begin
              rx_typ1_if_rdy <= 1;
              typ1_wrd_cnt <= $bits(verify_equihash_rpl_t)/8;
              typ1_msg_state <= TYP1_VERIFY_EQUIHASH;
              if (~ENB_VERIFY_EQUIHASH) begin
                typ1_msg <= get_fpga_ignore_rpl(header1);
                typ1_wrd_cnt <= $bits(fpga_ignore_rpl_t)/8;
                eop_typ1_l <= rx_typ1_if.eop;
                typ1_msg_state <= TYP1_SEND_IGNORE;
              end
            end
            VERIFY_SECP256K1_SIG: begin
              rx_typ1_if_rdy <= o_secp256k1_if.rdy;
              o_secp256k1_if.copy_if(rx_typ1_if.dat, rx_typ1_if.val, rx_typ1_if.sop, rx_typ1_if.eop);
              typ1_msg_state <= TYP1_VERIFY_SECP256K1;
              if (~ENB_VERIFY_SECP256K1_SIG) begin
                typ1_msg <= get_fpga_ignore_rpl(header1);
                typ1_wrd_cnt <= $bits(fpga_ignore_rpl_t)/8;
                eop_typ1_l <= rx_typ1_if.eop;
                typ1_msg_state <= TYP1_SEND_IGNORE;
              end
            end
            default: begin
              typ1_msg <= get_fpga_ignore_rpl(header1);
              typ1_wrd_cnt <= $bits(fpga_ignore_rpl_t)/8;
              eop_typ1_l <= rx_typ1_if.eop;
              typ1_msg_state <= TYP1_SEND_IGNORE;
            end
          endcase
        end
      end
      TYP1_VERIFY_EQUIHASH: begin
        if (rx_typ1_if.eop && rx_typ1_if.val && rx_typ1_if.rdy)
          rx_typ1_if_rdy <= 0;
          
        if (~equihash_index_val) begin
          if (rx_typ1_if.rdy && rx_typ1_if.val) begin
            equihash_index <= rx_typ1_if.dat;
            equihash_index_val <= 1;
          end
        end else begin         
          // First load block data (this might be bypassed if loading from memory)  
          if (~o_equihash_if.val || (o_equihash_if.rdy && o_equihash_if.val)) begin
            o_equihash_if.copy_if(rx_typ1_if.dat, rx_typ1_if.val, ~sop_l, rx_typ1_if.eop, rx_typ1_if.err, rx_typ1_if.mod);
            // First cycle has .sop set
            if (rx_typ1_if.val)  sop_l <= 1;
          end
        end
        
        // Wait for reply with result
        if (i_equihash_mask_val && ~verify_equihash_rpl_val) begin
          typ1_msg <= get_verify_equihash_rpl(i_equihash_mask, equihash_index);
          verify_equihash_rpl_val <= 1;
        end
        
        // Send result
        if (verify_equihash_rpl_val) begin
          send_typ1_message($bits(verify_equihash_rpl_t)/8);
        end
      end
      
      // The command header is sent through to output
      TYP1_VERIFY_SECP256K1: begin
        rx_typ1_if_rdy <= o_secp256k1_if.rdy;
        if (~eop_l && ~o_secp256k1_if.val || (o_secp256k1_if.rdy && o_secp256k1_if.val)) begin
          o_secp256k1_if.copy_if(rx_typ1_if.dat, rx_typ1_if.val, rx_typ1_if.sop, rx_typ1_if.eop, rx_typ1_if.err, rx_typ1_if.mod);
          eop_l <= rx_typ1_if.eop && rx_typ1_if.val;
          if (rx_typ1_if.eop && rx_typ1_if.val)
            rx_typ1_if_rdy <= 0;
        end
        
        if (~tx_arb_in_if[1].val || (tx_arb_in_if[1].rdy && tx_arb_in_if[1].val)) begin
          tx_arb_in_if[1].val <= i_secp256k1_if.val;
          tx_arb_in_if[1].dat <= i_secp256k1_if.dat;
          tx_arb_in_if[1].mod <= i_secp256k1_if.mod;
          tx_arb_in_if[1].sop <= i_secp256k1_if.sop;
          tx_arb_in_if[1].eop <= i_secp256k1_if.eop;
          tx_arb_in_if[1].err <= i_secp256k1_if.err;
        end
        
        if (tx_arb_in_if[1].val && tx_arb_in_if[1].rdy && tx_arb_in_if[1].eop) begin
          typ1_msg_state <= TYP1_IDLE;
        end
          
      end
      
      TYP1_SEND_IGNORE: begin
        send_typ1_message($bits(fpga_ignore_rpl_t)/8, eop_typ1_l ? TYP1_IDLE : TYP1_IGNORE);
      end
      TYP1_IGNORE: begin
        rx_typ1_if_rdy <= 1;
        if (rx_typ1_if.rdy && rx_typ1_if.eop && rx_typ1_if.val)
          typ1_msg_state <= TYP1_IDLE;
      end
    endcase
  end
end

// Task to help build reply messages. Assume no message will be more than MAX_BYT_MSG bytes
task send_typ1_message(input logic [$clog2(MAX_BYT_MSG)-1:0] msg_size,
                       input typ1_msg_state_t nxt_state = TYP1_IDLE);
  rx_typ1_if_rdy <= 0;
  if (~tx_arb_in_if[1].val || (tx_arb_in_if[1].rdy && tx_arb_in_if[1].val)) begin
    tx_arb_in_if[1].dat <= typ1_msg;
    tx_arb_in_if[1].val <= 1;
    tx_arb_in_if[1].sop <= typ1_wrd_cnt == msg_size;
    tx_arb_in_if[1].eop <= typ1_wrd_cnt <= DAT_BYTS;
    tx_arb_in_if[1].mod <= typ1_wrd_cnt < DAT_BYTS ? typ1_wrd_cnt : 0;
    typ1_wrd_cnt <= (typ1_wrd_cnt > DAT_BYTS) ? (typ1_wrd_cnt - DAT_BYTS) : 0;
    typ1_msg <= typ1_msg >> DAT_BITS;
    if (typ1_wrd_cnt == 0) begin
      tx_arb_in_if[1].val <= 0;
      typ1_msg_state <= nxt_state;
    end
  end
endtask

// Logic to mux the packet depending on its command type
logic msg_type, msg_type_l;
always_comb begin
  rx_int0_if.copy_if_comb(rx_if.dat, 0, rx_if.sop, rx_if.eop, 0, rx_if.mod, 0);
  rx_int1_if.copy_if_comb(rx_if.dat, 0, rx_if.sop, rx_if.eop, 0, rx_if.mod, 0);
  
  rx_if.rdy = 0;
  
  if (rx_if.sop && rx_if.val) begin
    if(header.cmd[8 +: 8] == 8'd0) begin
      msg_type = 0;
      rx_int0_if.val = rx_if.val;
      rx_if.rdy = rx_int0_if.rdy;
    end else begin
      msg_type = 1;
      rx_int1_if.val = rx_if.val;
      rx_if.rdy = rx_int1_if.rdy;
    end
  end else begin
    rx_int0_if.val = rx_if.val && (msg_type_l == 0);
    rx_int1_if.val = rx_if.val && (msg_type_l == 1);
    rx_if.rdy = (msg_type_l == 0) ? rx_int0_if.rdy : rx_int1_if.rdy;
    msg_type = msg_type_l;
  end
end
  
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    msg_type_l <= 0;
  end else begin
    if (rx_if.val && rx_if.rdy) begin
      if (rx_if.sop)
        msg_type_l <= msg_type;
    end
  end
end
  
// FIFO control queues for different message types
    
axi_stream_fifo #(
  .SIZE     ( 64       ),
  .DAT_BITS ( DAT_BITS )
)
cmd_fifo0 (
  .i_clk ( i_clk   ),
  .i_rst ( rst_int ),
  .i_axi ( rx_int0_if ),
  .o_axi ( rx_typ0_if )
);

axi_stream_fifo #(
  .SIZE     ( 64       ),
  .DAT_BITS ( DAT_BITS )
)
cmd_fifo1 (
  .i_clk ( i_clk   ),
  .i_rst ( rst_int ),
  .i_axi ( rx_int1_if ),
  .o_axi ( rx_typ1_if )
);

// Arbitrator for sending messages back
packet_arb # (
  .NUM_IN   ( 2        ),
  .DAT_BYTS ( DAT_BYTS ),
  .CTL_BITS ( 8        )
) 
packet_arb_tx (
  .i_clk ( i_clk  ),
  .i_rst ( rst_int ),

  .i_axi ( tx_arb_in_if ), 
  .o_axi ( tx_if    )
);

endmodule