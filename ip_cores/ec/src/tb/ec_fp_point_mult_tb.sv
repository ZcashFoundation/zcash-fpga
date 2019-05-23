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

module ec_fp_point_mult_tb ();
import common_pkg::*;
import bls12_381_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(384*3/8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(384*3/8)) out_if(clk);

if_axi_stream #(.DAT_BYTS(384*2/8), .CTL_BITS(16)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS(384/8), .CTL_BITS(16)) mult_out_if(clk);

logic [DAT_BITS-1:0] k_in;

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #(CLK_PERIOD/2) clk = ~clk;
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

always_comb begin
  mult_out_if.sop = 1;
  mult_out_if.eop = 1;
  mult_out_if.val = 0;
  mult_out_if.mod = 0;
  mult_in_if.rdy = 1;
end


ec_fp_point_mult #(
  .P          ( P ),
  .POINT_TYPE ( jb_point_t ),
  .DAT_BITS   ( DAT_BITS   ),
  .MUL_BITS   ( MUL_BITS   ),
  .RESOURCE_SHARE ("NO")
)
ec_fp_point_mult (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_p   ( in_if.dat  ),
  .i_k   ( k_in       ),
  .i_val ( in_if.val  ),
  .o_rdy ( in_if.rdy  ),
  .o_p   ( out_if.dat ),
  .i_rdy ( out_if.rdy ),
  .o_val ( out_if.val ),
  .o_err ( out_if.err ),
  .o_mult_if ( mult_in_if ),
  .i_mult_if ( mult_out_if ),
  .i_p2_val ( 0),
  .i_p2 ( 0 )
);


// Test a point
task test(input integer index, input logic [DAT_BITS-1:0] k, jb_point_t p_exp, p_in);
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  integer start_time, finish_time;
  jb_point_t  p_out;
  $display("Running test %d ...", index);
  k_in = k;
  start_time = $time;
  print_jb_point(p_in);
  fork
    in_if.put_stream(p_in, 384*3/8);
    out_if.get_stream(get_dat, get_len);
  join
  finish_time = $time;

  p_out = get_dat;

  if (p_exp != p_out) begin
    $display("Expected:");
    print_jb_point(p_exp);
    $display("Was:");
    print_jb_point(p_out);
    $fatal(1, "%m %t ERROR: test %d was wrong", $time, index);
  end

  $display("test %d PASSED in %d clocks", index, (finish_time-start_time)/CLK_PERIOD);
end
endtask;


initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);

  test(0,
       1,
       bls12_381_pkg::g_point,
       bls12_381_pkg::g_point);

  test(1,
       4,
       bls12_381_pkg::g_point,
       bls12_381_pkg::g_point);
       
  #1us $finish();
end
endmodule