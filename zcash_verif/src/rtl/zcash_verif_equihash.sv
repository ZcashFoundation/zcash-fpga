/*
  This verifies that a Zcash equihash solution is correct,
  input is an axi stream of the block header. This block checks:
    1. XOR of EquihashGen() is 0
    2. Ordering
    3. No duplicates
    4. Difficulty passes
  
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
logic [SOL_BITS-1:0]             ram_out;

logic [64*8-1:0] parameters;
logic [7:0]      byte_len;
logic            all_checks_done;



if_axi_stream #(.DAT_BYTS(BLAKE2B_DIGEST_BYTS), .CTL_BYTS(1)) blake2b_out_hash(i_clk);
if_axi_stream #(.DAT_BYTS(EQUIHASH_BLAKE2B_PIPE == 0 ? 128 : EQUIHASH_GEN_BYTS )) blake2b_in_hash(i_clk);

// We write the block into a port as it comes in and then read from the b port
if_ram #(.RAM_WIDTH(DAT_BITS), .RAM_DEPTH(SOL_LIST_BYTS/DAT_BYTS)) equihash_sol_bram_if_a (i_clk, i_rst);
if_ram #(.RAM_WIDTH(DAT_BITS), .RAM_DEPTH(SOL_LIST_BYTS/DAT_BYTS)) equihash_sol_bram_if_b (i_clk, i_rst);
logic [DAT_BITS-1:0] equihash_sol_bram_if_b_l;

enum {STATE_IDLE = 0,
      STATE_DATA_WRITE = 1,
      STATE_FINISH_WAIT = 2} ram_state;

// State machine for controlling writing equihash solution into the RAM and registering the header
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    i_axi.rdy <= 0;
    equihash_sol_bram_if_a.reset_source();
    cblockheader <= 0;
    cblockheader_byts <= 0;
    cblockheader_val <= 0;
    ram_state <= STATE_IDLE;
  end else begin
    // Defaults
    equihash_sol_bram_if_a.we <= 1;
    equihash_sol_bram_if_a.en <= 1;
    equihash_sol_bram_if_a.d <= i_axi.dat;
    
    if (i_axi.val && i_axi.rdy && ~cblockheader_val) begin
      cblockheader <= {cblockheader, i_axi.dat};
      cblockheader_val <= (cblockheader_byts + DAT_BYTS) >= $bits(cblockheader_t)/8;
      cblockheader_byts <= cblockheader_byts + DAT_BYTS;
    end

    case (ram_state)
      // This state we are waiting for an input block
      STATE_IDLE: begin
        i_axi.rdy <= 1;
        if (i_axi.val && i_axi.rdy) begin
          ram_state <= STATE_DATA_WRITE;
          equihash_sol_bram_if_a.a <= equihash_sol_bram_if_a.a + 1;
        end
      end
      // Here we are checking header values as well as populating the RAM
      STATE_DATA_WRITE: begin
        if (i_axi.val && i_axi.rdy) begin
          equihash_sol_bram_if_a.a <= equihash_sol_bram_if_a.a + 1;
          if (i_axi.eop) begin
            i_axi.rdy <= 0;
            ram_state <= STATE_FINISH_WAIT;
          end
        end
      end
      // Here we are have finished populating RAM and waiting for all checks to finish
      STATE_FINISH_WAIT: begin
        equihash_sol_bram_if_a.we <= 0;
        equihash_sol_bram_if_a.a <= equihash_sol_bram_if_a.a;
        if (all_checks_done) begin
          ram_state <= STATE_IDLE;
          i_axi.rdy <= 1;
          cblockheader_val <= 0;
          equihash_sol_bram_if_a.a <= 0;
        end
      end
    endcase
  end
end

// State machine for controlling the hash calculation
// and checking the header values
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mask_val <= 0;
    o_mask <= 0;
    sol_hash_xor <= 0;
    blake2b_in_hash.reset_source();
    blake2b_out_hash.rdy <= 0;
    equihash_sol_bram_if_b.reset_source();
    all_checks_done <= 0;
    sol_cnt_in <= 0;
    sol_cnt_out <= 0;
    sol_pos <= 0;
    equihash_sol_bram_if_b_l <= 0;
  end else begin
    // Defaults
    equihash_sol_bram_if_b.re <= 1;
    equihash_sol_bram_if_b.en <= 1;
    blake2b_out_hash.rdy <= 1;
    blake2b_in_hash.sop <= 1;
    blake2b_in_hash.eop <= 1;
    blake2b_in_hash.val <= 0;
    
    if (ram_state == STATE_IDLE) begin
      equihash_sol_bram_if_b.a <= $bits(cblockheader_t)/DAT_BITS;
      sol_pos <= $bits(cblockheader_t) % DAT_BITS;
      sol_cnt_out <= 0;
      sol_cnt_in <= 0;
      blake2b_in_hash.val <= 0;
      o_mask_val <= 0;
      o_mask <= 0;
    end
    
    if (cblockheader_val) begin
      equihash_gen_in.bits <= cblockheader.bits;
      equihash_gen_in.my_time <= cblockheader.my_time;
      equihash_gen_in.hash_reserved <= 0;
      equihash_gen_in.hash_merkle_root <= cblockheader.hash_merkle_root;
      equihash_gen_in.hash_prev_block <= cblockheader.hash_prev_block;
      equihash_gen_in.version <= cblockheader.version;
      equihash_gen_in.nonce <= cblockheader.nonce;
      for (int i = 0; i < SOL_BITS; i++)
        if (i + sol_pos >= DAT_BITS)
          equihash_gen_in.index[i] <= equihash_sol_bram_if_b_l[i + sol_pos - DAT_BITS];
        else
          equihash_gen_in.index[i] <= equihash_sol_bram_if_b.q[i+sol_pos];
    end
    
    // We can start loading the hash block
    if((sol_cnt_in < SOL_LIST_LEN - 1) && 
        blake2b_in_hash.rdy &&
        (equihash_sol_bram_if_a.a >= $bits(cblockheader_t)/8 + DAT_BYTS)) begin
      blake2b_in_hash.val <= 1; // TODO control if we take more than one hash per clock
      sol_cnt_in <= sol_cnt_in + 1;
      sol_pos <= sol_pos + SOL_BITS;
      // Calculate if we should increase our read pointer
      if (sol_pos + 2*SOL_BITS >= DAT_BITS) begin
        equihash_sol_bram_if_b_l <= equihash_sol_bram_if_b.q; // Latch current output as we might need some bits
        equihash_sol_bram_if_b.a <= equihash_sol_bram_if_b.a + 1;
      end
      
      //TODO here we also need to check the ordering, and duplicates?
      
    end

    // When we start getting the hash results, start XORing them
    if (blake2b_out_hash.val) begin
      sol_hash_xor <= hash_solution(sol_hash_xor, blake2b_out_hash.dat);
      sol_cnt_out <= sol_cnt_out + 1;
    end
    
    if (sol_cnt_out == SOL_LIST_LEN - 1) begin
      o_mask.XOR_FAIL <= |sol_hash_xor;
      o_mask_val <= 1;
      sol_cnt_out <= sol_cnt_out;
      equihash_sol_bram_if_b.a <= 0;
    end
  end
end

// Constants
always_comb begin
  parameters = {'0, 8'd1, 8'd1, 8'd0, BLAKE2B_DIGEST_BYTS};
  parameters[48*8-1 +: 16*8] = POW_TAG; 
  blake2b_in_hash.dat = equihash_gen_in;
end

// Function to OR the hash output depending on equihash parameters
function hash_solution(input [N-1:0] curr, input [N*INDICIES_PER_HASH-1:0] in);
  for (int i = 0; i < INDICIES_PER_HASH; i++)
    curr = curr ^ in[i*N +: N];
  return curr;
endfunction

// Instantiate the Blake2b block
generate if ( EQUIHASH_BLAKE2B_PIPE == 0 ) begin: BLAKE2B_GEN
  blake2b_top DUT (
    .i_clk ( i_clk ),
    .i_rst ( i_rst ),
    .i_parameters ( parameters ),
    .i_byte_len   ( EQUIHASH_GEN_BYTS ),
    .i_block ( blake2b_in_hash ),
    .o_hash  ( blake2b_out_hash )
  );
end else begin
  blake2b_pipe_top #(
    .MSG_LEN      ( EQUIHASH_GEN_BYTS ),
    .MSG_VAR_BYTS ( 4                 ),   // Only lower 4 bytes of input to hash change
    .CTL_BITS     ( 8                 )
  )
  DUT (
    .i_clk ( i_clk ),
    .i_rst ( i_rst ),
    .i_parameters ( parameters        ),
    .i_byte_len   ( EQUIHASH_GEN_BYTS ),
    .i_block ( blake2b_in_hash  ),
    .o_hash  ( blake2b_out_hash )
  );
end
endgenerate

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