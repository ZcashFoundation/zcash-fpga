/*
  This provides the interface to perform
  Fp^6 point logic (adding, subtracting, multiplication), over a Fp2 tower.
  Fq6 is constructed as Fq2(v) / (v3 - ξ) where ξ = u + 1

  TODO: Input control should be added to allow for sparse multiplication.

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

module ec_fe6_arithmetic
#(
  parameter type FE2_TYPE,
  parameter type FE6_TYPE,
  parameter CTL_BITS    = 14,
  parameter OVR_WRT_BIT = 8       // From this bit 4 bits are used for internal control, 2 bits for resource sharing - 6 total
)(
  input i_clk, i_rst,
  // Interface to FE2_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE2_TYPE adder (mod P)
  if_axi_stream.source o_add_fe2_if,
  if_axi_stream.sink   i_add_fe2_if,
  // Interface to FE2_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe2_if,
  if_axi_stream.sink   i_sub_fe2_if,
  // Interface to FE2_TYPE multiply by non-residue
  if_axi_stream.source o_mnr_fe2_if,
  if_axi_stream.sink   i_mnr_fe2_if,
  // Interface to FE6_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe6_if,
  if_axi_stream.sink   i_mul_fe6_if,
  // Interface to FE6_TYPE adder (mod P)
  if_axi_stream.source o_add_fe6_if,
  if_axi_stream.sink   i_add_fe6_if,
  // Interface to FE6_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe6_if,
  if_axi_stream.sink   i_sub_fe6_if
);

localparam NUM_OVR_WRT_BIT = 5;
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS))   add_if_fe2_i [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) add_if_fe2_o [1:0] (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS))   sub_if_fe2_i [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) sub_if_fe2_o [1:0] (i_clk);

// Point addtions are simple additions on each of the Fp2 elements
logic [1:0] add_cnt;
always_comb begin
  i_add_fe6_if.rdy = (add_cnt == 2) && (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy));
  add_if_fe2_i[0].rdy = ~o_add_fe6_if.val || (o_add_fe6_if.val && o_add_fe6_if.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_add_fe6_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    add_cnt <= 0;
    add_if_fe2_o[0].copy_if(0, 0, 1, 1, 0, 0, 0);
  end else begin

    if (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy) add_if_fe2_o[0].val <= 0;
    if (o_add_fe6_if.val && o_add_fe6_if.rdy) o_add_fe6_if.val <= 0;

    // One process to parse inputs and send them to the adder
    case(add_cnt)
      0: begin
        if (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy)) begin
          add_if_fe2_o[0].copy_if({i_add_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)],
                                   i_add_fe6_if.dat[0 +: $bits(FE2_TYPE)]},
                                   i_add_fe6_if.val, 1, 1, i_add_fe6_if.err, i_add_fe6_if.mod, i_add_fe6_if.ctl);
          add_if_fe2_o[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 1;
        end
      end
      1: begin
        if (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy)) begin
          add_if_fe2_o[0].copy_if({i_add_fe6_if.dat[$bits(FE6_TYPE)+$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                   i_add_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_add_fe6_if.val, 1, 1, i_add_fe6_if.err, i_add_fe6_if.mod, i_add_fe6_if.ctl);
          add_if_fe2_o[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 2;
        end
      end
      2: begin
        if (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy)) begin
          add_if_fe2_o[0].copy_if({i_add_fe6_if.dat[$bits(FE6_TYPE)+2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                   i_add_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_add_fe6_if.val, 1, 1, i_add_fe6_if.err, i_add_fe6_if.mod, i_add_fe6_if.ctl);
          add_if_fe2_o[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 0;
        end
      end
    endcase

    // One process to assign outputs
    if (~o_add_fe6_if.val || (o_add_fe6_if.val && o_add_fe6_if.rdy)) begin
      o_add_fe6_if.ctl <= add_if_fe2_i[0].ctl;
      o_add_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= 0;
      if (add_if_fe2_i[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] == 0) begin
        if (add_if_fe2_i[0].val)
          o_add_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[0].dat;
      end else if (add_if_fe2_i[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] == 1) begin
        if (add_if_fe2_i[0].val)
          o_add_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[0].dat;
      end else begin
        o_add_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[0].dat;
        o_add_fe6_if.val <= add_if_fe2_i[0].val;
      end
    end
  end
end

// Point subtractions are simple subtractions on each of the Fp2 elements
logic [1:0] sub_cnt;
always_comb begin
  i_sub_fe6_if.rdy = (sub_cnt == 2) && (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy));
  sub_if_fe2_i[0].rdy = ~o_sub_fe6_if.val || (o_sub_fe6_if.val && o_sub_fe6_if.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_sub_fe6_if.reset_source();
    sub_cnt <= 0;
    sub_if_fe2_o[0].reset_source();
  end else begin

    o_sub_fe6_if.sop <= 1;
    o_sub_fe6_if.eop <= 1;

    if (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy) sub_if_fe2_o[0].val <= 0;
    if (o_sub_fe6_if.val && o_sub_fe6_if.rdy) o_sub_fe6_if.val <= 0;

    case(sub_cnt)
      0: begin
        if (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy)) begin
          sub_if_fe2_o[0].copy_if({i_sub_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)],
                                   i_sub_fe6_if.dat[0 +: $bits(FE2_TYPE)]},
                                   i_sub_fe6_if.val, 1, 1, i_sub_fe6_if.err, i_sub_fe6_if.mod, i_sub_fe6_if.ctl);
          sub_if_fe2_o[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 1;
        end
      end
      1: begin
        if (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy)) begin
          sub_if_fe2_o[0].copy_if({i_sub_fe6_if.dat[$bits(FE6_TYPE)+$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                   i_sub_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                   i_sub_fe6_if.val, 1, 1, i_sub_fe6_if.err, i_sub_fe6_if.mod, i_sub_fe6_if.ctl);
          sub_if_fe2_o[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 2;
        end
      end
      2: begin
        if (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy)) begin
          sub_if_fe2_o[0].copy_if({i_sub_fe6_if.dat[$bits(FE6_TYPE)+2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                   i_sub_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                   i_sub_fe6_if.val, 1, 1, i_sub_fe6_if.err, i_sub_fe6_if.mod, i_sub_fe6_if.ctl);
          sub_if_fe2_o[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 0;
        end
      end
    endcase

    // One process to assign outputs
    if (~o_sub_fe6_if.val || (o_sub_fe6_if.val && o_sub_fe6_if.rdy)) begin
      if (sub_if_fe2_i[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] == 0 && sub_if_fe2_i[0].val) begin
        o_sub_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
        o_sub_fe6_if.ctl <= sub_if_fe2_i[0].ctl;
      end else if (sub_if_fe2_i[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] == 1 && sub_if_fe2_i[0].val) begin
        o_sub_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
      end else if (sub_if_fe2_i[0].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] == 2 && sub_if_fe2_i[0].val) begin
        o_sub_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
        o_sub_fe6_if.val <= 1;
      end
    end
    o_sub_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= 0;
  end
end

// Multiplications are calculated using the formula in bls12_381.pkg::fe6_mul()
FE2_TYPE a_a, b_b, c_c, t;

logic [22:0] eq_val, eq_wait;
logic rdy_l;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe6_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_mnr_fe2_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_mul_fe2_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    sub_if_fe2_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    add_if_fe2_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    i_mul_fe6_if.rdy <= 0;
    i_mul_fe2_if.rdy <= 0;
    sub_if_fe2_i[1].rdy <= 0;
    add_if_fe2_i[1].rdy <= 0;
    i_mnr_fe2_if.rdy <= 0;
    eq_val <= 0;
    eq_wait <= 0;
    rdy_l <= 0;
    a_a <= 0;
    b_b <= 0;
    c_c <= 0;
    t <= 0;
  end else begin

    i_mul_fe2_if.rdy <= 1;
    sub_if_fe2_i[1].rdy <= 1;
    add_if_fe2_i[1].rdy <= 1;
    i_mnr_fe2_if.rdy <= 1;
    i_mul_fe6_if.rdy <= 0;

    if (o_mul_fe6_if.rdy) o_mul_fe6_if.val <= 0;
    if (o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;
    if (sub_if_fe2_o[1].rdy) sub_if_fe2_o[1].val <= 0;
    if (add_if_fe2_o[1].rdy) add_if_fe2_o[1].val <= 0;
    if (o_mnr_fe2_if.rdy) o_mnr_fe2_if.val <= 0;

    if (eq_val[22] && eq_val[20] && eq_val[19])
      o_mul_fe6_if.val <= 1;

    if (o_mul_fe6_if.val && o_mul_fe6_if.rdy) begin
      eq_val <= 0;
      eq_wait <= 0;
      rdy_l <= 0;
      a_a <= 0;
      b_b <= 0;
      c_c <= 0;
      t <= 0;
      o_mul_fe6_if.val <= 0;
    end

    if (eq_wait[0] && eq_wait[1] && eq_wait[2] && eq_wait[13] && eq_wait[14] && ~rdy_l) begin
       i_mul_fe6_if.rdy <= 1;
       o_mul_fe6_if.ctl <= i_mul_fe6_if.ctl;
       rdy_l <= 1;
    end

    // Check any results from multiplier
    if (i_mul_fe2_if.val && i_mul_fe2_if.rdy) begin
      eq_val[i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        0:  a_a <= i_mul_fe2_if.dat;
        1:  b_b <= i_mul_fe2_if.dat;
        2:  c_c <= i_mul_fe2_if.dat;
        5:  o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= i_mul_fe2_if.dat;
        10: o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= i_mul_fe2_if.dat;
        15: o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= i_mul_fe2_if.dat;
        default: o_mul_fe6_if.err <= 1;
      endcase
    end

    // Check any results from mnr
    if (i_mnr_fe2_if.val && i_mnr_fe2_if.rdy) begin
      eq_val[i_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        18: o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= i_mnr_fe2_if.dat;
        21: c_c <= i_mnr_fe2_if.dat;
        default: o_mul_fe6_if.err <= 1;
      endcase
    end

    // Check any results from sub
    if (sub_if_fe2_i[1].val && sub_if_fe2_i[1].rdy) begin
      eq_val[sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        6: o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
        7: o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
        11: o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
        16: o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
        17: o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
        20: o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
        default: o_mul_fe6_if.err <= 1;
      endcase
    end

    // Check any results from add
    if (add_if_fe2_i[1].val && add_if_fe2_i[1].rdy) begin
      eq_val[add_if_fe2_i[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(add_if_fe2_i[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        3: o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
        4: t <= add_if_fe2_i[1].dat;
        8: o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
        9: t <= add_if_fe2_i[1].dat;
        12: o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
        13: o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
        14: t <= add_if_fe2_i[1].dat;
        19: o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
        22: begin
          o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
        end
        default: o_mul_fe6_if.err <= 1;
      endcase
    end

    // Issue new multiplies
    if (~eq_wait[0] && i_mul_fe6_if.val) begin  // 0. a_a = fe2_mul(a[0], b[0])
      fe2_multiply(0, i_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)],
                      i_mul_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[1] && i_mul_fe6_if.val) begin  // 1. b_b = fe2_mul(a[1], b[1])
      fe2_multiply(1, i_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                      i_mul_fe6_if.dat[$bits(FE6_TYPE) + $bits(FE2_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[2] && i_mul_fe6_if.val) begin  // 2. c_c = fe2_mul(a[2], b[2])
      fe2_multiply(2, i_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                      i_mul_fe6_if.dat[$bits(FE6_TYPE) + 2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[5] && eq_val[3] && eq_val[4]) begin  // 5. fe6_mul[0] = fe2_mul(fe6_mul[0], t)   [3, 4]
      fe2_multiply(5, o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)], t);
    end else
    if (~eq_wait[10] && eq_val[8] && eq_val[9]) begin  // 10. fe6_mul[2] = fe2_mul(fe6_mul[2], t)   [8, 9]
      fe2_multiply(10, o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)], t);
    end else
    if (~eq_wait[15] && eq_val[13] && eq_val[14]) begin  // 15. fe6_mul[1] = fe2_mul(fe6_mul[1], t)   [13, 14]
      fe2_multiply(15, o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)], t);
    end

    // Issue new adds
    if (~eq_wait[3] && i_mul_fe6_if.val) begin               // 3. fe6_mul[0] = fe2_add(a[1], a[2])
      fe2_addition(3, i_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                      i_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[4] && i_mul_fe6_if.val) begin               // 4. t =  fe2_add(b[1], b[2])
      fe2_addition(4, i_mul_fe6_if.dat[$bits(FE6_TYPE) + $bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                      i_mul_fe6_if.dat[$bits(FE6_TYPE) + 2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[8] && i_mul_fe6_if.val) begin               // 8. fe6_mul[2] = fe2_add(b[0], b[2])
      fe2_addition(8, i_mul_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)],
                      i_mul_fe6_if.dat[$bits(FE6_TYPE) + 2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[9] && eq_wait[5] && i_mul_fe6_if.val) begin               // 9. t = fe2_add(a[0], a[2])    [wait 5]
      fe2_addition(9, i_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)],
                      i_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[12] && eq_val[11] && eq_val[1]) begin               // 12. fe6_mul[2] = fe2_add(fe6_mul[2], b_b) [11, 1]
      fe2_addition(12, o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)], b_b);
    end else
    if (~eq_wait[13] && i_mul_fe6_if.val) begin               // 13. fe6_mul[1] = fe2_add(b[0], b[1])
      fe2_addition(13, i_mul_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)],
                       i_mul_fe6_if.dat[$bits(FE6_TYPE) + $bits(FE2_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[14] && eq_wait[10] && i_mul_fe6_if.val) begin    // 14. t = fe2_add(a[0], a[1])  [wait 10]
      fe2_addition(14, i_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)],
                       i_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[19] && eq_val[18] && eq_val[0]) begin    // 19. fe6_mul[0] = fe2_add(fe6_mul[0], a_a)    [18, 0]
      fe2_addition(19, o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)], a_a);
    end else
    if (~eq_wait[22] && eq_val[17] && eq_val[21]) begin    // 22. fe6_mul[1] = fe2_add(c_c, fe6_mul[1])   [17, 21]
      fe2_addition(22, o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)], c_c);
    end

    // Issue new sub
    if (~eq_wait[6] && eq_val[5] && eq_val[1]) begin        // 6. fe6_mul[0] = fe2_sub(fe6_mul[0], b_b) [5, 1]
      fe2_subtraction(6, o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)], b_b);
    end else
    if (~eq_wait[7] && eq_val[6] && eq_val[2]) begin        // 7. fe6_mul[0] = fe2_sub(fe6_mul[0], c_c)  [6, 2]
      fe2_subtraction(7, o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)], c_c);
    end else
    if (~eq_wait[11] && eq_val[10] && eq_val[0]) begin      // 11. fe6_mul[2] = fe2_sub(fe6_mul[2], a_a)  [10, 0]
      fe2_subtraction(11, o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)], a_a);
    end else
    if (~eq_wait[16] && eq_val[15] && eq_val[0]) begin      // 16. fe6_mul[1] = fe2_sub(fe6_mul[1], a_a)   [15, 0]
      fe2_subtraction(16, o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)], a_a);
    end else
    if (~eq_wait[17] && eq_val[16] && eq_val[1]) begin      // 17. fe6_mul[1] = fe2_sub(fe6_mul[1], b_b)   [16, 1]
      fe2_subtraction(17, o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)], b_b);
    end else
    if (~eq_wait[20] && eq_val[12] && eq_val[2]) begin      // 20. fe6_mul[2] = fe2_sub(fe6_mul[2], c_c)  [12, 2]
      fe2_subtraction(20, o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)], c_c);
    end

    // Issue new mnr
    if (~eq_wait[18] && eq_val[7]) begin        // 18. fe6_mul[0] = fe2_mul_by_nonresidue(fe6_mul[0])   [7]
      fe2_mnr(18, o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)]);
    end else
    if (~eq_wait[21] && eq_wait[20]) begin        // 21. c_c = fe2_mul_by_nonresidue(c_c)   [20]
      fe2_mnr(21, c_c);
    end

  end
end

resource_share # (
  .NUM_IN       ( 2                 ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS          ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT+NUM_OVR_WRT_BIT ),
  .PIPELINE_IN  ( 0                 ),
  .PIPELINE_OUT ( 0                 )
)
resource_share_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_if_fe2_o[1:0] ),
  .o_res ( o_sub_fe2_if ),
  .i_res ( i_sub_fe2_if ),
  .o_axi ( sub_if_fe2_i[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                 ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS          ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT+NUM_OVR_WRT_BIT ),
  .PIPELINE_IN  ( 0                 ),
  .PIPELINE_OUT ( 0                 )
)
resource_share_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_if_fe2_o[1:0] ),
  .o_res ( o_add_fe2_if      ),
  .i_res ( i_add_fe2_if      ),
  .o_axi ( add_if_fe2_i[1:0] )
);

// Task for subtractions
task fe2_subtraction(input int unsigned ctl, input FE2_TYPE a, b);
  if (~sub_if_fe2_o[1].val || (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy)) begin
    sub_if_fe2_o[1].val <= 1;
    sub_if_fe2_o[1].dat[0 +: $bits(FE2_TYPE)] <= a;
    sub_if_fe2_o[1].dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= b;
    sub_if_fe2_o[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for addition
task fe2_addition(input int unsigned ctl, input FE2_TYPE a, b);
  if (~add_if_fe2_o[1].val || (add_if_fe2_o[1].val && add_if_fe2_o[1].rdy)) begin
    add_if_fe2_o[1].val <= 1;
    add_if_fe2_o[1].dat[0 +: $bits(FE2_TYPE)] <= a;
    add_if_fe2_o[1].dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= b;
    add_if_fe2_o[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for using mult
task fe2_multiply(input int unsigned ctl, input FE2_TYPE a, b, input logic [1:0] en = 2'b11);
  if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
    o_mul_fe2_if.val <= 1;
    if (en[0])
      o_mul_fe2_if.dat[0 +: $bits(FE2_TYPE)] <= a;
    if (en[1])
      o_mul_fe2_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= b;
    o_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for using mnr
task fe2_mnr(input int unsigned ctl, input FE2_TYPE a, input logic en = 1'b1);
  if (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy)) begin
    o_mnr_fe2_if.val <= 1;
    if (en)
      o_mnr_fe2_if.dat <= a;
    o_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

endmodule