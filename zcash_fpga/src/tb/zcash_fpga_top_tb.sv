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
import secp256k1_pkg::*;
import equihash_pkg::*;
import common_pkg::*;

logic clk_if, rst_if;
logic clk_100, rst_100;
logic clk_300, rst_300;
logic clk_200, rst_200;

localparam CLK100_PERIOD = 10000;
localparam CLK200_PERIOD = 5000;
localparam CLK300_PERIOD = 3333;
localparam IF_CLK_PERIOD = 20000;

parameter DAT_BYTS = 8;
string my_file_path_s = get_file_dir(`__FILE__);

if_axi_stream #(.DAT_BYTS(DAT_BYTS)) tx_if(clk_if);
if_axi_stream #(.DAT_BYTS(DAT_BYTS)) tx_if_test(clk_if);
if_axi_stream #(.DAT_BYTS(DAT_BYTS)) tx_346_if(clk_if);
if_axi_stream #(.DAT_BYTS(DAT_BYTS)) rx_if(clk_if);

if_axi_lite #(.A_BITS(32)) axi_lite_if(clk_if);

logic start_346 = 0;
logic done_346 = 0;

initial begin
  rst_100 = 0;
  #(CLK100_PERIOD) rst_100 = 1;
  #(100*CLK100_PERIOD) rst_100 = 0;
end

initial begin
  clk_100 = 0;
  forever #(CLK100_PERIOD/2) clk_100 = ~clk_100;
end

initial begin
  rst_300 = 0;
  #(CLK300_PERIOD) rst_300 = 1;
  #(100*CLK300_PERIOD) rst_300 = 0;
end

initial begin
  clk_300 = 0;
  forever #(CLK300_PERIOD/2) clk_300 = ~clk_300;
end

initial begin
  rst_200 = 0;
  #(CLK200_PERIOD) rst_200 = 1;
  #(100*CLK200_PERIOD) rst_200 = 0;
end

initial begin
  clk_200 = 0;
  forever #(CLK200_PERIOD/2) clk_200 = ~clk_200;
end

initial begin
  rst_if = 0;
  #(IF_CLK_PERIOD) rst_if = 1;
  #(20*IF_CLK_PERIOD) rst_if = 0;
end

initial begin
  clk_if = 0;
  forever #(IF_CLK_PERIOD/2) clk_if = ~clk_if;
end

// Need one for each test so we can multiplex the input
always_comb begin
  if (start_346 && ~done_346) begin
    tx_346_if.rdy = tx_if.rdy;
    tx_if.val = tx_346_if.val;
    tx_if.sop = tx_346_if.sop;
    tx_if.eop = tx_346_if.eop;
    tx_if.ctl = tx_346_if.ctl;
    tx_if.mod = tx_346_if.mod;
    tx_if.err = tx_346_if.err;
    tx_if.dat = tx_346_if.dat;
    tx_if_test.rdy = 0;
  end else begin
    tx_if.copy_if_comb(tx_if_test.dat, tx_if_test.val, tx_if_test.sop, tx_if_test.eop, tx_if_test.err, tx_if_test.mod, tx_if_test.ctl);
    tx_if_test.rdy = tx_if.rdy;
    tx_346_if.rdy = 0;
  end
end


file_to_axi #(
  .BINARY   ( 1        ),
  .DAT_BYTS ( DAT_BYTS ),
  .FP       ( 0        )
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
  .DAT_BYTS ( DAT_BYTS    )
  )
zcash_fpga_top (
  // Clocks and resets
  .i_clk_100 ( clk_100 ),
  .i_rst_100 ( rst_100 ),
  .i_clk_200 ( clk_200 ),
  .i_rst_200 ( rst_200 ),
  .i_clk_300 ( clk_300 ),
  .i_rst_300 ( rst_300 ),
  .i_clk_if ( clk_if ),
  .i_rst_if ( rst_if ),
  .rx_if ( tx_if ),
  .tx_if ( rx_if ),
  .axi_lite_if ( axi_lite_if )
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
      tx_if_test.put_stream(header, $bits(header)/8);
      // Wait for tx_if.rdy to go low (reset started)
      repeat(50) @(posedge tx_if.i_clk);
      // Then send data
      start_346 = 1;
      while(!done_346) #(IF_CLK_PERIOD/2);
      // Then status request after few clocks
      repeat(20) @(posedge tx_if.i_clk);
      header.cmd = FPGA_STATUS;
      header.len = $bits(header_t)/8;
      tx_if_test.put_stream(header, $bits(header)/8);
    end
    begin
      rx_if.get_stream(get_dat1, get_len1);
      rx_if.get_stream(get_dat2, get_len2); 
      rx_if.get_stream(get_dat3, get_len3); 
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

// This task sends a malformed message and checks it gets ignored
task test_ignored_message();
begin
  header_t  header;
  fpga_ignore_rpl_t fpga_ignore_rpl;
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  logic fail = 0;
  $display("Running test_ignored_message...");

  // Some header value that is invalid
  header = {$bits(header_t){1'b1}};
  header.cmd[8 +: 8] = 0;
  fork
    tx_if_test.put_stream(header, $bits(header)/8);
    rx_if.get_stream(get_dat, get_len);
  join

  fpga_ignore_rpl = get_dat;

  fail |= get_len != $bits(fpga_ignore_rpl_t)/8;
  fail |= fpga_ignore_rpl.hdr.cmd != FPGA_IGNORE_RPL;
  fail |= fpga_ignore_rpl.hdr.len != $bits(fpga_ignore_rpl_t)/8;
  assert (~fail) else $fatal(1, "%m %t ERROR: test_ignored_message rply was wrong:\n%p", $time, fpga_ignore_rpl);

  $display("test_ignored_message PASSED");

end
endtask

task test_block_secp256k1();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  integer start_time, finish_time;
  logic [63:0] mm_data;
  logic fail = 0;
  verify_secp256k1_sig_t verify_secp256k1_sig;
  verify_secp256k1_sig_rpl_t verify_secp256k1_sig_rpl;

  $display("Running test_block_secp256k1...");
  verify_secp256k1_sig.hdr.cmd = VERIFY_SECP256K1_SIG;
  verify_secp256k1_sig.hdr.len = $bits(verify_secp256k1_sig_t)/8;
  verify_secp256k1_sig.index = 1;
  verify_secp256k1_sig.hash = 256'h4c7dbc46486ad9569442d69b558db99a2612c4f003e6631b593942f531e67fd4;
  verify_secp256k1_sig.r = 256'h1375af664ef2b74079687956fd9042e4e547d57c4438f1fc439cbfcb4c9ba8b;
  verify_secp256k1_sig.s = 256'hde0f72e442f7b5e8e7d53274bf8f97f0674f4f63af582554dbecbb4aa9d5cbcb;
  verify_secp256k1_sig.Qx = 256'h808a2c66c5b90fa1477d7820fc57a8b7574cdcb8bd829bdfcf98aa9c41fde3b4;
  verify_secp256k1_sig.Qy = 256'heed249ffde6e46d784cb53b4df8c9662313c1ce8012da56cb061f12e55a32249;

  start_time = $time;
  fork
    tx_if_test.put_stream(verify_secp256k1_sig, $bits(verify_secp256k1_sig)/8);
    rx_if.get_stream(get_dat, get_len);
  join
  finish_time = $time;

  verify_secp256k1_sig_rpl = get_dat;

  fail |= verify_secp256k1_sig_rpl.hdr.cmd != VERIFY_SECP256K1_SIG_RPL;
  fail |= (verify_secp256k1_sig_rpl.bm != 0);
  fail |= (verify_secp256k1_sig_rpl.index != verify_secp256k1_sig.index);
  assert (~fail) else $fatal(1, "%m %t ERROR: test_block_secp256k1 failed :\n%p", $time, verify_secp256k1_sig_rpl);


  $display("test_block_secp256k1 PASSED");
end
endtask;

// Main testbench calls
initial begin
  tx_if.rdy = 0;
  rx_if.rdy = 0;
  tx_if.val = 0;
  tx_if_test.val = 0;
  #20us; // Let internal memories reset

  test_ignored_message();
  #10us;
  
  if (zcash_fpga_pkg::ENB_VERIFY_EQUIHASH == 1)
    test_block_346_equihash();
    
  if (zcash_fpga_pkg::ENB_VERIFY_SECP256K1_SIG == 1)  
    test_block_secp256k1();

  #1us $finish();

end

endmodule