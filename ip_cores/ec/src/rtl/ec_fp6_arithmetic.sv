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
          add_if_fe2_o[0].ctl[OVR_WRT_BIT +: 2] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 1;
        end
      end
      1: begin
        if (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy)) begin
          add_if_fe2_o[0].copy_if({i_add_fe6_if.dat[$bits(FE6_TYPE)+$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                   i_add_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_add_fe6_if.val, 1, 1, i_add_fe6_if.err, i_add_fe6_if.mod, i_add_fe6_if.ctl);
          add_if_fe2_o[0].ctl[OVR_WRT_BIT +: 2] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 2;
        end
      end
      2: begin
        if (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy)) begin
          add_if_fe2_o[0].copy_if({i_add_fe6_if.dat[$bits(FE6_TYPE)+2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                   i_add_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_add_fe6_if.val, 1, 1, i_add_fe6_if.err, i_add_fe6_if.mod, i_add_fe6_if.ctl);
          add_if_fe2_o[0].ctl[OVR_WRT_BIT +: 2] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 0;
        end
      end
    endcase

    // One process to assign outputs
    if (~o_add_fe6_if.val || (o_add_fe6_if.val && o_add_fe6_if.rdy)) begin
      o_add_fe6_if.ctl <= add_if_fe2_i[0].ctl;
      o_add_fe6_if.ctl[OVR_WRT_BIT +: 2] <= 0;
      if (add_if_fe2_i[0].ctl[OVR_WRT_BIT +: 2] == 0) begin
        if (add_if_fe2_i[0].val)
          o_add_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[0].dat;
      end else if (add_if_fe2_i[0].ctl[OVR_WRT_BIT +: 2] == 1) begin
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
          sub_if_fe2_o[0].ctl[OVR_WRT_BIT +: 2] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 1;
        end
      end
      1: begin
        if (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy)) begin
          sub_if_fe2_o[0].copy_if({i_sub_fe6_if.dat[$bits(FE6_TYPE)+$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                   i_sub_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                   i_sub_fe6_if.val, 1, 1, i_sub_fe6_if.err, i_sub_fe6_if.mod, i_sub_fe6_if.ctl);
          sub_if_fe2_o[0].ctl[OVR_WRT_BIT +: 2] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 2;
        end
      end
      2: begin
        if (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy)) begin
          sub_if_fe2_o[0].copy_if({i_sub_fe6_if.dat[$bits(FE6_TYPE)+2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                   i_sub_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                   i_sub_fe6_if.val, 1, 1, i_sub_fe6_if.err, i_sub_fe6_if.mod, i_sub_fe6_if.ctl);
          sub_if_fe2_o[0].ctl[OVR_WRT_BIT +: 2] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 0;
        end
      end
    endcase

    // One process to assign outputs
    if (~o_sub_fe6_if.val || (o_sub_fe6_if.val && o_sub_fe6_if.rdy)) begin
      if (sub_if_fe2_i[0].ctl[OVR_WRT_BIT +: 2] == 0 && sub_if_fe2_i[0].val) begin
        o_sub_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
        o_sub_fe6_if.ctl <= sub_if_fe2_i[0].ctl;
      end else if (sub_if_fe2_i[0].ctl[OVR_WRT_BIT +: 2] == 1 && sub_if_fe2_i[0].val) begin
        o_sub_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
      end else if (sub_if_fe2_i[0].ctl[OVR_WRT_BIT +: 2] == 2 && sub_if_fe2_i[0].val) begin
        o_sub_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
        o_sub_fe6_if.val <= 1;
      end
    end
    o_sub_fe6_if.ctl[OVR_WRT_BIT +: 2] <= 0;
  end
end

// Multiplications are calculated using the formula in bls12_381.pkg::fe6_mul()

logic [3:0] mul_cnt, add_mul_cnt, sub_mul_cnt, mnr_cnt;
logic [2:0] mul_val;
FE2_TYPE a_a, b_b, c_c;

always_comb begin

  case(i_mul_fe2_if.ctl[OVR_WRT_BIT +: 4]) inside
    0, 1, 2: i_mul_fe2_if.rdy = 1;
    3:  i_mul_fe2_if.rdy = sub_mul_cnt == 0 && (~sub_if_fe2_o[1].val || (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy));
    4:  i_mul_fe2_if.rdy = sub_mul_cnt == 2 && (~sub_if_fe2_o[1].val || (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy));
    5:  i_mul_fe2_if.rdy = sub_mul_cnt == 3 && (~sub_if_fe2_o[1].val || (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy));
    default: i_mul_fe2_if.rdy = 0;
  endcase

  case(add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4]) inside
    0: add_if_fe2_i[1].rdy = mul_cnt == 3 && (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy));
    1: add_if_fe2_i[1].rdy = mul_cnt == 3 && (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy));
    2: add_if_fe2_i[1].rdy = mul_cnt == 4 && (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy));
    3: add_if_fe2_i[1].rdy = mul_cnt == 4 && (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy));
    4: add_if_fe2_i[1].rdy = mul_cnt == 5 && (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy));
    5: add_if_fe2_i[1].rdy = mul_cnt == 5 && (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy));
    6: add_if_fe2_i[1].rdy = sub_mul_cnt == 5 && (~sub_if_fe2_o[1].val || (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy));
    7, 8: add_if_fe2_i[1].rdy = ~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy);
    default: add_if_fe2_i[1].rdy = 0;
  endcase

  case(sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4]) inside
    0: sub_if_fe2_i[1].rdy = sub_mul_cnt == 1 && (~sub_if_fe2_o[1].val || (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy));
    1: sub_if_fe2_i[1].rdy = mnr_cnt == 0 && (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy));
    2: sub_if_fe2_i[1].rdy = add_mul_cnt == 6 && (~add_if_fe2_o[1].val || (add_if_fe2_o[1].val && add_if_fe2_o[1].rdy));
    3: sub_if_fe2_i[1].rdy = sub_mul_cnt == 4 && (~sub_if_fe2_o[1].val || (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy));
    4: sub_if_fe2_i[1].rdy = add_mul_cnt == 8 && i_mnr_fe2_if.val && i_mnr_fe2_if.ctl[OVR_WRT_BIT +: 4] == 1 && (~add_if_fe2_o[1].val || (add_if_fe2_o[1].val && add_if_fe2_o[1].rdy));
    5: sub_if_fe2_i[1].rdy = ~mul_val[2];
    default: sub_if_fe2_i[1].rdy = 0;
  endcase

  case(i_mnr_fe2_if.ctl[OVR_WRT_BIT +: 4]) inside
    0: i_mnr_fe2_if.rdy = add_mul_cnt == 7 && (~add_if_fe2_o[1].val || (add_if_fe2_o[1].val && add_if_fe2_o[1].rdy));
    1: i_mnr_fe2_if.rdy = add_mul_cnt == 8 && sub_if_fe2_i[1].val && sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 4 && (~add_if_fe2_o[1].val || (add_if_fe2_o[1].val && add_if_fe2_o[1].rdy));
    default: i_mnr_fe2_if.rdy = 0;
  endcase

  o_mul_fe6_if.val <= &mul_val;
end

logic output_done;
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe6_if.ctl <= 0;
    o_mul_fe6_if.mod <= 0;
    o_mul_fe6_if.err <= 0;
    o_mul_fe6_if.sop <= 1;
    o_mul_fe6_if.eop <= 1;
    o_mul_fe6_if.dat <= 0;
    o_mnr_fe2_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    mul_cnt <= 0;
    add_mul_cnt <= 0;
    sub_mul_cnt <= 0;
    mnr_cnt <= 0;
    o_mul_fe2_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    sub_if_fe2_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    add_if_fe2_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    a_a <= 0;
    b_b <= 0;
    c_c <= 0;
    i_mul_fe6_if.rdy <= 0;
    mul_val <= 0;
    output_done <= 1;
  end else begin

    i_mul_fe6_if.rdy <= 0;

    if (o_mul_fe6_if.val && o_mul_fe6_if.rdy) begin
      mul_val <= 0;
      output_done <= 1;
    end
    if (o_mul_fe2_if.val && o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;
    if (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy) sub_if_fe2_o[1].val <= 0;
    if (add_if_fe2_o[1].val && add_if_fe2_o[1].rdy) add_if_fe2_o[1].val <= 0;
    if (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy) o_mnr_fe2_if.val <= 0;

    // Multiplications
    if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
      case(mul_cnt)
        0: begin
          o_mul_fe2_if.copy_if({i_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[$bits(FE6_TYPE)  +: $bits(FE2_TYPE)]},
                                i_mul_fe6_if.val && output_done, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          if (i_mul_fe6_if.val && output_done) mul_cnt <= mul_cnt + 1;
        end
        1: begin
          o_mul_fe2_if.copy_if({i_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[$bits(FE6_TYPE) + $bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                1, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          mul_cnt <= mul_cnt + 1;
        end
        2: begin
          o_mul_fe2_if.copy_if({i_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[$bits(FE6_TYPE) + 2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                1, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          mul_cnt <= mul_cnt + 1;
        end
        3: begin
          if (add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 0 && add_if_fe2_i[1].val)
            o_mul_fe2_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
          if (add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 1 && add_if_fe2_i[1].val) begin
            o_mul_fe2_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
            o_mul_fe2_if.val <= 1;
            mul_cnt <= mul_cnt + 1;
          end
        end
        4: begin
          if (add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 2 && add_if_fe2_i[1].val)
            o_mul_fe2_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
          if (add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 3 && add_if_fe2_i[1].val) begin
            o_mul_fe2_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
            o_mul_fe2_if.val <= 1;
            mul_cnt <= mul_cnt + 1;
          end
        end
        5: begin
          if (add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 4 && add_if_fe2_i[1].val)
            o_mul_fe2_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
          if (add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 5 && add_if_fe2_i[1].val) begin
            o_mul_fe2_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
            o_mul_fe2_if.val <= 1;
            mul_cnt <= 0;
          end
        end
      endcase
      o_mul_fe2_if.ctl[OVR_WRT_BIT +: 4] <= mul_cnt;
     end

     // Additions
     if (~add_if_fe2_o[1].val || (add_if_fe2_o[1].val && add_if_fe2_o[1].rdy)) begin
      case (add_mul_cnt)
        0: begin
          add_if_fe2_o[1].copy_if({i_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_mul_fe6_if.val && output_done, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          if (i_mul_fe6_if.val && output_done) add_mul_cnt <= add_mul_cnt + 1;
        end
        1: begin
          add_if_fe2_o[1].copy_if({i_mul_fe6_if.dat[$bits(FE6_TYPE) + $bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[$bits(FE6_TYPE) + 2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                1, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          add_mul_cnt <= add_mul_cnt + 1;
        end
        2: begin
          add_if_fe2_o[1].copy_if({i_mul_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[$bits(FE6_TYPE) + 2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                1, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          add_mul_cnt <= add_mul_cnt + 1;
        end
        3: begin
          add_if_fe2_o[1].copy_if({i_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                1, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          add_mul_cnt <= add_mul_cnt + 1;
        end
        4: begin
          add_if_fe2_o[1].copy_if({i_mul_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[$bits(FE6_TYPE) + $bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                1, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          add_mul_cnt <= add_mul_cnt + 1;
        end
        5: begin
          add_if_fe2_o[1].copy_if({i_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)],
                                i_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                1, 1, 1, i_mul_fe6_if.err, i_mul_fe6_if.mod, i_mul_fe6_if.ctl);
          add_mul_cnt <= add_mul_cnt + 1;
          i_mul_fe6_if.rdy <= 1; // Release input here
          output_done <= 0;
        end
        6: begin
          add_if_fe2_o[1].dat[0 +: $bits(FE2_TYPE)] <= b_b;
          if (sub_if_fe2_i[1].val) begin
            add_if_fe2_o[1].dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
            add_if_fe2_o[1].ctl <= sub_if_fe2_i[1].ctl;
          end
          if (sub_if_fe2_i[1].val && sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 2) begin
            add_mul_cnt <= add_mul_cnt + 1;
            add_if_fe2_o[1].val <= 1;
          end
        end
        7: begin
          add_if_fe2_o[1].dat[0 +: $bits(FE2_TYPE)] <= a_a;
          if (i_mnr_fe2_if.val) begin
            add_if_fe2_o[1].dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= i_mnr_fe2_if.dat;
            add_if_fe2_o[1].ctl <= i_mnr_fe2_if.ctl;
          end
          if (i_mnr_fe2_if.val && i_mnr_fe2_if.ctl[OVR_WRT_BIT +: 4] == 0) begin
            add_mul_cnt <= add_mul_cnt + 1;
            add_if_fe2_o[1].val <= 1;
          end
        end
        8: begin
          if (sub_if_fe2_i[1].val && sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 4 &&
              i_mnr_fe2_if.val && i_mnr_fe2_if.ctl[OVR_WRT_BIT +: 4] == 1) begin
            add_if_fe2_o[1].dat[0 +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
            add_if_fe2_o[1].ctl <= sub_if_fe2_i[1].ctl;
            add_if_fe2_o[1].dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= i_mnr_fe2_if.dat;
            add_mul_cnt <= 0;
            add_if_fe2_o[1].val <= 1;
          end
        end
      endcase
      add_if_fe2_o[1].ctl[OVR_WRT_BIT +: 4] <= add_mul_cnt;
    end

    // Subtractions
    if (~sub_if_fe2_o[1].val || (sub_if_fe2_o[1].val && sub_if_fe2_o[1].rdy)) begin
      case (sub_mul_cnt)
        0: begin
          if (i_mul_fe2_if.ctl[OVR_WRT_BIT +: 4] == 3) begin
            sub_if_fe2_o[1].dat <= {b_b, i_mul_fe2_if.dat};
            sub_if_fe2_o[1].val <= i_mul_fe2_if.val;
            sub_if_fe2_o[1].ctl <= i_mul_fe2_if.ctl;
            if (i_mul_fe2_if.val) sub_mul_cnt <= sub_mul_cnt + 1;
          end
        end
        1: begin
          if (sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 0) begin
            sub_if_fe2_o[1].dat <= {c_c, sub_if_fe2_i[1].dat};
            sub_if_fe2_o[1].val <= sub_if_fe2_i[1].val;
            sub_if_fe2_o[1].ctl <= sub_if_fe2_i[1].ctl;
            if (sub_if_fe2_i[1].val) sub_mul_cnt <= sub_mul_cnt + 1;
          end
        end
        2: begin
          if (i_mul_fe2_if.ctl[OVR_WRT_BIT +: 4] == 4) begin
            sub_if_fe2_o[1].dat <= {a_a, i_mul_fe2_if.dat};
            sub_if_fe2_o[1].val <= i_mul_fe2_if.val;
            sub_if_fe2_o[1].ctl <= i_mul_fe2_if.ctl;
            if (i_mul_fe2_if.val) sub_mul_cnt <= sub_mul_cnt + 1;
          end
        end
        3: begin
          if (i_mul_fe2_if.ctl[OVR_WRT_BIT +: 4] == 5) begin
            sub_if_fe2_o[1].dat <= {a_a, i_mul_fe2_if.dat};
            sub_if_fe2_o[1].val <= i_mul_fe2_if.val;
            sub_if_fe2_o[1].ctl <= i_mul_fe2_if.ctl;
            if (i_mul_fe2_if.val) sub_mul_cnt <= sub_mul_cnt + 1;
          end
        end
        4: begin
          if (sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 3) begin
            sub_if_fe2_o[1].dat <= {b_b, sub_if_fe2_i[1].dat};
            sub_if_fe2_o[1].val <= sub_if_fe2_i[1].val;
            sub_if_fe2_o[1].ctl <= sub_if_fe2_i[1].ctl;
            if (sub_if_fe2_i[1].val) sub_mul_cnt <= sub_mul_cnt + 1;
          end
        end
        5: begin
          if (add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 6) begin
            sub_if_fe2_o[1].dat <= {c_c, add_if_fe2_i[1].dat};
            sub_if_fe2_o[1].val <= add_if_fe2_i[1].val;
            sub_if_fe2_o[1].ctl <= add_if_fe2_i[1].ctl;
            if (add_if_fe2_i[1].val) sub_mul_cnt <= 0;
          end
        end
      endcase
      sub_if_fe2_o[1].ctl[OVR_WRT_BIT +: 4] <= sub_mul_cnt;
    end

    // Non-residue
    if (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy)) begin
      case(mnr_cnt)
        0: begin
          if (sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 1 && sub_if_fe2_i[1].val) begin
            o_mnr_fe2_if.dat <= sub_if_fe2_i[1].dat;
            o_mnr_fe2_if.val <= sub_if_fe2_i[1].val;
            o_mnr_fe2_if.ctl <= 0;
            o_mnr_fe2_if.ctl[OVR_WRT_BIT +: 4] <= mnr_cnt;
            mnr_cnt <= mnr_cnt + 1;
          end
        end
        1: begin
          o_mnr_fe2_if.dat <= c_c;
          o_mnr_fe2_if.val <= 1;
          o_mnr_fe2_if.ctl <= 0;
          o_mnr_fe2_if.ctl[OVR_WRT_BIT +: 4] <= mnr_cnt;
          mnr_cnt <= 0;
        end
      endcase
    end

    // Take results from multiplications to save a_a, b_b, c_c
    if (i_mul_fe2_if.val && i_mul_fe2_if.rdy) begin
      case (i_mul_fe2_if.ctl[OVR_WRT_BIT +: 4])
        0: a_a <= i_mul_fe2_if.dat;
        1: b_b <= i_mul_fe2_if.dat;
        2: c_c <= i_mul_fe2_if.dat;
      endcase
    end

    // Final output valid
    if (sub_if_fe2_i[1].val && sub_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 5 && ~mul_val[2]) begin
      o_mul_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[1].dat;
      o_mul_fe6_if.ctl <= sub_if_fe2_i[1].ctl;
      mul_val[2] <= 1;
    end
    if (add_if_fe2_i[1].val && add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 8 && ~mul_val[1]) begin
      o_mul_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
      o_mul_fe6_if.ctl <= add_if_fe2_i[1].ctl;
      mul_val[1] <= 1;
    end
    if (add_if_fe2_i[1].val && add_if_fe2_i[1].ctl[OVR_WRT_BIT +: 4] == 7 && ~mul_val[0]) begin
      o_mul_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[1].dat;
      o_mul_fe6_if.ctl <= add_if_fe2_i[1].ctl;
      mul_val[0] <= 1;
    end
    o_mul_fe6_if.ctl[OVR_WRT_BIT +: 4] <= 0;
    
    

  end
end

resource_share # (
  .NUM_IN       ( 2                 ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BITS          ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT+4     ),
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
  .OVR_WRT_BIT  ( OVR_WRT_BIT+4     ),
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

endmodule