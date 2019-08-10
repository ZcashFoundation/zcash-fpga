/*
  This does the Fp12 inversion required in the final exponentiation.

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

module bls12_381_fe12_inv_wrapper
  import bls12_381_pkg::*;
#(
  parameter type FE_TYPE  = fe_t,
  parameter type FE2_TYPE = fe2_t,
  parameter type FE6_TYPE = fe6_t,
  parameter      CTL_BITS = 12,
  parameter      OVR_WRT_BIT = 8 // Need 32 bits for control
)(
  input i_clk, i_rst,
  // Input/Output interfaces for inversion result, FE_TYPE data width
  if_axi_stream.source o_inv_fe12_if,
  if_axi_stream.sink   i_inv_fe12_if,
  // Interface to FE_TYPE mul (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if
);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_o_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe_i_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_o_if [5:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   add_fe_i_if [5:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_o_if [6:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   sub_fe_i_if [6:0] (i_clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_o_if [2:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe2_i_if [2:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mnr_fe2_o_if [3:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mnr_fe2_i_if [3:0] (i_clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe6_o_if       (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe6_i_if       (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mnr_fe6_o_if       (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mnr_fe6_i_if       (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe_o_if          (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe_i_if          (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe2_o_if         (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe2_i_if         (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe6_o_if         (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe6_i_if         (i_clk);

bin_inv_s #(
  .P     ( bls12_381_pkg::P ),
  .LEVEL ( 2                )
)
bin_inv_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_dat_if ( inv_fe_i_if ),
  .i_dat_if ( inv_fe_o_if )
);

ec_fe2_inv_s #(
  .FE_TYPE     ( FE_TYPE          ),
  .OVR_WRT_BIT ( OVR_WRT_BIT      )
)
ec_fe2_inv_s(
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_inv_fe2_if ( inv_fe2_i_if   ),
  .i_inv_fe2_if ( inv_fe2_o_if   ),
  .o_inv_fe_if  ( inv_fe_o_if    ),
  .i_inv_fe_if  ( inv_fe_i_if    ),  //
  .o_mul_fe_if  ( mul_fe_o_if[0] ),
  .i_mul_fe_if  ( mul_fe_i_if[0] ),
  .o_add_fe_if  ( add_fe_o_if[0] ),
  .i_add_fe_if  ( add_fe_i_if[0] ),
  .o_sub_fe_if  ( sub_fe_o_if[0] ),
  .i_sub_fe_if  ( sub_fe_i_if[0] )
);

ec_fe2_mul_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .CTL_BITS ( CTL_BITS )
)
ec_fe2_mul_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe2_if ( mul_fe2_i_if[2] ),
  .i_mul_fe2_if ( mul_fe2_o_if[2] ),
  .o_add_fe_if ( add_fe_o_if[1] ),
  .i_add_fe_if ( add_fe_i_if[1] ),
  .o_sub_fe_if ( sub_fe_o_if[1] ),
  .i_sub_fe_if ( sub_fe_i_if[1] ),
  .o_mul_fe_if ( mul_fe_o_if[1] ),
  .i_mul_fe_if ( mul_fe_i_if[1] )
);

fe2_mul_by_nonresidue_s #(
  .FE_TYPE  ( FE_TYPE  )
)
fe2_mul_by_nonresidue_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mnr_fe2_if ( mnr_fe2_i_if[3] ),
  .i_mnr_fe2_if ( mnr_fe2_o_if[3] ),
  .o_add_fe_if ( add_fe_o_if[2] ),
  .i_add_fe_if ( add_fe_i_if[2] ),
  .o_sub_fe_if ( sub_fe_o_if[2] ),
  .i_sub_fe_if ( sub_fe_i_if[2] )
);

ec_fe6_inv_s
#(
  .FE_TYPE     ( FE_TYPE          ),
  .FE2_TYPE    ( FE2_TYPE         ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 2  )
)
ec_fe6_inv_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe2_if ( mul_fe2_o_if[0] ),
  .i_mul_fe2_if ( mul_fe2_i_if[0] ),
  .o_add_fe_if  ( add_fe_o_if[3]  ),
  .i_add_fe_if  ( add_fe_i_if[3]  ),
  .o_sub_fe_if  ( sub_fe_o_if[3]  ),
  .i_sub_fe_if  ( sub_fe_i_if[3]  ),
  .o_mnr_fe2_if ( mnr_fe2_o_if[0] ),
  .i_mnr_fe2_if ( mnr_fe2_i_if[0] ),
  .o_inv_fe2_if ( inv_fe2_o_if    ),
  .i_inv_fe2_if ( inv_fe2_i_if    ),
  .o_inv_fe6_if ( inv_fe6_i_if    ),
  .i_inv_fe6_if ( inv_fe6_o_if    )
);

ec_fe6_mul_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .FE2_TYPE ( FE2_TYPE ),
  .FE6_TYPE ( FE6_TYPE ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 7 )
)
ec_fe6_mul_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe2_if ( mul_fe2_o_if[1] ),
  .i_mul_fe2_if ( mul_fe2_i_if[1] ),
  .o_add_fe_if  ( add_fe_o_if[4]  ),
  .i_add_fe_if  ( add_fe_i_if[4]  ),
  .o_sub_fe_if  ( sub_fe_o_if[4]  ),
  .i_sub_fe_if  ( sub_fe_i_if[4]  ),
  .o_mnr_fe2_if ( mnr_fe2_o_if[1] ),
  .i_mnr_fe2_if ( mnr_fe2_i_if[1] ),
  .o_mul_fe6_if ( mul_fe6_i_if    ),
  .i_mul_fe6_if ( mul_fe6_o_if    )
);

fe6_mul_by_nonresidue_s #(
  .FE_TYPE  ( FE_TYPE  )
)
fe6_mul_by_nonresidue_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mnr_fe2_if ( mnr_fe2_o_if[2] ),
  .i_mnr_fe2_if ( mnr_fe2_i_if[2] ),
  .o_mnr_fe6_if ( mnr_fe6_i_if ),
  .i_mnr_fe6_if ( mnr_fe6_o_if )
);

ec_fe12_inv_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 14 )
)
ec_fe12_inv_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe6_if ( mul_fe6_o_if   ),
  .i_mul_fe6_if ( mul_fe6_i_if   ),
  .o_sub_fe_if  ( sub_fe_o_if[5] ),
  .i_sub_fe_if  ( sub_fe_i_if[5] ),
  .o_mnr_fe6_if ( mnr_fe6_o_if   ),
  .i_mnr_fe6_if ( mnr_fe6_i_if   ),
  .o_inv_fe6_if ( inv_fe6_o_if   ),
  .i_inv_fe6_if ( inv_fe6_i_if   ),
  .o_inv_fe12_if ( o_inv_fe12_if ),
  .i_inv_fe12_if ( i_inv_fe12_if )
);

adder_pipe # (
  .BITS     ( bls12_381_pkg::DAT_BITS ),
  .P        ( bls12_381_pkg::P        ),
  .CTL_BITS ( CTL_BITS ),
  .LEVEL    ( 2        )
)
adder_pipe (
  .i_clk ( i_clk          ),
  .i_rst ( i_rst          ),
  .i_add ( add_fe_o_if[5] ),
  .o_add ( add_fe_i_if[5] )
);

subtractor_pipe # (
  .BITS     ( bls12_381_pkg::DAT_BITS ),
  .P        ( bls12_381_pkg::P        ),
  .CTL_BITS ( CTL_BITS ),
  .LEVEL    ( 2        )
)
subtractor_pipe (
  .i_clk ( i_clk          ),
  .i_rst ( i_rst          ),
  .i_sub ( sub_fe_o_if[6] ),
  .o_sub ( sub_fe_i_if[6] )
);

resource_share # (
  .NUM_IN       ( 5                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 18 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_fe_o_if[4:0] ),
  .o_res ( add_fe_o_if[5]   ),
  .i_res ( add_fe_i_if[5]   ),
  .o_axi ( add_fe_i_if[4:0] )
);

resource_share # (
  .NUM_IN       ( 6                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 18 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_fe_o_if[5:0] ),
  .o_res ( sub_fe_o_if[6]   ),
  .i_res ( sub_fe_i_if[6]   ),
  .o_axi ( sub_fe_i_if[5:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 18 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe_o_if[1:0] ),
  .o_res ( o_mul_fe_if      ),
  .i_res ( i_mul_fe_if      ),
  .o_axi ( mul_fe_i_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 3                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 24 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe2_mnr (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mnr_fe2_o_if[2:0] ),
  .o_res ( mnr_fe2_o_if[3]   ),
  .i_res ( mnr_fe2_i_if[3]   ),
  .o_axi ( mnr_fe2_i_if[2:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 24 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe2_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe2_o_if[1:0] ),
  .o_res ( mul_fe2_o_if[2]   ),
  .i_res ( mul_fe2_i_if[2]   ),
  .o_axi ( mul_fe2_i_if[1:0] )
);

endmodule