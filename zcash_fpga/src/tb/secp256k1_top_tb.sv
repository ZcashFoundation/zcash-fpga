/*
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

module secp256k1_top_tb ();
import common_pkg::*;
import secp256k1_pkg::*;
import zcash_fpga_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(8)) out_if(clk);
if_axi_mm mm_if(clk);

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #(CLK_PERIOD/2) clk = ~clk;
end


// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err) begin
    out_if.rdy = 1;
    $error(1, "%m %t ERROR: output .err asserted", $time);
  end

secp256k1_top secp256k1_top (
  .i_clk      ( clk    ),
  .i_rst      ( rst    ),
  .if_cmd_rx  ( in_if  ),
  .if_cmd_tx  ( out_if ),
  .if_axi_mm  ( mm_if  )
);

// Test a point
task test(input integer k, input logic [255:0] hash, r, s, Qx, Qy);
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  integer start_time, finish_time;
  logic fail = 0;
  verify_secp256k1_sig_t verify_secp256k1_sig;
  verify_secp256k1_sig_rpl_t verify_secp256k1_sig_rpl;
  
  $display("Running test...");
  verify_secp256k1_sig.hdr.cmd = VERIFY_SECP256K1_SIG;
  verify_secp256k1_sig.hdr.len = $bits(verify_secp256k1_sig_t)/8;
  verify_secp256k1_sig.index = k;
  verify_secp256k1_sig.hash = hash;
  verify_secp256k1_sig.r = r;
  verify_secp256k1_sig.s = s;
  verify_secp256k1_sig.Qx = Qx;
  verify_secp256k1_sig.Qy = Qy;
 
  start_time = $time;
  fork
    in_if.put_stream(verify_secp256k1_sig, $bits(verify_secp256k1_sig)/8);
    out_if.get_stream(get_dat, get_len);
  join
  finish_time = $time;
  
  verify_secp256k1_sig_rpl = get_dat;
  
  fail |= verify_secp256k1_sig_rpl.hdr.cmd != VERIFY_SECP256K1_SIG_RPL;
  fail |= (verify_secp256k1_sig_rpl.bm != 0);
  fail |= (verify_secp256k1_sig_rpl.index != k);
  assert (~fail) else $fatal(1, "%m %t ERROR: test failed :\n%p", $time, verify_secp256k1_sig_rpl);

  $display("test #%d PASSED in %d clocks", integer'(k), (finish_time-start_time)/CLK_PERIOD);
end
endtask;


initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  mm_if.reset_source();
  #(40*CLK_PERIOD);

  test(1, 256'h4c7dbc46486ad9569442d69b558db99a2612c4f003e6631b593942f531e67fd4,
          256'h808a2c66c5b90fa1477d7820fc57a8b7574cdcb8bd829bdfcf98aa9c41fde3b4,
          256'h7d4a15dda75c683f002305c2d6ebeebf6c6590f48e128497f118f43250f9924f,
          256'hdbe7be814625d52029f94f956147df9347b56e6b5f1cb70bf5d6069ecd8405dd,
          256'h3feab712653c82df859affc1c287a5353cbe7ca59b83d6d55d97fc04f243c19f);


  #1us $finish();
end
endmodule