/*
  This verifies that a Zcash equihash solution is correct,
  input is an axi stream of the block header. This block checks:
    1. XOR of EquihashGen() is 0
    2. Ordering
    3. No duplicates
    4. Difficulty passes
  
  Code is split up into 3 main always blocks, one for loading RAM, one for parsing
  output and loading the Blake2b block, and the final for running checks.
  
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

module zcash_verif_equihash
  import zcash_verif_pkg::*;
#(
  parameter DAT_BYTS = 8 
)(
  input i_clk, i_rst,

  if_axi_stream.sink   i_axi,
  output equihash_bm_t o_mask,
  output logic         o_mask_val
);
 
localparam [7:0] EQUIHASH_GEN_BYTS = $bits(equihash_gen_in_t)/8;
localparam DAT_BITS = DAT_BYTS*8;

cblockheader_t                              cblockheader;
logic                                       cblockheader_val;
logic [$clog2($bits(cblockheader_t)/8)-1:0] cblockheader_byts;

equihash_gen_in_t                equihash_gen_in;
logic [N-1:0]                    sol_hash_xor;
logic [$clog2(SOL_LIST_LEN)-1:0] sol_cnt_out, sol_cnt_in; // This tracks how many solutions we have XORed
logic [$clog2(DAT_BITS)-1:0]     sol_pos;                 // This tracks the pos in our DAT_BITS RAM output
logic [64*8-1:0] parameters;
logic [7:0]      byte_len;
logic [DAT_BITS-1:0] sol_ram_byte_bit_flip;



if_axi_stream #(.DAT_BYTS(BLAKE2B_DIGEST_BYTS), .CTL_BYTS(1)) blake2b_out_hash(i_clk);
if_axi_stream #(.DAT_BYTS(EQUIHASH_GEN_BYTS)) blake2b_in_hash(i_clk);

// We write the block into a port as it comes in and then read from the b port
if_ram #(.RAM_WIDTH(DAT_BITS), .RAM_DEPTH(SOL_LIST_BYTS/DAT_BYTS)) equihash_sol_bram_if_a (i_clk, i_rst);
if_ram #(.RAM_WIDTH(DAT_BITS), .RAM_DEPTH(SOL_LIST_BYTS/DAT_BYTS)) equihash_sol_bram_if_b (i_clk, i_rst);
logic [DAT_BITS-1:0] equihash_sol_bram_if_b_l;
logic [1:0] equihash_sol_bram_read;

enum {STATE_WR_IDLE = 0,
      STATE_WR_DATA = 1,
      STATE_WR_WAIT = 2} ram_wr_state;
      
enum {STATE_RD_IDLE = 0,
      STATE_RD_DATA = 1,
      STATE_RD_WAIT = 2} ram_rd_state;
      
enum {STATE_CHK_IDLE = 0,
      STATE_CHK_DATA = 1,
      STATE_CHK_WAIT = 2} chk_state;      

// State machine for controlling writing equihash solution into the RAM and registering the header
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    i_axi.rdy <= 0;
    equihash_sol_bram_if_a.reset_source();
    cblockheader <= 0;
    cblockheader_byts <= 0;
    cblockheader_val <= 0;
    ram_wr_state <= STATE_WR_IDLE;
  end else begin
    // Defaults
    equihash_sol_bram_if_a.we <= 1;
    equihash_sol_bram_if_a.en <= 1;
    equihash_sol_bram_if_a.d <= i_axi.dat;
    
    if (i_axi.val && i_axi.rdy && ~cblockheader_val) begin
      cblockheader[cblockheader_byts*8 +: DAT_BITS] <= i_axi.dat;
      cblockheader_val <= (cblockheader_byts + DAT_BYTS) > $bits(cblockheader_t)/8;
      cblockheader_byts <= cblockheader_byts + DAT_BYTS;
    end

    case (ram_wr_state)
      // This state we are waiting for an input block
      STATE_WR_IDLE: begin
        i_axi.rdy <= 1;
        if (i_axi.val && i_axi.rdy) begin
          ram_wr_state <= STATE_WR_DATA;
          equihash_sol_bram_if_a.a <= 0;
        end
      end
      // Here we are checking header values as well as populating the RAM
      STATE_WR_DATA: begin
        if (i_axi.val && i_axi.rdy) begin
          equihash_sol_bram_if_a.a <= equihash_sol_bram_if_a.a + 1;
          if (i_axi.eop) begin
            i_axi.rdy <= 0;
            ram_wr_state <= STATE_WR_WAIT;
          end
        end
      end
      // Here we are have finished populating RAM and waiting for all checks to finish
      STATE_WR_WAIT: begin
        equihash_sol_bram_if_a.we <= 0;
        equihash_sol_bram_if_a.a <= equihash_sol_bram_if_a.a;
        if (chk_state == STATE_CHK_WAIT) begin
          ram_wr_state <= STATE_WR_IDLE;
          i_axi.rdy <= 1;
          cblockheader_val <= 0;
          equihash_sol_bram_if_a.a <= 0;
        end
      end
    endcase
  end
end

// State machine for loading the output of RAM into the Blake2b block
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    blake2b_in_hash.reset_source();
    equihash_sol_bram_if_b.reset_source();
    sol_cnt_in <= 0;
    sol_pos <= 0;
    equihash_sol_bram_if_b_l <= 0;
    equihash_gen_in <= 0;
    equihash_sol_bram_read <= 0;
    ram_rd_state <= STATE_RD_IDLE;
  end else begin
    // Defaults
    equihash_sol_bram_if_b.re <= 1;
    equihash_sol_bram_if_b.en <= 1;
    blake2b_in_hash.sop <= 1;
    blake2b_in_hash.eop <= 1;
    blake2b_in_hash.val <= 0;
    equihash_sol_bram_read <= equihash_sol_bram_read << 1;
    
    case(ram_rd_state)
      STATE_RD_IDLE: begin
        if (~|equihash_sol_bram_read)
          equihash_sol_bram_if_b.a <= $bits(cblockheader_t)/DAT_BITS;
        sol_pos <= 3*8 + ($bits(cblockheader_t) % DAT_BITS); // Add on 3*8 as this encodes the size of solution
        sol_cnt_in <= 0;
        blake2b_in_hash.val <= 0;
        
        //First case has special state       
        if (equihash_sol_bram_if_a.a >= ($bits(cblockheader_t)/8) + (DAT_BYTS*2)) begin
          if (~|equihash_sol_bram_read) begin
            equihash_sol_bram_if_b_l <= sol_ram_byte_bit_flip;// equihash_sol_bram_if_b.q;
            equihash_sol_bram_if_b.a <= equihash_sol_bram_if_b.a + 1;
            equihash_sol_bram_read[0] <= 1;
          end
          if (equihash_sol_bram_read[1])
            ram_rd_state <= STATE_RD_DATA;          
        end
      end
      STATE_RD_DATA: begin
        equihash_gen_in <= 0;
        equihash_gen_in.bits <= cblockheader.bits;
        equihash_gen_in.my_time <= cblockheader.my_time;
        equihash_gen_in.hash_merkle_root <= cblockheader.hash_merkle_root;
        equihash_gen_in.hash_prev_block <= cblockheader.hash_prev_block;
        equihash_gen_in.version <= cblockheader.version;
        equihash_gen_in.nonce <= cblockheader.nonce;
        // Load the solution, need to flip it
        for (int i = 0; i < SOL_BITS; i++)
          if ((sol_pos + SOL_BITS) >= DAT_BITS && (i + sol_pos < DAT_BITS))
            equihash_gen_in.index[SOL_BITS-1-i] <= equihash_sol_bram_if_b_l[i + sol_pos];
          else
            equihash_gen_in.index[SOL_BITS-1-i] <= /*equihash_sol_bram_if_b.q*/sol_ram_byte_bit_flip[(i+sol_pos) % DAT_BITS];
      
        // Stay 2 clocks behind the RAM write
        if ((equihash_sol_bram_if_a.a*DAT_BYTS + DAT_BYTS) >= (equihash_sol_bram_if_b.a + $bits(cblockheader_t)/DAT_BITS) ||
             ram_wr_state == STATE_WR_WAIT) begin
          // Check if we need to load next memory address
          if (sol_pos + 2*SOL_BITS >= DAT_BITS && ~|equihash_sol_bram_read) begin
            equihash_sol_bram_if_b_l <= sol_ram_byte_bit_flip;
            equihash_sol_bram_if_b.a <= equihash_sol_bram_if_b.a + 1;  
            equihash_sol_bram_read[0] <= 1; 
          end
                      
          // Load input into Blake2b block
          blake2b_in_hash.val <= 1;
          sol_cnt_in <= sol_cnt_in + 1;
          sol_pos <= sol_pos + SOL_BITS;
          if (sol_cnt_in == SOL_LIST_LEN - 2)
            ram_rd_state <= STATE_RD_WAIT;
        end
      
      end
      STATE_RD_WAIT: begin
        if (chk_state == STATE_CHK_WAIT) begin
          ram_rd_state <= STATE_RD_IDLE;
        end
      end
    endcase
    

  end
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mask_val <= 0;
    o_mask <= 0;
    sol_hash_xor <= 0;
    blake2b_out_hash.rdy <= 0;
    sol_cnt_out <= 0;
    chk_state <= STATE_CHK_IDLE;
  end else begin
    // Defaults
    blake2b_out_hash.rdy <= 1;
    
    case(chk_state)
      STATE_CHK_IDLE: begin
        sol_cnt_out <= 0;
        o_mask_val <= 0;
        o_mask <= 0;
        sol_hash_xor <= 0;
        if (ram_rd_state == STATE_RD_DATA)
          chk_state <= STATE_CHK_DATA;
      end
      STATE_CHK_DATA: begin

        // When we start getting the hash results, start XORing them
        if (blake2b_out_hash.val) begin
          sol_hash_xor <= hash_solution(sol_hash_xor, blake2b_out_hash.dat);
          sol_cnt_out <= sol_cnt_out + 1;
          //TODO here we also need to check the ordering, and duplicates?
        end
        
        if (sol_cnt_out == SOL_LIST_LEN - 1) begin
          o_mask.XOR_FAIL <= |sol_hash_xor;
          o_mask_val <= 1;
          chk_state <= STATE_CHK_WAIT;
        end
                
      end
      STATE_CHK_WAIT: begin
        if (ram_rd_state == STATE_RD_IDLE && ram_wr_state == STATE_WR_IDLE)
          chk_state <= STATE_CHK_IDLE;
      end
    endcase
  end
end
// Constants
always_comb begin
  parameters = {'0, 8'd1, 8'd1, 8'd0, BLAKE2B_DIGEST_BYTS};
  parameters[48*8-1 +: 16*8] = POW_TAG; 
  blake2b_in_hash.dat = equihash_gen_in;
  for (int i = 0; i < DAT_BYTS; i++)
    sol_ram_byte_bit_flip[i*8 +: 8] = flip_bit_byte(equihash_sol_bram_if_b.q[i*8 +: 8]);
end

// Function to OR the hash output depending on equihash parameters
function [N-1:0] hash_solution(input [N-1:0] curr, input [N*INDICIES_PER_HASH-1:0] in);
  hash_solution = curr;
  for (int i = 0; i < INDICIES_PER_HASH; i++)
    hash_solution = hash_solution ^ in[i*N +: N];
endfunction

// Function to convert bit order in each byte of the solution list
function [7:0] flip_bit_byte(input [7:0] in);
  for (int i = 0; i < 8; i++)
    flip_bit_byte[8-1-i] = in[i];
endfunction

// Instantiate the Blake2b block - use high performance pipelined version
localparam [EQUIHASH_GEN_BYTS*8-1:0] EQUIHASH_GEN_BYTS_BM = {{(EQUIHASH_GEN_BYTS*8-21){1'b0}}, {21{1'b1}}}; // Only lower 21 bits of input to hash change
blake2b_pipe_top #(
  .MSG_LEN    ( EQUIHASH_GEN_BYTS    ),
  .MSG_VAR_BM ( EQUIHASH_GEN_BYTS_BM ),   
  .CTL_BITS   ( 8                    )
)
blake2b_pipe_top_i (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_parameters ( parameters        ),
  .i_byte_len   ( EQUIHASH_GEN_BYTS ),
  .i_block ( blake2b_in_hash  ),
  .o_hash  ( blake2b_out_hash )
);


// Memory to store the equihash solution as it comes in. We use dual port,
// one port for writing and one port for reading
bram #(
  .RAM_WIDTH       ( DAT_BITS               ),
  .RAM_DEPTH       ( SOL_LIST_BYTS/DAT_BYTS ),
  .RAM_PERFORMANCE ( "LOW_LATENCY"          )  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
) equihash_sol_bram (
  .a ( equihash_sol_bram_if_a ),
  .b ( equihash_sol_bram_if_b )
);


// Some checks to make sure our data structures are correct:
initial begin
  assert ($bits(equihash_gen_in_t)/8 == 144) else $fatal(1, "%m %t ERROR: equihash_gen_in_t is not 144 bytes in size", $time);
end

endmodule