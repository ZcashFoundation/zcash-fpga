/*
  This performs a multiplication followed by modular reduction
  using karabusa multiplier and barrets algorithm on Fp elements.
  (Used when the prime feild is not a special form that allows for
  fast modulus reduction)

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

module ec_fp_mult_mod #(
  parameter                P,                   // Mod value to be used
  parameter                DAT_BITS = $clog2(P),
  parameter                KARATSUBA_LVL = 3,   // Number of levels in the multiplier, each adds 3 clock cycles
  parameter                CTL_BITS = 16
)(
  input i_clk, i_rst,
  if_axi_stream.sink   i_mul,
  if_axi_stream.source o_mul
);

// The reduction mod takes DAT_BITS + 1 bits, but we also need to make sure we are a multiple of KARATSUBA_LVL*2
localparam MLT_BITS = DAT_BITS + 1 + (KARATSUBA_LVL*2 - (DAT_BITS + 1) % (KARATSUBA_LVL*2));
localparam ARB_BIT = CTL_BITS;

if_axi_stream #(.DAT_BITS(MLT_BITS*2), .CTL_BITS(CTL_BITS)) mult_if [4:0] (i_clk);

karatsuba_ofman_mult # (
  .BITS     ( MLT_BITS      ),
  .LEVEL    ( KARATSUBA_LVL ),
  .CTL_BITS ( CTL_BITS   )
)
karatsuba_ofman_mult_0 (
  .i_clk  ( i_clk ),
  .i_rst  ( i_rst ),
  .i_ctl  ( i_mul.ctl ),
  .i_dat_a( {{(MLT_BITS-DAT_BITS){1'd0}}, i_mul.dat[0 +: DAT_BITS]}  ),
  .i_dat_b( {{(MLT_BITS-DAT_BITS){1'd0}}, i_mul.dat[DAT_BITS +: DAT_BITS]} ),
  .i_val  ( i_mul.val ),
  .o_rdy  ( i_mul.rdy ),
  .o_dat  ( mult_if[0].dat  ),
  .o_val  ( mult_if[0].val ),
  .i_rdy  ( mult_if[0].rdy ),
  .o_ctl  ( mult_if[0].ctl )
);

karatsuba_ofman_mult # (
  .BITS     ( MLT_BITS      ),
  .LEVEL    ( KARATSUBA_LVL ),
  .CTL_BITS ( CTL_BITS   )
)
karatsuba_ofman_mult_1 (
  .i_clk  ( i_clk ),
  .i_rst  ( i_rst ),
  .i_ctl  ( mult_if[1].ctl ),
  .i_dat_a( mult_if[1].dat[0 +: MLT_BITS]  ),
  .i_dat_b( mult_if[1].dat[MLT_BITS +: MLT_BITS] ),
  .i_val  ( mult_if[1].val ),
  .o_rdy  ( mult_if[1].rdy ),
  .o_dat  ( mult_if[2].dat ),
  .o_val  ( mult_if[2].val ),
  .i_rdy  ( mult_if[2].rdy ),
  .o_ctl  ( mult_if[2].ctl )
);

karatsuba_ofman_mult # (
  .BITS     ( MLT_BITS      ),
  .LEVEL    ( KARATSUBA_LVL ),
  .CTL_BITS ( CTL_BITS   )
)
karatsuba_ofman_mult_2 (
  .i_clk  ( i_clk ),
  .i_rst  ( i_rst ),
  .i_ctl  ( mult_if[3].ctl ),
  .i_dat_a( mult_if[3].dat[0 +: MLT_BITS]  ),
  .i_dat_b( mult_if[3].dat[MLT_BITS +: MLT_BITS] ),
  .i_val  ( mult_if[3].val ),
  .o_rdy  ( mult_if[3].rdy ),
  .o_dat  ( mult_if[4].dat ),
  .o_val  ( mult_if[4].val ),
  .i_rdy  ( mult_if[4].rdy ),
  .o_ctl  ( mult_if[4].ctl )
);

barret_mod_pipe #(
  .DAT_BITS ( MLT_BITS ),
  .CTL_BITS ( CTL_BITS ),
  .P        ( P        )
)
barret_mod_pipe (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_dat ( mult_if[0].dat ),
  .i_val ( mult_if[0].val ),
  .i_ctl ( mult_if[0].ctl ),
  .o_ctl ( o_mul.ctl ),
  .o_rdy ( mult_if[0].rdy ),
  .o_dat ( o_mul.dat ),
  .o_val ( o_mul.val ),
  .i_rdy ( o_mul.rdy ),
  .o_mult_if_0 ( mult_if[1]  ),
  .i_mult_if_0 ( mult_if[2] ),
  .o_mult_if_1 ( mult_if[3]  ),
  .i_mult_if_1 ( mult_if[4] )
);

endmodule