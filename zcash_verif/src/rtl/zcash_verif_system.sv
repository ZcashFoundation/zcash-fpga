/*
  This takes in an AXI stream of a block and runs verification
  checks (detailed in the architecture document). When all the checks are
  completed the o_val will go high, and o_mask bit mask will be 1 for any
  checks that failed.
  
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

module zcash_verif_system(
  input i_clk, i_rst,
  
  if_axi_stream.sink  i_axi,
  output logic [31:0] o_mask,
  output logic        o_val
);
  
if_axi_stream #(.DAT_BYTS(128)) blake2b_in(clk);
if_axi_stream #(.DAT_BYTS(64)) blake2b_out(clk);


always_ff @ (posedge i_clk) begin
  i_data.rdy <= blake2b_in.rdy;
  blake2b_in.val <= i_data.val;
  blake2b_in.sop <= i_data.sop;
  blake2b_in.eop <= i_data.eop;
  blake2b_in.dat <= i_data.dat;
  blake2b_in.err <= 0;
  blake2b_in.mod <= 0;
  blake2b_in.ctl <= 0;
  
  blake2b_out.rdy <= 1; 
  o_valid <= (blake2b_out.val && blake2b_out.dat == {64{1'b1}});
end
  
  
// The Blake2 core for generating hashes

logic [64*8-1:0] blake2_parameters;
always_comb begin
  blake2_parameters = {32'd0, 8'd1, 8'd1, 8'd0, 8'd64};
end

blake2_top #(
  .EQUIHASH( 1 )
)
blake2_top (
  .i_clk        ( i_clk             ), 
  .i_rst        ( i_rst             ),
  .i_byte_len   ( 8'd128            ),
  .i_parameters ( blake2_parameters ),
  .i_block      ( blake2b_in        ),
  .o_hash       ( blake2b_out       )
);
  
endmodule