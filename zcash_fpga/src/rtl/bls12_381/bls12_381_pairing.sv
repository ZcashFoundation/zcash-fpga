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
  parameter OVR_WRT_BIT = 8,             // We override 16 bits from here for internal control
  parameter SQ_BIT = OVR_WRT_BIT + 16,   // We can re-use this bit as it is not used by multiplier
  parameter FMAP_BIT = OVR_WRT_BIT + 17, // Bit used to store power for fmap operation
  parameter POW_BIT  = OVR_WRT_BIT + 19  // These bits hold the value for the exponentiation (need $bits(bls12_381_pkg::ATE_X), 64 bits)
)(
  input i_clk, i_rst,
  // Inputs
  input                i_val,
  input                i_mode,  // 0 == ate pairing, 1 == only point multiplication
  input FE_TYPE        i_key,   // Input key when in mode == 1
  output logic         o_rdy,
  input G1_FP_AF_TYPE  i_g1_af,
  input G2_FP_AF_TYPE  i_g2_af,
  if_axi_stream.source o_fe12_if,
  if_axi_stream.source o_p_jb_if,     // Output point if we did a point multiplication
  // Interface to FE_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if,
  // Interface to FE2_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE_TYPE adder (mod P)
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface to FE12_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe12_if,
  if_axi_stream.sink   i_mul_fe12_if,
  // Interface to FE12_TYPE exponentiation (mod P)
  if_axi_stream.source o_pow_fe12_if,
  if_axi_stream.sink   i_pow_fe12_if,
  // Interface to FE12_TYPE frobenius map (mod P)
  if_axi_stream.source o_fmap_fe12_if,
  if_axi_stream.sink   i_fmap_fe12_if,
   // Interface to FE12_TYPE inversion (mod P)
  if_axi_stream.source o_inv_fe12_if,
  if_axi_stream.sink   i_inv_fe12_if
);


if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_i_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe_o_if [1:0] (i_clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe12_o_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe12_i_if [1:0] (i_clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_i_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe2_o_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_i_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   add_fe_o_if [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_i_if [2:0] (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   sub_fe_o_if [2:0] (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) final_exp_fe12_o_if (i_clk);


logic dbl_i_val, dbl_o_rdy;
logic add_i_val, add_o_rdy;

logic wait_dbl, wait_add, stage_done;

G1_FP_AF_TYPE g1_af_i;
G2_FP_JB_TYPE g2_r_jb_i, add_g2_o, dbl_g2_o;
G2_FP_AF_TYPE g2_af_i;

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   add_f12_o_if (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   dbl_f12_o_if (i_clk);

logic [$clog2($bits(FE_TYPE))-1:0] ate_loop_cnt;
logic [1:0] miller_mult_cnt;

enum {IDLE, POINT_MULT_DBL, POINT_MULT_ADD, POINT_MULT_DONE, MILLER_LOOP, FINAL_EXP} pair_state;

FE12_TYPE f;
logic f_val;
logic [3:0] out_cnt;
logic point_mul_mode, found_one;

FE_TYPE key;

always_comb begin
  final_exp_fe12_o_if.dat = f[0][0][0];
  final_exp_fe12_o_if.err = 0;
  final_exp_fe12_o_if.ctl = 0;
  final_exp_fe12_o_if.mod = 0;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    final_exp_fe12_o_if.val <= 0;
    final_exp_fe12_o_if.sop <= 0;
    final_exp_fe12_o_if.eop <= 0;
    g1_af_i <= 0;
    g2_r_jb_i <= 0;
    mul_fe12_i_if[0].rdy <= 0;
    mul_fe12_o_if[0].reset_source();
    pair_state <= IDLE;
    add_i_val <= 0;
    dbl_i_val <= 0;
    o_rdy <= 0;
    wait_dbl <= 0;
    wait_add <= 0;
    miller_mult_cnt <= 0;
    ate_loop_cnt <= ATE_X_START-1;

    f <= FE12_one;
    f_val <= 0;
    out_cnt <= 0;
    point_mul_mode <= 0;

    key <= 0;
    found_one <= 0;
    stage_done <= 0;
    
    o_p_jb_if.reset_source();
    
    dbl_f12_o_if.rdy <= 0;
    add_f12_o_if.rdy <= 0;

  end else begin

    if (add_o_rdy) add_i_val <= 0;
    if (dbl_o_rdy) dbl_i_val <= 0;
    if (mul_fe12_o_if[0].rdy) mul_fe12_o_if[0].val <= 0;
    if (final_exp_fe12_o_if.rdy) final_exp_fe12_o_if.val <= 0;

    mul_fe12_i_if[0].rdy <= 1;
    if (mul_fe12_i_if[0].val && mul_fe12_i_if[0].rdy) begin
      f <= {mul_fe12_i_if[0].dat, f[1], f[0][2:1], f[0][0][1]};
      f_val <= mul_fe12_i_if[0].eop;
    end
    
    dbl_f12_o_if.rdy <= 0;
    add_f12_o_if.rdy <= 0;

    case(pair_state)
      IDLE: begin
        ate_loop_cnt <= i_mode == 0 ? ATE_X_START-1 : $bits(FE_TYPE)-1;
        f <= FE12_one;
        add_i_val <= 0;
        dbl_i_val <= 0;
        wait_dbl <= 0;
        wait_add <= 0;
        out_cnt <= 0;
        f_val <= 0;
        o_rdy <= 1;
        miller_mult_cnt <= 0;
        found_one <= 0;
        stage_done <= 0;
        if (i_val && o_rdy) begin
          pair_state <= i_mode == 0 ? MILLER_LOOP : POINT_MULT_DBL;
          key <= i_key;
          point_mul_mode <= i_mode;
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
          wait_dbl <= 1;
        end

        if (wait_dbl && dbl_f12_o_if.val && dbl_f12_o_if.sop && dbl_f12_o_if.rdy) begin
          g2_r_jb_i <= dbl_g2_o;
          if (~wait_add && ATE_X[ate_loop_cnt] == 1) begin
            add_i_val <= 1;
            wait_add <= 1;
          end
        end

        // Also three multiplications
        case(miller_mult_cnt)
          0: begin // Square first
            if(~mul_fe12_o_if[0].val || (mul_fe12_o_if[0].val && mul_fe12_o_if[0].rdy)) begin
              mul_fe12_o_if[0].val <= 1;
              mul_fe12_o_if[0].sop <= out_cnt == 0;
              mul_fe12_o_if[0].eop <= out_cnt == 11;
              mul_fe12_o_if[0].dat <= {f[0][0][0], f[0][0][0]}; //square
              mul_fe12_o_if[0].ctl <= miller_mult_cnt;
              mul_fe12_o_if[0].ctl[SQ_BIT] <= 1;
              out_cnt <= out_cnt + 1;
              f <= {mul_fe12_i_if[0].dat, f[1], f[0][2:1], f[0][0][1]};
              if (out_cnt == 11) begin
                out_cnt <= 0;
                miller_mult_cnt <= 1;
              end
            end
          end
          1: begin // Multiply by double result
            if(~dbl_f12_o_if.rdy && (~mul_fe12_o_if[0].val || (mul_fe12_o_if[0].val && mul_fe12_o_if[0].rdy))) begin
              if ((dbl_f12_o_if.val && f_val) || (out_cnt/2 == 5)) begin
                mul_fe12_o_if[0].sop <= out_cnt == 0;
                mul_fe12_o_if[0].eop <= out_cnt == 11;
                mul_fe12_o_if[0].val <= dbl_f12_o_if.val || (out_cnt/2 == 2) || (out_cnt/2 == 3) || (out_cnt/2 == 5);
                dbl_f12_o_if.rdy <= (out_cnt/2 == 0) || (out_cnt/2 == 1) || (out_cnt/2 == 4);
                case (out_cnt/2) inside
                  0,1,4: mul_fe12_o_if[0].dat <= {dbl_f12_o_if.dat, f[0][0][0]};
                  default: mul_fe12_o_if[0].dat <= {381'd0, f[0][0][0]};
                endcase
                
                out_cnt <= out_cnt + 1;
                f <= {mul_fe12_i_if[0].dat, f[1], f[0][2:1], f[0][0][1]};
                if (out_cnt == 11) begin
                  f_val <= 0;
                  out_cnt <= 0;
                  miller_mult_cnt <= ATE_X[ate_loop_cnt] == 0 ? 3 : 2;
                end                  
                 
                mul_fe12_o_if[0].ctl <= miller_mult_cnt;
                mul_fe12_o_if[0].ctl[SQ_BIT] <= 0;
                
              end
            end
          end
          2: begin  // Multiply by add result
            if(~add_f12_o_if.rdy && (~mul_fe12_o_if[0].val || (mul_fe12_o_if[0].val && mul_fe12_o_if[0].rdy))) begin
              if ((add_f12_o_if.val && f_val) || (out_cnt/2 == 5)) begin
                g2_r_jb_i <= add_g2_o;
                mul_fe12_o_if[0].ctl <= miller_mult_cnt;
                mul_fe12_o_if[0].ctl[SQ_BIT] <= 0;
                mul_fe12_o_if[0].sop <= out_cnt == 0;
                mul_fe12_o_if[0].eop <= out_cnt == 11;
                mul_fe12_o_if[0].val <= add_f12_o_if.val || (out_cnt/2 == 2) || (out_cnt/2 == 3) || (out_cnt/2 == 5);
                add_f12_o_if.rdy <= (out_cnt/2 == 0) || (out_cnt/2 == 1) || (out_cnt/2 == 4);
                out_cnt <= out_cnt + 1;
                case (out_cnt/2) inside
                  0,1,4: mul_fe12_o_if[0].dat <= {add_f12_o_if.dat, f[0][0][0]};
                  default: mul_fe12_o_if[0].dat <= {381'd0, f[0][0][0]};
                endcase
                f <= {mul_fe12_i_if[0].dat, f[1], f[0][2:1], f[0][0][1]};
                if (out_cnt == 11) begin
                  f_val <= 0;
                  out_cnt <= 0;
                  miller_mult_cnt <= 3;
                end
              end
            end
          end
          3: begin
            // Wait for result and then move counter, start next stage
            if (f_val) begin
              wait_dbl <= 0;
              f_val <= 0;
              wait_add <= 0;
              miller_mult_cnt <= 0;
              ate_loop_cnt <= ate_loop_cnt - 1;
              if (ate_loop_cnt == 0) begin
                pair_state <= FINAL_EXP;
              end
            end
          end
        endcase

      end
      FINAL_EXP: begin
        if (~final_exp_fe12_o_if.val || (final_exp_fe12_o_if.val && final_exp_fe12_o_if.rdy)) begin
          final_exp_fe12_o_if.val <= 1;
          final_exp_fe12_o_if.sop <= out_cnt == 0;
          final_exp_fe12_o_if.eop <= out_cnt == 11;
          out_cnt <= out_cnt + 1;
          if (final_exp_fe12_o_if.val) f <= {mul_fe12_i_if[0].dat, f[1], f[0][2:1], f[0][0][1]};
          if (out_cnt == 11) begin
            pair_state <= IDLE;
          end
        end
      end
      POINT_MULT_DBL: begin
        dbl_f12_o_if.rdy <= 1;
        if(found_one == 0) begin
          key <= key << 1;
          ate_loop_cnt <= ate_loop_cnt - 1;
          found_one = key[$bits(FE_TYPE)-1];
        end else begin
          if (~wait_dbl) begin
            wait_dbl <= 1;
            dbl_i_val <= 1;
          end
          if (dbl_f12_o_if.val) begin
            wait_dbl <= 0;
            dbl_i_val <= 0;
            g2_r_jb_i <= dbl_g2_o;
            if (key[$bits(FE_TYPE)-1] == 1) begin
              pair_state <= POINT_MULT_ADD;
            end else if (ate_loop_cnt == 0) begin
              pair_state <= POINT_MULT_DONE;
            end else begin
              ate_loop_cnt <= ate_loop_cnt - 1;
              key <= key << 1;
            end
          end
        end
      end
      POINT_MULT_ADD: begin
        add_f12_o_if.rdy <= 1;
        if (~wait_add) begin
          wait_add <= 1;
          add_i_val <= 1;
        end
        if (add_f12_o_if.val) begin
          wait_add <= 0;
          add_i_val <= 0;
          g2_r_jb_i <= add_g2_o;
          if (ate_loop_cnt == 0) begin
            pair_state <= POINT_MULT_DONE;
          end else begin
            ate_loop_cnt <= ate_loop_cnt - 1;
            key <= key << 1;
            pair_state <= POINT_MULT_DBL;
          end
        end      
      end
      POINT_MULT_DONE: begin
        if (~o_p_jb_if.val || (o_p_jb_if.val && o_p_jb_if.rdy)) begin
          o_p_jb_if.val <= 1;
          o_p_jb_if.sop <= out_cnt == 0;
          o_p_jb_if.eop <= out_cnt == 5;
          o_p_jb_if.dat <= g2_r_jb_i;
          
          out_cnt <= out_cnt + 1;
          g2_r_jb_i <= g2_r_jb_i >> $bits(FE_TYPE);
          if (o_p_jb_if.val && o_p_jb_if.rdy && o_p_jb_if.eop) begin
            pair_state <= IDLE;
            out_cnt <= 0;
            o_p_jb_if.val <= 0;
          end
        end
      end
    endcase

  end
end

bls12_381_pairing_miller_dbl #(
  .FE_TYPE       ( FE_TYPE       ),
  .FE2_TYPE      ( FE2_TYPE      ),
  .G1_FP_AF_TYPE ( G1_FP_AF_TYPE ),
  .G2_FP_JB_TYPE ( G2_FP_JB_TYPE ),
  .OVR_WRT_BIT   ( OVR_WRT_BIT   )
)
bls12_381_pairing_miller_dbl (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_val            ( dbl_i_val      ),
  .i_point_mul_mode ( point_mul_mode ),
  .o_rdy            ( dbl_o_rdy      ),
  .i_g1_af          ( g1_af_i        ),
  .i_g2_jb          ( g2_r_jb_i      ),
  .o_res_fe12_sparse_if    ( dbl_f12_o_if ),
  .o_g2_jb                 ( dbl_g2_o     ),
  .o_mul_fe2_if ( mul_fe2_i_if[0] ),
  .i_mul_fe2_if ( mul_fe2_o_if[0] ),
  .o_add_fe_if  ( add_fe_i_if[0]  ),
  .i_add_fe_if  ( add_fe_o_if[0]  ),
  .o_sub_fe_if  ( sub_fe_i_if[0]  ),
  .i_sub_fe_if  ( sub_fe_o_if[0]  ),
  .o_mul_fe_if  ( mul_fe_i_if[0]  ),
  .i_mul_fe_if  ( mul_fe_o_if[0]  )
);

bls12_381_pairing_miller_add #(
  .FE_TYPE       ( FE_TYPE       ),
  .FE2_TYPE      ( FE2_TYPE      ),
  .G1_FP_AF_TYPE ( G1_FP_AF_TYPE ),
  .G2_FP_JB_TYPE ( G2_FP_JB_TYPE ),
  .G2_FP_AF_TYPE ( G2_FP_AF_TYPE ),
  .OVR_WRT_BIT   ( OVR_WRT_BIT   )
)
bls12_381_pairing_miller_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_val            ( add_i_val     ),
  .i_point_mul_mode ( point_mul_mode ),
  .o_rdy            ( add_o_rdy      ),
  .i_g1_af          ( g1_af_i        ),
  .i_g2_jb          ( dbl_g2_o       ),
  .i_g2_q_af        ( g2_af_i        ),
  .o_res_fe12_sparse_if ( add_f12_o_if ),
  .o_g2_jb              ( add_g2_o     ),
  .o_mul_fe2_if ( mul_fe2_i_if[1] ),
  .i_mul_fe2_if ( mul_fe2_o_if[1] ),
  .o_add_fe_if  ( add_fe_i_if[1]  ),
  .i_add_fe_if  ( add_fe_o_if[1]  ),
  .o_sub_fe_if  ( sub_fe_i_if[1]  ),
  .i_sub_fe_if  ( sub_fe_o_if[1]  ),
  .o_mul_fe_if  ( mul_fe_i_if[1]  ),
  .i_mul_fe_if  ( mul_fe_o_if[1]  )
);

bls12_381_final_exponent #(
  .OVR_WRT_BIT ( OVR_WRT_BIT ), // Control can overlap
  .FMAP_BIT    ( FMAP_BIT    ),
  .POW_BIT     ( POW_BIT     ),
  .SQ_BIT      ( SQ_BIT      )
)
bls12_381_final_exponent (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .o_mul_fe12_if       ( mul_fe12_o_if[1]    ),
  .i_mul_fe12_if       ( mul_fe12_i_if[1]    ),
  .o_pow_fe12_if       ( o_pow_fe12_if       ),
  .i_pow_fe12_if       ( i_pow_fe12_if       ),
  .o_fmap_fe12_if      ( o_fmap_fe12_if      ),
  .i_fmap_fe12_if      ( i_fmap_fe12_if      ),
  .o_inv_fe12_if       ( o_inv_fe12_if       ),
  .i_inv_fe12_if       ( i_inv_fe12_if       ),
  .o_sub_fe_if         ( sub_fe_i_if[2]      ),
  .i_sub_fe_if         ( sub_fe_o_if[2]      ),
  .o_final_exp_fe12_if ( o_fe12_if           ),
  .i_final_exp_fe12_if ( final_exp_fe12_o_if )
);

resource_share # (
  .NUM_IN       ( 2                 ),
  .DAT_BITS     ( 2*$bits(FE_TYPE)  ),
  .CTL_BITS     ( CTL_BITS          ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 12  ),
  .PIPELINE_IN  ( 0                 ),
  .PIPELINE_OUT ( 0                 )
)
resource_share_fe12_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe12_o_if[1:0] ),
  .o_res ( o_mul_fe12_if      ),
  .i_res ( i_mul_fe12_if      ),
  .o_axi ( mul_fe12_i_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 10 ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe_i_if[1:0] ),
  .o_res ( o_mul_fe_if      ),
  .i_res ( i_mul_fe_if      ),
  .o_axi ( mul_fe_o_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 8  ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe2_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_fe2_i_if[1:0] ),
  .o_res ( o_mul_fe2_if      ),
  .i_res ( i_mul_fe2_if      ),
  .o_axi ( mul_fe2_o_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 8  ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_fe_i_if[1:0] ),
  .o_res ( o_add_fe_if      ),
  .i_res ( i_add_fe_if      ),
  .o_axi ( add_fe_o_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 3                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + 8  ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_fe_i_if[2:0] ),
  .o_res ( o_sub_fe_if      ),
  .i_res ( i_sub_fe_if      ),
  .o_axi ( sub_fe_o_if[2:0] )
);



endmodule