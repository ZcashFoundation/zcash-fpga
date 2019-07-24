/*
  This is the top level for the bls12-381 pairing engine.
  It performs both the miller loop and final exponentiation required for ate pairing (G2 x G1).
  Inputs are points in G1 and G2 (affine coordinates)
  Output is a Fp12 element.

  TODO: Replace multiplications in fe12 with spare versions.
  TODO: Implement squaring functions.

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

module bls12_381_pairing
  import bls12_381_pkg::*;
#(
  parameter type FE_TYPE = fe_t,
  parameter type FE2_TYPE = fe2_t,
  parameter type FE12_TYPE = fe12_t,
  parameter type G1_FP_AF_TYPE = af_point_t,
  parameter type G2_FP_AF_TYPE = fp2_af_point_t,
  parameter type G2_FP_JB_TYPE = fp2_jb_point_t,
  parameter CTL_BITS = 32,
  parameter OVR_WRT_BIT = 8 // We override 16 bits from here
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
  // Interface to FE2_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE2_TYPE adder (mod P)
  if_axi_stream.source o_add_fe2_if,
  if_axi_stream.sink   i_add_fe2_if,
  // Interface to FE2_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe2_if,
  if_axi_stream.sink   i_sub_fe2_if,
  // Interface to FE12_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe12_if,
  if_axi_stream.sink   i_mul_fe12_if
);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_i_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe_o_if [2:0] (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_i_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe2_o_if [2:0] (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) add_fe2_i_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS))   add_fe2_o_if [2:0] (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe2_i_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS))   sub_fe2_o_if [2:0] (clk);


logic dbl_i_val, dbl_o_rdy, dbl_o_val, dbl_i_rdy, dbl_o_err;
logic add_i_val, add_o_rdy, add_o_val, add_i_rdy, add_o_err;

logic wait_dbl, wait_add;

G1_FP_AF_TYPE g1_af_i;
G2_FP_JB_TYPE g2_r_jb_i, add_g2_o, dbl_g2_o;
G2_FP_AF_TYPE g2_af_i;
FE12_TYPE add_f12_o, dbl_f12_o;
logic [$clog2(ATE_X_START)-1:0] ate_loop_cnt;

enum {IDLE, MILLER_LOOP, FINAL_EXP} pair_state;


always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_fe12 <= 0;
    g1_af_i <= 0;
    g2_r_jb_i <= 0;
    i_mul_fe12_if.rdy <= 0;
    o_mul_fe12_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    pair_state <= IDLE;
    add_i_val <= 0;
    dbl_i_val <= 0;
    add_i_rdy <= 0;
    dbl_i_rdy <= 0;
    o_rdy <= 0;
    wait_dbl <= 0;
    wait_add <= 0;
    ate_loop_cnt <= ATE_X_START;
  end else begin

    if (i_rdy && o_val) o_val <= 0;
    if (add_i_val && add_o_rdy) add_i_val <= 0;
    if (dbl_i_val && dbl_o_rdy) dbl_i_val <= 0;
    if (o_mul_fe12_if.val && o_mul_fe12_if.rdy) o_mul_fe12_if.val <= 0;

    i_mul_fe12_if.rdy <= 1;

    case(pair_state)
      IDLE: begin
        ate_loop_cnt <= ATE_X_START;
        o_fe12 <= 0;
        o_rdy <= 1;
        add_i_val <= 0;
        dbl_i_val <= 0;
        add_i_rdy <= 0;
        dbl_i_rdy <= 0;
        wait_dbl <= 0;
        wait_add <= 0;
        if (i_val && o_rdy) begin
          pair_state <= MILLER_LOOP;
          o_rdy <= 0;

          g1_af_i <= i_g1_af;
          g2_af_i <= i_g2_af;

          g2_r_jb_i.x <= i_g2_af.x;
          g2_r_jb_i.y <= i_g2_af.y;
          g2_r_jb_i.z <= 1;
        end
      end
      MILLER_LOOP: begin
        if (~wait_dbl) begin
          dbl_i_val <= 1;

        end

        if (ATE_X[ate_loop_cnt] == 1) begin
          // Do add step in here as well

        end

        // Also three multiplications


        add_i_rdy <= 0;
        dbl_i_rdy <= 0;


      end
      FINAL_EXP: begin

      end
    endcase

  end
end

bls12_381_pairing_miller_dbl #(
  .FE_TYPE       ( FE_TYPE       ),
  .FE2_TYPE      ( FE2_TYPE      ),
  .FE12_TYPE     ( FE12_TYPE     ),
  .G1_FP_AF_TYPE ( G1_FP_AF_TYPE ),
  .G2_FP_JB_TYPE ( G2_FP_JB_TYPE ),
  .OVR_WRT_BIT   ( OVR_WRT_BIT   )
)
bls12_381_pairing_miller_dbl (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_val         ( dbl_i_val ),
  .o_rdy         ( dbl_o_rdy ),
  .i_g1_af       ( g1_af_i   ),
  .i_g2_jb       ( g2_r_jb_i ),
  .o_val         ( dbl_o_val ),
  .i_rdy         ( dbl_i_rdy ),
  .o_err         ( dbl_o_err ),
  .o_res_fe12    ( dbl_f12_o ),
  .o_g2_jb       ( dbl_g2_o ),
  .o_mul_fe2_if ( mul_fe2_i_if[0] ),
  .i_mul_fe2_if ( mul_fe2_o_if[0] ),
  .o_add_fe2_if ( add_fe2_i_if[0] ),
  .i_add_fe2_if ( add_fe2_o_if[0] ),
  .o_sub_fe2_if ( sub_fe2_i_if[0] ),
  .i_sub_fe2_if ( sub_fe2_i_if[0] ),
  .o_mul_fe_if ( mul_fe_i_if[0] ),
  .i_mul_fe_if ( mul_fe_i_if[0] )
);

bls12_381_pairing_miller_add #(
  .FE_TYPE       ( FE_TYPE       ),
  .FE2_TYPE      ( FE2_TYPE      ),
  .FE12_TYPE     ( FE12_TYPE     ),
  .G1_FP_AF_TYPE ( G1_FP_AF_TYPE ),
  .G2_FP_JB_TYPE ( G2_FP_JB_TYPE ),
  .G2_FP_AF_TYPE ( G2_FP_AF_TYPE ),
  .OVR_WRT_BIT   ( OVR_WRT_BIT   )
)
bls12_381_pairing_miller_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_val         ( add_i_val ),
  .o_rdy         ( add_o_rdy ),
  .i_g1_af       ( g1_af_i   ),
  .i_g2_jb       ( g2_r_jb_i ),
  .i_g2_q_af     ( g2_af_i   ),
  .o_val         ( add_o_val ),
  .i_rdy         ( add_i_rdy ),
  .o_err         ( add_o_err ),
  .o_res_fe12    ( add_f12_o ),
  .o_g2_jb       ( add_g2_o ),
  .o_mul_fe2_if ( mul_fe2_i_if[1] ),
  .i_mul_fe2_if ( mul_fe2_o_if[1] ),
  .o_add_fe2_if ( add_fe2_i_if[1] ),
  .i_add_fe2_if ( add_fe2_o_if[1] ),
  .o_sub_fe2_if ( sub_fe2_i_if[1] ),
  .i_sub_fe2_if ( sub_fe2_i_if[1] ),
  .o_mul_fe_if ( mul_fe_i_if[1] ),
  .i_mul_fe_if ( mul_fe_i_if[1] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 8  ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe_i_if[1:0] ),
  .o_res ( mul_fe_i_if[2]   ),
  .i_res ( mul_fe_o_if[2]   ),
  .o_axi ( mul_fe_o_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 8  ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe2_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe2_i_if[1:0] ),
  .o_res ( mul_fe2_i_if[2]   ),
  .i_res ( mul_fe2_o_if[2]   ),
  .o_axi ( mul_fe2_o_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 8  ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe2_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_fe2_i_if[1:0] ),
  .o_res ( add_fe2_i_if[2]   ),
  .i_res ( add_fe2_o_if[2]   ),
  .o_axi ( add_fe2_o_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 8  ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe2_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_fe2_i_if[1:0] ),
  .o_res ( sub_fe2_i_if[2]   ),
  .i_res ( sub_fe2_o_if[2]   ),
  .o_axi ( sub_fe2_o_if[1:0] )
);

endmodule