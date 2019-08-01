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
  parameter type FE_TYPE = fe_t,         // Base field element type
  parameter      CTL_BITS    = 12,
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


always_comb begin
  i_fmap_fe2_if.rdy = ~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy);
  i_mul_fe_if.rdy = ~o_fmap_fe2_if.val || (o_fmap_fe2_if.val && o_fmap_fe2_if.rdy);
end

logic mul_cnt;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_fmap_fe2_if.reset_source();
    o_mul_fe_if.reset_source();
    mul_cnt <= 0;
  end else begin

    if (o_mul_fe_if.val && o_mul_fe_if.rdy) o_mul_fe_if.val <= 0;
    if (o_fmap_fe2_if.val && o_fmap_fe2_if.rdy) o_fmap_fe2_if.val <= 0;

    if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
      case(mul_cnt) 
        0: begin
          o_mul_fe_if.dat[0 +: $bits(FE_TYPE)] <= i_fmap_fe2_if.dat;
          o_mul_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= 1;
        end
        1: begin
          o_mul_fe_if.dat <= {i_fmap_fe2_if.dat, FROBENIUS_COEFF_FQ2_C1[i_fmap_fe2_if.ctl[CTL_BIT_POW +: 2]]};
        end
      endcase
      o_mul_fe_if.val <= i_fmap_fe2_if.val;
      o_mul_fe_if.ctl <= i_fmap_fe2_if.ctl;
      o_mul_fe_if.sop <= 1;
      o_mul_fe_if.eop <= 1;
      mul_cnt <= i_fmap_fe2_if.val ? mul_cnt + 1 : mul_cnt;
    end

    if (~o_fmap_fe2_if.val || (o_fmap_fe2_if.val && o_fmap_fe2_if.rdy)) begin
      o_fmap_fe2_if.val <= i_mul_fe_if.val;
      o_fmap_fe2_if.eop <= i_mul_fe_if.val ? o_fmap_fe2_if.sop : o_fmap_fe2_if.eop;
      o_fmap_fe2_if.sop <= i_mul_fe_if.val ? ~o_fmap_fe2_if.sop : o_fmap_fe2_if.sop;
      o_fmap_fe2_if.dat <= i_mul_fe_if.dat;
      o_fmap_fe2_if.ctl <= i_mul_fe_if.ctl;
    end
  end
end

endmodule