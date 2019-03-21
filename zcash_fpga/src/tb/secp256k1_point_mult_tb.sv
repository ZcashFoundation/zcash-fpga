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

module secp256k1_point_mult_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 100;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(256*3/8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(256*3/8)) out_if(clk);

jb_point_t in_p, out_p;
logic [255:0] k;

always_comb begin
  in_p = in_if.dat; 
  out_if.dat = out_p;
end

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
  out_if.ctl = 0;
  out_if.mod = 0;
end

// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err) begin
    out_if.rdy = 1;
    $error(1, "%m %t ERROR: output .err asserted", $time);
  end


secp256k1_point_mult secp256k1_point_mult (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_p   ( in_if.dat  ),
  .i_k   ( k          ),
  .i_val ( in_if.val  ),
  .o_rdy ( in_if.rdy  ),
  .o_p   ( out_p      ),
  .i_rdy ( out_if.rdy ),
  .o_val ( out_if.val ),
  .o_err ( out_if.err )
);

task test_0();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [255:0] in_a, in_b;
  jb_point_t p_in, p_exp, p_out;
  $display("Running test_0...");
  p_in = {z:1, x:2, y:3};
  k = 100;
  //p_exp = dbl_jb_point(p_in);
  
  fork
    in_if.put_stream(p_in, 256*3/8);
    out_if.get_stream(get_dat, get_len);
  join
  
  /*p_out = get_dat;
  
  if (p_exp != p_out) begin
    $display("Expected:");
    print_jb_point(p_exp);
    $display("Was:");
    print_jb_point(p_out);
    $fatal(1, "%m %t ERROR: test_0 point was wrong", $time);
  end */

  $display("test_0 PASSED");
end
endtask;

function compare_point();
  
endfunction

initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);
  
  test_0();

  #1us $finish();
end
endmodule