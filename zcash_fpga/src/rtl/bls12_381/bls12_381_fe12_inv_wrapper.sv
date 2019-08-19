/*
  This does the Fe12 inversion required in the final exponentiation.
  Also provide inputs for Fe and Fe2 inversion so we can do point multiplication
  and pairing inside FPGA.

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
  parameter      OVR_WRT_BIT = 8 // Need 13 bits for control
)(
  input i_clk, i_rst,
  // Input/Output interfaces for inversion, FE_TYPE data width
  if_axi_stream.source o_inv_fe12_if,
  if_axi_stream.sink   i_inv_fe12_if,
  if_axi_stream.source o_inv_fe2_if,
  if_axi_stream.sink   i_inv_fe2_if,
  if_axi_stream.source o_inv_fe_if,
  if_axi_stream.sink   i_inv_fe_if,
  // Interface to FE_TYPE mul (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if,
  // Interface to FE2_TYPE mul (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE2_TYPE mnr (mod P), FE_TYPE data width
  if_axi_stream.source o_mnr_fe2_if,
  if_axi_stream.sink   i_mnr_fe2_if,
  // Interface to FE6_TYPE mul (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe6_if,
  if_axi_stream.sink   i_mul_fe6_if,
  // Interface to FE6_TYPE mnr (mod P), FE_TYPE data width
  if_axi_stream.source o_mnr_fe6_if,
  if_axi_stream.sink   i_mnr_fe6_if,
  // Interface to FE_TYPE add (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE_TYPE sub (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if
);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_o_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   add_fe_i_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_o_if [2:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   sub_fe_i_if [2:0] (i_clk);


if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe_o_if    [2:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe_i_if    [2:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe2_o_if   [2:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe2_i_if   [2:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe6_o_if         (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) inv_fe6_i_if         (i_clk);


always_comb begin
  i_inv_fe_if.rdy = inv_fe_o_if[1].rdy;
  inv_fe_o_if[1].copy_if_comb(i_inv_fe_if.dat,
                              i_inv_fe_if.val,
                              i_inv_fe_if.sop,
                              i_inv_fe_if.eop,
                              i_inv_fe_if.err,
                              i_inv_fe_if.mod,
                              i_inv_fe_if.ctl);
  inv_fe_i_if[1].rdy = o_inv_fe_if.rdy;
  o_inv_fe_if.copy_if_comb(inv_fe_i_if[1].dat,
                           inv_fe_i_if[1].val,
                           inv_fe_i_if[1].sop,
                           inv_fe_i_if[1].eop,
                           inv_fe_i_if[1].err,
                           inv_fe_i_if[1].mod,
                           inv_fe_i_if[1].ctl);

  i_inv_fe2_if.rdy = inv_fe2_o_if[1].rdy;
  inv_fe2_o_if[1].copy_if_comb(i_inv_fe2_if.dat,
                               i_inv_fe2_if.val,
                               i_inv_fe2_if.sop,
                               i_inv_fe2_if.eop,
                               i_inv_fe2_if.err,
                               i_inv_fe2_if.mod,
                               i_inv_fe2_if.ctl);
  inv_fe2_i_if[1].rdy = o_inv_fe2_if.rdy;
  o_inv_fe2_if.copy_if_comb(inv_fe2_i_if[1].dat,
                            inv_fe2_i_if[1].val,
                            inv_fe2_i_if[1].sop,
                            inv_fe2_i_if[1].eop,
                            inv_fe2_i_if[1].err,
                            inv_fe2_i_if[1].mod,
                            inv_fe2_i_if[1].ctl);

end

bin_inv_s #(
  .P     ( bls12_381_pkg::P ),
  .LEVEL ( 2                )
)
bin_inv_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_dat_if ( inv_fe_i_if[2] ),
  .i_dat_if ( inv_fe_o_if[2] )
);

ec_fe2_inv_s #(
  .FE_TYPE     ( FE_TYPE          ),
  .OVR_WRT_BIT ( OVR_WRT_BIT      ) // Needs 2 bits
)
ec_fe2_inv_s(
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_inv_fe2_if ( inv_fe2_i_if[2] ) ,
  .i_inv_fe2_if ( inv_fe2_o_if[2] ),
  .o_inv_fe_if  ( inv_fe_o_if[0]  ),
  .i_inv_fe_if  ( inv_fe_i_if[0]  ),
  .o_mul_fe_if  ( o_mul_fe_if     ),
  .i_mul_fe_if  ( i_mul_fe_if     ),
  .o_add_fe_if  ( add_fe_o_if[0]  ),
  .i_add_fe_if  ( add_fe_i_if[0]  ),
  .o_sub_fe_if  ( sub_fe_o_if[0]  ),
  .i_sub_fe_if  ( sub_fe_i_if[0]  )
);

ec_fe6_inv_s
#(
  .FE_TYPE     ( FE_TYPE          ),
  .FE2_TYPE    ( FE2_TYPE         ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 2  ) // Needs 5 bits
)
ec_fe6_inv_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe2_if ( o_mul_fe2_if    ),
  .i_mul_fe2_if ( i_mul_fe2_if    ),
  .o_add_fe_if  ( add_fe_o_if[1]  ),
  .i_add_fe_if  ( add_fe_i_if[1]  ),
  .o_sub_fe_if  ( sub_fe_o_if[1]  ),
  .i_sub_fe_if  ( sub_fe_i_if[1]  ),
  .o_mnr_fe2_if ( o_mnr_fe2_if    ),
  .i_mnr_fe2_if ( i_mnr_fe2_if    ),
  .o_inv_fe2_if ( inv_fe2_o_if[0] ),
  .i_inv_fe2_if ( inv_fe2_i_if[0] ),
  .o_inv_fe6_if ( inv_fe6_i_if    ),
  .i_inv_fe6_if ( inv_fe6_o_if    )
);

ec_fe12_inv_s #(
  .FE_TYPE     ( FE_TYPE         ),
  .OVR_WRT_BIT ( OVR_WRT_BIT + 7 ) // Needs 3 bits
)
ec_fe12_inv_s (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe6_if ( o_mul_fe6_if   ),
  .i_mul_fe6_if ( i_mul_fe6_if   ),
  .o_sub_fe_if  ( sub_fe_o_if[2] ),
  .i_sub_fe_if  ( sub_fe_i_if[2] ),
  .o_mnr_fe6_if ( o_mnr_fe6_if   ),
  .i_mnr_fe6_if ( i_mnr_fe6_if   ),
  .o_inv_fe6_if ( inv_fe6_o_if   ),
  .i_inv_fe6_if ( inv_fe6_i_if   ),
  .o_inv_fe12_if ( o_inv_fe12_if ),
  .i_inv_fe12_if ( i_inv_fe12_if )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 8  ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_fe_o_if[1:0] ),
  .o_res ( o_add_fe_if      ),
  .i_res ( i_add_fe_if      ),
  .o_axi ( add_fe_i_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 3                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 10 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_fe_o_if[2:0] ),
  .o_res ( o_sub_fe_if      ),
  .i_res ( i_sub_fe_if      ),
  .o_axi ( sub_fe_i_if[2:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( $bits(FE_TYPE)   ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 11 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_inv (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( inv_fe_o_if[1:0] ),
  .o_res ( inv_fe_o_if[2]   ),
  .i_res ( inv_fe_i_if[2]   ),
  .o_axi ( inv_fe_i_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( $bits(FE_TYPE)   ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 12 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe2_inv (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( inv_fe2_o_if[1:0] ),
  .o_res ( inv_fe2_o_if[2]   ),
  .i_res ( inv_fe2_i_if[2]   ),
  .o_axi ( inv_fe2_i_if[1:0] )
);

endmodule