/*
  This provides the interface to perform
  Fp^6 multiplication, over a Fp2 tower.

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

module ec_fe6_mul_s
#(
  parameter type FE_TYPE,
  parameter type FE2_TYPE,
  parameter type FE6_TYPE,
  parameter OVR_WRT_BIT = 8       // From this bit 4 bits are used for internal control, 2 bits for resource sharing - 6 total
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
  // Interface to FE6_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe6_if,
  if_axi_stream.sink   i_mul_fe6_if
);

localparam NUM_OVR_WRT_BIT = 5;

// Multiplications are calculated using the formula in bls12_381.pkg::fe6_mul()
FE2_TYPE a_a, b_b, c_c, t;
FE6_TYPE out, in_a, in_b;

logic [22:0] eq_val, eq_wait;
logic mul_cnt, add_cnt, sub_cnt, mnr_cnt;
logic mul_en, add_en, sub_en, mnr_en;
logic [4:0] nxt_fe2_mul, nxt_fe2_mnr, nxt_fe_add, nxt_fe_sub;
logic [2:0] out_cnt;

logic rdy_l;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe6_if.reset_source();
    o_mnr_fe2_if.reset_source();
    o_mul_fe2_if.reset_source();
    o_sub_fe_if.reset_source();
    o_add_fe_if.reset_source();
    i_mul_fe6_if.rdy <= 0;
    i_mul_fe2_if.rdy <= 0;
    i_sub_fe_if.rdy <= 0;
    i_add_fe_if.rdy <= 0;
    i_mnr_fe2_if.rdy <= 0;
    eq_val <= 0;
    eq_wait <= 0;
    rdy_l <= 0;
    a_a <= 0;
    b_b <= 0;
    c_c <= 0;
    t <= 0;
    out <= 0;
    {out_cnt, mul_cnt, add_cnt, sub_cnt, mnr_cnt} <= 0;
    {nxt_fe2_mul, nxt_fe2_mnr, nxt_fe_add, nxt_fe_sub} <= 0;
    {mul_en, add_en, sub_en, mnr_en} <= 0;
    {in_a, in_b} <= 0;

  end else begin

    i_mul_fe2_if.rdy <= 1;
    i_sub_fe_if.rdy <= 1;
    i_add_fe_if.rdy <= 1;
    i_mnr_fe2_if.rdy <= 1;

    if (o_mul_fe6_if.rdy) o_mul_fe6_if.val <= 0;
    if (o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_add_fe_if.rdy) o_add_fe_if.val <= 0;
    if (o_mnr_fe2_if.rdy) o_mnr_fe2_if.val <= 0;

    if (~sub_en) get_next_sub();
    if (~add_en) get_next_add();
    if (~mul_en) get_next_fe2_mul();
    if (~mnr_en) get_next_fe2_mnr();

    if (rdy_l == 0) i_mul_fe6_if.rdy <= 1;

    if (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy)) begin

      if (eq_val[22] && eq_val[20] && eq_val[19]) begin
        o_mul_fe6_if.val <= 1;
        out_cnt <= out_cnt + 1;
      end

      o_mul_fe6_if.sop <= out_cnt == 0;
      o_mul_fe6_if.eop <= out_cnt == 5;
      o_mul_fe6_if.dat <= out[out_cnt/2][out_cnt%2];

      if(out_cnt == 5) begin
        eq_val <= 0;
        eq_wait <= 0;
        rdy_l <= 0;
        a_a <= 0;
        b_b <= 0;
        c_c <= 0;
        t <= 0;
        out <= 0;
        {out_cnt, mul_cnt, add_cnt, sub_cnt} <= 0;
        {nxt_fe2_mul, nxt_fe_add, nxt_fe_sub, nxt_fe2_mnr} <= 0;
        {mul_en, add_en, sub_en, mnr_en} <= 0;
        {in_a, in_b} <= 0;
      end
    end

    // Latch input
    if (i_mul_fe6_if.rdy && i_mul_fe6_if.val) begin
      in_a <= {i_mul_fe6_if.dat[0 +: $bits(FE_TYPE)], in_a[2:1], in_a[0][1]};
      in_b <= {i_mul_fe6_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)], in_b[2:1], in_b[0][1]};
      if (i_mul_fe6_if.eop) begin
        i_mul_fe6_if.rdy <= 0;
        rdy_l <= 1;
        o_mul_fe6_if.ctl <= i_mul_fe6_if.ctl;
      end
    end

    // Check any results from multiplier
    if (i_mul_fe2_if.val && i_mul_fe2_if.rdy) begin
      if (i_mul_fe2_if.eop) eq_val[i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        0:  a_a[i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        1:  b_b[i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        2:  c_c[i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        5:  out[0][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        10: out[2][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        15: out[1][i_mul_fe2_if.eop] <= i_mul_fe2_if.dat;
        default: o_mul_fe6_if.err <= 1;
      endcase
    end

    // Check any results from mnr
    if (i_mnr_fe2_if.val && i_mnr_fe2_if.rdy) begin
      if(i_mnr_fe2_if.eop) eq_val[i_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        18: out[0][i_mnr_fe2_if.eop] <= i_mnr_fe2_if.dat;
        21: c_c[i_mnr_fe2_if.eop] <= i_mnr_fe2_if.dat;
        default: o_mul_fe6_if.err <= 1;
      endcase
    end

    // Check any results from sub
    if (i_sub_fe_if.val && i_sub_fe_if.rdy) begin
      if(i_sub_fe_if.eop) eq_val[i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        6: out[0][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        7: out[0][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        11: out[2][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        16: out[1][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        17: out[1][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        20: out[2][i_sub_fe_if.eop] <= i_sub_fe_if.dat;
        default: o_mul_fe6_if.err <= 1;
      endcase
    end

    // Check any results from add
    if (i_add_fe_if.val && i_add_fe_if.rdy) begin
      if (i_add_fe_if.eop) eq_val[i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        3: out[0][i_add_fe_if.eop] <= i_add_fe_if.dat;
        4: t[i_add_fe_if.eop] <= i_add_fe_if.dat;
        8: out[2][i_add_fe_if.eop] <= i_add_fe_if.dat;
        9: t[i_add_fe_if.eop] <= i_add_fe_if.dat;
        12: out[2][i_add_fe_if.eop] <= i_add_fe_if.dat;
        13: out[1][i_add_fe_if.eop] <= i_add_fe_if.dat;
        14: t[i_add_fe_if.eop] <= i_add_fe_if.dat;
        19: out[0][i_add_fe_if.eop] <= i_add_fe_if.dat;
        22: out[1][i_add_fe_if.eop] <= i_add_fe_if.dat;
        default: o_mul_fe6_if.err <= 1;
      endcase
    end

    // Issue new multiplies
    if (mul_en)
      case(nxt_fe2_mul)
        0: fe2_multiply(0, in_a[0], in_b[0]);
        1: fe2_multiply(1, in_a[1], in_b[1]);
        2: fe2_multiply(2, in_a[2], in_b[2]);
        5: fe2_multiply(5, out[0], t);
        10: fe2_multiply(10, out[2], t);
        15: fe2_multiply(15, out[1], t);
      endcase

    // Issue new adds
    if (add_en)
      case(nxt_fe_add)
        3: fe2_addition(3, in_a[1], in_a[2]);
        4: fe2_addition(4, in_b[1], in_b[2]);
        8: fe2_addition(8, in_b[0], in_b[2]);
        9: fe2_addition(9, in_a[0], in_a[2]);
        12: fe2_addition(12, out[2], b_b);
        13: fe2_addition(13, in_b[0], in_b[1]);
        14: fe2_addition(14, in_a[0], in_a[1]);
        19: fe2_addition(19, out[0], a_a);
        22: fe2_addition(22, out[1], c_c);
      endcase

    // Issue new sub
    if (sub_en)
      case(nxt_fe_sub)
        6: fe2_subtraction(6, out[0], b_b);
        7: fe2_subtraction(7, out[0], c_c);
        11: fe2_subtraction(11, out[2], a_a);
        16: fe2_subtraction(16, out[1], a_a);
        17: fe2_subtraction(17, out[1], b_b);
        20: fe2_subtraction(20, out[2], c_c);
      endcase

    // Issue new mnr
    if (mnr_en)
      case(nxt_fe2_mnr)
        18: fe2_mnr(18, out[0]);
        21: fe2_mnr(21, c_c);
      endcase

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

task get_next_fe2_mul();
  mul_en <= 1;
  if(~eq_wait[0] && rdy_l)
    nxt_fe2_mul <= 0;
  else if(~eq_wait[1] && rdy_l)
    nxt_fe2_mul <= 1;
  else if(~eq_wait[2] && rdy_l)
    nxt_fe2_mul <= 2;
  else if(~eq_wait[5] && eq_val[3] && eq_val[4])
    nxt_fe2_mul <= 5;
  else if (~eq_wait[10] && eq_val[8] && eq_val[9])
    nxt_fe2_mul <= 10;
  else if (~eq_wait[15] && eq_val[13] && eq_val[14])
    nxt_fe2_mul <= 15;
  else
    mul_en <= 0;
endtask

task get_next_add();
  add_en <= 1;
  if(~eq_wait[3] && rdy_l)
    nxt_fe_add <= 3;
  else if(~eq_wait[4] && rdy_l)
    nxt_fe_add <= 4;
  else if(~eq_wait[8] && rdy_l)
    nxt_fe_add <= 8;
  else if(~eq_wait[9] && eq_wait[5] && rdy_l)
    nxt_fe_add <= 9;
  else if (~eq_wait[12] && eq_val[11] && eq_val[1])
    nxt_fe_add <= 12;
  else if(~eq_wait[13] && rdy_l)
    nxt_fe_add <= 13;
  else if(~eq_wait[14] && eq_wait[10] && rdy_l)
    nxt_fe_add <= 14;
  else if(~eq_wait[19] && eq_val[18] && eq_val[0])
    nxt_fe_add <= 19;
  else if(~eq_wait[22] && eq_val[17] && eq_val[21])
    nxt_fe_add <= 22;
  else
    add_en <= 0;
endtask

task get_next_sub();
  sub_en <= 1;
  if(~eq_wait[6] && eq_val[5] && eq_val[1])
    nxt_fe_sub <= 6;
  else if(~eq_wait[7] && eq_val[6] && eq_val[2])
    nxt_fe_sub <= 7;
  else if (~eq_wait[11] && eq_val[10] && eq_val[0])
    nxt_fe_sub <= 11;
  else if (~eq_wait[16] && eq_val[15] && eq_val[0])
    nxt_fe_sub <= 16;
  else if (~eq_wait[17] && eq_val[16] && eq_val[1])
    nxt_fe_sub <= 17;
  else if (~eq_wait[20] && eq_val[12] && eq_val[2])
    nxt_fe_sub <= 20;
  else
    sub_en <= 0;
endtask

task get_next_fe2_mnr();
  mnr_en <= 1;
  if(~eq_wait[18] && eq_val[7])
    nxt_fe2_mnr <= 18;
  else if(~eq_wait[21] && eq_wait[20])
    nxt_fe2_mnr <= 21;
  else
    mnr_en <= 0;
endtask

endmodule