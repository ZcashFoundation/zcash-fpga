/*
  This provides the interface to perform
  Fp^6 inverse

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

module ec_fe6_inv_s
#(
  parameter type FE_TYPE,
  parameter type FE2_TYPE,
  parameter OVR_WRT_BIT = 8       // From this bit 5 bits are used for internal control
)(
  input i_clk, i_rst,
  // Interface to FE2_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE2_TYPE adder (mod P)
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE2_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface to FE2_TYPE multiply by non-residue
  if_axi_stream.source o_mnr_fe2_if,
  if_axi_stream.sink   i_mnr_fe2_if,
  // Interface to FE2_TYPE inverse (mod P)
  if_axi_stream.source o_inv_fe2_if,
  if_axi_stream.sink   i_inv_fe2_if,
  // Interface to FE6_TYPE inverse (mod P)
  if_axi_stream.source o_inv_fe6_if,
  if_axi_stream.sink   i_inv_fe6_if
);

localparam NUM_OVR_WRT_BIT = 5;

// Multiplications are calculated using the formula in bls12_381.pkg::fe6_inv()
FE2_TYPE [5:0] t;
FE2_TYPE [2:0] a;

logic [21:0] eq_val, eq_wait;
logic mul_cnt, add_cnt, sub_cnt, mnr_cnt, inv_cnt;
logic mul_en, add_en, sub_en, mnr_en, inv_en;
logic [4:0] nxt_fe2_mul, nxt_fe2_mnr, nxt_fe_add, nxt_fe_sub, nxt_fe2_inv;
logic [2:0] out_cnt;

logic rdy_l;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_inv_fe6_if.reset_source();
    o_mnr_fe2_if.reset_source();
    o_mul_fe2_if.reset_source();
    o_inv_fe2_if.reset_source();
    o_sub_fe_if.reset_source();
    o_add_fe_if.reset_source();
    i_inv_fe6_if.rdy <= 0;
    i_mul_fe2_if.rdy <= 0;
    i_sub_fe_if.rdy <= 0;
    i_add_fe_if.rdy <= 0;
    i_mnr_fe2_if.rdy <= 0;
    i_inv_fe2_if.rdy <= 0;
    eq_val <= 0;
    eq_wait <= 0;
    rdy_l <= 0;
    t <= 0;
    a <= 0;
    {out_cnt, mul_cnt, add_cnt, sub_cnt, mnr_cnt, inv_cnt} <= 0;
    {nxt_fe2_mul, nxt_fe2_mnr, nxt_fe_add, nxt_fe_sub, nxt_fe2_inv} <= 0;
    {mul_en, add_en, sub_en, mnr_en, inv_en} <= 0;
  end else begin

    i_mul_fe2_if.rdy <= 1;
    i_inv_fe2_if.rdy <= 1;
    i_sub_fe_if.rdy <= 1;
    i_add_fe_if.rdy <= 1;
    i_mnr_fe2_if.rdy <= 1;

    if (o_inv_fe6_if.rdy) o_inv_fe6_if.val <= 0;
    if (o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_add_fe_if.rdy) o_add_fe_if.val <= 0;
    if (o_mnr_fe2_if.rdy) o_mnr_fe2_if.val <= 0;
    if (o_inv_fe2_if.rdy) o_inv_fe2_if.val <= 0;

    if (~sub_en) get_next_sub();
    if (~add_en) get_next_add();
    if (~mul_en) get_next_fe2_mul();
    if (~mnr_en) get_next_fe2_mnr();
    if (~inv_en) get_next_fe2_inv();

    if (rdy_l == 0) i_inv_fe6_if.rdy <= 1;

    if (~o_inv_fe6_if.val || (o_inv_fe6_if.val && o_inv_fe6_if.rdy)) begin

      o_inv_fe6_if.sop <= out_cnt == 0;
      o_inv_fe6_if.eop <= out_cnt == 5;

      if (eq_val[19] && out_cnt/2 == 0) begin
        o_inv_fe6_if.val <= 1;
        out_cnt <= out_cnt + 1;
        o_inv_fe6_if.dat <= t[3][out_cnt%2];
      end
      if (eq_val[20] && out_cnt/2 == 1) begin
        o_inv_fe6_if.val <= 1;
        out_cnt <= out_cnt + 1;
        o_inv_fe6_if.dat <= t[4][out_cnt%2];
      end
      if (eq_val[21] && out_cnt/2 == 2) begin
        o_inv_fe6_if.val <= 1;
        out_cnt <= out_cnt + 1;
        o_inv_fe6_if.dat <= t[5][out_cnt%2];
      end

      if (out_cnt == 5) begin
        eq_val <= 0;
        eq_wait <= 0;
        rdy_l <= 0;
        t <= 0;
        a <= 0;
        {out_cnt, mul_cnt, add_cnt, sub_cnt, inv_cnt} <= 0;
        {nxt_fe2_mul, nxt_fe_add, nxt_fe_sub, nxt_fe2_mnr, nxt_fe2_inv} <= 0;
        {mul_en, add_en, sub_en, mnr_en, inv_en} <= 0;
      end
    end

    // Latch input
    if (i_inv_fe6_if.rdy && i_inv_fe6_if.val) begin
      a <= {i_inv_fe6_if.dat, a[2:1], a[0][1]};
      if (i_inv_fe6_if.eop) begin
        i_inv_fe6_if.rdy <= 0;
        rdy_l <= 1;
        o_inv_fe6_if.ctl <= i_inv_fe6_if.ctl;
      end
    end

    // Check any results from multiplier
    if (i_mul_fe2_if.val && i_mul_fe2_if.rdy) begin
      if (i_mul_fe2_if.eop) eq_val[i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        1: t[3][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        3: t[0][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        5: t[4][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        7: t[2][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        9: t[5][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        10: t[2][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        12: t[0][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        13: t[1][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        16: t[0][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        19: t[3][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        20: t[4][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        21: t[5][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        default: o_inv_fe6_if.err <= 1;
      endcase
    end

    // Check any results from mnr
    if (i_mnr_fe2_if.val && i_mnr_fe2_if.rdy) begin
      if(i_mnr_fe2_if.eop) eq_val[i_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        0: t[3][i_mnr_fe2_if.eop] <= i_mnr_fe2_if.dat;
        6: t[4][i_mnr_fe2_if.eop] <= i_mnr_fe2_if.dat;
        15: t[1][i_mnr_fe2_if.eop] <= i_mnr_fe2_if.dat;
        default: o_inv_fe6_if.err <= 1;
      endcase
    end

    // Check any results from sub
    if (i_sub_fe_if.val && i_sub_fe_if.rdy) begin
      if(i_sub_fe_if.eop) eq_val[i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        2: t[3][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        8: t[4][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        11: t[5][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        default: o_inv_fe6_if.err <= 1;
      endcase
    end

    // Check any results from add
    if (i_add_fe_if.val && i_add_fe_if.rdy) begin
      if (i_add_fe_if.eop) eq_val[i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        4: t[3][i_add_fe_if.eop] <= i_add_fe_if.dat;
        14: t[1][i_add_fe_if.eop] <= i_add_fe_if.dat;
        17: t[1][i_add_fe_if.eop] <= i_add_fe_if.dat;
        default: o_inv_fe6_if.err <= 1;
      endcase
    end

    // Check any results from inv_fe2
    if (i_inv_fe2_if.val && i_inv_fe2_if.rdy) begin
      if (i_inv_fe2_if.eop) eq_val[i_inv_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_inv_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        18: t[1][i_inv_fe2_if.eop] <= i_inv_fe2_if.dat;
        default: o_inv_fe6_if.err <= 1;
      endcase
    end

    // Issue new multiplies
    if (mul_en)
      case(nxt_fe2_mul)
        1: fe2_multiply(1, t[3], a[1]);
        3: fe2_multiply(3, a[0], a[0]);
        5: fe2_multiply(5, a[2], a[2]);
        7: fe2_multiply(7, a[0], a[1]);
        9: fe2_multiply(9, a[1], a[1]);
        10: fe2_multiply(10, a[2], a[0]);
        12: fe2_multiply(12, a[2], t[4]);
        13: fe2_multiply(13, a[1], t[5]);
        16: fe2_multiply(16, a[0], t[3]);
        19: fe2_multiply(19, t[3], t[1]);
        20: fe2_multiply(20, t[4], t[1]);
        21: fe2_multiply(21, t[5], t[1]);
      endcase

    // Issue new adds
    if (add_en)
      case(nxt_fe_add)
        4: fe2_addition(4, t[0], t[3]);
        14: fe2_addition(14, t[0], t[1]);
        17: fe2_addition(17, t[1], t[0]);
      endcase

    // Issue new sub
    if (sub_en)
      case(nxt_fe_sub)
        2: fe2_subtraction(2, 0, t[3]);
        8: fe2_subtraction(8, t[4], t[2]);
        11: fe2_subtraction(11, t[5], t[2]);
      endcase

    // Issue new mnr
    if (mnr_en)
      case(nxt_fe2_mnr)
        0: fe2_mnr(0, a[2]);
        6: fe2_mnr(6, t[4]);
        15: fe2_mnr(15, t[1]);
      endcase

    // Issue new inv
    if (inv_en)
     fe2_inv(18, t[1]);

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

// Task for using mnr
task fe2_mnr(input int unsigned ctl, input FE2_TYPE a);
  if (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy)) begin
    o_mnr_fe2_if.val <= 1;
    o_mnr_fe2_if.sop <= mnr_cnt == 0;
    o_mnr_fe2_if.eop <= mnr_cnt == 1;
    o_mnr_fe2_if.dat <= a[mnr_cnt];
    o_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    if (mnr_cnt == 1) begin
      get_next_fe2_mnr();
    end
    mnr_cnt <= mnr_cnt + 1;
  end
endtask

// Task for using inv
task fe2_inv(input int unsigned ctl, input FE2_TYPE a);
  if (~o_inv_fe2_if.val || (o_inv_fe2_if.val && o_inv_fe2_if.rdy)) begin
    o_inv_fe2_if.val <= 1;
    o_inv_fe2_if.sop <= inv_cnt == 0;
    o_inv_fe2_if.eop <= inv_cnt == 1;
    o_inv_fe2_if.dat <= a[inv_cnt];
    o_inv_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    if (inv_cnt == 1) begin
      get_next_fe2_inv();
    end
    inv_cnt <= inv_cnt + 1;
  end
endtask

task get_next_fe2_mul();
  mul_en <= 1;
  if(~eq_wait[1] && eq_val[0])
    nxt_fe2_mul <= 1;
  else if(~eq_wait[3] && rdy_l)
    nxt_fe2_mul <= 3;
  else if(~eq_wait[5] && rdy_l)
    nxt_fe2_mul <= 5;
  else if(~eq_wait[7] && rdy_l)
    nxt_fe2_mul <= 7;
  else if(~eq_wait[9] && rdy_l)
    nxt_fe2_mul <= 9;
  else if(~eq_wait[10] && eq_wait[8] && rdy_l)
    nxt_fe2_mul <= 10;
  else if(~eq_wait[12] && eq_val[8] && eq_wait[4])
    nxt_fe2_mul <= 12;
  else if(~eq_wait[13] && eq_val[11])
    nxt_fe2_mul <= 13;
  else if(~eq_wait[16] && eq_val[4] && eq_wait[14])
    nxt_fe2_mul <= 16;
  else if(~eq_wait[19] && eq_val[4] && eq_val[18])
    nxt_fe2_mul <= 19;
  else if(~eq_wait[20] && eq_val[8] && eq_val[18])
    nxt_fe2_mul <= 20;
  else if(~eq_wait[21] && eq_val[11] && eq_val[18])
    nxt_fe2_mul <= 21;
  else
    mul_en <= 0;
endtask


task get_next_add();
  add_en <= 1;
  if(~eq_wait[4] && eq_val[2] && eq_val[3])
    nxt_fe_add <= 4;
  else if(~eq_wait[14] && eq_val[12] && eq_val[13])
    nxt_fe_add <= 14;
  else if(~eq_wait[17] && eq_val[16] && eq_val[15])
    nxt_fe_add <= 17;
  else
    add_en <= 0;
endtask

task get_next_sub();
  sub_en <= 1;
  if(~eq_wait[2] && eq_val[1])
    nxt_fe_sub <= 2;
  else if(~eq_wait[8] && eq_val[6] && eq_val[7])
    nxt_fe_sub <= 8;
  else if(~eq_wait[11] && eq_val[9] && eq_val[10])
    nxt_fe_sub <= 11;
  else
    sub_en <= 0;
endtask

task get_next_fe2_mnr();
  mnr_en <= 1;
  if(~eq_wait[0] && rdy_l)
    nxt_fe2_mnr <= 0;
  else if(~eq_wait[6] && eq_val[5])
    nxt_fe2_mnr <= 6;
  else if(~eq_wait[15] && eq_val[14])
    nxt_fe2_mnr <= 15;
  else
    mnr_en <= 0;
endtask

task get_next_fe2_inv();
  inv_en <= 1;
  if(~eq_wait[18] && eq_val[17])
    inv_en <= 1;
  else
    inv_en <= 0;
endtask

endmodule