/*
  This provides the interface to perform Fp6 field element mul. Using karabusta algorithm.
  Because of feedback path we can lockup if there are not enough pipelines for fe2_sub/ fe2_add.

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

module ec_fe6_mul_s
#(
  parameter type FE_TYPE,                // Base field element type
  parameter type FE2_TYPE,               // Fp6 is towered over Fp2
  parameter type FE6_TYPE,               // Fp6 is towered over Fp2
  parameter      CTL_BITS    = 12,
  parameter      OVR_WRT_BIT = 0
)(
  input i_clk, i_rst,
  // Interface to FE2_TYPE multiplier (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE_TYPE adder (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE_TYPE subtractor (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface to FE2_TYPE multiply by non-residue, FE_TYPE data width
  if_axi_stream.source o_mnr_fe2_if,
  if_axi_stream.sink   i_mnr_fe2_if,
  // Interface to FE6_TYPE multiplier (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe6_if,
  if_axi_stream.sink   i_mul_fe6_if
);

localparam CNT_BITS = 5;
localparam NUM_OVR_WRT = $clog2((1 << CNT_BITS)/2); // Only need half the bits for control

// Multiplications are calculated using the formula in bls12_381.pkg::fe6_mul()
// Need storage to latch input stream
// a_a is a[2], b_b is a[1], c_c is a[0]
FE6_TYPE a, b;
FE_TYPE t;

logic [CNT_BITS-1:0] add_cnt, sub_cnt, mul_cnt, mnr_cnt, out_cnt;
logic start;

always_comb begin

  i_mul_fe6_if.rdy = (start == 0) && (~o_mul_fe2_if.val || (o_mul_fe2_if.val & o_mul_fe2_if.rdy));

  case (i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0,1,2: i_mul_fe2_if.rdy = 1;
    3,4,5: i_mul_fe2_if.rdy = ~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy);
    default: i_mul_fe2_if.rdy = 0;
  endcase

  case (i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0,1,2,3,4,5: i_add_fe_if.rdy = ~o_mul_fe2_if.val || (o_mul_fe2_if.val & o_mul_fe2_if.rdy);
    6: i_add_fe_if.rdy = 1;
    7: i_add_fe_if.rdy = (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy));
    8: i_add_fe_if.rdy = (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy));
    default: i_add_fe_if.rdy = 0;
  endcase

  case (i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0,1: i_sub_fe_if.rdy = (sub_cnt/2 > 2) && (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy));
    2: i_sub_fe_if.rdy = (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy));
    3: i_sub_fe_if.rdy = (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy));
    4: i_sub_fe_if.rdy = 1;
    5: i_sub_fe_if.rdy = (out_cnt/2 == 2) && (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy));
    default: i_sub_fe_if.rdy = 0;
  endcase

  case (i_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0: i_mnr_fe2_if.rdy = (add_cnt/2 == 7) && (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy));
    1: i_mnr_fe2_if.rdy = (add_cnt/2 == 8) && (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy));
    default: i_mnr_fe2_if.rdy = 0;
  endcase


end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe6_if.reset_source();
    o_mnr_fe2_if.reset_source();
    o_mul_fe2_if.reset_source();
    o_sub_fe_if.reset_source();
    o_add_fe_if.reset_source();

    add_cnt <= 0;
    sub_cnt <= 0;
    mul_cnt <= 0;
    mnr_cnt <= 0;
    out_cnt <= 0;

    a <= 0;
    b <= 0;
    t <= 0;

    start <= 0;
  end else begin

    if (o_mul_fe6_if.rdy) o_mul_fe6_if.val <= 0;
    if (o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_add_fe_if.rdy) o_add_fe_if.val <= 0;
    if (o_mnr_fe2_if.rdy) o_mnr_fe2_if.val <= 0;

    // Latch some results temp
    if (i_add_fe_if.val && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 6) begin
      b[0] <= {i_add_fe_if.dat, b[0][1]};
    end

    if (i_sub_fe_if.val && i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 4) begin
      b[1] <= {i_sub_fe_if.dat, b[1][1]};
    end

    // Latch multiplier results of a_a, b_b, c_c
    if (i_mul_fe2_if.val && i_mul_fe2_if.rdy && i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] < 3) begin
      a <= {i_mul_fe2_if.dat, {a[2], a[1], a[0][1]}};
    end

    if (i_mul_fe6_if.rdy && i_mul_fe6_if.eop && i_mul_fe6_if.val)
      start <= 1;

    // Multiplier input flow
    case (mul_cnt) inside
      0,1,2,3,4,5: begin // Calculates a_a, b_b, c_c
        fe2_mul(i_mul_fe6_if.val, i_mul_fe6_if.dat[0 +: $bits(FE_TYPE)],
                i_mul_fe6_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)], mul_cnt);

        if (i_mul_fe6_if.val && i_mul_fe6_if.rdy) begin
          a <= {i_mul_fe6_if.dat[0 +: $bits(FE_TYPE)], a[2], a[1], a[0][1]};
          b <= {i_mul_fe6_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)], b[2], b[1], b[0][1]};
        end
      end
      6,10,14: begin
        // Store result into multiplier and temp - calculates fe6_mul[0] / fe6_mul[1] / fe6_mul[2]
        if (i_add_fe_if.val && i_add_fe_if.rdy) begin
          o_mul_fe2_if.dat[0 +: $bits(FE_TYPE)] <= i_add_fe_if.dat;
          o_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= o_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] + 1;
          mul_cnt <= mul_cnt + 1;
        end
      end
      7,11,15: begin
        if (i_add_fe_if.val && i_add_fe_if.rdy) begin
          t <= i_add_fe_if.dat;
          mul_cnt <= mul_cnt + 1;
        end
      end
      8,12,16: begin
        if (i_add_fe_if.val && i_add_fe_if.rdy) begin // .rdy takes into account the multiplier output state
          o_mul_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= i_add_fe_if.dat;
          o_mul_fe2_if.sop <= 1;
          o_mul_fe2_if.eop <= 0;
          o_mul_fe2_if.val <= 1;
          mul_cnt <= mul_cnt + 1;
        end
      end
      9,13,17: begin
        if (i_add_fe_if.val && i_add_fe_if.rdy) begin
          o_mul_fe2_if.dat <= {i_add_fe_if.dat, t};
          o_mul_fe2_if.sop <= 0;
          o_mul_fe2_if.eop <= 1;
          o_mul_fe2_if.val <= 1;
          mul_cnt <= mul_cnt + 1;
        end
      end
      default: if (start==0) mul_cnt <= 0;
    endcase

    // Adder input flow
    case (add_cnt) inside
      0,1: fe2_add(start, a[1][add_cnt%2], a[2][add_cnt%2], add_cnt);
      2,3: fe2_add(start, b[1][add_cnt%2], b[2][add_cnt%2], add_cnt);
      4,5: fe2_add(start, b[0][add_cnt%2], b[1][add_cnt%2], add_cnt);
      6,7: fe2_add(start, a[0][add_cnt%2], a[1][add_cnt%2], add_cnt);
      8,9: fe2_add(start, b[0][add_cnt%2], b[2][add_cnt%2], add_cnt);
      10,11: fe2_add(start, a[0][add_cnt%2], a[2][add_cnt%2], add_cnt);
      12,13: fe2_add(i_sub_fe_if.val && i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 2 , i_sub_fe_if.dat, a[1][add_cnt%2], add_cnt);
      14,15: fe2_add(i_mnr_fe2_if.val, i_mnr_fe2_if.dat, a[0][add_cnt%2], add_cnt);
      16,17: fe2_add(i_mnr_fe2_if.val, b[1][add_cnt%2], i_mnr_fe2_if.dat, add_cnt);
      default: if (start==0) add_cnt <= 0;
    endcase

    // Sub input flow
    case (sub_cnt) inside
      0,1: fe2_sub(i_mul_fe2_if.val && i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 3, i_mul_fe2_if.dat, a[1][sub_cnt%2], sub_cnt);
      2,3: fe2_sub(i_mul_fe2_if.val, i_mul_fe2_if.dat, a[1][sub_cnt%2], sub_cnt);
      4,5: fe2_sub(i_mul_fe2_if.val, i_mul_fe2_if.dat, a[0][sub_cnt%2], sub_cnt);
      6,7: fe2_sub(i_sub_fe_if.val, i_sub_fe_if.dat, a[2][sub_cnt%2], sub_cnt);
      8,9: fe2_sub(i_sub_fe_if.val, i_sub_fe_if.dat, a[0][sub_cnt%2], sub_cnt);
      10,11: fe2_sub(add_cnt >= 18, b[0][sub_cnt%2], a[2][sub_cnt%2], sub_cnt);
      default: if (start==0) sub_cnt <= 0;
    endcase

    // mnr flow
    case (mnr_cnt) inside
      0,1: fe2_mnr(i_sub_fe_if.val && i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 3, i_sub_fe_if.dat, mnr_cnt);
      2,3: fe2_mnr(1, a[2][mnr_cnt%2], mnr_cnt);
      default: if (start==0) mnr_cnt <= 0;
    endcase

    // Final output flow
    if (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy)) begin
      case (out_cnt) inside
        0,1: begin
          o_mul_fe6_if.dat <= i_add_fe_if.dat;
          o_mul_fe6_if.ctl <= i_add_fe_if.ctl;
          o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
          o_mul_fe6_if.sop <= out_cnt == 0;
          o_mul_fe6_if.eop <= 0;
          if (i_add_fe_if.val && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 7) begin
            o_mul_fe6_if.val <= 1;
            out_cnt <= out_cnt + 1;
          end
        end
        2,3: begin
          o_mul_fe6_if.dat <= i_add_fe_if.dat;
          o_mul_fe6_if.sop <= 0;
          o_mul_fe6_if.eop <= 0;
          if (i_add_fe_if.val) begin
            o_mul_fe6_if.val <= 1;
            out_cnt <= out_cnt + 1;
          end
        end
        4,5: begin
          o_mul_fe6_if.dat <= i_sub_fe_if.dat;
          o_mul_fe6_if.sop <= 0;
          o_mul_fe6_if.eop <= out_cnt == 5;
          if (i_sub_fe_if.val) begin
            o_mul_fe6_if.val <= 1;
            out_cnt <= out_cnt + 1;
          end
        end
        default: begin
          out_cnt <= 0;
          start <= 0;
        end
      endcase
  end


  end
end

// Task for fe2_mul
task automatic fe2_mul(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b, ref [CNT_BITS-1:0] cnt);
  if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
    o_mul_fe2_if.sop <= val ? ~o_mul_fe2_if.sop : o_mul_fe2_if.sop;
    o_mul_fe2_if.eop <= val ? o_mul_fe2_if.sop : o_mul_fe2_if.eop;
    o_mul_fe2_if.dat <= {b, a};
    o_mul_fe2_if.val <= val;
    o_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= cnt / 2;
    if (val) cnt = cnt + 1;
  end
endtask

// Task for fe2_add
task automatic fe2_add(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b, ref [CNT_BITS-1:0] cnt);
  if (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy)) begin
    o_add_fe_if.sop <= val ? ~o_add_fe_if.sop : o_add_fe_if.sop;
    o_add_fe_if.eop <= val ? o_add_fe_if.sop : o_add_fe_if.eop;
    o_add_fe_if.dat <= {b, a};
    o_add_fe_if.val <= val;
    o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= cnt / 2;
    if (val) cnt = cnt + 1;
  end
endtask

// Task for fe2_sub
task automatic fe2_sub(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b, ref [CNT_BITS-1:0] cnt);
  if (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy)) begin
    o_sub_fe_if.sop <= val ? ~o_sub_fe_if.sop : o_sub_fe_if.sop;
    o_sub_fe_if.eop <= val ? o_sub_fe_if.sop : o_sub_fe_if.eop;
    o_sub_fe_if.dat <= {b, a};
    o_sub_fe_if.val <= val;
    o_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= cnt / 2;
    if (val) cnt = cnt + 1;
  end
endtask

// Task for fe2_mnr
task automatic fe2_mnr(input logic val, input logic [$bits(FE_TYPE)-1:0] a, ref [CNT_BITS-1:0] cnt);
  if (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy)) begin
    o_mnr_fe2_if.sop <= val ? ~o_mnr_fe2_if.sop : o_mnr_fe2_if.sop;
    o_mnr_fe2_if.eop <= val ? o_mnr_fe2_if.sop : o_mnr_fe2_if.eop;
    o_mnr_fe2_if.dat <= {b, a};
    o_mnr_fe2_if.val <= val;
    o_mnr_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= cnt / 2;
    if (val) cnt = cnt + 1;
  end
endtask


endmodule