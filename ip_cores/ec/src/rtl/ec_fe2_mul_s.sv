/*
  This provides the interface to perform Fp2 field element mul.

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

module ec_fe2_mul_s
#(
  parameter type FE_TYPE,                // Base field element type
  parameter      CTL_BITS    = 12
)(
  input i_clk, i_rst,
  // Interface to FE2_TYPE mul (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE_TYPE mul (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE_TYPE mul (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface to FE_TYPE mul (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if
);

FE_TYPE a, b; // Temp storage
logic [1:0] mul_cnt, add_sub_cnt;
logic out_cnt;

// Point addtions are simple additions on each of the Fp elements
always_comb begin
  i_mul_fe2_if.rdy = (mul_cnt == 0 || mul_cnt == 1) && (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy));
  i_mul_fe_if.rdy = (add_sub_cnt == 0 || add_sub_cnt == 1) ? ~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy) :
                     ~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy);
  i_add_fe_if.rdy = out_cnt == 1 && (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy));
  i_sub_fe_if.rdy = out_cnt == 0 && (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy));
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe2_if.reset_source();
    o_add_fe_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_sub_fe_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_mul_fe_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    a <= 0;
    b <= 0;
    mul_cnt <= 0;
    add_sub_cnt <= 0;
    out_cnt <= 0;
  end else begin

    if (o_add_fe_if.val && o_add_fe_if.rdy) o_add_fe_if.val <= 0;
    if (o_sub_fe_if.val && o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_mul_fe_if.val && o_mul_fe_if.rdy) o_mul_fe_if.val <= 0;
    if (o_mul_fe2_if.val && o_mul_fe2_if.rdy) o_mul_fe2_if.val <= 0;

    case(mul_cnt)
      0: begin
        if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
          o_mul_fe_if.dat <= i_mul_fe2_if.dat;  // a0 * b0
          o_mul_fe_if.val <= i_mul_fe2_if.val;
          o_mul_fe_if.ctl <= i_mul_fe2_if.ctl;
          {b, a} <= i_mul_fe2_if.dat;
          if (i_mul_fe2_if.val) mul_cnt <= mul_cnt + 1;
        end
      end
      1: begin
        if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
          o_mul_fe_if.dat <= i_mul_fe2_if.dat;  // a1 * b1
          o_mul_fe_if.val <= i_mul_fe2_if.val;
          if (i_mul_fe2_if.val) mul_cnt <= mul_cnt + 1;
        end
      end
      2: begin
        if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
          o_mul_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= b; // a1 * b0
          o_mul_fe_if.val <= 1;
          mul_cnt <= mul_cnt + 1;
          b <= o_mul_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)];
        end
      end
      3: begin
        if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
          o_mul_fe_if.dat <= {a, b};  // b1 * a0
          o_mul_fe_if.val <= 1;
          mul_cnt <= 0;
        end
      end
    endcase


    case(add_sub_cnt)
      0: begin
        if (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy)) begin
          o_sub_fe_if.dat[0 +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
          if (i_mul_fe_if.val) add_sub_cnt <= add_sub_cnt + 1;
        end
      end
      1: begin
        o_sub_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
        o_sub_fe_if.ctl <= i_mul_fe_if.ctl; // a0b0 - a1b1
        if (i_mul_fe_if.val) begin
          o_sub_fe_if.val <= 1;
          add_sub_cnt <= add_sub_cnt + 1;
        end
      end
      2: begin
        if (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy)) begin
          o_add_fe_if.dat[0 +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
          if (i_mul_fe_if.val) add_sub_cnt <= add_sub_cnt + 1;
        end
      end
      3: begin
        o_add_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
        o_add_fe_if.ctl <= i_mul_fe_if.ctl; // a1b0 + a0b1
        if (i_mul_fe_if.val) begin
          o_add_fe_if.val <= 1;
          add_sub_cnt <= add_sub_cnt + 1;
        end
      end
    endcase

    case(out_cnt)
      0: begin
        if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
          o_mul_fe2_if.dat <= i_sub_fe_if.dat;
          o_mul_fe2_if.sop <= 1;
          o_mul_fe2_if.eop <= 0;
          o_mul_fe2_if.ctl <= i_sub_fe_if.ctl;
          o_mul_fe2_if.val <= i_sub_fe_if.val;
          if (i_sub_fe_if.val) out_cnt <= out_cnt + 1;
        end
      end
      1: begin
        if (~o_mul_fe2_if.val || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
          o_mul_fe2_if.dat <= i_add_fe_if.dat;
          o_mul_fe2_if.sop <= 0;
          o_mul_fe2_if.eop <= 1;
          o_mul_fe2_if.ctl <= i_add_fe_if.ctl;
          o_mul_fe2_if.val <= i_add_fe_if.val;
          if (i_add_fe_if.val) out_cnt <= out_cnt + 1;
        end
      end
    endcase

  end
end
endmodule