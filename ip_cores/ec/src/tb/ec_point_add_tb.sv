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

module ec_point_add_tb ();
import common_pkg::*;
import bls12_381_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

if_axi_stream #(.DAT_BYTS((384*6)/8)) in_if(clk); // Two points
if_axi_stream #(.DAT_BYTS((384*3)/8)) out_if(clk);

if_axi_stream #(.DAT_BYTS(384*2/8), .CTL_BITS(8)) mult_in_if(clk);
if_axi_stream #(.DAT_BITS(381), .CTL_BITS(8)) mult_out_if(clk);

if_axi_stream #(.DAT_BITS(2*bls12_381_pkg::DAT_BITS), .CTL_BITS(8)) add_in_if(clk);
if_axi_stream #(.DAT_BITS(bls12_381_pkg::DAT_BITS), .CTL_BITS(8)) add_out_if(clk);

if_axi_stream #(.DAT_BITS(2*bls12_381_pkg::DAT_BITS), .CTL_BITS(8)) sub_in_if(clk);
if_axi_stream #(.DAT_BITS(bls12_381_pkg::DAT_BITS), .CTL_BITS(8)) sub_out_if(clk);

jb_point_t in_p1, in_p2, out_p;

always_comb begin
  in_p1 = in_if.dat[0 +: $bits(jb_point_t)];
  in_p2 = in_if.dat[$bits(jb_point_t) +: $bits(jb_point_t)];
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
  if (out_if.val && out_if.err)
    $error(1, "%m %t ERROR: output .err asserted", $time);

ec_point_add #(
  .FP_TYPE ( jb_point_t ),
  .FE_TYPE ( fe_t )
)
ec_point_add (
  .i_clk ( clk ),
  .i_rst ( rst ),
    // Input points
  .i_p1   ( in_p1      ),
  .i_p2   ( in_p2      ),
  .i_val ( in_if.val ),
  .o_rdy ( in_if.rdy ),
  .o_p   ( out_p     ),
  .o_err ( out_if.err ),
  .i_rdy ( out_if.rdy ),
  .o_val  ( out_if.val ) ,
  .o_mul_if ( mult_in_if ),
  .i_mul_if ( mult_out_if ),
  .o_add_if ( add_in_if ),
  .i_add_if ( add_out_if ),
  .o_sub_if ( sub_in_if ),
  .i_sub_if ( sub_out_if )
);



// Attach a mod reduction unit and multiply - mod unit
ec_fp_mult_mod #(
  .P             ( P   ),
  .KARATSUBA_LVL ( 3   ),
  .CTL_BITS      ( 8   )
)
ec_fp_mult_mod (
  .i_clk( clk         ),
  .i_rst( rst         ),
  .i_mul ( mult_in_if ),
  .o_mul ( mult_out_if )
);

adder_pipe # (
  .BITS     ( bls12_381_pkg::DAT_BITS ),
  .P        ( P   ),
  .CTL_BITS ( 8   ),
  .LEVEL    ( 2   )
)
adder_pipe (
  .i_clk ( clk        ),
  .i_rst ( rst        ),
  .i_add ( add_in_if  ),
  .o_add ( add_out_if )
);

subtractor_pipe # (
  .BITS     ( bls12_381_pkg::DAT_BITS ),
  .P        ( P   ),
  .CTL_BITS ( 8   ),
  .LEVEL    ( 2   )
)
subtractor_pipe (
  .i_clk ( clk        ),
  .i_rst ( rst        ),
  .i_sub ( sub_in_if  ),
  .o_sub ( sub_out_if )
);

task test();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  jb_point_t p1, p2, p_exp, p_out;
  $display("Running test ...");

  p1 = bls12_381_pkg::g_point;
  p2 = add_jb_point(p1, p1);
  p_exp = add_jb_point(p1, p2);

  fork
    in_if.put_stream({p2, p1}, (384*6/8));
    out_if.get_stream(get_dat, get_len);
  join

  p_out = get_dat;

  $display("Expected:");
  print_jb_point(p_exp);
  $display("Was:");
  print_jb_point(p_out);

  if (~(p_exp == p_out)) begin
    $fatal(1, "%m %t ERROR: test_0 point was wrong", $time);
  end

  $display("test PASSED");

end
endtask;


initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);

 test();


  #1us $finish();
end
endmodule