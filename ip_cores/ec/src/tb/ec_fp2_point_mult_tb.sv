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

module ec_fp2_point_mult_tb ();
import common_pkg::*;
import bls12_381_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

parameter type FP_TYPE  = bls12_381_pkg::fp2_jb_point_t;
parameter type FE_TYPE  = bls12_381_pkg::fe_t;
parameter type FE2_TYPE = bls12_381_pkg::fe2_t;
parameter KEY_BITS      = bls12_381_pkg::DAT_BITS;
parameter P             = bls12_381_pkg::P;

parameter CTL_BITS = 64;

`define MULT_FUNC(K, IN_POINT) fp2_point_mult(K, IN_POINT);
`define PRINT_FUNC(IN_POINT)   print_fp2_jb_point(IN_POINT);
`define G_POINT                bls12_381_pkg::g2_point
`define TO_AFFINE              bls12_381_pkg::fp2_to_affine

if_axi_stream #(.DAT_BYTS(($bits(FP_TYPE)+7)/8), .CTL_BITS(KEY_BITS)) in_if(clk);
if_axi_stream #(.DAT_BYTS(($bits(FP_TYPE)+7)/8)) out_if(clk);



if_axi_stream #(.DAT_BITS(2*$bits(FP_TYPE))) add_i_if(clk);
if_axi_stream #(.DAT_BITS($bits(FP_TYPE))) add_o_if(clk);
if_axi_stream #(.DAT_BITS($bits(FP_TYPE))) dbl_i_if(clk);
if_axi_stream #(.DAT_BITS($bits(FP_TYPE))) dbl_o_if(clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(16)) mult_in_if [2:0] (clk) ;
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(16)) mult_out_if [2:0](clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(16)) add_in_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(16)) add_out_if [2:0] (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(16)) sub_in_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(16)) sub_out_if [2:0] (clk);

initial begin
  rst = 0;
  repeat(2) #(10*CLK_PERIOD) rst = ~rst;
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

ec_point_mult #(
  .P       ( P ),
  .FP_TYPE ( FP_TYPE )
)
ec_point_mult (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_pt_mult ( out_if ),
  .i_pt_mult ( in_if  ),
  // Interface to point adder / doubler
  .o_dbl ( dbl_i_if ),
  .i_dbl ( dbl_o_if ),
  .o_add ( add_i_if ),
  .i_add ( add_o_if )
);

ec_fp2_point_add #(
  .FP2_TYPE ( FP_TYPE  ),
  .FE_TYPE  ( FE_TYPE  ),
  .FE2_TYPE ( FE2_TYPE ),
  .CTL_BITS ( CTL_BITS )
)
ec_fp2_point_add (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_fp_mode(0),
    // Input points
  .i_p1  ( add_i_if.dat[0 +: $bits(FP_TYPE)]              ),
  .i_p2  ( add_i_if.dat[$bits(FP_TYPE) +: $bits(FP_TYPE)] ),
  .i_val ( add_i_if.val ),
  .o_rdy ( add_i_if.rdy ),
  .o_p   ( add_o_if.dat ),
  .o_err ( add_o_if.err ),
  .i_rdy ( add_o_if.rdy ),
  .o_val ( add_o_if.val ) ,
  .o_mul_if ( mult_in_if[0] ),
  .i_mul_if ( mult_out_if[0] ),
  .o_add_if ( add_in_if[0] ),
  .i_add_if ( add_out_if[0] ),
  .o_sub_if ( sub_in_if[0] ),
  .i_sub_if ( sub_out_if[0] )
);

ec_fp2_point_dbl #(
 .FP2_TYPE ( FP_TYPE  ),
 .FE_TYPE  ( FE_TYPE  ),
 .FE2_TYPE ( FE2_TYPE ),
 .CTL_BITS ( CTL_BITS )
)
ec_fp2_point_dbl (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_fp_mode(0),
  .i_p  ( dbl_i_if.dat),
  .i_val ( dbl_i_if.val ),
  .o_rdy ( dbl_i_if.rdy ),
  .o_p   ( dbl_o_if.dat ),
  .o_err ( dbl_o_if.err ),
  .i_rdy ( dbl_o_if.rdy ),
  .o_val ( dbl_o_if.val ) ,
  .o_mul_if ( mult_in_if[1] ),
  .i_mul_if ( mult_out_if[1] ),
  .o_add_if ( add_in_if[1] ),
  .i_add_if ( add_out_if[1] ),
  .o_sub_if ( sub_in_if[1] ),
  .i_sub_if ( sub_out_if[1] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( 16               ),
  .OVR_WRT_BIT  ( 14               ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_mul (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( mult_in_if[1:0]  ),
  .o_res ( mult_in_if[2]    ),
  .i_res ( mult_out_if[2]   ),
  .o_axi ( mult_out_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( 16               ),
  .OVR_WRT_BIT  ( 14               ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_sub (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( sub_in_if[1:0] ),
  .o_res ( sub_in_if[2] ),
  .i_res ( sub_out_if[2] ),
  .o_axi ( sub_out_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( 16               ),
  .OVR_WRT_BIT  ( 14               ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_add (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( add_in_if[1:0] ),
  .o_res ( add_in_if[2] ),
  .i_res ( add_out_if[2] ),
  .o_axi ( add_out_if[1:0] )
);

ec_fp_mult_mod #(
  .P             ( P   ),
  .KARATSUBA_LVL ( 3   ),
  .CTL_BITS      ( 16  )
)
ec_fp_mult_mod (
  .i_clk( clk         ),
  .i_rst( rst         ),
  .i_mul ( mult_in_if[2] ),
  .o_mul ( mult_out_if[2] )
);

adder_pipe # (
  .P        ( P   ),
  .CTL_BITS ( 16  ),
  .LEVEL    ( 2   )
)
adder_pipe (
  .i_clk ( clk           ),
  .i_rst ( rst           ),
  .i_add ( add_in_if[2]  ),
  .o_add ( add_out_if[2] )
);

subtractor_pipe # (
  .P        ( P   ),
  .CTL_BITS ( 16  ),
  .LEVEL    ( 2   )
)
subtractor_pipe (
  .i_clk ( clk           ),
  .i_rst ( rst           ),
  .i_sub ( sub_in_if[2]  ),
  .o_sub ( sub_out_if[2] )
);

// Test a point
task test(input logic [KEY_BITS-1:0] k);
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  integer start_time, finish_time;
  FP_TYPE  p_out, p_exp;
  $display("Running test with k= %d", k);
  p_exp = `MULT_FUNC(k, `G_POINT);
  start_time = $time;
  fork
    in_if.put_stream(`G_POINT, ($bits(FP_TYPE)+7)/8, k);
    out_if.get_stream(get_dat, get_len);
  join
  finish_time = $time;

  p_out = get_dat;

  $display("Expected:");
  `PRINT_FUNC(`TO_AFFINE(p_exp));
  $display("Was:");
  `PRINT_FUNC(`TO_AFFINE(p_out));

  if (p_exp != p_out) begin
    $fatal(1, "%m %t ERROR: output was wrong", $time);
  end

  $display("test PASSED in %d clocks", (finish_time-start_time)/CLK_PERIOD);
end
endtask;

logic [380:0] in_k;

initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);
  test(381'd2);
  test(381'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa);

  #1us $finish();
end
endmodule