/*
  This performs Fp^2 point doubling.
  Is has wrapper around the Fp point double module, with logic
  to handle the multiplications / subtractions / additions.

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

module ec_fp2_point_dbl
#(
  parameter type FP2_TYPE,   // Should have FE2_TYPE elements
  parameter type FE_TYPE,
  parameter type FE2_TYPE
)(
  input i_clk, i_rst,
  // Input points
  input FP2_TYPE i_p,
  input logic    i_val,
  output logic   o_rdy,
  // Output point
  output FP2_TYPE o_p,
  input logic     i_rdy,
  output logic    o_val,
  output logic    o_err,
  // Interface to FE_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_if,
  if_axi_stream.sink   i_mul_if,
  // Interface to FE_TYPE adder (mod P)
  if_axi_stream.source o_add_if,
  if_axi_stream.sink   i_add_if,
  // Interface to FE_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_if,
  if_axi_stream.sink   i_sub_if
);

if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(8)) mul_if_fe2_i(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(8))   mul_if_fe2_o(i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(8)) add_if_fe2_i(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(8))   add_if_fe2_o(i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(8)) sub_if_fe2_i(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(8))   sub_if_fe2_o(i_clk);

ec_point_dbl #(
  .FP_TYPE ( FP2_TYPE ),
  .FE_TYPE ( FE2_TYPE )
)
ec_point_dbl (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
    // Input points
  .i_p   ( i_p  ),
  .i_val ( i_val ),
  .o_rdy ( o_rdy ),
  .o_p   ( o_p   ),
  .o_err ( o_err ),
  .i_rdy ( i_rdy ),
  .o_val ( o_val ) ,
  .o_mul_if ( mul_if_fe2_i ),
  .i_mul_if ( mul_if_fe2_o ),
  .o_add_if ( add_if_fe2_i  ),
  .i_add_if ( add_if_fe2_o  ),
  .o_sub_if ( sub_if_fe2_i  ),
  .i_sub_if ( sub_if_fe2_o  )
);

ec_fe2_arithmetic
#(
  .FE_TYPE  ( FE_TYPE  ),
  .FE2_TYPE ( FE2_TYPE )
)
ec_fe2_arithmetic (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_fp_mode ( 1'd0 ),
  .o_mul_fe_if ( o_mul_if ),
  .i_mul_fe_if ( i_mul_if ),
  .o_add_fe_if ( o_add_if ),
  .i_add_fe_if ( i_add_if ),
  .o_sub_fe_if ( o_sub_if ),
  .i_sub_fe_if ( i_sub_if ),
  .o_mul_fe2_if ( mul_if_fe2_o ),
  .i_mul_fe2_if ( mul_if_fe2_i ),
  .o_add_fe2_if ( add_if_fe2_o ),
  .i_add_fe2_if ( add_if_fe2_i ),
  .o_sub_fe2_if ( sub_if_fe2_o ),
  .i_sub_fe2_if ( sub_if_fe2_i )
);

endmodule