/*
  This does the for Frobenius map calculation required in final
  exponentiation in the ate pairing on a Fp^2 element.

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

module bls12_381_fe2_fmap
  import bls12_381_pkg::*;
#(
  parameter type FE_TYPE     = fe_t,     // Base field element type
  parameter      OVR_WRT_BIT = 0,        // Need 1 bit for control
  parameter      CTL_BIT_POW = 8         // This is where we encode the power value with 2 bits - only 0,1,2,3 are supported
)(
  input i_clk, i_rst,
  // Input/Output intefaces for fmap result, FE_TYPE data width
  if_axi_stream.source o_fmap_fe2_if,
  if_axi_stream.sink   i_fmap_fe2_if,
  // Interface to FE_TYPE mul (mod P), 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if
);

localparam NUM_OVR_WRT_BIT = 1;

FE_TYPE [1:0] t;

logic [1:0] eq_val, eq_wait;
logic mul_cnt;
logic out_cnt;
logic mul_en;
logic nxt_mul;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe_if.reset_source();
    o_fmap_fe2_if.reset_source();

    i_mul_fe_if.rdy <= 0;
    i_fmap_fe2_if.rdy <= 0;
    
    eq_val <= 0;
    eq_wait <= 0;
    t <= 0;
    {mul_cnt, out_cnt} <= 0;
    {nxt_mul} <= 0;
    {mul_en} <= 0;
  end else begin

    i_mul_fe_if.rdy <= 1;

    if (o_mul_fe_if.rdy) o_mul_fe_if.val <= 0;
    if (o_fmap_fe2_if.rdy) o_fmap_fe2_if.val <= 0;

    if (~mul_en) get_next_mul();

    if (|eq_wait == 0) i_fmap_fe2_if.rdy <= 1;

    if (~o_fmap_fe2_if.val || (o_fmap_fe2_if.val && o_fmap_fe2_if.rdy)) begin

      o_fmap_fe2_if.sop <= out_cnt == 0;
      o_fmap_fe2_if.eop <= out_cnt == 1;

      case (out_cnt) inside
        0: o_fmap_fe2_if.dat <= t[0];
        1: o_fmap_fe2_if.dat <= t[1];
      endcase
      
      if (eq_val[0] && eq_val[1]) begin
        o_fmap_fe2_if.val <= 1;
        out_cnt <= out_cnt + 1;
      end

      if (out_cnt == 1) begin
        eq_val <= 0;
        eq_wait <= 0;
        t <= 0;
       {mul_cnt, out_cnt} <= 0;
       {nxt_mul} <= 0;
       {mul_en} <= 0;
      end
    end

    // Latch input
    if (i_fmap_fe2_if.rdy && i_fmap_fe2_if.val) begin
      t <= {i_fmap_fe2_if.dat, t[1]};
      if (i_fmap_fe2_if.eop) begin
        i_fmap_fe2_if.rdy <= 0;
        eq_val[0] <= 1;
        eq_wait[0] <= 1;
        o_fmap_fe2_if.ctl <= i_fmap_fe2_if.ctl;
      end
    end

    // Check any results from multiplier
    if (i_mul_fe_if.val && i_mul_fe_if.rdy) begin
      if (i_mul_fe_if.eop) eq_val[i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        1: t[1] <= i_mul_fe_if.dat;
        default: o_fmap_fe2_if.err <= 1;
      endcase
    end

    // Issue new multiplies
    if (mul_en)
      case(nxt_mul)
        1: fe_multiply(1, t[1], FROBENIUS_COEFF_FQ2_C1[o_fmap_fe2_if.ctl[CTL_BIT_POW +: 1]]);
      endcase

  end
end


// Task for using mult
task fe_multiply(input int unsigned ctl, input FE_TYPE a, b);
  if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
    o_mul_fe_if.val <= 1;
    o_mul_fe_if.sop <= 1;
    o_mul_fe_if.eop <= 1;
    o_mul_fe_if.dat[0 +: $bits(FE_TYPE)] <= a;
    o_mul_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b;
    o_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
    mul_en <= 0;
  end
endtask


task get_next_mul();
  mul_en <= 1;
  if(~eq_wait[1] && eq_val[0])
    nxt_mul <= 1;
  else
    mul_en <= 0;
endtask

endmodule