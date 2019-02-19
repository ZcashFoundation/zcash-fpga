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
(
  input i_clk, i_rst,

  if_axi_stream.sink   i_axi,
  output equihash_bm_t o_mask,
  output logic         o_mask_val
);
  
cblockheader_t cblockheader;
logic [COLLISION_BIT_LEN-1:0] sol_hash_xor;
logic [64*8-1:0] parameters;
logic [7:0] byte_len;

if_axi_stream #(.DAT_BYTS(INDICIES_PER_HASH * N), .CTL_BYTS(1)) blake2b_out_hash(clk);
if_axi_stream #(.DAT_BYTS(EQUIHASH_BLAKE2B_PIPE == 0 ? 128 : $bits(equihash_gen_in_t)/8 )) blake2b_in_hash(clk);

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    i_axi.rdy <= 0;
    o_mask_val <= 0;
    o_mask <= 0;
    sol_hash_xor <= 0;
    blake2b_in_hash.reset_source();
    blake2b_out_hash.rdy <= 0;
  end else begin
    blake2b_out_hash.rdy <= 1;
    i_axi.rdy <= 1;
    
    
    
  end
end

// Constants that do not change
always_comb begin
  byte_len = $bits(equihash_gen_in_t)/8;
  parameters = {'0, 8'd1, 8'd1, 8'd0, byte_len};
  parameters[48*8-1 +: 16*8] = POW_TAG;
end

generate if ( EQUIHASH_BLAKE2B_PIPE == 0 ) begin: BLAKE2B_GEN
  blake2b_top DUT (
    .i_clk ( i_clk ),
    .i_rst ( i_rst ),
    .i_parameters ( parameters ),
    .i_byte_len   ( byte_len   ),
    .i_block ( blake2b_in_hash ),
    .o_hash  ( blake2b_out_hash )
  );
end else begin
  blake2b_pipe_top #(
    .MSG_LEN  ( $bits(equihash_gen_in_t)/8 ),
    .CTL_BITS ( 8                          )
  )
  DUT (
    .i_clk ( i_clk ),
    .i_rst ( i_rst ),
    .i_parameters ( parameters ),
    .i_byte_len   ( byte_len ),
    .i_block ( blake2b_in_hash  ),
    .o_hash  ( blake2b_out_hash )
  );
end
endgenerate

// Some checks to make sure our data structures are correct:

initial begin
  assert ($bits(equihash_gen_in_t)/8 == 144) else $fatal(1, "%m %t ERROR: equihash_gen_in_t is not 144 bytes in size", $time);
end

endmodule