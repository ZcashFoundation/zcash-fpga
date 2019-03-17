/*
  The zcash_fpga_top testbench.
  
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
`timescale 1ps/1ps
module zcash_fpga_top_tb();

import zcash_fpga_pkg::*;
import equihash_pkg::*;
import common_pkg::*;

logic clk_if, rst_if;
logic clk_300, rst_300;
logic clk_200, rst_200;

localparam CLK200_PERIOD = 600;
localparam CLK300_PERIOD = 400;
localparam IF_CLK_PERIOD = 1000;

parameter DAT_BYTS = 8;
parameter IF_DAT_BYTS = 4;
string my_file_path_s = get_file_dir(`__FILE__);

if_axi_stream #(.DAT_BYTS(IF_DAT_BYTS)) tx_if(clk_if);
if_axi_stream #(.DAT_BYTS(IF_DAT_BYTS)) tx_346_if(clk_if);
if_axi_stream #(.DAT_BYTS(IF_DAT_BYTS)) rx_if(clk_if);

logic start_346 = 0;
logic done_346 = 0;

initial begin
  rst_300 = 0;
  repeat(2) #(20*CLK300_PERIOD) rst_300 = ~rst_300;
end

initial begin
  clk_300 = 0;
  forever #CLK300_PERIOD clk_300 = ~clk_300;
end

initial begin
  rst_200 = 0;
  repeat(2) #(20*CLK200_PERIOD) rst_200 = ~rst_200;
end

initial begin
  clk_200 = 0;
  forever #CLK200_PERIOD clk_200 = ~clk_200;
end

initial begin
  rst_if = 0;
 repeat(2) #(20*IF_CLK_PERIOD) rst_if = ~rst_if;
end

initial begin
  clk_if = 0;
  forever #IF_CLK_PERIOD clk_if = ~clk_if;
end

// Need one for each test so we can multiplex the input
always_comb begin
  tx_346_if.rdy = 0;
  tx_if.val = 0;
  
  if (start_346 && ~done_346) begin
    tx_346_if.rdy = tx_if.rdy;
    tx_if.val = tx_346_if.val;
    tx_if.sop = tx_346_if.sop;
    tx_if.eop = tx_346_if.eop;
    tx_if.ctl = tx_346_if.ctl;
    tx_if.mod = tx_346_if.mod;
    tx_if.err = tx_346_if.err;
    tx_if.dat = tx_346_if.dat;
  end
  
end


file_to_axi #(
  .BINARY   ( 1           ),
  .DAT_BYTS ( IF_DAT_BYTS ),
  .FP       ( 0           )
)
file_to_axi_block346 (
  .i_file  ({my_file_path_s, "/../data/block_346_with_header.bin"}),
  .i_clk   ( clk_if    ),
  .i_rst   ( rst_if    ),
  .i_start ( start_346 ),
  .o_done  ( done_346  ),
  .o_axi   ( tx_346_if )
);


zcash_fpga_top #(
  .IF_DAT_BYTS   ( IF_DAT_BYTS ),
  .CORE_DAT_BYTS ( DAT_BYTS    )
  )
DUT(
  // Clocks and resets
  .i_clk_200 ( clk_200 ),
  .i_rst_200 ( rst_200 ),
  .i_clk_300 ( clk_300 ),
  .i_rst_300 ( rst_300 ),
  .i_clk_if ( clk_if ),
  .i_rst_if ( rst_if ),
  .rx_if ( tx_if ),
  .tx_if ( rx_if )
);

// This is a tests the sample block 346 in the block chain with the header to verify the equihash solution
// Also send a reset first and then status request to check it is correct
task test_block_346_equihash();
begin
  header_t  header;
  fpga_status_rpl_t fpga_status_rpl;
  fpga_reset_rpl_t fpga_reset_rpl;
  verify_equihash_rpl_t verify_equihash_rpl;
  integer signed get_len1, get_len2, get_len3;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat1, get_dat2, get_dat3;
  logic fail = 0;
  $display("Running test_block_346_equihash...");
  
  fork 
    begin
      // First send reset
      header.cmd = RESET_FPGA;
      header.len = $bits(header_t)/8;
      tx_if.put_stream(header, $bits(header)/8);
      // Wait for tx_if.rdy to go low (reset started)
      while (tx_if.rdy) @(posedge tx_if.i_clk);
      // Then send data
      start_346 = 1;
      while(!done_346) @(posedge clk_if);
      // Then status request
      header.cmd = FPGA_STATUS;
      header.len = $bits(header_t)/8;
      tx_if.put_stream(header, $bits(header)/8);
    end
    begin
      rx_if.get_stream(get_dat1, get_len1); // reset rpl
      rx_if.get_stream(get_dat2, get_len2); // status rpl
      rx_if.get_stream(get_dat3, get_len3); // equihash rpl
    end
  join
  
  fpga_reset_rpl = get_dat1;
  verify_equihash_rpl = get_dat3;
  fpga_status_rpl = get_dat2;
  
  fail |= get_len3 != $bits(verify_equihash_rpl_t)/8;
  fail |= verify_equihash_rpl.hdr.cmd != VERIFY_EQUIHASH_RPL;
  fail |= verify_equihash_rpl.hdr.len != $bits(verify_equihash_rpl_t)/8;
  fail |= verify_equihash_rpl.index != 1;
  fail |= verify_equihash_rpl.bm != 0;
  assert (~fail) else $fatal(1, "%m %t ERROR: test_block_346_equihash equihash rply was wrong:\n%p", $time, verify_equihash_rpl);
  
  fail |= get_len2 != $bits(fpga_status_rpl_t)/8;
  fail |= fpga_status_rpl.hdr.cmd != FPGA_STATUS_RPL;
  fail |= fpga_status_rpl.hdr.len != $bits(fpga_status_rpl_t)/8;
  fail |= fpga_status_rpl.hdr.len != get_len2;
  fail |= fpga_status_rpl.version != FPGA_VERSION;
  fail |= fpga_status_rpl.build_host != "test";
  fail |= fpga_status_rpl.build_date != "20180311";
  fail |= fpga_status_rpl.fpga_state == 1;
  assert (~fail) else $fatal(1, "%m %t ERROR: test_block_346_equihash status reply was wrong:\n%p", $time, fpga_status_rpl);
  
  fail |= get_len1 != $bits(fpga_reset_rpl_t)/8;
  fail |= fpga_reset_rpl.hdr.cmd != RESET_FPGA_RPL;
  assert (~fail) else $fatal(1, "%m %t ERROR: test_block_346_equihash reset reply was wrong:\n%p", $time, fpga_reset_rpl);
  
  $display("test_block_346_equihash PASSED");
  
end
endtask


// Main testbench calls
initial begin
  rx_if.rdy = 0;
  #20us; // Let internal memories reset
  
  test_block_346_equihash();
  test_ignored_message();
  
  #1us $finish();

end

endmodule