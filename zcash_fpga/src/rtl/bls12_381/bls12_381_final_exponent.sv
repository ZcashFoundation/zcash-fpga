/*
  This provides the interface to perform the final exponentiation
  required in the ate pairing.

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

module bls12_381_final_exponent
  import bls12_381_pkg::*;
#(
  parameter type FE_TYPE    = bls12_381_pkg::fe_t,
  parameter OVR_WRT_BIT     = 0,       // From this bit 5 bits are used for internal control, and $bits(ATE_X) for pow channel, 2 bits for fmap power
  parameter NUM_OVR_WRT_BIT = 5,
  parameter POW_BIT,              // $bits(ATE_X)
  parameter FMAP_BIT,             // 2 bits
  parameter SQ_BIT
)(
  input i_clk, i_rst,
  // Interface to FE12_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe12_if,
  if_axi_stream.sink   i_mul_fe12_if,
  // Interface to FE12_TYPE multiplier (mod P)
  if_axi_stream.source o_pow_fe12_if,
  if_axi_stream.sink   i_pow_fe12_if,
  // Interface to FE12_TYPE fmap (mod P)
  if_axi_stream.source o_fmap_fe12_if,
  if_axi_stream.sink   i_fmap_fe12_if,
  // Interface to FE12_TYPE inversion (mod P)
  if_axi_stream.source o_inv_fe12_if,
  if_axi_stream.sink   i_inv_fe12_if,
  // Interface to FE_TYPE subtractor by non-residue
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface for final exponent calculation
  if_axi_stream.source o_final_exp_fe12_if,
  if_axi_stream.sink   i_final_exp_fe12_if
);

FE_TYPE [4:0][11:0] t;

logic [27:0] eq_val, eq_wait;
logic [3:0] mul_cnt, sub_cnt, pow_cnt, inv_cnt, fmap_cnt, out_cnt;
logic mul_en, sub_en, pow_en, inv_en, fmap_en;
logic [4:0] nxt_mul, nxt_sub, nxt_pow, nxt_inv, nxt_fmap;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_inv_fe12_if.reset_source();
    o_mul_fe12_if.reset_source();
    o_fmap_fe12_if.reset_source();
    o_sub_fe_if.reset_source();
    o_pow_fe12_if.reset_source();
    o_final_exp_fe12_if.reset_source();

    i_inv_fe12_if.rdy <= 0;
    i_mul_fe12_if.rdy <= 0;
    i_sub_fe_if.rdy <= 0;
    i_fmap_fe12_if.rdy <= 0;
    i_pow_fe12_if.rdy <= 0;
    i_final_exp_fe12_if.rdy <= 1;

    eq_val <= 0;
    eq_wait <= 0;
    t <= 0;
    {mul_cnt, sub_cnt, pow_cnt, inv_cnt, fmap_cnt, out_cnt} <= 0;
    {nxt_mul, nxt_sub, nxt_pow, nxt_inv, nxt_fmap} <= 0;
    {mul_en, sub_en, pow_en, inv_en, fmap_en} <= 0;
  end else begin

    i_inv_fe12_if.rdy <= 1;
    i_mul_fe12_if.rdy <= 1;
    i_sub_fe_if.rdy <= 1;
    i_fmap_fe12_if.rdy <= 1;
    i_pow_fe12_if.rdy <= 1;

    if (o_inv_fe12_if.rdy) o_inv_fe12_if.val <= 0;
    if (o_mul_fe12_if.rdy) o_mul_fe12_if.val <= 0;
    if (o_fmap_fe12_if.rdy) o_fmap_fe12_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_pow_fe12_if.rdy) o_pow_fe12_if.val <= 0;
    if (o_final_exp_fe12_if.rdy) o_final_exp_fe12_if.val <= 0;

    if (~sub_en) get_next_sub();
    if (~mul_en) get_next_mul();
    if (~pow_en) get_next_pow();
    if (~inv_en) get_next_inv();
    if (~fmap_en) get_next_fmap();

    if (|eq_wait == 0) i_final_exp_fe12_if.rdy <= 1;

    if (~o_final_exp_fe12_if.val || (o_final_exp_fe12_if.val && o_final_exp_fe12_if.rdy)) begin

      o_final_exp_fe12_if.sop <= out_cnt == 0;
      o_final_exp_fe12_if.eop <= out_cnt == 11;

      o_final_exp_fe12_if.dat <= t[1][out_cnt];

      if (eq_val[27]) begin
        o_final_exp_fe12_if.val <= 1;
        out_cnt <= out_cnt + 1;
      end

      if (out_cnt == 11) begin
        eq_val <= 0;
        eq_wait <= 0;
        t <= 0;
       {mul_cnt, sub_cnt, pow_cnt, inv_cnt, fmap_cnt, out_cnt} <= 0;
       {nxt_mul, nxt_sub, nxt_pow, nxt_inv, nxt_fmap} <= 0;
       {mul_en, sub_en, pow_en, inv_en, fmap_en} <= 0;
      end
    end

    // Latch input
    if (i_final_exp_fe12_if.rdy && i_final_exp_fe12_if.val) begin
      t[4] <= {i_final_exp_fe12_if.dat, t[4][11:1]};
      t[0] <= {i_final_exp_fe12_if.dat, t[0][11:1]};
      if (i_final_exp_fe12_if.eop) begin
        i_final_exp_fe12_if.rdy <= 0;
        eq_val[0] <= 1;
        eq_wait[0] <= 1;
        eq_val[1] <= 1;
        eq_wait[1] <= 1;
        o_final_exp_fe12_if.ctl <= i_final_exp_fe12_if.ctl;
      end
    end

    // Check any results from multiplier
    if (i_mul_fe12_if.val && i_mul_fe12_if.rdy) begin
      if (i_mul_fe12_if.eop) eq_val[i_mul_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        4: t[4] <= {i_mul_fe12_if.dat, t[4][11:1]};
        6: t[4] <= {i_mul_fe12_if.dat, t[4][11:1]};
        7: t[0] <= {i_mul_fe12_if.dat, t[0][11:1]};
        11: t[1] <= {i_mul_fe12_if.dat, t[1][11:1]};
        13: t[1] <= {i_mul_fe12_if.dat, t[1][11:1]};
        17: t[3] <= {i_mul_fe12_if.dat, t[3][11:1]};
        21: t[1] <= {i_mul_fe12_if.dat, t[1][11:1]};
        23: t[2] <= {i_mul_fe12_if.dat, t[2][11:1]};
        24: t[2] <= {i_mul_fe12_if.dat, t[2][11:1]};
        25: t[1] <= {i_mul_fe12_if.dat, t[1][11:1]};
        27: t[1] <= {i_mul_fe12_if.dat, t[1][11:1]};
        default: o_final_exp_fe12_if.err <= 1;
      endcase
    end

    // Check any results from pow
    if (i_pow_fe12_if.val && i_pow_fe12_if.rdy) begin
      if(i_pow_fe12_if.eop) eq_val[i_pow_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_pow_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        8: t[1] <= {i_pow_fe12_if.dat, t[1][11:1]};
        9: t[2] <= {i_pow_fe12_if.dat, t[2][11:1]};
        14: t[2] <= {i_pow_fe12_if.dat, t[2][11:1]};
        15: t[3] <= {i_pow_fe12_if.dat, t[3][11:1]};
        22: t[2] <= {i_pow_fe12_if.dat, t[2][11:1]};
        default: o_final_exp_fe12_if.err <= 1;
      endcase
    end

    // Check any results from sub
    if (i_sub_fe_if.val && i_sub_fe_if.rdy) begin
      if(i_sub_fe_if.eop) eq_val[i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        2: t[4][11:6] <= {i_sub_fe_if.dat, t[4][11:7]};
        10: t[3][11:6] <= {i_sub_fe_if.dat, t[3][11:7]};
        12: t[1][11:6] <= {i_sub_fe_if.dat, t[1][11:7]};
        16: t[1][11:6] <= {i_sub_fe_if.dat, t[1][11:7]};
        18: t[1][11:6] <= {i_sub_fe_if.dat, t[1][11:7]};
        default: o_final_exp_fe12_if.err <= 1;
      endcase
    end

    // Check any results from inv
    if (i_inv_fe12_if.val && i_inv_fe12_if.rdy) begin
      if (i_inv_fe12_if.eop) eq_val[i_inv_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_inv_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        3:  t[3] <= {i_inv_fe12_if.dat, t[3][11:1]};
        default: o_final_exp_fe12_if.err <= 1;
      endcase
    end

    // Check any results from fmap
    if (i_fmap_fe12_if.val && i_fmap_fe12_if.rdy) begin
      if(i_fmap_fe12_if.eop) eq_val[i_fmap_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_fmap_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        5: t[2] <= {i_fmap_fe12_if.dat, t[2][11:1]};
        19: t[1] <= {i_fmap_fe12_if.dat, t[1][11:1]};
        20: t[2] <= {i_fmap_fe12_if.dat, t[2][11:1]};
        26: t[2] <= {i_fmap_fe12_if.dat, t[2][11:1]};
        default: o_final_exp_fe12_if.err <= 1;
      endcase
    end

    // Issue new multiplies
    if (mul_en)
      case(nxt_mul)
        4: fe12_multiply(4, t[0], t[3]);
        6: fe12_multiply(6, t[2], t[4]);
        7: fe12_multiply(7, t[4], t[4], 1); // This is a square
        11: fe12_multiply(11, t[1], {t[3][11:6], t[4][5:0]});
        13: fe12_multiply(13, t[1], t[2]);
        17: fe12_multiply(17, t[3], t[1]);
        21: fe12_multiply(21, t[1], t[2]);
        23: fe12_multiply(23, t[2], t[0]);
        24: fe12_multiply(24, t[2], t[4]);
        25: fe12_multiply(25, t[1], t[2]);
        27: fe12_multiply(27, t[1], t[2]);
      endcase


    // Issue new pow
    if (pow_en)
      case(nxt_pow)
        8: fe12_pow_task(8, t[0], bls12_381_pkg::ATE_X);
        9: fe12_pow_task(9, t[1], bls12_381_pkg::ATE_X >> 1);
        14: fe12_pow_task(14, t[1], bls12_381_pkg::ATE_X);
        15: fe12_pow_task(15, t[2], bls12_381_pkg::ATE_X);
        22: fe12_pow_task(22, t[3], bls12_381_pkg::ATE_X);
      endcase

    // Issue new sub
    if (sub_en)
      case(nxt_sub)
        2: fe6_subtraction(2, 0, t[4][11:6]);
        10: fe6_subtraction(10, 0, t[4][11:6]);
        12: fe6_subtraction(12, 0, t[1][11:6]);
        16: fe6_subtraction(16, 0, t[1][11:6]);
        18: fe6_subtraction(18, 0, t[1][11:6]);
      endcase

    // Issue new inv
    if (inv_en)
     fe12_inv_task(3, t[4]);

    // Issue new fmap
    if (fmap_en)
      case(nxt_fmap)
        5: fe12_fmap_task(5, t[4], 2);
        19: fe12_fmap_task(19, t[1], 3);
        20: fe12_fmap_task(20, t[2], 2);
        26: fe12_fmap_task(26, t[3], 1);
      endcase

  end
end

// Task for subtractions
task fe6_subtraction(input int unsigned ctl, input FE_TYPE [5:0] a, b);
  if (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy)) begin
    o_sub_fe_if.val <= 1;
    o_sub_fe_if.sop <= sub_cnt == 0;
    o_sub_fe_if.eop <= sub_cnt == 5;
    o_sub_fe_if.dat[0 +: $bits(FE_TYPE)] <= a[sub_cnt];
    o_sub_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b[sub_cnt];
    o_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    sub_cnt <= sub_cnt + 1;
    if (sub_cnt == 5) begin
      sub_cnt <= 0;
      get_next_sub();
    end
  end
endtask


// Task for using mult
task fe12_multiply(input int unsigned ctl, input FE_TYPE [11:0] a, b, input sq = 0);
  if (~o_mul_fe12_if.val || (o_mul_fe12_if.val && o_mul_fe12_if.rdy)) begin
    o_mul_fe12_if.val <= 1;
    o_mul_fe12_if.sop <= mul_cnt == 0;
    o_mul_fe12_if.eop <= mul_cnt == 11;
    o_mul_fe12_if.dat[0 +: $bits(FE_TYPE)] <= a[mul_cnt];
    o_mul_fe12_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b[mul_cnt];
    o_mul_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    o_mul_fe12_if.ctl[SQ_BIT] <= sq;
    eq_wait[ctl] <= 1;
    mul_cnt <= mul_cnt + 1;
    if (mul_cnt == 11) begin
      mul_cnt <= 0;
      get_next_mul();
    end
  end
endtask

// Task for using pow
task fe12_pow_task(input int unsigned ctl, input FE_TYPE [11:0] a, input [$bits(bls12_381_pkg::ATE_X)-1:0] pow);
  if (~o_pow_fe12_if.val || (o_pow_fe12_if.val && o_pow_fe12_if.rdy)) begin
    o_pow_fe12_if.val <= 1;
    o_pow_fe12_if.sop <= pow_cnt == 0;
    o_pow_fe12_if.eop <= pow_cnt == 11;
    o_pow_fe12_if.dat <= a[pow_cnt];
    o_pow_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    o_pow_fe12_if.ctl[POW_BIT +: $bits(bls12_381_pkg::ATE_X)] <= pow;
    eq_wait[ctl] <= 1;
    pow_cnt <= pow_cnt + 1;
    if (pow_cnt == 11) begin
      pow_cnt <= 0;
      get_next_pow();
    end
  end
endtask

// Task for using inv
task fe12_inv_task(input int unsigned ctl, input FE_TYPE [11:0] a);
  if (~o_inv_fe12_if.val || (o_inv_fe12_if.val && o_inv_fe12_if.rdy)) begin
    o_inv_fe12_if.val <= 1;
    o_inv_fe12_if.sop <= inv_cnt == 0;
    o_inv_fe12_if.eop <= inv_cnt == 11;
    o_inv_fe12_if.dat <= a[inv_cnt];
    o_inv_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    inv_cnt <= inv_cnt + 1;
    if (inv_cnt == 11) begin
      inv_cnt <= 0;
      get_next_inv();
    end
  end
endtask

// Task for using fmap
task fe12_fmap_task(input int unsigned ctl, input FE_TYPE [11:0] a, input [1:0] fmap);
  if (~o_fmap_fe12_if.val || (o_fmap_fe12_if.val && o_fmap_fe12_if.rdy)) begin
    o_fmap_fe12_if.val <= 1;
    o_fmap_fe12_if.sop <= fmap_cnt == 0;
    o_fmap_fe12_if.eop <= fmap_cnt == 11;
    o_fmap_fe12_if.dat <= a[fmap_cnt];
    o_fmap_fe12_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    o_fmap_fe12_if.ctl[FMAP_BIT +: 2] <= fmap;
    eq_wait[ctl] <= 1;
    fmap_cnt <= fmap_cnt + 1;
    if (fmap_cnt == 11) begin
      fmap_cnt <= 0;
      get_next_fmap();
    end
  end
endtask

task get_next_mul();
  mul_en <= 1;
  if(~eq_wait[4] && eq_val[3])
    nxt_mul <= 4;
  else if(~eq_wait[6] && eq_val[4] && eq_val[5])
    nxt_mul <= 6;
  else if(~eq_wait[7] && eq_val[6])
    nxt_mul <= 7;
  else if(~eq_wait[11] && eq_val[6] && eq_val[10] && eq_wait[9])
    nxt_mul <= 11;
  else if(~eq_wait[13] && eq_val[12] && eq_val[9])
    nxt_mul <= 13;
  else if(~eq_wait[17] && eq_val[15] && eq_val[16])
    nxt_mul <= 17;
  else if(~eq_wait[21] && eq_val[20] && eq_val[19])
    nxt_mul <= 21;
  else if(~eq_wait[23] && eq_val[22] && eq_val[7])
    nxt_mul <= 23;
  else if(~eq_wait[24] && eq_val[23] && eq_val[6])
    nxt_mul <= 24;
  else if(~eq_wait[25] && eq_val[21] && eq_val[24])
    nxt_mul <= 25;
  else if(~eq_wait[27] && eq_val[25] && eq_val[26])
    nxt_mul <= 27;
  else
    mul_en <= 0;
endtask


task get_next_sub();
  sub_en <= 1;
  if(~eq_wait[2] && eq_val[0])
    nxt_sub <= 2;
  else if(~eq_wait[10] && eq_val[6])
    nxt_sub <= 10;
  else if(~eq_wait[12] && eq_val[11])
    nxt_sub <= 12;
  else if(~eq_wait[16] && eq_val[13] && eq_wait[14] && pow_cnt == 0)
    nxt_sub <= 16;
  else if(~eq_wait[18] && eq_wait[17] && mul_cnt == 0)
    nxt_sub <= 18;
  else
    sub_en <= 0;
endtask

task get_next_pow();
  pow_en <= 1;
  if(~eq_wait[8] && eq_val[7])
    nxt_pow <= 8;
  else if(~eq_wait[9] && eq_val[8])
    nxt_pow <= 9;
  else if(~eq_wait[14] && eq_val[13])
    nxt_pow <= 14;
  else if(~eq_wait[15] && eq_val[14])
    nxt_pow <= 15;
  else if(~eq_wait[22] && eq_val[17] && eq_wait[21] && mul_cnt == 0)
    nxt_pow <= 22;
  else
    pow_en <= 0;
endtask

task get_next_inv();
  inv_en <= 1;
  if(~eq_wait[3] && eq_val[2])
    inv_en <= 1;
  else
    inv_en <= 0;
endtask

task get_next_fmap();
  fmap_en <= 1;
  if(~eq_wait[5] && eq_val[4])
    nxt_fmap <= 5;
  else if(~eq_wait[19] && eq_val[18])
    nxt_fmap <= 19;
  else if(~eq_wait[20] && eq_wait[15] && pow_cnt == 0)
    nxt_fmap <= 20;
  else if(~eq_wait[26] && eq_val[17] && eq_wait[25] && mul_cnt == 0)
    nxt_fmap <= 26;
  else
    fmap_en <= 0;
endtask

endmodule