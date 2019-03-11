/*
  The equihash_verif_top testbench.
  
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

module equihash_verif_top_tb();

import equihash_pkg::*;
import common_pkg::*;

logic clk, rst;
logic clk_300, rst_300;
equihash_bm_t mask;
logic mask_val;
logic start_346 = 0;
logic done_346;
logic start_346_error = 0;
logic done_346_error;

parameter DAT_BYTS = 8;
string my_file_path_s = get_file_dir(`__FILE__);

if_axi_stream #(.DAT_BYTS(DAT_BYTS)) header(clk);
if_axi_stream #(.DAT_BYTS(DAT_BYTS)) header_346(clk);
if_axi_stream #(.DAT_BYTS(DAT_BYTS)) header_346_error(clk);

// Need one for each test so we can multiplex the input
always_comb begin
  header_346.rdy = 0;
  header_346_error.rdy = 0;
  header.val = 0;
  
  if (start_346 && ~done_346) begin
    header_346.rdy = header.rdy;
    header.val = header_346.val;
    header.sop = header_346.sop;
    header.eop = header_346.eop;
    header.ctl = header_346.ctl;
    header.mod = header_346.mod;
    header.err = header_346.err;
    header.dat = header_346.dat;
  end
  
  if (start_346_error && ~done_346_error) begin
    header_346_error.rdy = header.rdy;
    header.val = header_346_error.val;
    header.sop = header_346_error.sop;
    header.eop = header_346_error.eop;
    header.ctl = header_346_error.ctl;
    header.mod = header_346_error.mod;
    header.err = header_346_error.err;
    header.dat = header_346_error.dat;
  end  
end

initial begin
  rst = 0;
  #100ns rst = 1;
  #100ns rst = 0;
end

initial begin
  rst_300 = 0;
  #100ns rst_300 = 1;
  #100ns rst_300 = 0;
end

initial begin
  clk = 0;
  forever #10ns clk = ~clk;
end

initial begin
  clk_300 = 0;
  forever #3ns clk_300 = ~clk_300;
end

file_to_axi #(
  .BINARY   ( 1        ),
  .DAT_BYTS ( DAT_BYTS ),
  .FP       ( 0        )
)
file_to_axi_block346 (
  .i_file  ({my_file_path_s, "/../data/block_346.bin"}),
  .i_clk   ( clk        ),
  .i_rst   ( rst        ),
  .i_start ( start_346  ),
  .o_done  ( done_346   ),
  .o_axi   ( header_346 )
);

file_to_axi #(
  .BINARY   ( 1        ),
  .DAT_BYTS ( DAT_BYTS ),
  .FP       ( 0        )
)
file_to_axi_block346_error (
  .i_file  ({my_file_path_s, "/../data/block_346_errors.bin"}),
  .i_clk   ( clk              ),
  .i_rst   ( rst              ),
  .i_start ( start_346_error  ),
  .o_done  ( done_346_error   ),
  .o_axi   ( header_346_error )
);

equihash_verif_top 
DUT (
  .i_clk      ( clk      ),
  .i_rst      ( rst      ),
  .i_clk_300  ( clk_300  ),
  .i_rst_300  ( rst_300  ),
  .i_axi      ( header   ),
  .o_mask     ( mask     ),
  .o_mask_val ( mask_val )
);

// This is a tests the sample block 346 in the block chain
task test_block_346();
begin
  $display("Running test_block_346...");
  start_346 = 1;
  
  while(!done_346 || !mask_val) @(posedge clk);
  
  assert (~(|mask)) else $fatal(1, "%m %t ERROR: test_block_346 mask was non-zero:\n%p", $time, mask);
  $display("test_block_346 PASSED");
  
end
endtask

// This is a tests the sample block 346 in the block chain but with deliberate errors
task test_block_346_error();
begin
  $display("Running test_block_346_error...");
  start_346_error = 1;
  
  while(!done_346_error || !mask_val) @(posedge clk);
  
  assert (&mask) else $fatal(1, "%m %t ERROR: test_block_346_error mask was zero but should of failed:\n%p", $time, mask);
  $display("test_block_346_error PASSED");
  
end
endtask

// Main testbench calls
initial begin
 #20us; // Let internal memories reset
  
 test_block_346_error();
 test_block_346();
 

 #10us $finish();

end

endmodule