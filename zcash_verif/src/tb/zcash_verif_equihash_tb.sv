/*
  The zcash_verif_equihash testbench.
  
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

module zcash_verif_equihash_tb();

import zcash_verif_pkg::*;
import common_pkg::*;

logic clk, rst;
equihash_bm_t mask;
logic mask_val;
logic start_241 = 0;
logic done_241;

parameter DAT_BYTS = 8;
string my_file_path_s = get_file_dir(`__FILE__);

if_axi_stream #(.DAT_BYTS(DAT_BYTS)) header(clk);
if_axi_stream #(.DAT_BYTS(DAT_BYTS)) header_241(clk);

always_comb begin
  header_241.rdy = 0;
  if (start_241) begin
    header_241.rdy = header.rdy;
    header.val = header_241.val;
    header.sop = header_241.sop;
    header.eop = header_241.eop;
    header.ctl = header_241.ctl;
    header.mod = header_241.mod;
    header.err = header_241.err;
    header.dat = header_241.dat;
  end
end

initial begin
  rst = 0;
  #100ns rst = 1;
  #100ns rst = 0;
end

initial begin
  clk = 0;
  forever #10ns clk = ~clk;
end

file_to_axi #(
  .BINARY   ( 1        ),
  .DAT_BYTS ( DAT_BYTS ),
  .FP       ( 0        )
)
file_to_axi_block241 (
  .i_file  ({my_file_path_s, "/../data/block_346.bin"}),
  .i_clk   ( clk        ),
  .i_rst   ( rst        ),
  .i_start ( start_241  ),
  .o_done  ( done_241   ),
  .o_axi   ( header_241 )
);

zcash_verif_equihash 
DUT (
  .i_clk      ( clk      ),
  .i_rst      ( rst      ),
  .i_axi      ( header   ),
  .o_mask     ( mask     ),
  .o_mask_val ( mask_val )
);

// This is a tests the sample block 346 in the block chain
task test_block_346();
begin
  $display("Running test_block_346...");
  start_241 = 1;
  
  
  while(!done_241 && !mask_val) @(posedge clk);
  
  assert (~(|mask)) else $fatal(1, "%m %t ERROR: test_block_346 mask was non-zero", $time);
  assert (~mask.XOR_FAIL) else $fatal(1, "%m %t ERROR: test_block_346 failed XOR mask check", $time);
  $display("test_block_346 PASSED");
  
end
endtask

// Main testbench calls
initial begin
  #200ns;
  
 test_block_346();

 #10us $finish();

end

endmodule