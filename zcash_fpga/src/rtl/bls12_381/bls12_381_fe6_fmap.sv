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

module bls12_381_fe6_fmap
  import bls12_381_pkg::*;
#(
  parameter type FE_TYPE     = fe_t,     // Base field element type
  parameter      CTL_BITS    = 12,
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

logic [2:0] out_cnt, out_cnt1;

always_comb begin
  i_fmap_fe6_if.rdy = ~o_fmap_fe2_if.val || (o_fmap_fe2_if.val && o_fmap_fe2_if.rdy);
  i_fmap_fe2_if.rdy = ~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy);
  i_mul_fe2_if.rdy = ~o_fmap_fe6_if.val || (o_fmap_fe6_if.val && o_fmap_fe6_if.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_fmap_fe6_if.reset_source();
    o_fmap_fe2_if.reset_source();
    o_mul_fe2_if.reset_source();
    out_cnt <= 0;
    out_cnt1 <= 0;
  end else begin

    if (o_fmap_fe6_if.val && o_fmap_fe6_if.rdy) o_fmap_fe6_if.val <= 0;
    if (o_fmap_fe2_if.val && o_fmap_fe2_if.rdy) o_fmap_fe2_if.val <= 0;
    if (o_mul_fe2_if.val && o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;

    if (~o_fmap_fe2_if.val || (o_fmap_fe2_if.val && o_fmap_fe2_if.rdy)) begin
      o_fmap_fe2_if.val <= i_fmap_fe6_if.val;
      o_fmap_fe2_if.dat <= i_fmap_fe6_if.dat;
      o_fmap_fe2_if.sop <= i_fmap_fe6_if.val ? ~o_fmap_fe2_if.sop : o_fmap_fe2_if.sop;
      o_fmap_fe2_if.eop <= i_fmap_fe6_if.val ? o_fmap_fe2_if.sop : o_fmap_fe2_if.eop;
      o_fmap_fe2_if.ctl <= i_fmap_fe6_if.ctl;
    end

    if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
      o_mul_fe2_if.val <= i_fmap_fe2_if.val;
      o_mul_fe2_if.sop <= out_cnt % 2 == 0;
      o_mul_fe2_if.eop <= out_cnt % 2 == 1;
      o_mul_fe2_if.ctl <= i_fmap_fe2_if.ctl;
      case (out_cnt) inside
        0,1: begin
          o_mul_fe2_if.dat[0 +: $bits(FE_TYPE)] <= i_fmap_fe2_if.dat;
          o_mul_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= out_cnt == 0 ? 1 : 0;
        end
        2,3: o_mul_fe2_if.dat <= {FROBENIUS_COEFF_FQ6_C1[i_fmap_fe2_if.ctl[CTL_BIT_POW +: 2]][out_cnt % 2], i_fmap_fe2_if.dat};
        4,5: o_mul_fe2_if.dat <= {FROBENIUS_COEFF_FQ6_C2[i_fmap_fe2_if.ctl[CTL_BIT_POW +: 2]][out_cnt % 2], i_fmap_fe2_if.dat};
      endcase
      out_cnt <= i_fmap_fe2_if.val ? out_cnt == 5 ? 0 : out_cnt + 1 : out_cnt;
    end


    if (~o_fmap_fe6_if.val || (o_fmap_fe6_if.val && o_fmap_fe6_if.rdy)) begin
      o_fmap_fe6_if.val <= i_mul_fe2_if.val;
      o_fmap_fe6_if.sop <= out_cnt1 == 0;
      o_fmap_fe6_if.eop <= out_cnt1 == 5;
      o_fmap_fe6_if.ctl <= i_mul_fe2_if.ctl;
      o_fmap_fe6_if.dat <= i_mul_fe2_if.dat;
      out_cnt1 <= i_mul_fe2_if.val ? out_cnt1 == 5 ? 0 : out_cnt1 + 1 : out_cnt1;
    end
  end
end

endmodule