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
  parameter      OVR_WRT_BIT = 0,
  parameter      SQ_BIT = OVR_WRT_BIT + 5,  // If this bit is set, we perform a square
  parameter      SPARSE_BIT = OVR_WRT_BIT + 6  // If this bit is set, we perform a sparse multiplication
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
logic start, aa_val, bb_val, b0_val, val_l;

enum {MULT, SQ, SPARSE} mul_mode;
always_comb begin
  case(mul_mode)
    MULT: begin
      i_mul_fe12_if.rdy = val_l && ~start && (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy));

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
        1: i_sub_fe_if.rdy = 1;
        default: i_sub_fe_if.rdy = 0;
      endcase

      case (i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
        0: i_mul_fe6_if.rdy = 1;
        1: i_mul_fe6_if.rdy = add_cnt >= 12;
        2: i_mul_fe6_if.rdy = (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy));
        default: i_mul_fe6_if.rdy = 0;
      endcase
    end
    SQ: begin
      i_mul_fe12_if.rdy = val_l && ~start;

      case (i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
        0: i_add_fe_if.rdy = 1;
        1: i_add_fe_if.rdy = 1;
        2: i_add_fe_if.rdy = 1;
        default: i_add_fe_if.rdy = 0;
      endcase

      case (i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
        0: i_mul_fe6_if.rdy = 1;
        1: i_mul_fe6_if.rdy = 1;
        default: i_mul_fe6_if.rdy = 0;
      endcase

      case (i_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
        0: i_mnr_fe6_if.rdy = 1;
        1: i_mnr_fe6_if.rdy = 1;
        default: i_mnr_fe6_if.rdy = 0;
      endcase

      case (i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
        0: i_sub_fe_if.rdy = 1;
        1: i_sub_fe_if.rdy = (~o_mul_fe12_if.val || (o_mul_fe12_if.val && o_mul_fe12_if.rdy));
        default: i_sub_fe_if.rdy = 0;
      endcase

    end
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
    aa_val <= 0;
    bb_val <= 0;
    b0_val <= 0;
    val_l <= 0;
    mul_mode <= MULT;
  end else begin
  
    if (i_mul_fe12_if.val && ~val_l) begin
      val_l <= 1;
      mul_mode <= i_mul_fe12_if.ctl[SQ_BIT] ? SQ : i_mul_fe12_if.ctl[SPARSE_BIT] ? SPARSE : MULT;
    end

    if (o_mul_fe6_if.rdy) o_mul_fe6_if.val <= 0;
    if (o_mul_fe12_if.rdy) o_mul_fe12_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_add_fe_if.rdy) o_add_fe_if.val <= 0;
    if (o_mnr_fe6_if.rdy) o_mnr_fe6_if.val <= 0;

    if (i_mul_fe12_if.val && i_mul_fe12_if.rdy) begin
      if(i_mul_fe12_if.eop) start <= 1;
      if(i_mul_fe12_if.sop) begin
        o_mul_fe12_if.ctl <= i_mul_fe12_if.ctl;       
      end

      // Latch input
      {a1, a0} <= {i_mul_fe12_if.dat[0 +: $bits(FE_TYPE)], a1, a0[5:1]};
      {b1, b0} <= {i_mul_fe12_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)], b1, b0[5:1]};
    end


    case(mul_mode)
      MULT: begin
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
        
        if (i_sub_fe_if.val && i_sub_fe_if.rdy && i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 0) begin
          a1 <= {i_sub_fe_if.dat, a1[5:1]};
          if (i_sub_fe_if.eop) aa_val <= 1;
        end

        if (i_add_fe_if.val && i_add_fe_if.rdy && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
          b0 <= {i_add_fe_if.dat, b0[5:1]};
          b0_val <= i_add_fe_if.eop;
        end
      end
      SQ: begin
        if (i_mul_fe6_if.val && i_mul_fe6_if.rdy && i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 0) begin
          aa <= {i_mul_fe6_if.dat, aa[5:1]};
          if (i_mul_fe6_if.eop)  aa_val <= 1;
        end

        if (i_add_fe_if.val && i_add_fe_if.rdy && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 0) begin
          b0 <= {i_add_fe_if.dat, b0[5:1]};
        end

        if (i_mnr_fe6_if.val && i_mnr_fe6_if.rdy && i_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 0) begin
          b1 <= {i_mnr_fe6_if.dat, b1[5:1]};
          if (i_mnr_fe6_if.eop) bb_val <= 1;
        end

        if (i_add_fe_if.val && i_add_fe_if.rdy && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
          a1 <= {i_add_fe_if.dat, a1[5:1]};
          if (i_add_fe_if.eop) bb_val <= 1;
        end

        if (i_mul_fe6_if.val && i_mul_fe6_if.rdy && i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
          b1 <= {i_mul_fe6_if.dat, b1[5:1]};
          if (i_mul_fe6_if.eop) bb_val <= 1;
        end

        if (i_add_fe_if.val && i_add_fe_if.rdy && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 2) begin
          a0 <= {i_add_fe_if.dat, a0[5:1]};
          if (i_add_fe_if.eop) b0_val <= 1;
        end

        if (i_sub_fe_if.val && i_sub_fe_if.rdy && i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 0) begin
          a1 <= {i_sub_fe_if.dat, a1[5:1]};
          if (i_sub_fe_if.eop) bb_val <= 1;
        end

        if (i_mnr_fe6_if.val && i_mnr_fe6_if.rdy && i_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
          aa <= {i_mnr_fe6_if.dat, aa[5:1]};
          if (i_mnr_fe6_if.eop) aa_val <= 1;
        end

      end
    endcase


    case(mul_mode)
      MULT: begin
        // Multiplier input flow
        case (mul_cnt) inside
          0,1,2,3,4,5: fe6_mul(val_l && i_mul_fe12_if.val, i_mul_fe12_if.dat[0 +: $bits(FE_TYPE)], i_mul_fe12_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)]);
          6,7,8,9,10,11: fe6_mul(i_mul_fe12_if.val, i_mul_fe12_if.dat[0 +: $bits(FE_TYPE)], i_mul_fe12_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)]);
          12,13,14,15,16,17: fe6_mul(b0_val, b0[mul_cnt%6], a0[mul_cnt%6]);
        endcase

        // Adder input flow
        case (add_cnt) inside
          0,1,2,3,4,5: fe6_add(start, a1[add_cnt%6], a0[add_cnt%6]);
          6,7,8,9,10,11: fe6_add(start, b0[add_cnt%6], b1[add_cnt%6]);
          12,13,14,15,16,17: fe6_add(i_mnr_fe6_if.val, aa[add_cnt%6], i_mnr_fe6_if.dat);
        endcase

        // Sub input flow
        case (sub_cnt) inside
          0,1,2,3,4,5: fe6_sub(i_mul_fe6_if.val && i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 2, i_mul_fe6_if.dat, aa[sub_cnt%6]);
          6,7,8,9,10,11: fe6_sub(aa_val, a1[sub_cnt%6], b1[sub_cnt%6]);
        endcase

        // mnr flow
        case (mnr_cnt) inside
          0,1,2,3,4,5: fe6_mnr(bb_val, b1[mnr_cnt%6]);
        endcase
      end
      SQ: begin
        case (mul_cnt) inside
          0,1,2,3,4,5: fe6_mul(start, a0[mul_cnt%6], a1[mul_cnt%6]);
          6,7,8,9,10,11: begin
            if (mul_cnt == 11) bb_val <= 0;
            fe6_mul(bb_val && add_cnt >= 12, a1[mul_cnt%6], b0[mul_cnt%6]);            
          end
        endcase

        case (add_cnt) inside
          0,1,2,3,4,5: fe6_add(start, a1[add_cnt%6], a0[add_cnt%6]);
          6,7,8,9,10,11: begin
            if (add_cnt == 11) bb_val <= 0;
            fe6_add(bb_val, b1[add_cnt%6], a0[add_cnt%6]);            
          end
          12,13,14,15,16,17: fe6_add(aa_val, aa[add_cnt%6], aa[add_cnt%6]);
        endcase

        case (mnr_cnt) inside
          0,1,2,3,4,5: fe6_mnr(start, a1[mnr_cnt%6]);
          6,7,8,9,10,11: begin
            if (mnr_cnt == 11) aa_val <= 0;
            fe6_mnr(add_cnt >= 18 && sub_cnt >= 6, aa[mnr_cnt%6]);
          end
        endcase

        case (sub_cnt) inside
          0,1,2,3,4,5: begin
            fe6_sub(bb_val && aa_val && mul_cnt >= 12, b1[sub_cnt%6], aa[sub_cnt%6]);
            if (sub_cnt == 5) bb_val <= 0;
          end
          6,7,8,9,10,11: fe6_sub(bb_val && aa_val && mnr_cnt >= 12 && add_cnt >= 12, a1[sub_cnt%6], aa[sub_cnt%6]);
        endcase

      end
    endcase

    // Final output flow
    if (~o_mul_fe12_if.val || (o_mul_fe12_if.val && o_mul_fe12_if.rdy)) begin
      o_mul_fe12_if.sop <= out_cnt == 0;
      o_mul_fe12_if.eop <= out_cnt == 11;
      case (out_cnt) inside
        0,1,2,3,4,5: begin
          case(mul_mode)
            MULT: begin
              o_mul_fe12_if.dat <= i_add_fe_if.dat;
              if (i_add_fe_if.val && i_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 2) begin
                o_mul_fe12_if.val <= 1;
                out_cnt <= out_cnt + 1;
              end
            end
            SQ: begin
              o_mul_fe12_if.dat <= i_sub_fe_if.dat;
              if (i_sub_fe_if.val && i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
                o_mul_fe12_if.val <= 1;
                out_cnt <= out_cnt + 1;
              end
            end
          endcase
        end
        6,7,8,9,10,11: begin
          case(mul_mode)
            MULT: begin
              o_mul_fe12_if.dat <= i_sub_fe_if.dat;
              if (i_sub_fe_if.val && i_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
                o_mul_fe12_if.val <= 1;
                out_cnt <= out_cnt + 1;
              end
            end
            SQ: begin
              o_mul_fe12_if.dat <= a0[out_cnt%6];
              if (b0_val) begin
                o_mul_fe12_if.val <= 1;
                out_cnt <= out_cnt + 1;
              end
            end
          endcase
        end
        default: begin
          out_cnt <= 0;
          bb_val <= 0;
          aa_val <= 0;
          b0_val <= 0;
          mnr_cnt <= 0;
          mul_cnt <= 0;
          add_cnt <= 0;
          sub_cnt <= 0;
          start <= 0;
          val_l <= 0;
        end
      endcase
    end
  end
end

// Task for fe6_mul
task fe6_mul(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b);
  if (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy)) begin
    o_mul_fe6_if.sop <= mul_cnt == 0 || mul_cnt == 6 || mul_cnt == 12;
    o_mul_fe6_if.eop <= mul_cnt == 5 || mul_cnt == 11 || mul_cnt == 17;
    o_mul_fe6_if.dat <= {b, a};
    o_mul_fe6_if.val <= val;
    if (mul_cnt == 0) o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
    if (mul_cnt == 6) o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 1;
    if (mul_cnt == 12) o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 2;
    if(val) mul_cnt <= mul_cnt + 1;
  end
endtask

// Task for fe6_add
task  fe6_add(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b);
  if (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy)) begin
    o_add_fe_if.sop <= add_cnt == 0 || add_cnt == 6 || add_cnt == 12;
    o_add_fe_if.eop <= add_cnt == 5 || add_cnt == 11 || add_cnt == 17;
    o_add_fe_if.dat <= {b, a};
    o_add_fe_if.val <= val;
    if (add_cnt == 0) o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
    if (add_cnt == 6) o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 1;
    if (add_cnt == 12) o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 2;
    if(val) add_cnt <= add_cnt + 1;
  end
endtask

// Task for fe6_sub
task fe6_sub(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b);
  if (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy)) begin
    o_sub_fe_if.sop <= sub_cnt == 0 || sub_cnt == 6;
    o_sub_fe_if.eop <= sub_cnt == 5 || sub_cnt == 11;
    o_sub_fe_if.dat <= {b, a};
    o_sub_fe_if.val <= val;
    if (sub_cnt == 0) o_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
    if (sub_cnt == 6) o_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 1;
    if(val) sub_cnt <= sub_cnt + 1;
  end
endtask

// Task for fe6_mnr
task fe6_mnr(input logic val, input logic [$bits(FE_TYPE)-1:0] a);
  if (~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy)) begin
    o_mnr_fe6_if.sop <= mnr_cnt == 0 || mnr_cnt == 6;
    o_mnr_fe6_if.eop <= mnr_cnt == 5 || mnr_cnt == 11;
    o_mnr_fe6_if.dat <= a;
    o_mnr_fe6_if.val <= val;
    if (mnr_cnt == 0) o_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 0;
    if (mnr_cnt == 6) o_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= 1;
    if(val) mnr_cnt <= mnr_cnt + 1;
  end
endtask


endmodule