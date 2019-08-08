/*
  This provides the interface to perform Fp12 field element mul. Using karabusta algorithm.

  Inputs must be interleaved starting at c0 (i.e. clock 0 = {b.c0, a.c0})
  _s in the name represents the input is a stream starting at c0.

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

module ec_fe12_mul_s
#(
  parameter type FE_TYPE,                // Base field element type\
  parameter      CTL_BITS    = 12,
  parameter      OVR_WRT_BIT = 0
)(
  input i_clk, i_rst,
  // Interface to FE6_TYPE multiplier (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe6_if,
  if_axi_stream.sink   i_mul_fe6_if,
  // Interface to FE_TYPE adder (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE_TYPE subtractor (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface to FE6_TYPE multiply by non-residue, FE_TYPE data width
  if_axi_stream.source o_mnr_fe6_if,
  if_axi_stream.sink   i_mnr_fe6_if,
  // Interface to FE12_TYPE multiplier (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe12_if,
  if_axi_stream.sink   i_mul_fe12_if
);

localparam CNT_BITS = 5;
localparam NUM_OVR_WRT = $clog2((1 << CNT_BITS)/2); // Only need half the bits for control

// Multiplications are calculated using the formula in bls12_381.pkg::fe6_mul()
// Need storage to latch input stream, also used for temp storage
FE_TYPE [5:0] a0, a1, b0, b1, aa;
logic [CNT_BITS-1:0] add_cnt, sub_cnt, mul_cnt, mnr_cnt, out_cnt;
logic start, bb_val, b0_val;

always_comb begin
  i_mul_fe12_if.rdy = ~start && (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy));

  case (i_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0: i_mnr_fe6_if.rdy = (add_cnt >= 12) && (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy));
    default: i_mnr_fe6_if.rdy = 0;
  endcase

  case (i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0: i_add_fe_if.rdy = 1;
    1: i_add_fe_if.rdy = 1;
    2: i_add_fe_if.rdy = (~o_mul_fe12_if.val || (o_mul_fe12_if.val && o_mul_fe12_if.rdy));
    default: i_add_fe_if.rdy = 0;
  endcase

  case (i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0: i_sub_fe_if.rdy = (sub_cnt >= 6) && (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy));
    1: i_sub_fe_if.rdy = (out_cnt >= 6) && (~o_mul_fe12_if.val || (o_mul_fe12_if.val && o_mul_fe12_if.rdy));
    default: i_sub_fe_if.rdy = 0;
  endcase

  case (i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0: i_mul_fe6_if.rdy = 1;
    1: i_mul_fe6_if.rdy = add_cnt >= 12;
    2: i_mul_fe6_if.rdy = (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy));
    default: i_mul_fe6_if.rdy = 0;
  endcase

end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe12_if.reset_source();
    o_mnr_fe6_if.reset_source();
    o_mul_fe6_if.reset_source();
    o_sub_fe_if.reset_source();
    o_add_fe_if.reset_source();

    add_cnt <= 0;
    sub_cnt <= 0;
    mul_cnt <= 0;
    mnr_cnt <= 0;
    out_cnt <= 0;

    {a1, a0} <= 0;
    {b1, b0} <= 0;

    start <= 0;
    bb_val <= 0;
    b0_val <= 0;
  end else begin

    if (o_mul_fe6_if.rdy) o_mul_fe6_if.val <= 0;
    if (o_mul_fe12_if.rdy) o_mul_fe12_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_add_fe_if.rdy) o_add_fe_if.val <= 0;
    if (o_mnr_fe6_if.rdy) o_mnr_fe6_if.val <= 0;

    if (i_mul_fe12_if.val && i_mul_fe12_if.rdy) begin // TODO change input backpressure
      // Latch input
      {a1, a0} <= {i_mul_fe12_if.dat[0 +: $bits(FE_TYPE)], a1, a0[5:1]};
      {b1, b0} <= {i_mul_fe12_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)], b1, b0[5:1]};
    end

    // Latch multiplier results of aa, bb
    if (i_mul_fe6_if.val && i_mul_fe6_if.rdy && i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 0) begin
      aa <= {i_mul_fe6_if.dat, aa[5:1]};
    end

    if (i_mul_fe6_if.val && i_mul_fe6_if.rdy && add_cnt >= 12 && i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
      b1 <= {i_mul_fe6_if.dat, b1[5:1]};
      if (i_mul_fe6_if.eop) bb_val <= 1;
    end

    if (i_add_fe_if.val && i_add_fe_if.rdy && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 0) begin
      a0 <= {i_add_fe_if.dat, a0[5:1]};
    end

    if (i_add_fe_if.val && i_add_fe_if.rdy && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
      b0 <= {i_add_fe_if.dat, b0[5:1]};
      b0_val <= i_add_fe_if.eop;
    end

    if (i_mul_fe12_if.rdy && i_mul_fe12_if.val) begin
      if(i_mul_fe12_if.eop) start <= 1;
      if(i_mul_fe12_if.sop) o_mul_fe12_if.ctl <= i_mul_fe12_if.ctl;
    end

    // Multiplier input flow
    case (mul_cnt) inside
      0,1,2,3,4,5: fe6_mul(i_mul_fe12_if.val, i_mul_fe12_if.dat[0 +: $bits(FE_TYPE)], i_mul_fe12_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)], mul_cnt);
      6,7,8,9,10,11: fe6_mul(i_mul_fe12_if.val, i_mul_fe12_if.dat[0 +: $bits(FE_TYPE)], i_mul_fe12_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)], mul_cnt);
      12,13,14,15,16,17:  fe6_mul(b0_val, b0[mul_cnt%6], a0[mul_cnt%6], mul_cnt);
    endcase

    // Adder input flow
    case (add_cnt) inside
      0,1,2,3,4,5: fe6_add(start, a1[add_cnt%6], a0[add_cnt%6], add_cnt);
      6,7,8,9,10,11: fe6_add(start, b0[add_cnt%6], b1[add_cnt%6], add_cnt);
      12,13,14,15,16,17: fe6_add(i_mnr_fe6_if.val, aa[add_cnt%6], i_mnr_fe6_if.dat, add_cnt);
    endcase

    // Sub input flow
    case (sub_cnt) inside
      0,1,2,3,4,5: fe6_sub(i_mul_fe6_if.val && i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 2, i_mul_fe6_if.dat, aa[sub_cnt%6], sub_cnt);
      6,7,8,9,10,11: fe6_sub(i_sub_fe_if.val, i_sub_fe_if.dat, b1[sub_cnt%6], sub_cnt);
    endcase

    // mnr flow
    case (mnr_cnt) inside
      0,1,2,3,4,5: fe6_mnr(bb_val, b1[mnr_cnt%6], mnr_cnt);
    endcase

    // Final output flow
    if (~o_mul_fe12_if.val || (o_mul_fe12_if.val && o_mul_fe12_if.rdy)) begin
      case (out_cnt) inside
        0,1,2,3,4,5: begin
          o_mul_fe12_if.dat <= i_add_fe_if.dat;
          o_mul_fe12_if.sop <= out_cnt == 0;
          o_mul_fe12_if.eop <= 0;
          if (i_add_fe_if.val && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 2) begin
            o_mul_fe12_if.val <= 1;
            out_cnt <= out_cnt + 1;
          end
        end
        6,7,8,9,10,11: begin
          o_mul_fe12_if.dat <= i_sub_fe_if.dat;
          o_mul_fe12_if.sop <= 0;
          o_mul_fe12_if.eop <= out_cnt == 11;
          if (i_sub_fe_if.val && i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
            o_mul_fe12_if.val <= 1;
            out_cnt <= out_cnt + 1;
          end
        end
        default: begin
          out_cnt <= 0;
          bb_val <= 0;
          b0_val <= 0;
          mnr_cnt <= 0;
          mul_cnt <= 0;
          add_cnt <= 0;
          sub_cnt <= 0;
          start <= 0;
        end
      endcase
    end
  end
end

// Task for fe6_mul
task automatic fe6_mul(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b, ref [CNT_BITS-1:0] cnt);
  if (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy)) begin
    o_mul_fe6_if.sop <= cnt == 0 || cnt == 6 || cnt == 12;
    o_mul_fe6_if.eop <= cnt == 5 || cnt == 11 || cnt == 17;
    o_mul_fe6_if.dat <= {b, a};
    o_mul_fe6_if.val <= val;
    if (cnt == 0) o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
    if (cnt == 6) o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 1;
    if (cnt == 12) o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 2;
    if (val) cnt = cnt + 1;
  end
endtask

// Task for fe6_add
task automatic fe6_add(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b, ref [CNT_BITS-1:0] cnt);
  if (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy)) begin
    o_add_fe_if.sop <= cnt == 0 || cnt == 6 || cnt == 12;
    o_add_fe_if.eop <= cnt == 5 || cnt == 11 || cnt == 17;
    o_add_fe_if.dat <= {b, a};
    o_add_fe_if.val <= val;
    if (cnt == 0) o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
    if (cnt == 6) o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 1;
    if (cnt == 12) o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 2;
    if (val) cnt = cnt + 1;
  end
endtask

// Task for fe6_sub
task automatic fe6_sub(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b, ref [CNT_BITS-1:0] cnt);
  if (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy)) begin
    o_sub_fe_if.sop <= cnt == 0 || cnt == 6;
    o_sub_fe_if.eop <= cnt == 5 || cnt == 11;
    o_sub_fe_if.dat <= {b, a};
    o_sub_fe_if.val <= val;
    if (cnt == 0) o_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
    if (cnt == 6) o_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 1;
    if (val) cnt = cnt + 1;
  end
endtask

// Task for fe6_mnr
task automatic fe6_mnr(input logic val, input logic [$bits(FE_TYPE)-1:0] a, ref [CNT_BITS-1:0] cnt);
  if (~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy)) begin
    o_mnr_fe6_if.sop <= cnt  == 0;
    o_mnr_fe6_if.eop <= cnt  == 5;
    o_mnr_fe6_if.dat <= a;
    o_mnr_fe6_if.val <= val;
    o_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
    if (val) cnt = cnt + 1;
  end
endtask


endmodule