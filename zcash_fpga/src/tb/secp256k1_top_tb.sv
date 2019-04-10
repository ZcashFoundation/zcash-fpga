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

localparam CLK_PERIOD = 5000;
localparam USE_ENDOMORPH = "NO";

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
  if (out_if.val && out_if.err) begin;
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
  logic [63:0] mm_data;
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
  
  // Also try reading some RAM values
  mm_if.get_data(mm_data, SIG_VER_HASH);
  
  fail |= mm_data != hash[0 +: 64];
  assert (~fail) else $fatal(1, "%m %t ERROR: mm_if data read back wrong hash", $time);

  $display("test #%d PASSED in %d clocks", integer'(k), (finish_time-start_time)/CLK_PERIOD);
end
endtask;


initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  mm_if.reset_source();
  #(40*CLK_PERIOD);

  test(1, 256'h4c7dbc46486ad9569442d69b558db99a2612c4f003e6631b593942f531e67fd4,  // message hash
          256'h1375af664ef2b74079687956fd9042e4e547d57c4438f1fc439cbfcb4c9ba8b,  // r
          256'hde0f72e442f7b5e8e7d53274bf8f97f0674f4f63af582554dbecbb4aa9d5cbcb,  // s
          256'h808a2c66c5b90fa1477d7820fc57a8b7574cdcb8bd829bdfcf98aa9c41fde3b4,  //Qx
          256'heed249ffde6e46d784cb53b4df8c9662313c1ce8012da56cb061f12e55a32249); //Qy

  test(2, 256'haca448f8093e33286c7d284569feae5f65ae7fa2ea5ce9c46acaad408da61e1f,  // message hash
          256'hbce4a3be622e3f919f97b03b45e3f32ccdf3dd6bcce40657d8f9fc973ae7b29,  // r
          256'h6abcd5e40fcee8bca6b506228a2dcae67daa5d743e684c4d3fb1cb77e43b48fe,  // s
          256'hb661c143ffbbad5acfe16d427767cdc57fb2e4c019a4753ba68cd02c29e4a153,  //Qx
          256'h6e1fb00fdb9ddd39b55596bfb559bc395f220ae51e46dbe4e4df92d1a5599726); //Qy

  #1us $finish();
end
endmodule