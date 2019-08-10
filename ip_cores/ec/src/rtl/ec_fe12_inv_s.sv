/*
  This provides the interface to perform
  Fp^12 inverse

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

module ec_fe12_inv_s
#(
  parameter type FE_TYPE,
  parameter OVR_WRT_BIT = 8       // From this bit 5 bits are used for internal control
)(
  input i_clk, i_rst,
  // Interface to FE2_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe6_if,
  if_axi_stream.sink   i_mul_fe6_if,
  // Interface to FE2_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface to FE2_TYPE multiply by non-residue
  if_axi_stream.source o_mnr_fe6_if,
  if_axi_stream.sink   i_mnr_fe6_if,
  // Interface to FE2_TYPE inverse (mod P)
  if_axi_stream.source o_inv_fe6_if,
  if_axi_stream.sink   i_inv_fe6_if,
  // Interface to FE6_TYPE inverse (mod P)
  if_axi_stream.source o_inv_fe12_if,
  if_axi_stream.sink   i_inv_fe12_if
);

localparam NUM_OVR_WRT_BIT = 3;

// Multiplications are calculated using the formula in bls12_381.pkg::fe6_inv()
FE_TYPE [1:0][5:0] t;
FE_TYPE [1:0][5:0] a;

logic [7:0] eq_val, eq_wait;
logic [2:0] mul_cnt, sub_cnt, mnr_cnt, inv_cnt;
logic mul_en, sub_en, mnr_en, inv_en;
logic [2:0] nxt_mul, nxt_mnr, nxt_sub, nxt_inv;
logic [3:0] out_cnt;

logic rdy_l;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_inv_fe12_if.reset_source();
    o_mnr_fe6_if.reset_source();
    o_mul_fe6_if.reset_source();
    o_inv_fe6_if.reset_source();
    o_sub_fe_if.reset_source();
    i_inv_fe12_if.rdy <= 0;
    i_mul_fe6_if.rdy <= 0;
    i_sub_fe_if.rdy <= 0;
    i_mnr_fe6_if.rdy <= 0;
    i_inv_fe6_if.rdy <= 0;
    eq_val <= 0;
    eq_wait <= 0;
    rdy_l <= 0;
    t <= 0;
    a <= 0;
    {out_cnt, mul_cnt, sub_cnt, mnr_cnt, inv_cnt} <= 0;
    {nxt_mul, nxt_mnr, nxt_sub, nxt_inv} <= 0;
    {mul_en, sub_en, mnr_en, inv_en} <= 0;
  end else begin

    i_mul_fe6_if.rdy <= 1;
    i_inv_fe6_if.rdy <= 1;
    i_sub_fe_if.rdy <= 1;
    i_mnr_fe6_if.rdy <= 1;

    if (o_inv_fe12_if.rdy) o_inv_fe12_if.val <= 0;
    if (o_mul_fe6_if.rdy) o_mul_fe6_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_mnr_fe6_if.rdy) o_mnr_fe6_if.val <= 0;
    if (o_inv_fe6_if.rdy) o_inv_fe6_if.val <= 0;

    if (~sub_en) get_next_sub();
    if (~mul_en) get_next_mul();
    if (~mnr_en) get_next_mnr();
    if (~inv_en) get_next_inv();

    if (rdy_l == 0) i_inv_fe12_if.rdy <= 1;

    if (~o_inv_fe12_if.val || (o_inv_fe12_if.val && o_inv_fe12_if.rdy)) begin

      o_inv_fe12_if.sop <= out_cnt == 0;
      o_inv_fe12_if.eop <= out_cnt == 11;

      if (eq_val[5] && out_cnt < 6) begin
        o_inv_fe12_if.val <= 1;
        out_cnt <= out_cnt + 1;
        o_inv_fe12_if.dat <= t[1][out_cnt%6];
      end else
      if (eq_val[7] && out_cnt >= 6) begin
        o_inv_fe12_if.val <= 1;
        out_cnt <= out_cnt + 1;
        o_inv_fe12_if.dat <= t[0][out_cnt%6];
      end

      if (out_cnt == 11) begin
        eq_val <= 0;
        eq_wait <= 0;
        rdy_l <= 0;
        t <= 0;
        a <= 0;
        {out_cnt, mul_cnt, sub_cnt, inv_cnt} <= 0;
        {nxt_mul, nxt_mnr, nxt_sub, nxt_inv} <= 0;
        {mul_en, sub_en, mnr_en, inv_en} <= 0;
      end
    end

    // Latch input
    if (i_inv_fe12_if.rdy && i_inv_fe12_if.val) begin
      a <= {i_inv_fe12_if.dat, a[1], a[0][5:1]};
      if (i_inv_fe12_if.eop) begin
        i_inv_fe12_if.rdy <= 0;
        rdy_l <= 1;
        o_inv_fe6_if.ctl <= i_inv_fe12_if.ctl;
      end
    end

    // Check any results from multiplier
    if (i_mul_fe6_if.val && i_mul_fe6_if.rdy) begin
      if (i_mul_fe6_if.eop) eq_val[i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        0: t[0] <= {i_mul_fe6_if.dat, t[0][5:1]};
        1: t[1] <= {i_mul_fe6_if.dat, t[1][5:1]};
        5: t[1] <= {i_mul_fe6_if.dat, t[1][5:1]};
        6: t[0] <= {i_mul_fe6_if.dat, t[0][5:1]};
        default: o_inv_fe12_if.err <= 1;
      endcase
    end

    // Check any results from mnr
    if (i_mnr_fe6_if.val && i_mnr_fe6_if.rdy) begin
      if(i_mnr_fe6_if.eop) eq_val[i_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        2: t[1] <= {i_mnr_fe6_if.dat, t[1][5:1]};
        default: o_inv_fe12_if.err <= 1;
      endcase
    end

    // Check any results from sub
    if (i_sub_fe_if.val && i_sub_fe_if.rdy) begin
      if(i_sub_fe_if.eop) eq_val[i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        3: t[0] <= {i_sub_fe_if.dat, t[0][5:1]};
        7: t[0] <= {i_sub_fe_if.dat, t[0][5:1]};
        default: o_inv_fe12_if.err <= 1;
      endcase
    end

    // Check any results from inv_fe2
    if (i_inv_fe6_if.val && i_inv_fe6_if.rdy) begin
      if (i_inv_fe6_if.eop) eq_val[i_inv_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_inv_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        4:  t[0] <= {i_inv_fe6_if.dat, t[0][5:1]};
        default: o_inv_fe12_if.err <= 1;
      endcase
    end

    // Issue new multiplies
    if (mul_en)
      case(nxt_mul)
        0: fe6_multiply(0, a[0], a[0]);
        1: fe6_multiply(1, a[1], a[1]);
        5: fe6_multiply(5, a[0], t[0]);
        6: fe6_multiply(6, a[1], t[0]);
      endcase


    // Issue new sub
    if (sub_en)
      case(nxt_sub)
        3: fe6_subtraction(3, t[0], t[1]);
        7: fe6_subtraction(7, 0, t[0]);
      endcase

    // Issue new mnr
    if (mnr_en)
      case(nxt_mnr)
        2: fe6_mnr(2, t[1]);
      endcase

    // Issue new inv
    if (inv_en)
     fe6_inv(4, t[0]);

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
task fe6_multiply(input int unsigned ctl, input FE_TYPE [5:0] a, b);
  if (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy)) begin
    o_mul_fe6_if.val <= 1;
    o_mul_fe6_if.sop <= mul_cnt == 0;
    o_mul_fe6_if.eop <= mul_cnt == 5;
    o_mul_fe6_if.dat[0 +: $bits(FE_TYPE)] <= a[mul_cnt];
    o_mul_fe6_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b[mul_cnt];
    o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    mul_cnt <= mul_cnt + 1;
    if (mul_cnt == 5) begin
      mul_cnt <= 0;
      get_next_mul();
    end
  end
endtask

// Task for using mnr
task fe6_mnr(input int unsigned ctl, input FE_TYPE [5:0] a);
  if (~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy)) begin
    o_mnr_fe6_if.val <= 1;
    o_mnr_fe6_if.sop <= mnr_cnt == 0;
    o_mnr_fe6_if.eop <= mnr_cnt == 5;
    o_mnr_fe6_if.dat <= a[mnr_cnt];
    o_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    mnr_cnt <= mnr_cnt + 1;
    if (mnr_cnt == 5) begin
      mnr_cnt <= 0;
      get_next_mnr();
    end
  end
endtask

// Task for using inv
task fe6_inv(input int unsigned ctl, input FE_TYPE [5:0] a);
  if (~o_inv_fe6_if.val || (o_inv_fe6_if.val && o_inv_fe6_if.rdy)) begin
    o_inv_fe6_if.val <= 1;
    o_inv_fe6_if.sop <= inv_cnt == 0;
    o_inv_fe6_if.eop <= inv_cnt == 5;
    o_inv_fe6_if.dat <= a[inv_cnt];
    o_inv_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    inv_cnt <= inv_cnt + 1;
    if (inv_cnt == 5) begin
      inv_cnt <= 0;
      get_next_inv();
    end
  end
endtask

task get_next_mul();
  mul_en <= 1;
  if(~eq_wait[0] && rdy_l)
    nxt_mul <= 0;
  else if(~eq_wait[1] && rdy_l)
    nxt_mul <= 1;
  else if(~eq_wait[5] && eq_val[4])
    nxt_mul <= 5;
  else if(~eq_wait[6] && eq_val[4] && eq_wait[5])
    nxt_mul <= 6;
  else
    mul_en <= 0;
endtask


task get_next_sub();
  sub_en <= 1;
  if(~eq_wait[3] && eq_val[0] && eq_val[2])
    nxt_sub <= 3;
  else if(~eq_wait[7] && eq_val[6])
    nxt_sub <= 7;
  else
    sub_en <= 0;
endtask

task get_next_mnr();
  mnr_en <= 1;
  if(~eq_wait[2] && eq_val[1])
    nxt_mnr <= 2;
  else
    mnr_en <= 0;
endtask

task get_next_inv();
  inv_en <= 1;
  if(~eq_wait[4] && eq_val[3])
    inv_en <= 1;
  else
    inv_en <= 0;
endtask

endmodule