/*
  This performs a multiplication followed by modular reduction
  using karabusa multiplier and barrets algorithm on Fp elements.

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
  // Input value
  input [DAT_BITS-1:0] i_dat_a,
  input [DAT_BITS-1:0] i_dat_b,
  input                i_val,
  input                i_err,
  input [CTL_BITS-1:0] i_ctl,
  output logic         o_rdy,
  // output
  output logic [DAT_BITS-1:0] o_dat,
  output logic [CTL_BITS-1:0] o_ctl,
  input                       i_rdy,
  output logic                o_val
);

// The reduction mod takes DAT_BITS + 1 bits, but we also need to make sure we are a multiple of KARATSUBA_LVL*2
localparam MLT_BITS = DAT_BITS + 1 + (KARATSUBA_LVL*2 - (DAT_BITS + 1) % (KARATSUBA_LVL*2));
localparam ARB_BIT = CTL_BITS;

if_axi_stream #(.DAT_BITS(MLT_BITS*2), .CTL_BITS(CTL_BITS+2)) mult_if_in [3:0] (i_clk);
if_axi_stream #(.DAT_BITS(MLT_BITS*2), .CTL_BITS(CTL_BITS+2)) mult_if_out [3:0] (i_clk);

always_comb begin
  mult_if_in[0].mod = 0;
  mult_if_in[0].sop = 1;
  mult_if_in[0].eop = 1;
  mult_if_in[0].dat = 0;
  mult_if_in[0].dat[0 +: DAT_BITS] = i_dat_a;
  mult_if_in[0].dat[MLT_BITS +: DAT_BITS] = i_dat_b;
  mult_if_in[0].val = i_val;
  mult_if_in[0].err = i_err;
  mult_if_in[0].ctl = i_ctl;
  o_rdy = mult_if_in[0].rdy;

  mult_if_out[3].sop = 1;
  mult_if_out[3].eop = 1;
  mult_if_out[3].mod = 0;
  mult_if_out[3].err = 0;
end

resource_share # (
  .NUM_IN       ( 3       ),
  .OVR_WRT_BIT  ( ARB_BIT ),
  .PIPELINE_IN  ( 0       ),
  .PIPELINE_OUT ( 1       ),
  .PRIORITY_IN  ( 1       )
)
resource_share_mod (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mult_if_in[2:0]  ),
  .o_res ( mult_if_in[3]    ),
  .i_res ( mult_if_out[3]   ),
  .o_axi ( mult_if_out[2:0] )
);

karatsuba_ofman_mult # (
  .BITS     ( MLT_BITS      ),
  .LEVEL    ( KARATSUBA_LVL ),
  .CTL_BITS ( CTL_BITS + 2  )
)
karatsuba_ofman_mult (
  .i_clk  ( i_clk ),
  .i_rst  ( i_rst ),
  .i_ctl  ( mult_if_in[3].ctl ),
  .i_dat_a( mult_if_in[3].dat[0 +: MLT_BITS]   ),
  .i_dat_b( mult_if_in[3].dat[MLT_BITS +: MLT_BITS] ),
  .i_val  ( mult_if_in[3].val ),
  .o_rdy  ( mult_if_in[3].rdy ),
  .o_dat  ( mult_if_out[3].dat ),
  .o_val  ( mult_if_out[3].val ),
  .i_rdy  ( mult_if_out[3].rdy ),
  .o_ctl  ( mult_if_out[3].ctl )
);



barret_mod_pipe #(
  .DAT_BITS ( MLT_BITS ),
  .CTL_BITS ( CTL_BITS ),
  .P        ( P        )
)
barret_mod_pipe (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_dat ( mult_if_out[0].dat ),
  .i_val ( mult_if_out[0].val ),
  .i_ctl ( mult_if_out[0].ctl ),
  .o_ctl ( o_ctl ),
  .o_rdy ( mult_if_out[0].rdy ),
  .o_dat ( o_dat ),
  .o_val ( o_val ),
  .i_rdy ( i_rdy ),
  .o_mult_if_0 ( mult_if_in[1]  ),
  .i_mult_if_0 ( mult_if_out[1] ),
  .o_mult_if_1 ( mult_if_in[2]  ),
  .i_mult_if_1 ( mult_if_out[2] )
);

endmodule