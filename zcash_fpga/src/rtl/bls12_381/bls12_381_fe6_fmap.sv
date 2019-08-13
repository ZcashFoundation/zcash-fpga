/*
  This does the for Frobenius map calculation required in final
  exponentiation in the ate pairing on a Fp^6 element.

  Input is expected to be streamed in with Fp .c0 in the first clock cycle

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

module bls12_381_fe6_fmap
  import bls12_381_pkg::*;
#(
  parameter type FE_TYPE     = fe_t,     // Base field element type
  parameter      OVR_WRT_BIT = 0,        // Need 2 bits for control
  parameter      CTL_BIT_POW = 8         // This is where we encode the power value with 2 bits - only 0,1,2,3 are supported
)(
  input i_clk, i_rst,
  // Input/Output intefaces for fmap result, FE_TYPE data width
  if_axi_stream.source o_fmap_fe6_if,
  if_axi_stream.sink   i_fmap_fe6_if,
  // Interface to FE2_TYPE fmap block, FE_TYPE data width
  if_axi_stream.source o_fmap_fe2_if,
  if_axi_stream.sink   i_fmap_fe2_if,
  // Interface to FE_TYPE mul (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if
);

localparam NUM_OVR_WRT_BIT = 3;

FE_TYPE [2:0][1:0] t;

logic [5:0] eq_val, eq_wait;
logic mul_cnt, fmap_cnt;
logic [2:0] out_cnt;
logic mul_en, fmap_en;
logic [2:0] nxt_mul, nxt_fmap;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe2_if.reset_source();
    o_fmap_fe6_if.reset_source();
    o_fmap_fe2_if.reset_source();

    i_mul_fe2_if.rdy <= 0;
    i_fmap_fe6_if.rdy <= 0;
    i_fmap_fe2_if.rdy <= 0;
    
    eq_val <= 0;
    eq_wait <= 0;
    t <= 0;
    {mul_cnt, fmap_cnt, out_cnt} <= 0;
    {nxt_mul, nxt_fmap} <= 0;
    {mul_en, fmap_en} <= 0;
  end else begin

    i_mul_fe2_if.rdy <= 1;
    i_fmap_fe2_if.rdy <= 1;

    if (o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;
    if (o_fmap_fe6_if.rdy) o_fmap_fe6_if.val <= 0;
    if (o_fmap_fe2_if.rdy) o_fmap_fe2_if.val <= 0;

    if (~mul_en) get_next_mul();
    if (~fmap_en) get_next_fmap();

    if (|eq_wait == 0) i_fmap_fe6_if.rdy <= 1;

    if (~o_fmap_fe6_if.val || (o_fmap_fe6_if.val && o_fmap_fe6_if.rdy)) begin

      o_fmap_fe6_if.sop <= out_cnt == 0;
      o_fmap_fe6_if.eop <= out_cnt == 5;

      case (out_cnt) inside
        0,1: o_fmap_fe6_if.dat <= t[0][out_cnt%2];
        2,3: o_fmap_fe6_if.dat <= t[1][out_cnt%2];
        4,5: o_fmap_fe6_if.dat <= t[2][out_cnt%2];
      endcase
      
      if (eq_val[1] && eq_val[4] && eq_val[5]) begin
        o_fmap_fe6_if.val <= 1;
        out_cnt <= out_cnt + 1;
      end

      if (out_cnt == 5) begin
        eq_val <= 0;
        eq_wait <= 0;
        t <= 0;
       {mul_cnt, fmap_cnt, out_cnt} <= 0;
       {nxt_mul, nxt_fmap} <= 0;
       {mul_en, fmap_en} <= 0;
      end
    end

    // Latch input
    if (i_fmap_fe6_if.rdy && i_fmap_fe6_if.val) begin
      t <= {i_fmap_fe6_if.dat, t[2:1], t[0][1]};
      if (i_fmap_fe6_if.eop) begin
        i_fmap_fe6_if.rdy <= 0;
        eq_val[0] <= 1;
        eq_wait[0] <= 1;
        o_fmap_fe6_if.ctl <= i_fmap_fe6_if.ctl;
      end
    end

    // Check any results from multiplier
    if (i_mul_fe2_if.val && i_mul_fe2_if.rdy) begin
      if (i_mul_fe2_if.eop) eq_val[i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        4: t[1] <= {i_mul_fe2_if.dat, t[1][1]};
        5: t[2] <= {i_mul_fe2_if.dat, t[2][1]};
        default: o_fmap_fe6_if.err <= 1;
      endcase
    end

    // Check any results from fmap
    if (i_fmap_fe2_if.val && i_fmap_fe2_if.rdy) begin
      if(i_fmap_fe2_if.eop) eq_val[i_fmap_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_fmap_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        1: t[0] <= {i_fmap_fe2_if.dat, t[0][1]};
        2: t[1] <= {i_fmap_fe2_if.dat, t[1][1]};
        3: t[2] <= {i_fmap_fe2_if.dat, t[2][1]};
        default: o_fmap_fe6_if.err <= 1;
      endcase
    end

    // Issue new multiplies
    if (mul_en)
      case(nxt_mul)
        4: fe2_multiply(4, t[1], FROBENIUS_COEFF_FQ6_C1[o_fmap_fe6_if.ctl[CTL_BIT_POW +: 2]]);
        5: fe2_multiply(5, t[2], FROBENIUS_COEFF_FQ6_C2[o_fmap_fe6_if.ctl[CTL_BIT_POW +: 2]]);
      endcase

    // Issue new fmap
    if (fmap_en)
      case(nxt_fmap)
        1: fe2_fmap_task(1, t[0], o_fmap_fe6_if.ctl[CTL_BIT_POW +: 2]);
        2: fe2_fmap_task(2, t[1], o_fmap_fe6_if.ctl[CTL_BIT_POW +: 2]);
        3: fe2_fmap_task(3, t[2], o_fmap_fe6_if.ctl[CTL_BIT_POW +: 2]);
      endcase

  end
end


// Task for using mult
task fe2_multiply(input int unsigned ctl, input FE_TYPE [1:0] a, b);
  if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
    o_mul_fe2_if.val <= 1;
    o_mul_fe2_if.sop <= mul_cnt == 0;
    o_mul_fe2_if.eop <= mul_cnt == 1;
    o_mul_fe2_if.dat[0 +: $bits(FE_TYPE)] <= a[mul_cnt];
    o_mul_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b[mul_cnt];
    o_mul_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    mul_cnt <= mul_cnt + 1;
    if (mul_cnt == 1) begin
      mul_cnt <= 0;
      get_next_mul();
    end
  end
endtask

// Task for using fmap
task fe2_fmap_task(input int unsigned ctl, input FE_TYPE [1:0] a, input int unsigned pow);
  if (~o_fmap_fe2_if.val || (o_fmap_fe2_if.val && o_fmap_fe2_if.rdy)) begin
    o_fmap_fe2_if.val <= 1;
    o_fmap_fe2_if.sop <= fmap_cnt == 0;
    o_fmap_fe2_if.eop <= fmap_cnt == 1;
    o_fmap_fe2_if.dat <= a[fmap_cnt];
    o_fmap_fe2_if.ctl[CTL_BIT_POW +: 1] <= pow;
    o_fmap_fe2_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    fmap_cnt <= fmap_cnt + 1;
    if (fmap_cnt == 1) begin
      fmap_cnt <= 0;
      get_next_fmap();
    end
  end
endtask

task get_next_mul();
  mul_en <= 1;
  if(~eq_wait[4] && eq_val[2])
    nxt_mul <= 4;
  else if(~eq_wait[5] && eq_val[3])
    nxt_mul <= 5;
  else
    mul_en <= 0;
endtask

task get_next_fmap();
  fmap_en <= 1;
  if(~eq_wait[1] && eq_val[0])
    nxt_fmap <= 1;
  else if(~eq_wait[2] && eq_val[0])
    nxt_fmap <= 2;   
  else if(~eq_wait[3] && eq_val[0])
    nxt_fmap <= 3;      
  else
    fmap_en <= 0;
endtask

endmodule
