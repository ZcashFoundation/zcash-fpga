/*
  This does the for Frobenius map calculation required in final
  exponentiation in the ate pairing on a Fp^2 element.

  Input is expected to be streamed in with Fp .c0 in the first clock cycle

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

module bls12_381_fe12_fmap_wrapper
  import bls12_381_pkg::*;
#(
  parameter type FE_TYPE = fe_t,     
  parameter      CTL_BITS    = 12,
  parameter      CTL_BIT_POW = 8         // This is where we encode the power value with 2 bits - only 0,1,2,3 are supported - 5 extra bits required after this for control
)(
  input i_clk, i_rst,
  // Input/Output intefaces for fmap result, FE_TYPE data width
  if_axi_stream.source o_fmap_fe12_if,
  if_axi_stream.sink   i_fmap_fe12_if,
  // Interface to FE2_TYPE mul (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE_TYPE mul (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if
);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_if_o [1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe2_if_i [1:0] (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) fmap_fe6_if_o (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) fmap_fe6_if_i (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) fmap_fe2_if_o (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) fmap_fe2_if_i (i_clk);

bls12_381_fe2_fmap #(
  .FE_TYPE     ( FE_TYPE         ),
  .OVR_WRT_BIT ( CTL_BIT_POW + 2 ),  // 3 bits control
  .CTL_BIT_POW ( CTL_BIT_POW     )
)
bls12_381_fe2_fmap (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_fmap_fe2_if ( fmap_fe2_if_i ),
  .i_fmap_fe2_if ( fmap_fe2_if_o ),
  .o_mul_fe_if   ( o_mul_fe_if   ),
  .i_mul_fe_if   ( i_mul_fe_if   )
);

bls12_381_fe6_fmap #(
  .FE_TYPE     ( FE_TYPE         ),
  .OVR_WRT_BIT ( CTL_BIT_POW + 3 ),  // 3 bits control
  .CTL_BIT_POW ( CTL_BIT_POW     )
)
bls12_381_fe6_fmap (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_fmap_fe6_if ( fmap_fe6_if_i   ),
  .i_fmap_fe6_if ( fmap_fe6_if_o   ),
  .o_fmap_fe2_if ( fmap_fe2_if_o   ),
  .i_fmap_fe2_if ( fmap_fe2_if_i   ),
  .o_mul_fe2_if  ( mul_fe2_if_o[0] ),
  .i_mul_fe2_if  ( mul_fe2_if_i[0] )
);

bls12_381_fe12_fmap #(
  .FE_TYPE     ( FE_TYPE     ),
  .OVR_WRT_BIT ( CTL_BIT_POW + 6 ),  // 3 bits control
  .CTL_BIT_POW ( CTL_BIT_POW     )
)
bls12_381_fe12_fmap (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_fmap_fe12_if ( o_fmap_fe12_if  ),
  .i_fmap_fe12_if ( i_fmap_fe12_if  ),
  .o_fmap_fe6_if  ( fmap_fe6_if_o   ),
  .i_fmap_fe6_if  ( fmap_fe6_if_i   ),
  .o_mul_fe2_if   ( mul_fe2_if_o[1] ),
  .i_mul_fe2_if   ( mul_fe2_if_i[1] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( CTL_BIT_POW+9    ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe2_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe2_if_o[1:0] ),
  .o_res ( o_mul_fe2_if      ),
  .i_res ( i_mul_fe2_if      ),
  .o_axi ( mul_fe2_if_i[1:0] )
);

endmodule