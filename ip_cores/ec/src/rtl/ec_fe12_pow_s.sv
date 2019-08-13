/*
  This takes an fe12 element and raises it to a power using the multiply and
  square algorithm.

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

module ec_fe12_pow_s
#(
  parameter type FE_TYPE,          // Base field element type
  parameter      POW_BITS,         // Number of bits for the power value (in .ctl of input)
  parameter      CTL_BIT_POW,      // Where does the power config bit start
  parameter      SQ_BIT            // This bit is set when we are doing a square
)(
  input i_clk, i_rst,
  // Interface to FE_TYPE12 mul (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe12_if,
  if_axi_stream.sink   i_mul_fe12_if,
  // Interface to FE_TYPE sub (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if,
  // Interface to FE_TYPE mul (mod P) FE_TYPE data width
  if_axi_stream.source o_pow_fe12_if,
  if_axi_stream.sink   i_pow_fe12_if  // Power is stored in .ctl
);

FE_TYPE [11:0] a;
FE_TYPE [11:0] res;
logic [3:0] cnt;
logic [POW_BITS-1:0] pow;
enum {IDLE, POW_MUL, POW_SQ, SUB, OUTPUT} state;

always_comb begin
  i_pow_fe12_if.rdy = state == IDLE;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe12_if.reset_source();
    o_sub_fe_if.reset_source();
    o_pow_fe12_if.reset_source();
    a <= 0;
    res <= 0;
    cnt <= 0;
    state <= IDLE;
    pow <= 0;
  end else begin

    i_sub_fe_if.rdy <= 0;
    i_mul_fe12_if.rdy <= 0;

    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_mul_fe12_if.rdy) o_mul_fe12_if.val <= 0;
    if (o_pow_fe12_if.rdy) o_pow_fe12_if.val <= 0;


    case (state)
      IDLE: begin
        cnt <= 0;
        res <= 0;
        res[0][0] <= 1;
        if (i_pow_fe12_if.val && i_pow_fe12_if.rdy) begin
          if (i_pow_fe12_if.eop) begin
            state <= pow[0] ? POW_MUL : POW_SQ;
            pow <= pow >> 1;
          end
          if (i_pow_fe12_if.sop) begin
            o_pow_fe12_if.ctl <= i_pow_fe12_if.ctl;
            pow <= i_pow_fe12_if.ctl[CTL_BIT_POW +: POW_BITS];
          end
          a <= {i_pow_fe12_if.dat, a[11:1]};
        end
      end
      POW_MUL: begin
        if (cnt < 12) begin
          if (~o_mul_fe12_if.val || (o_mul_fe12_if.val && o_mul_fe12_if.rdy)) begin
            cnt <= cnt + 1;
            o_mul_fe12_if.ctl[SQ_BIT] <= 0;
            o_mul_fe12_if.sop <= cnt == 0;
            o_mul_fe12_if.eop <= cnt == 11;
            o_mul_fe12_if.dat <= {a[cnt], res[cnt]};
            o_mul_fe12_if.val <= 1;
          end
        end else begin
          // Waiting for result
          i_mul_fe12_if.rdy <= 1;
          if (i_mul_fe12_if.val && i_mul_fe12_if.rdy) begin
            res <= {i_mul_fe12_if.dat, res[11:1]};
            if (i_mul_fe12_if.eop) begin
              state <= (pow == 0) ? SUB : POW_SQ;
              cnt <= 0;
            end
          end
        end
      end
      POW_SQ: begin
        if (cnt < 12) begin
          if (~o_mul_fe12_if.val || (o_mul_fe12_if.val && o_mul_fe12_if.rdy)) begin
            cnt <= cnt + 1;
            o_mul_fe12_if.ctl[SQ_BIT] <= 1;
            o_mul_fe12_if.sop <= cnt == 0;
            o_mul_fe12_if.eop <= cnt == 11;
            o_mul_fe12_if.dat <= {a[cnt], a[cnt]};
            o_mul_fe12_if.val <= 1;
          end
        end else begin
          // Waiting for result
          i_mul_fe12_if.rdy <= 1;
          if (i_mul_fe12_if.val && i_mul_fe12_if.rdy) begin
            a <= {i_mul_fe12_if.dat, a[11:1]};
            if (i_mul_fe12_if.eop) begin
              pow <= pow >> 1;
              state <= pow[0] ? POW_MUL : POW_SQ;
              cnt <= 0;
            end
          end
        end
      end
      SUB: begin
        if (cnt < 6) begin
          if (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy)) begin
            cnt <= cnt + 1;
            o_sub_fe_if.ctl[SQ_BIT] <= 1;
            o_sub_fe_if.sop <= cnt == 0;
            o_sub_fe_if.eop <= cnt == 5;
            o_sub_fe_if.dat[0 +: $bits(FE_TYPE)] <= 0;
            o_sub_fe_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= res[cnt+6]; // Only top Fe6
            o_sub_fe_if.val <= 1;
          end
        end else begin
          // Waiting for result
          i_sub_fe_if.rdy <= 1;
          if (i_sub_fe_if.val && i_sub_fe_if.rdy) begin
            res[11:6] <= {i_sub_fe_if.dat, res[11:7]};
            if (i_sub_fe_if.eop) begin
              i_sub_fe_if.rdy <= 0;
              cnt <= 0;
              state <= OUTPUT;
            end
          end
        end
      end
      OUTPUT: begin
        if (~o_pow_fe12_if.val || (o_pow_fe12_if.val && o_pow_fe12_if.rdy)) begin
          o_pow_fe12_if.sop <= cnt == 0;
          o_pow_fe12_if.eop <= cnt == 11;
          o_pow_fe12_if.val <= 1;
          o_pow_fe12_if.dat <= res[0];
          res <= {i_sub_fe_if.dat, res[11:1]};
          cnt <= cnt + 1;
          if (cnt == 11) state <= IDLE;
        end
      end
    endcase

  end
end
endmodule