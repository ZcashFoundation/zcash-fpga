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
  parameter        IN_DAT_BYTS,
  parameter        CORE_DAT_BYTS = 8, // Only tested at 8 byte data width
  parameter [63:0] BUILD_HOST = "test",
  parameter [63:0] BUILD_DATE = "20180311"
)(
  input i_clk_core, i_rst_core,
  input i_clk_if, i_rst_if,
  // User is able to reset custom logic on FPGA
  output logic o_usr_rst,
  // Interface inputs and outputs
  if_axi_stream.sink   rx_if,
  if_axi_stream.source tx_if,
  
  // Used when verifying equihash soltion
  if_axi_stream.source o_equihash_axi,
  input equihash_bm_t i_equihash_mask,
  input               i_equihash_mask_val
);

localparam IN_DAT_BITS = IN_DAT_BYTS*8;
localparam CORE_DAT_BITS = CORE_DAT_BYTS*8;

// When a command comes in it is put through a clock crossing, and then stored in a command
// FIFO to be processed. There are two FIFOS - one for processing status / reset commands (msg_type == 0),
// and one for everything else. This is so we can process these messages even if we are 
// running something else.


if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) rx_int_if (i_clk_core);
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) rx_int0_if (i_clk_core);
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) rx_int1_if (i_clk_core);

if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) rx_typ0_if (i_clk_core);
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) rx_typ1_if (i_clk_core);

if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) tx_arb_in_if [2] (i_clk_core);
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) tx_int_if (i_clk_core);

enum {TYP0_IDLE = 0,
      TYP0_SEND_STATUS = 1,
      TYP0_RESET_FPGA = 2,
      TYP0_IGNORE = 3} typ0_msg_state;

enum {TYP1_IDLE = 0,
      TYP1_VERIFY_EQUIHASH = 1,
      TYP1_IGNORE = 2} typ1_msg_state;
      
header_t header, header0, header1, header0_l, header1_l;
fpga_status_rpl_t fpga_status_rpl;
fpga_reset_rpl_t fpga_reset_rpl;
verify_equihash_rpl_t verify_equihash_rpl;

logic [7:0] typ0_wrd_cnt, typ1_wrd_cnt, reset_cnt;
logic [63:0] equihash_index;
logic equihash_index_val, rx_typ1_if_rdy, verify_equihash_rpl_val;
logic sop_l;

fpga_state_t fpga_state;
always_comb begin
  fpga_state = 0;
  fpga_state.error = 0;
  fpga_state.typ1_state = typ1_msg_state;
  header = rx_int_if.dat;
  header0 = rx_typ0_if.dat;
  header1 = rx_typ1_if.dat;
end

// Logic for processing msg_type == 0 messages
always_ff @ (posedge i_clk_core) begin
  if (i_rst_core) begin
    rx_typ0_if.rdy <= 0;
    typ0_msg_state <= TYP0_IDLE;
    header0_l <= 0;
    tx_arb_in_if[0].reset_source();
    fpga_status_rpl <= 0;
    fpga_reset_rpl <= 0;
    typ0_wrd_cnt <= 0;
    o_usr_rst <= 0;
    reset_cnt <= 0;
  end else begin
    rx_typ0_if.rdy <= 1;
    case (typ0_msg_state)
      
      TYP0_IDLE: begin
        fpga_status_rpl <= get_fpga_status_rpl(BUILD_HOST, BUILD_DATE, fpga_state);
        fpga_reset_rpl <= get_fpga_reset_rpl();
      
        if (rx_typ0_if.val && rx_typ0_if.rdy) begin
          header0_l <= header0;
          rx_typ0_if.rdy <= 0;
          case(header0.cmd)
            RESET_FPGA: begin
              typ0_wrd_cnt <= $bits(fpga_reset_rpl_t)/8;
              typ0_msg_state <= TYP0_RESET_FPGA;
              o_usr_rst <= 1;
              reset_cnt <= -1;
            end
            FPGA_STATUS: begin
              typ0_wrd_cnt <= $bits(fpga_status_rpl_t)/8;
              typ0_msg_state <= TYP0_SEND_STATUS;
            end
            default:
              if (~rx_typ0_if.eop)
                typ0_msg_state <= TYP0_IGNORE;
          endcase
        end
      end
      TYP0_SEND_STATUS: begin
        rx_typ0_if.rdy <= 0;
        if (~tx_arb_in_if[0].val || (tx_arb_in_if[0].rdy && tx_arb_in_if[0].val)) begin
          tx_arb_in_if[0].dat <= fpga_status_rpl;
          tx_arb_in_if[0].val <= 1;
          tx_arb_in_if[0].sop <= typ0_wrd_cnt == $bits(fpga_status_rpl_t)/8;
          tx_arb_in_if[0].eop <= typ0_wrd_cnt <= CORE_DAT_BYTS;
          tx_arb_in_if[0].mod <= typ0_wrd_cnt < CORE_DAT_BYTS ? typ0_wrd_cnt : 0;
          typ0_wrd_cnt <= (typ0_wrd_cnt > CORE_DAT_BYTS) ? (typ0_wrd_cnt - CORE_DAT_BYTS) : 0;
          fpga_status_rpl <= fpga_status_rpl >> CORE_DAT_BITS;
          if (typ0_wrd_cnt == 0) begin
            tx_arb_in_if[0].val <= 0;
            typ0_msg_state <= TYP0_IDLE;
          end
        end
      end
      TYP0_RESET_FPGA: begin
        rx_typ0_if.rdy <= 0;  
        if (reset_cnt == 0)
          o_usr_rst <= 0;
        else
          reset_cnt <= reset_cnt - 1;
        
        if (~o_usr_rst) begin
          if (~tx_arb_in_if[0].val || (tx_arb_in_if[0].rdy && tx_arb_in_if[0].val)) begin
            tx_arb_in_if[0].dat <= fpga_reset_rpl;
            tx_arb_in_if[0].val <= 1;
            tx_arb_in_if[0].sop <= typ0_wrd_cnt == $bits(fpga_reset_rpl_t)/8;
            tx_arb_in_if[0].eop <= typ0_wrd_cnt <= CORE_DAT_BYTS;
            tx_arb_in_if[0].mod <= typ0_wrd_cnt < CORE_DAT_BYTS ? typ0_wrd_cnt : 0;
            typ0_wrd_cnt <= (typ0_wrd_cnt > CORE_DAT_BYTS) ? (typ0_wrd_cnt - CORE_DAT_BYTS) : 0;
            fpga_reset_rpl <= fpga_reset_rpl >> CORE_DAT_BITS;
            if (typ0_wrd_cnt == 0) begin
              tx_arb_in_if[0].val <= 0;
              typ0_msg_state <= TYP0_IDLE;
            end
          end
        end

      end
      TYP0_IGNORE: begin
        rx_typ0_if.rdy <= 1;
        if (rx_typ0_if.rdy && rx_typ0_if.eop && rx_typ0_if.val)
          typ0_msg_state <= TYP0_IDLE;
      end
    endcase
  end
end

always_comb begin
  case(typ1_msg_state)
    TYP1_IDLE:       rx_typ1_if.rdy = rx_typ1_if_rdy;
    VERIFY_EQUIHASH: rx_typ1_if.rdy = rx_typ1_if_rdy && o_equihash_axi.rdy;
    default:         rx_typ1_if.rdy = rx_typ1_if_rdy;
  endcase
end
// Logic for processing msg_type == 1 messages
always_ff @ (posedge i_clk_core) begin
  if (i_rst_core) begin
    rx_typ1_if_rdy <= 0;
    typ1_msg_state <= TYP1_IDLE;
    header1_l <= 0;
    tx_arb_in_if[1].reset_source();
    o_equihash_axi.reset_source();
    verify_equihash_rpl <= 0;
    typ1_wrd_cnt <= 0;
    equihash_index <= 0;
    verify_equihash_rpl_val <= 0;
    equihash_index_val <= 0;
    sop_l <= 0;    
  end else begin
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
            end
            default:
              if (~rx_typ1_if.eop)
                typ1_msg_state <= TYP1_IGNORE;
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
          if (~o_equihash_axi.val || (o_equihash_axi.rdy && o_equihash_axi.val)) begin
            o_equihash_axi.copy_if(rx_typ1_if.to_struct());
            // First cycle has .sop set
            o_equihash_axi.sop <= ~sop_l;
            if (o_equihash_axi.val) begin
              sop_l <= 1;
              o_equihash_axi.sop <= 0;
            end
          end
        end
        
        // Wait for reply with result
        if (i_equihash_mask_val && ~verify_equihash_rpl_val) begin
          verify_equihash_rpl <= get_verify_equihash_rpl(i_equihash_mask, equihash_index);
          verify_equihash_rpl_val <= 1;
        end
        
        // Send result
        if (verify_equihash_rpl_val) begin
          if (~tx_arb_in_if[1].val || (tx_arb_in_if[1].rdy && tx_arb_in_if[1].val)) begin
            tx_arb_in_if[1].dat <= verify_equihash_rpl;
            tx_arb_in_if[1].val <= 1;
            tx_arb_in_if[1].sop <= typ1_wrd_cnt == $bits(verify_equihash_rpl_t)/8;
            tx_arb_in_if[1].eop <= typ1_wrd_cnt <= CORE_DAT_BYTS;
            tx_arb_in_if[1].mod <= typ1_wrd_cnt < CORE_DAT_BYTS ? typ1_wrd_cnt : 0;
            typ1_wrd_cnt <= (typ1_wrd_cnt > CORE_DAT_BYTS) ? (typ1_wrd_cnt - CORE_DAT_BYTS) : 0;
            verify_equihash_rpl <= verify_equihash_rpl >> CORE_DAT_BITS;
            if (typ1_wrd_cnt == 0) begin
              tx_arb_in_if[1].val <= 0;
              typ1_msg_state <= TYP1_IDLE;
            end
          end
        end
      end
      TYP1_IGNORE: begin
        rx_typ1_if_rdy <= 1;
        if (rx_typ1_if.rdy && rx_typ1_if.eop && rx_typ1_if.val)
          typ1_msg_state <= TYP1_IDLE;
      end
    endcase
  end
end

// Logic to mux the packet depending on its command type
logic msg_type, msg_type_l;
always_comb begin
  rx_int0_if.copy_if_comb(rx_int_if.to_struct());
  rx_int1_if.copy_if_comb(rx_int_if.to_struct());
  
  rx_int0_if.val = 0;
  rx_int1_if.val = 0;
  rx_int_if.rdy = 0;
  
  if (rx_int_if.sop && rx_int_if.val) begin
    if(header.cmd[8 +: 8] == 8'd0) begin
      msg_type = 0;
      rx_int0_if.val = rx_int_if.val;
      rx_int_if.rdy = rx_int0_if.rdy;
    end else begin
      msg_type = 1;
      rx_int1_if.val = rx_int_if.val;
      rx_int_if.rdy = rx_int1_if.rdy;
    end
  end else begin
    rx_int0_if.val = rx_int_if.val && (msg_type_l == 0);
    rx_int1_if.val = rx_int_if.val && (msg_type_l == 1);
    rx_int_if.rdy = (msg_type_l == 0) ? rx_int0_if.rdy : rx_int1_if.rdy;
    msg_type = msg_type_l;
  end
end
  
always_ff @ (posedge i_clk_core) begin
  if (i_rst_core || o_usr_rst) begin
    msg_type_l <= 0;
  end else begin
    if (rx_int_if.val && rx_int_if.rdy) begin
      if (rx_int_if.sop)
        msg_type_l <= msg_type;
    end
  end
end
  
// FIFO control queues for different message types
    
axi_stream_fifo #(
  .SIZE     ( 64            ),
  .DAT_BITS ( CORE_DAT_BITS )
)
cmd_fifo0 (
  .i_clk ( i_clk_core ),
  .i_rst ( i_rst_core || o_usr_rst ),
  .i_axi ( rx_int0_if ),
  .o_axi ( rx_typ0_if )
);

axi_stream_fifo #(
  .SIZE     ( 64            ),
  .DAT_BITS ( CORE_DAT_BITS )
)
cmd_fifo1 (
  .i_clk ( i_clk_core ),
  .i_rst ( i_rst_core || o_usr_rst ),
  .i_axi ( rx_int1_if ),
  .o_axi ( rx_typ1_if )
);

width_change_cdc_fifo #(
  .IN_DAT_BYTS  ( IN_DAT_BYTS   ),
  .OUT_DAT_BYTS ( CORE_DAT_BYTS ),
  .CTL_BITS     ( 8             ),
  .FIFO_ABITS   ( $clog2(1024/IN_DAT_BITS) ),
  .USE_BRAM     ( 1             ) 
) 
cdc_fifo_rx (
  .i_clk_a ( i_clk_if   ),
  .i_rst_a ( i_rst_if   || o_usr_rst ),
  .i_clk_b ( i_clk_core ),
  .i_rst_b ( i_rst_core || o_usr_rst ),
  .i_axi_a ( rx_if      ),
  .o_axi_b ( rx_int_if  )
);

// Arbitrator for sending messages back
packet_arb # (
  .NUM_IN   ( 2             ),
  .DAT_BYTS ( CORE_DAT_BYTS ),
  .CTL_BITS ( 8             )
) 
packet_arb_tx (
  .i_clk ( i_clk_core ),
  .i_rst ( i_rst_core || o_usr_rst ),

  .i_axi ( tx_arb_in_if ), 
  .o_axi ( tx_int_if    )
);

// Width change back to tx interface
width_change_cdc_fifo #(
  .IN_DAT_BYTS  ( CORE_DAT_BYTS ),
  .OUT_DAT_BYTS ( IN_DAT_BYTS   ),
  .CTL_BITS     ( 8             ),
  .FIFO_ABITS   ( $clog2(1024/CORE_DAT_BYTS) ),
  .USE_BRAM     ( 1             ) 
) 
cdc_fifo_tx (
  .i_clk_a ( i_clk_core ),
  .i_rst_a ( i_rst_core || o_usr_rst ),
  .i_clk_b ( i_clk_if   ),
  .i_rst_b ( i_rst_if   || o_usr_rst ),
  .i_axi_a ( tx_int_if  ),
  .o_axi_b ( tx_if      )
);
endmodule