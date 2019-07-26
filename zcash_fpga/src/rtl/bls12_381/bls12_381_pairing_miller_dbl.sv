/*
  This performs the line evaluation and doubling required for the miller loop
  in the ate pairing.

  Inputs are points in G1 (Fp affine), G2 (Fp2 jacobian)
  The output is a sparse Fe12.

  Equations are mapped to bls12_381_pkg::miller_double_step()

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

module bls12_381_pairing_miller_dbl
#(
  parameter type FE_TYPE,
  parameter type FE2_TYPE,
  parameter type FE12_TYPE,
  parameter type G1_FP_AF_TYPE,
  parameter type G2_FP_JB_TYPE,
  parameter OVR_WRT_BIT = 8 // Require 6 bits from this for control
)(
  input i_clk, i_rst,
  // Inputs
  input               i_val,
  output logic        o_rdy,
  input G1_FP_AF_TYPE i_g1_af,
  input G2_FP_JB_TYPE i_g2_jb,
  // Result is sparse Fe12 and doubled G2 point
  output logic         o_val,
  input                i_rdy,
  output logic         o_err,
  output FE12_TYPE     o_res_fe12,
  output G2_FP_JB_TYPE o_g2_jb,
  // Interface to FE2_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE2_TYPE adder (mod P)
  if_axi_stream.source o_add_fe2_if,
  if_axi_stream.sink   i_add_fe2_if,
  // Interface to FE2_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe2_if,
  if_axi_stream.sink   i_sub_fe2_if,
  // Interface to FE_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if
);

localparam NUM_OVR_WRT_BIT = 6;

logic [36:0] eq_val, eq_wait;
FE2_TYPE zsquared;
FE2_TYPE [6:0] t;
logic o_rdy_l;

always_comb begin
  o_res_fe12 = 0;
  o_res_fe12[0][0] = t[6];
  o_res_fe12[0][1] = t[3];
  o_res_fe12[1][1] = t[0];
  o_val = eq_val[33] && eq_val[34] && eq_val[35] && eq_val[36] && eq_val[30];
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe2_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_add_fe2_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_sub_fe2_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_mul_fe_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_g2_jb <= 0;
    o_err <= 0;

    t <= 0;
    zsquared <= 0;

    i_mul_fe2_if.rdy <= 0;
    i_add_fe2_if.rdy <= 0;
    i_sub_fe2_if.rdy <= 0;
    i_mul_fe_if.rdy <= 0;

    eq_val <= 0;
    eq_wait <= 0;
    o_rdy <= 0;
    o_rdy_l <= 0;
  end else begin

    i_mul_fe2_if.rdy <= 1;
    i_add_fe2_if.rdy <= 1;
    i_sub_fe2_if.rdy <= 1;
    i_mul_fe_if.rdy <= 1;

    if (o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;
    if (o_add_fe2_if.rdy) o_add_fe2_if.val <= 0;
    if (o_sub_fe2_if.rdy) o_sub_fe2_if.val <= 0;
    if (o_mul_fe_if.rdy) o_mul_fe_if.val <= 0;
    if (i_val && o_rdy) o_rdy <= 0;

    if (o_val && i_rdy) begin
      eq_val <= 0;
      eq_wait <= 0;
      t <= 0;
      zsquared <= 0;
      o_rdy_l <= 0;
    end

    if (eq_wait[33] && eq_wait[33] && eq_wait[33] && eq_wait[33] && ~o_rdy_l) begin
       o_rdy <= 1;
       o_rdy_l <= 1;
    end

    // Check any results from multiplier
    if (i_mul_fe2_if.val && i_mul_fe2_if.rdy) begin
      eq_val[i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        0: zsquared <= i_mul_fe2_if.dat;
        1: t[0] <= i_mul_fe2_if.dat;
        4: t[1] <= i_mul_fe2_if.dat;
        5: t[2] <= i_mul_fe2_if.dat;
        7: t[3] <= i_mul_fe2_if.dat;
        12: t[5] <= i_mul_fe2_if.dat;
        16: o_g2_jb.z <= i_mul_fe2_if.dat;
        20: o_g2_jb.y <= i_mul_fe2_if.dat;
        21: t[2] <= i_mul_fe2_if.dat;
        23: t[3] <= i_mul_fe2_if.dat;
        26: t[6] <= i_mul_fe2_if.dat;
        29: t[1] <= i_mul_fe2_if.dat;
        31: t[0] <= i_mul_fe2_if.dat;
        default: o_err <= 1;
      endcase
    end

    // Check any results from sub
    if (i_sub_fe2_if.val && i_sub_fe2_if.rdy) begin
      eq_val[i_sub_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_sub_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        8:  t[3] <= i_sub_fe2_if.dat;
        9: t[3] <= i_sub_fe2_if.dat;
        13: o_g2_jb.x <= i_sub_fe2_if.dat;
        14: o_g2_jb.x <= i_sub_fe2_if.dat;
        17: o_g2_jb.z <= i_sub_fe2_if.dat;
        18: o_g2_jb.z <= i_sub_fe2_if.dat;
        19: o_g2_jb.y <= i_sub_fe2_if.dat;
        22: o_g2_jb.y <= i_sub_fe2_if.dat;
        25: t[3] <= i_sub_fe2_if.dat;
        27: t[6] <= i_sub_fe2_if.dat;
        28: t[6] <= i_sub_fe2_if.dat;
        30: t[6] <= i_sub_fe2_if.dat;
        default: o_err <= 1;
      endcase
    end

    // Check any results from add
    if (i_add_fe2_if.val && i_add_fe2_if.rdy) begin
      eq_val[i_add_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_add_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        2: t[4] <= i_add_fe2_if.dat;
        3: t[4] <= i_add_fe2_if.dat;
        6: t[3] <= i_add_fe2_if.dat;
        10: t[3] <= i_add_fe2_if.dat;
        11: t[6] <= i_add_fe2_if.dat;
        15: o_g2_jb.z <= i_add_fe2_if.dat;
        24: t[3] <= i_add_fe2_if.dat;
        32: t[0] <= i_add_fe2_if.dat;
        default: o_err <= 1;
      endcase
    end

    // Check any results from fe multiplier
    if (i_mul_fe_if.val && i_mul_fe_if.rdy) begin
      eq_val[i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        33: t[0][0] <= i_mul_fe_if.dat;
        34: t[0][1] <= i_mul_fe_if.dat;
        35: t[3][0] <= i_mul_fe_if.dat;
        36: t[3][1] <= i_mul_fe_if.dat;
        default: o_err <= 1;
      endcase
    end

    // Issue new multiplies
    if (~eq_wait[0] && i_val) begin
      fe2_multiply(0, i_g2_jb.z, i_g2_jb.z);
    end else
    if (~eq_wait[1] && i_val) begin
      fe2_multiply(1, i_g2_jb.x, i_g2_jb.x);
    end else
    if (~eq_wait[4] && i_val) begin
      fe2_multiply(4, i_g2_jb.y, i_g2_jb.y);
    end else
    if (~eq_wait[5] && eq_val[4]) begin
      fe2_multiply(5, t[1], t[1]);
    end else
    if (~eq_wait[7] && eq_val[6]) begin
      fe2_multiply(7, t[3], t[3]);
    end else
    if (~eq_wait[12] && eq_val[3]) begin
      fe2_multiply(12, t[4], t[4]);
    end else
    if (~eq_wait[16] && eq_val[15]) begin
      fe2_multiply(16, o_g2_jb.z, o_g2_jb.z);
    end else
    if (~eq_wait[20] && eq_val[19] && eq_val[2]) begin
      fe2_multiply(20, o_g2_jb.y, t[4]);
    end else
    if (~eq_wait[21] && eq_wait[9]) begin
      fe2_multiply(21, 8, t[2]);
    end else
    if (~eq_wait[23] && eq_val[0] && eq_val[2] && eq_wait[14]) begin
      fe2_multiply(23, t[4], zsquared);
    end else
    if (~eq_wait[26] && eq_val[11]) begin
      fe2_multiply(26, t[6], t[6]);
    end else
    if (~eq_wait[29] && eq_wait[17] && eq_val[4] && eq_wait[5] && eq_wait[6]) begin
      fe2_multiply(29, 4, t[1]);
    end else
    if (~eq_wait[31] && eq_val[0] && eq_val[18]) begin
      fe2_multiply(31, o_g2_jb.z, zsquared);
    end

    // Issue new adds
    if (~eq_wait[2] && eq_val[1]) begin
      fe2_addition(2, t[0], t[0]);
    end else
    if (~eq_wait[3] && eq_val[2]) begin
      fe2_addition(3, t[4], t[0]);
    end else
    if (~eq_wait[6] && eq_val[4]) begin
      fe2_addition(6, i_g2_jb.x, t[1]);
    end else
    if (~eq_wait[10] && eq_val[9]) begin
      fe2_addition(10, t[3], t[3]);
    end else
    if (~eq_wait[11] && eq_val[3]) begin
      fe2_addition(11, i_g2_jb.x, t[4]);
    end else
    if (~eq_wait[15] && i_val && eq_wait[0]) begin
      fe2_addition(15, i_g2_jb.z, i_g2_jb.y);
    end else
    if (~eq_wait[24] && eq_val[23]) begin
      fe2_addition(24, t[3], t[3]);
    end else
    if (~eq_wait[32] && eq_val[31]) begin
      fe2_addition(32, t[0], t[0]);
    end

    // Issue new sub
    if (~eq_wait[8] && eq_val[7] && eq_val[1]) begin
      fe2_subtraction(8, t[3], t[0]);
    end else
    if (~eq_wait[9] && eq_val[8] && eq_val[5]) begin
      fe2_subtraction(9, t[3], t[2]);
    end else
    if (~eq_wait[13] && eq_val[12] && eq_val[10]) begin
      fe2_subtraction(13, t[5], t[3]);
    end else
    if (~eq_wait[14] && eq_val[13]) begin
      fe2_subtraction(14, o_g2_jb.x, t[3]);
    end else
    if (~eq_wait[17] && eq_val[16] && eq_val[4]) begin
      fe2_subtraction(17, o_g2_jb.z, t[1]);
    end else
    if (~eq_wait[18] && eq_val[17] && eq_val[0]) begin
      fe2_subtraction(18, o_g2_jb.z, zsquared);
    end else
    if (~eq_wait[19] && eq_val[14] && eq_val[10] && eq_wait[15]) begin
      fe2_subtraction(19, t[3], o_g2_jb.x);
    end else
    if (~eq_wait[22] && eq_val[20] && eq_val[21]) begin
      fe2_subtraction(22, o_g2_jb.y, t[2]);
    end else
    if (~eq_wait[25] && eq_val[24]) begin
      fe2_subtraction(25, 0, t[3]);
    end else
    if (~eq_wait[27] && eq_val[26] && eq_val[1]) begin
      fe2_subtraction(27, t[6], t[0]);
    end else
    if (~eq_wait[28] && eq_val[27] && eq_val[12]) begin
      fe2_subtraction(28, t[6], t[5]);
    end else
    if (~eq_wait[30] && eq_val[29] && eq_val[28]) begin
      fe2_subtraction(30, t[6], t[1]);
    end

    // Issue final fe multiplications
    if (~eq_wait[33] && eq_val[32]) begin
      fe_multiply(33, t[0][0], i_g1_af.y);
    end else
    if (~eq_wait[34] && eq_val[32]) begin
      fe_multiply(34, t[0][1], i_g1_af.y);
    end else
    if (~eq_wait[35] && eq_val[25]) begin
      fe_multiply(35, t[3][0], i_g1_af.x);
    end else
    if (~eq_wait[36] && eq_val[25]) begin
      fe_multiply(36, t[3][1], i_g1_af.x);
    end

  end
end

// Task for subtractions
task fe2_subtraction(input int unsigned ctl, input FE2_TYPE a, b);
  if (~o_sub_fe2_if.val || (o_sub_fe2_if.val && o_sub_fe2_if.rdy)) begin
    o_sub_fe2_if.val <= 1;
    o_sub_fe2_if.dat[0 +: $bits(FE2_TYPE)] <= a;
    o_sub_fe2_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= b;
    o_sub_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for addition
task fe2_addition(input int unsigned ctl, input FE2_TYPE a, b);
  if (~o_add_fe2_if.val || (o_add_fe2_if.val && o_add_fe2_if.rdy)) begin
    o_add_fe2_if.val <= 1;
    o_add_fe2_if.dat[0 +: $bits(FE2_TYPE)] <= a;
    o_add_fe2_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= b;
    o_add_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for using mult
task fe2_multiply(input int unsigned ctl, input FE2_TYPE a, b);
  if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
    o_mul_fe2_if.val <= 1;
    o_mul_fe2_if.dat[0 +: $bits(FE2_TYPE)] <= a;
    o_mul_fe2_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= b;
    o_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for using mult (fe)
task fe_multiply(input int unsigned ctl, input FE_TYPE a, b);
  if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
    o_mul_fe_if.val <= 1;
    o_mul_fe_if.dat[0 +: $bits(FE_TYPE)] <= a;
    o_mul_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b;
    o_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

endmodule