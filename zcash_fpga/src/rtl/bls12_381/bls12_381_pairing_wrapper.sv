/*
  Wrapper for the bls12-381 pairing engine.

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

module bls12_381_pairing_wrapper
  import bls12_381_pkg::*;
#(
  parameter type FE_TYPE = fe_t,
  parameter type FE2_TYPE = fe2_t,
  parameter type FE6_TYPE = fe6_t,
  parameter type FE12_TYPE = fe12_t,
  parameter type G1_FP_AF_TYPE = af_point_t,
  parameter type G2_FP_AF_TYPE = fp2_af_point_t,
  parameter type G2_FP_JB_TYPE = fp2_jb_point_t,
  parameter CTL_BITS = 32,
  parameter OVR_WRT_BIT = 8 // We override 36 bits from here
)(
  input i_clk, i_rst,
  // Inputs
  input               i_val,
  output logic        o_rdy,
  input G1_FP_AF_TYPE i_g1_af,
  input G2_FP_AF_TYPE i_g2_af,
  // Outputs
  output logic     o_val,
  input            i_rdy,
  output FE12_TYPE o_fe12,
  // Interface to FE_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if,
  // Interface to FE_TYPE adder (mod P)
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if
);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_in_if[1:0](i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_out_if[1:0](i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_in_if[1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_out_if[1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_in_if[1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_out_if[1:0] (i_clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_o_if[2:0](i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_i_if[2:0](i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) add_fe2_o_if[2:0](i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) add_fe2_i_if[2:0](i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe2_o_if[2:0](i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe2_i_if[2:0](i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) mnr_fe2_o_if[2:0](i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) mnr_fe2_i_if[2:0](i_clk);

if_axi_stream #(.DAT_BYTS((2*$bits(FE6_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) mul_fe6_o_if(i_clk);
if_axi_stream #(.DAT_BYTS(($bits(FE6_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) mul_fe6_i_if(i_clk);
if_axi_stream #(.DAT_BYTS((2*$bits(FE6_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) add_fe6_o_if(i_clk);
if_axi_stream #(.DAT_BYTS(($bits(FE6_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) add_fe6_i_if(i_clk);
if_axi_stream #(.DAT_BYTS((2*$bits(FE6_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) sub_fe6_o_if(i_clk);
if_axi_stream #(.DAT_BYTS(($bits(FE6_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) sub_fe6_i_if(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE6_TYPE)), .CTL_BITS(CTL_BITS)) mnr_fe6_o_if(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE6_TYPE)), .CTL_BITS(CTL_BITS)) mnr_fe6_i_if(i_clk);

if_axi_stream #(.DAT_BYTS((2*$bits(FE12_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) mul_fe12_o_if(i_clk);
if_axi_stream #(.DAT_BYTS(($bits(FE12_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) mul_fe12_i_if(i_clk);
if_axi_stream #(.DAT_BYTS((2*$bits(FE12_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) add_fe12_o_if(i_clk);
if_axi_stream #(.DAT_BYTS(($bits(FE12_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) add_fe12_i_if(i_clk);
if_axi_stream #(.DAT_BYTS((2*$bits(FE12_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) sub_fe12_o_if(i_clk);
if_axi_stream #(.DAT_BYTS(($bits(FE12_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) sub_fe12_i_if(i_clk);

always_comb begin
  add_fe12_o_if.reset_source();
  add_fe12_i_if.rdy = 0;
  sub_fe12_o_if.reset_source();
  sub_fe12_i_if.rdy = 0;
end

ec_fe2_arithmetic #(
  .FE_TYPE     ( FE_TYPE  ),
  .FE2_TYPE    ( FE2_TYPE ),
  .CTL_BITS    ( CTL_BITS ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 0 )
)
ec_fe2_arithmetic (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_fp_mode ( 1'd0 ),
  .o_mul_fe_if ( mul_fe_in_if[0]  ),
  .i_mul_fe_if ( mul_fe_out_if[0] ),
  .o_add_fe_if ( add_fe_in_if[0]  ),
  .i_add_fe_if ( add_fe_out_if[0] ),
  .o_sub_fe_if ( sub_fe_in_if[0]  ),
  .i_sub_fe_if ( sub_fe_out_if[0] ),
  .o_mul_fe2_if ( mul_fe2_i_if[2]  ),
  .i_mul_fe2_if ( mul_fe2_o_if[2] ),
  .o_add_fe2_if ( add_fe2_i_if[2]  ),
  .i_add_fe2_if ( add_fe2_o_if[2] ),
  .o_sub_fe2_if ( sub_fe2_i_if[2]  ),
  .i_sub_fe2_if ( sub_fe2_o_if[2] )
);

ec_fe6_arithmetic #(
  .FE2_TYPE    ( FE2_TYPE ),
  .FE6_TYPE    ( FE6_TYPE ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 4 ),
  .CTL_BITS    ( CTL_BITS )
)
ec_fe6_arithmetic (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe2_if ( mul_fe2_o_if[0] ),
  .i_mul_fe2_if ( mul_fe2_i_if[0] ),
  .o_add_fe2_if ( add_fe2_o_if[0] ),
  .i_add_fe2_if ( add_fe2_i_if[0] ),
  .o_sub_fe2_if ( sub_fe2_o_if[0] ),
  .i_sub_fe2_if ( sub_fe2_i_if[0] ),
  .o_mnr_fe2_if ( mnr_fe2_i_if[0] ),
  .i_mnr_fe2_if ( mnr_fe2_o_if[0] ),
  .o_mul_fe6_if ( mul_fe6_i_if  ),
  .i_mul_fe6_if ( mul_fe6_o_if ),
  .o_add_fe6_if ( add_fe6_i_if  ),
  .i_add_fe6_if ( add_fe6_o_if ),
  .o_sub_fe6_if ( sub_fe6_i_if  ),
  .i_sub_fe6_if ( sub_fe6_o_if )
);

ec_fe12_arithmetic #(
  .FE6_TYPE    ( FE6_TYPE  ),
  .FE12_TYPE   ( FE12_TYPE ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 10 ),
  .CTL_BITS    ( CTL_BITS  )
)
ec_fe12_arithmetic (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe6_if ( mul_fe6_o_if  ),
  .i_mul_fe6_if ( mul_fe6_i_if ),
  .o_add_fe6_if ( add_fe6_o_if  ),
  .i_add_fe6_if ( add_fe6_i_if ),
  .o_sub_fe6_if ( sub_fe6_o_if  ),
  .i_sub_fe6_if ( sub_fe6_i_if ),
  .o_mnr_fe6_if ( mnr_fe6_o_if  ),
  .i_mnr_fe6_if ( mnr_fe6_i_if ),
  .o_mul_fe12_if ( mul_fe12_i_if  ),
  .i_mul_fe12_if ( mul_fe12_o_if ),
  .o_add_fe12_if ( add_fe12_i_if  ),
  .i_add_fe12_if ( add_fe12_o_if ),
  .o_sub_fe12_if ( sub_fe12_i_if  ),
  .i_sub_fe12_if ( sub_fe12_o_if )
);

fe2_mul_by_nonresidue #(
  .FE_TYPE ( FE_TYPE )
)
fe2_mul_by_nonresidue (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mnr_fe2_if ( mnr_fe2_o_if[2] ),
  .i_mnr_fe2_if ( mnr_fe2_i_if[2] ),
  .o_add_fe_if ( add_fe_in_if[1] ),
  .i_add_fe_if ( add_fe_out_if[1] ),
  .o_sub_fe_if ( sub_fe_in_if[1] ),
  .i_sub_fe_if ( sub_fe_out_if[1] )
);

fe6_mul_by_nonresidue #(
  .FE2_TYPE ( FE2_TYPE )
)
fe6_mul_by_nonresidue (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mnr_fe6_if ( mnr_fe6_i_if ),
  .i_mnr_fe6_if ( mnr_fe6_o_if ),
  .o_mnr_fe2_if ( mnr_fe2_i_if[1] ),
  .i_mnr_fe2_if ( mnr_fe2_o_if[1] )
);

bls12_381_pairing #(
  .FE_TYPE     ( FE_TYPE   ),
  .FE2_TYPE    ( FE2_TYPE  ),
  .FE12_TYPE   ( FE12_TYPE ),
  .CTL_BITS    ( CTL_BITS  ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 16 )
)
bls12_381_pairing (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_val ( i_val ),
  .o_rdy ( o_rdy ),
  .i_g1_af ( i_g1_af ),
  .i_g2_af ( i_g2_af ),
  .o_val  ( o_val  ),
  .i_rdy  ( i_rdy  ),
  .o_fe12 ( o_fe12 ),
  .o_mul_fe2_if ( mul_fe2_o_if[1] ),
  .i_mul_fe2_if ( mul_fe2_i_if[1] ),
  .o_add_fe2_if ( add_fe2_o_if[1] ),
  .i_add_fe2_if ( add_fe2_i_if[1] ),
  .o_sub_fe2_if ( sub_fe2_o_if[1] ),
  .i_sub_fe2_if ( sub_fe2_i_if[1] ),
  .o_mul_fe12_if ( mul_fe12_o_if ),
  .i_mul_fe12_if ( mul_fe12_i_if ),
  .o_mul_fe_if ( mul_fe_in_if[1] ),
  .i_mul_fe_if ( mul_fe_out_if[1] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 32 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_fe_in_if[1:0] ),
  .o_res ( o_sub_fe_if ),
  .i_res ( i_sub_fe_if ),
  .o_axi ( sub_fe_out_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 32 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_fe_in_if[1:0] ),
  .o_res ( o_add_fe_if ),
  .i_res ( i_add_fe_if ),
  .o_axi ( add_fe_out_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 32 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe_in_if[1:0] ),
  .o_res ( o_mul_fe_if ),
  .i_res ( i_mul_fe_if ),
  .o_axi ( mul_fe_out_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( $bits(FE2_TYPE)  ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 34 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_mnr (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mnr_fe2_i_if[1:0] ),
  .o_res ( mnr_fe2_i_if[2] ),
  .i_res ( mnr_fe2_o_if[2] ),
  .o_axi ( mnr_fe2_o_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 34 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe2_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_fe2_o_if[1:0] ),
  .o_res ( add_fe2_o_if[2] ),
  .i_res ( add_fe2_i_if[2] ),
  .o_axi ( add_fe2_i_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 34 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe2_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_fe2_o_if[1:0] ),
  .o_res ( sub_fe2_o_if[2] ),
  .i_res ( sub_fe2_i_if[2] ),
  .o_axi ( sub_fe2_i_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 34 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe2_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe2_o_if[1:0] ),
  .o_res ( mul_fe2_o_if[2] ),
  .i_res ( mul_fe2_i_if[2] ),
  .o_axi ( mul_fe2_i_if[1:0] )
);

endmodule