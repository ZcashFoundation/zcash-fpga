/*
  This performs the line evaluation and add required for the miller loop
  in the ate pairing.

  Inputs are points in G1 (Fp affine), G2 (Fp2 jacobian), G2_Q (Fp2 affine)
  The output is a sparse Fe12.

  Equations are mapped to bls12_381_pkg::miller_add_step()

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

module bls12_381_pairing_miller_add
#(
  parameter type FE_TYPE,
  parameter type FE2_TYPE,
  parameter type G1_FP_AF_TYPE,
  parameter type G2_FP_JB_TYPE,
  parameter type G2_FP_AF_TYPE,
  parameter OVR_WRT_BIT = 8 // Require 6 bits from this for control
)(
  input i_clk, i_rst,
  // Inputs
  input               i_val,
  output logic        o_rdy,
  input G1_FP_AF_TYPE i_g1_af,
  input G2_FP_JB_TYPE i_g2_jb,
  input G2_FP_AF_TYPE i_g2_q_af,
  // Result is sparse Fe12 stream and added G2 point
  if_axi_stream.source o_res_fe12_sparse_if,
  output G2_FP_JB_TYPE o_g2_jb,
  // Interface to FE2_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE_TYPE adder (mod P)
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface to FE_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if
);

localparam NUM_OVR_WRT_BIT = 6;

logic [42:0] eq_val, eq_wait;
FE2_TYPE zsquared, ysquared;
FE2_TYPE [10:0] t;
logic [5:0] nxt_fe2_mul, nxt_fe_add, nxt_fe_sub;
logic mul_en, add_en, sub_en;
logic o_rdy_l;
logic mul_cnt, add_cnt, sub_cnt;
logic [2:0] out_cnt;


always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe2_if.reset_source();
    o_add_fe_if.reset_source();
    o_sub_fe_if.reset_source();
    o_mul_fe_if.reset_source();
    o_res_fe12_sparse_if.reset_source();

    o_g2_jb <= 0;
    t <= 0;
    zsquared <= 0;
    ysquared <= 0;

    i_mul_fe2_if.rdy <= 0;
    i_add_fe_if.rdy <= 0;
    i_sub_fe_if.rdy <= 0;
    i_mul_fe_if.rdy <= 0;

    eq_val <= 0;
    eq_wait <= 0;
    o_rdy <= 0;
    o_rdy_l <= 0;

    {out_cnt, mul_cnt, add_cnt, sub_cnt} <= 0;
    {nxt_fe2_mul, nxt_fe_add, nxt_fe_sub} <= 0;
    {mul_en, add_en, sub_en} <= 0;

  end else begin

    i_mul_fe2_if.rdy <= 1;
    i_add_fe_if.rdy <= 1;
    i_sub_fe_if.rdy <= 1;
    i_mul_fe_if.rdy <= 1;

    if (o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;
    if (o_add_fe_if.rdy) o_add_fe_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_mul_fe_if.rdy) o_mul_fe_if.val <= 0;
    if (i_val && o_rdy) o_rdy <= 0;
    if (o_res_fe12_sparse_if.rdy) o_res_fe12_sparse_if.val <= 0;

    if (~o_res_fe12_sparse_if.val || (o_res_fe12_sparse_if.val && o_res_fe12_sparse_if.rdy)) begin
    
      if (eq_val[39] && eq_val[40] && eq_val[41] && eq_val[36] && eq_val[42] &&
          eq_val[19] && eq_val[23] && eq_val[30]) begin
        o_res_fe12_sparse_if.val <= 1;
        out_cnt <= out_cnt + 1;
      end
      o_res_fe12_sparse_if.sop <= out_cnt == 0;
      o_res_fe12_sparse_if.eop <= out_cnt == 5;

      case (out_cnt) inside
        0,1: o_res_fe12_sparse_if.dat <= t[9][out_cnt%2];
        2,3: o_res_fe12_sparse_if.dat <= t[1][out_cnt%2];
        4,5: o_res_fe12_sparse_if.dat <= t[10][out_cnt%2];
      endcase
      
      if(out_cnt == 5) begin
        eq_val <= 0;
        eq_wait <= 0;
        t <= 0;
        zsquared <= 0;
        ysquared <= 0;
        o_rdy_l <= 0;
        {out_cnt, mul_cnt, add_cnt, sub_cnt} <= 0;
        {nxt_fe2_mul, nxt_fe_add, nxt_fe_sub} <= 0;
        {mul_en, add_en, sub_en} <= 0;
      end
    end

    if (eq_wait[39] && eq_wait[40] && eq_wait[41] && eq_wait[42] && ~o_rdy_l) begin
       o_rdy <= 1;
       o_rdy_l <= 1;
    end
    
    if (~sub_en) get_next_sub();
    if (~add_en) get_next_add();
    if (~mul_en) get_next_fe2_mul();

    // Check any results from multiplier
    if (i_mul_fe2_if.val && i_mul_fe2_if.rdy) begin
      if (i_mul_fe2_if.eop) eq_val[i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        0: zsquared[i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        1: ysquared[i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        2: t[0][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        4: t[1][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        7: t[1][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        9: t[3][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        10: t[4][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        11: t[5][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        14: t[9][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        15: t[7][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        16: o_g2_jb.x[i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        21: o_g2_jb.z[i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        24: zsquared[i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        27: t[8][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        28: t[0][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        31: t[10][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        default: o_res_fe12_sparse_if.err <= 1;
      endcase
    end

    // Check any results from sub
    if (i_sub_fe_if.val && i_sub_fe_if.rdy) begin
      if (i_sub_fe_if.eop) eq_val[i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        5: t[1][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        6: t[1][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        8: t[2][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        12: t[6][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        13: t[6][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        17: o_g2_jb.x[i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        18: o_g2_jb.x[i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        19: o_g2_jb.x[i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        22: o_g2_jb.z[i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        23: o_g2_jb.z[i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        26: t[8][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        30: o_g2_jb.y[i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        32: t[10][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        33: t[10][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        35: t[9][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        37: t[6][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        default: o_res_fe12_sparse_if.err <= 1;
      endcase
    end

    // Check any results from add
    if (i_add_fe_if.val && i_add_fe_if.rdy) begin
      if (i_add_fe_if.eop) eq_val[i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        3: t[1][i_add_fe_if.eop] <= i_add_fe_if.dat;
        20: o_g2_jb.z[i_add_fe_if.eop] <= i_add_fe_if.dat;
        25: t[10][i_add_fe_if.eop] <= i_add_fe_if.dat;
        29: t[0][i_add_fe_if.eop] <= i_add_fe_if.dat;
        34: t[9][i_add_fe_if.eop] <= i_add_fe_if.dat;
        36: t[10][i_add_fe_if.eop] <= i_add_fe_if.dat;
        38: t[1][i_add_fe_if.eop] <= i_add_fe_if.dat;
        default: o_res_fe12_sparse_if.err <= 1;
      endcase
    end

    // Check any results from fe multiplier
    if (i_mul_fe_if.val && i_mul_fe_if.rdy) begin
      eq_val[i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        39: t[10][0] <= i_mul_fe_if.dat;
        40: t[10][1] <= i_mul_fe_if.dat;
        41: t[1][0] <= i_mul_fe_if.dat;
        42: t[1][1] <= i_mul_fe_if.dat;
        default: o_res_fe12_sparse_if.err <= 1;
      endcase
    end
    
    // Issue new multiplies
    if (mul_en)
      case (nxt_fe2_mul)
        0: fe2_multiply(0, i_g2_jb.z, i_g2_jb.z);
        1: fe2_multiply(1, i_g2_q_af.y, i_g2_q_af.y);
        2: fe2_multiply(2, zsquared, i_g2_q_af.x);
        4: fe2_multiply(4, t[1], t[1]);
        7: fe2_multiply(7, t[1], zsquared);
        9: fe2_multiply(9, t[2], t[2]);
        10: fe2_multiply(10, t[3], 4);
        11: fe2_multiply(11, t[2], t[4]);
        14: fe2_multiply(14, t[6], i_g2_q_af.x);
        15: fe2_multiply(15, t[4], i_g2_jb.x);
        16: fe2_multiply(16, t[6], t[6]);
        21: fe2_multiply(21, o_g2_jb.z, o_g2_jb.z);
        24: fe2_multiply(24, o_g2_jb.z, o_g2_jb.z);
        27: fe2_multiply(27, t[8], t[6]);
        28: fe2_multiply(28, i_g2_jb.y, t[5]);
        31: fe2_multiply(31, t[10], t[10]);
      endcase
      
    if (add_en)
      case (nxt_fe_add)
        3: fe2_addition(3, i_g2_jb.z, i_g2_q_af.y);
        20: fe2_addition(20, i_g2_jb.z, t[2]);
        25: fe2_addition(25, o_g2_jb.z, i_g2_q_af.y);
        29: fe2_addition(29, t[0], t[0]);
        34: fe2_addition(34, t[9], t[9]);
        36: fe2_addition(36, o_g2_jb.z, o_g2_jb.z);
        38: fe2_addition(38, t[6], t[6]);
      endcase
      
    if (sub_en)
      case (nxt_fe_sub)
        5: fe2_subtraction(5, t[1], ysquared);
        6: fe2_subtraction(6, t[1], zsquared);
        8: fe2_subtraction(8, t[0], i_g2_jb.x);
        12: fe2_subtraction(12, t[1], i_g2_jb.y);
        13: fe2_subtraction(13, t[6], i_g2_jb.y);
        17: fe2_subtraction(17, o_g2_jb.x, t[5]);
        18: fe2_subtraction(18, o_g2_jb.x, t[7]);
        19: fe2_subtraction(19, o_g2_jb.x, t[7]);
        22: fe2_subtraction(22, o_g2_jb.z, zsquared);
        23: fe2_subtraction(23, o_g2_jb.z, t[3]);
        26: fe2_subtraction(26, t[7], o_g2_jb.x);
        30: fe2_subtraction(30, t[8], t[0]);
        32: fe2_subtraction(32, t[10], ysquared);
        33: fe2_subtraction(33, t[10], zsquared);
        35: fe2_subtraction(35, t[9], t[10]);
        37: fe2_subtraction(37, 0, t[6]);
      endcase
     

    // Issue final fe multiplications
    if (~eq_wait[39] && eq_val[36]) begin
      fe_multiply(39, t[10][0], i_g1_af.y);
    end else
    if (~eq_wait[40] && eq_val[36]) begin
      fe_multiply(40, t[10][1], i_g1_af.y);
    end else
    if (~eq_wait[41] && eq_val[38]) begin
      fe_multiply(41, t[1][0], i_g1_af.x);
    end else
    if (~eq_wait[42] && eq_val[38]) begin
      fe_multiply(42, t[1][1], i_g1_af.x);
    end

  end
end

// Task for subtractions
task fe2_subtraction(input int unsigned ctl, input FE2_TYPE a, b);
  if (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy)) begin
    o_sub_fe_if.val <= 1;
    o_sub_fe_if.sop <= sub_cnt == 0;
    o_sub_fe_if.eop <= sub_cnt == 1;
    o_sub_fe_if.dat[0 +: $bits(FE_TYPE)] <= a[sub_cnt];
    o_sub_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b[sub_cnt];
    o_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    if (sub_cnt == 1) begin
      get_next_sub();
    end
    sub_cnt <= sub_cnt + 1;
  end
endtask

// Task for addition
task fe2_addition(input int unsigned ctl, input FE2_TYPE a, b);
  if (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy)) begin
    o_add_fe_if.val <= 1;
    o_add_fe_if.sop <= add_cnt == 0;
    o_add_fe_if.eop <= add_cnt == 1;
    o_add_fe_if.dat[0 +: $bits(FE_TYPE)] <= a[add_cnt];
    o_add_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b[add_cnt];
    o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    if (add_cnt == 1) begin
      get_next_add();
    end
    add_cnt <= add_cnt + 1;
  end
endtask

// Task for using mult
task fe2_multiply(input int unsigned ctl, input FE2_TYPE a, b);
  if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
    o_mul_fe2_if.val <= 1;
    o_mul_fe2_if.sop <= mul_cnt == 0;
    o_mul_fe2_if.eop <= mul_cnt == 1;
    o_mul_fe2_if.dat[0 +: $bits(FE_TYPE)] <= a[mul_cnt];
    o_mul_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b[mul_cnt];
    o_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    if (mul_cnt == 1) begin
      get_next_fe2_mul();
    end
    mul_cnt <= mul_cnt + 1;
  end
endtask

// Task for using mult (fe)
task fe_multiply(input int unsigned ctl, input FE_TYPE a, b);
  if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
    o_mul_fe_if.val <= 1;
    o_mul_fe_if.sop <= 1;
    o_mul_fe_if.eop <= 1;
    o_mul_fe_if.dat[0 +: $bits(FE_TYPE)] <= a;
    o_mul_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b;
    o_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

task get_next_fe2_mul();
  mul_en <= 1;
  if (~eq_wait[0] && i_val)
    nxt_fe2_mul <= 0;
  else if (~eq_wait[1] && i_val)
    nxt_fe2_mul <= 1;
  else if (~eq_wait[2] && eq_val[0])
    nxt_fe2_mul <= 2;
  else if (~eq_wait[4] && eq_val[3])
    nxt_fe2_mul <= 4;
  else if(~eq_wait[7] && eq_val[6])
    nxt_fe2_mul <= 7;
  else if(~eq_wait[9] && eq_val[8])
    nxt_fe2_mul <= 9;
  else if(~eq_wait[10] && eq_val[9])
    nxt_fe2_mul <= 10;
  else if (~eq_wait[11] && eq_val[8] && eq_val[10])
    nxt_fe2_mul <= 11;
  else if (~eq_wait[14] && eq_val[13])
    nxt_fe2_mul <= 14;
  else if (~eq_wait[15] && eq_val[10])
    nxt_fe2_mul <= 15;
  else if (~eq_wait[16] && eq_val[13])
    nxt_fe2_mul <= 16;
  else if (~eq_wait[21] && eq_val[20])
    nxt_fe2_mul <= 21;
  else if (~eq_wait[24] && eq_val[23])
    nxt_fe2_mul <= 24;    
  else if (~eq_wait[27] && eq_val[26] && eq_val[13])
    nxt_fe2_mul <= 27;
  else if (~eq_wait[28] && eq_val[11] && eq_wait[8])
    nxt_fe2_mul <= 28;
  else if(~eq_wait[31] && eq_val[25]) 
    nxt_fe2_mul <= 31;
  else
    mul_en <= 0;
endtask

task get_next_add();
  add_en <= 1;
  if (~eq_wait[3] && i_val) 
    nxt_fe_add <= 3;
  else if (~eq_wait[20] && eq_val[8])
    nxt_fe_add <= 20;
  else if (~eq_wait[25] && eq_val[23])
    nxt_fe_add <= 25;
  else if (~eq_wait[29] && eq_val[28])
    nxt_fe_add <= 29;
  else if (~eq_wait[34] && eq_val[14]) 
    nxt_fe_add <= 34;
  else if (~eq_wait[36] && eq_val[23] && eq_wait[35])
    nxt_fe_add <= 36;
  else if (~eq_wait[38] && eq_val[37])
    nxt_fe_add <= 38;
  else
    add_en <= 0;
endtask

task get_next_sub();
  sub_en <= 1;
  if (~eq_wait[5] && eq_val[4] && eq_val[1])
    nxt_fe_sub <= 5;
  else if (~eq_wait[6] && eq_val[5] && eq_val[0]) 
    nxt_fe_sub <= 6;
  else if (~eq_wait[8] && eq_val[2] && i_val)
    nxt_fe_sub <= 8;
  else if (~eq_wait[12] && eq_val[7]) 
    nxt_fe_sub <= 12;
  else if (~eq_wait[13] && eq_val[12])
    nxt_fe_sub <= 13; 
  else if (~eq_wait[17] && eq_val[11] && eq_val[16])
    nxt_fe_sub <= 17; 
  else if (~eq_wait[18] && eq_val[17] && eq_val[10])
    nxt_fe_sub <= 18;
  else if (~eq_wait[19] && eq_val[18] && eq_val[15])
    nxt_fe_sub <= 19;
  else if (~eq_wait[22] && eq_val[21] && eq_val[0])
    nxt_fe_sub <= 22;
  else if (~eq_wait[23] && eq_val[22] && eq_val[9])
    nxt_fe_sub <= 23;
  else if (~eq_wait[26] && eq_val[19] && eq_val[15])
    nxt_fe_sub <= 26;
  else if (~eq_wait[30] && eq_val[29] && eq_val[27])
    nxt_fe_sub <= 30;
  else if (~eq_wait[32] && eq_val[31] && eq_val[1])
    nxt_fe_sub <= 32;
  else if (~eq_wait[33] && eq_val[32] && eq_val[24])
    nxt_fe_sub <= 33;
  else if (~eq_wait[35] && eq_val[34] && eq_val[33])
    nxt_fe_sub <= 35;
  else if (~eq_wait[37] && eq_wait[27])
    nxt_fe_sub <= 37;
  else
    sub_en <= 0;
endtask

endmodule