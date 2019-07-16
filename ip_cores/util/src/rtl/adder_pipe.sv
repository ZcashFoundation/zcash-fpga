/*
  Adder which is pipelined over multiple stages and does moudlo reduction if needed.

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

module adder_pipe # (
  parameter  P = bls12_381_pkg::P,
  parameter  BITS = $clog2(P),
  parameter  CTL_BITS = 8,
  parameter  LEVEL = 1     // If LEVEL == 1 this is just an add with registered output
) (
  input                i_clk,
  input                i_rst,
  if_axi_stream.sink   i_add,
  if_axi_stream.source o_add
);

// Internally we want to use a even divisor for BITS of BITS/LEVEL
localparam DAT_BITS = BITS + (BITS % LEVEL);
localparam BITS_LEVEL = DAT_BITS/LEVEL;

logic [DAT_BITS-1:0] P_;

logic [LEVEL:0][DAT_BITS:0] result0, result1;
logic [LEVEL:0][DAT_BITS:0] a, b;
logic [LEVEL:0][CTL_BITS-1:0] ctl;   // Top ctl bit we use to check if this needs a subtraction in P
logic [LEVEL:0] val, rdy;
logic [LEVEL:0] carry_neg;


always_comb begin
  P_ = 0;
  P_ = P;
  carry_neg[0] = 0;
  val[0] = i_add.val;
  ctl[0] = i_add.ctl;
  a[0] = 0;
  a[0] = i_add.dat[0 +: BITS];
  b[0] = 0;
  b[0] = i_add.dat[BITS +: BITS];
  result0[0] = 0;
  result1[0] = 0;
  rdy[LEVEL] = o_add.rdy;
  i_add.rdy = rdy[0];
  o_add.copy_if_comb(carry_neg[LEVEL] ? result0[LEVEL] : result1[LEVEL], val[LEVEL], 1, 1, 0, 0, ctl[LEVEL]);
end

generate
genvar g;
  for (g = 0; g < LEVEL; g++) begin: ADDER_GEN

    logic [BITS_LEVEL:0] add_res0, add_res0_, add_res1;
    logic cn;

    always_comb begin
      rdy[g] = ~val[g+1] || (val[g+1] && rdy[g+1]);
      add_res0 = a[g][g*BITS_LEVEL +: BITS_LEVEL] +
                 b[g][g*BITS_LEVEL +: BITS_LEVEL] +
                 result0[g][g*BITS_LEVEL];

      add_res0_ = a[g][g*BITS_LEVEL +: BITS_LEVEL] +
                  b[g][g*BITS_LEVEL +: BITS_LEVEL] +
                  result1[g][g*BITS_LEVEL];

      if (add_res0_ < (P_[g*BITS_LEVEL +: BITS_LEVEL] + carry_neg[g])) begin
        cn = 1;
        add_res1 = add_res0_ - P_[g*BITS_LEVEL +: BITS_LEVEL] + (1 << BITS_LEVEL) - carry_neg[g];
      end else begin
        cn = 0;
        add_res1 = add_res0_ - P_[g*BITS_LEVEL +: BITS_LEVEL] - carry_neg[g];
      end
    end

    always_ff @ (posedge i_clk) begin
      if (i_rst) begin
        val[g+1] <= 0;
        result0[g+1] <= 0;
        result1[g+1] <= 0;
        a[g+1] <= 0;
        b[g+1] <= 0;
        ctl[g+1] <= 0;
        carry_neg[g+1] <= 0;
      end else begin
        if (rdy[g]) begin
          val[g+1] <= val[g];
          ctl[g+1] <= ctl[g];
          a[g+1] <= a[g];
          b[g+1] <= b[g];

          result0[g+1] <= result0[g];
          result0[g+1][g*BITS_LEVEL +: BITS_LEVEL + 1] <= add_res0;

          result1[g+1] <= result1[g];
          result1[g+1][g*BITS_LEVEL +: BITS_LEVEL + 1] <= add_res1;

          carry_neg[g+1] <= cn;
        end
      end
    end
  end
endgenerate
endmodule