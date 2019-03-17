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

module secp256k1_mod_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 100;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(512/8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8)) out_if(clk);

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
  out_if.err = 0;
  out_if.ctl = 0;
  out_if.mod = 0;
end

secp256k1_mod secp256k1_mod
(
  .i_clk( clk        ),
  .i_rst( rst        ),
  .i_dat( in_if.dat  ),
  .i_val( in_if.val  ),
  .o_rdy( in_if.rdy  ),
  .o_dat( out_if.dat ),
  .i_rdy( out_if.rdy ),
  .o_val( out_if.val )
);

task test0();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected, in_dat, get_dat;
  $display("Running test0...");
  in_dat = 1 << 433;
  expected = 256'd822752465816620949324161418291805943222876982255305228346720256;
  fork
    in_if.put_stream(in_dat, 512/8);
    out_if.get_stream(get_dat, get_len);
  join
  
  common_pkg::compare_and_print(get_dat, expected);
  $display("test0 PASSED");
end
endtask;

task test_loop();
begin
  integer signed get_len, i, max;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected, in_dat, get_dat;
  $display("Running test_loop...");
  in_dat = 1 << 433;
  expected = 256'd822752465816620949324161418291805943222876982255305228346720256;
  i = 0;
  max = 10000;
  repeat (max) begin
    
    in_dat = in_dat*2;
    expected = expected*2;
    while (expected >= p_eq)
      expected = expected - p_eq;
    
    fork
      in_if.put_stream(in_dat, 512/8);
      out_if.get_stream(get_dat, get_len);
    join
    
    common_pkg::compare_and_print(get_dat, expected);
    $display("test_loop PASSED loop %d/%d", i, max);
    i = i + 1;
  end
  
  
  $display("test_loop PASSED");
end
endtask;

initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);
  test0();
  test_loop();
  #1us $finish();
end
endmodule