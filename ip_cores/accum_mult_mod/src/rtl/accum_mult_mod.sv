/*
  This does a BITS multiplication using adder tree and parameterizable
  DSP sizes. A python script generates the accum_gen.sv file.

  Does modulus reduction using RAM tables. Multiplication and reduction has
  latency of 5 clock cycles and a throughput of 1 clock cycle per result.

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

module accum_mult_mod #(
  parameter DAT_BITS,
  parameter MODULUS,
  parameter CTL_BITS,
  parameter A_DSP_W,
  parameter B_DSP_W,
  parameter GRID_BIT,
  parameter RAM_A_W,
  parameter RAM_D_W
)(
  input i_clk,
  input i_rst,
  if_axi_stream.sink   i_mul,
  if_axi_stream.source o_mul,
  input [RAM_D_W-1:0] i_ram_d,
  input               i_ram_we,
  input               i_ram_se
);

localparam int TOT_DSP_W = A_DSP_W+B_DSP_W;
localparam int NUM_COL = (DAT_BITS+A_DSP_W-1)/A_DSP_W;
localparam int NUM_ROW = (DAT_BITS+B_DSP_W-1)/B_DSP_W;
localparam int MAX_COEF = (2*DAT_BITS+GRID_BIT-1)/GRID_BIT;
localparam int PIPE = 9;

logic [A_DSP_W*NUM_COL-1:0]             dat_a;
logic [B_DSP_W*NUM_ROW-1:0]             dat_b;
(* DONT_TOUCH = "yes" *) logic [A_DSP_W+B_DSP_W-1:0] mul_grid [NUM_COL][NUM_ROW];
logic [2*DAT_BITS:0] res0_c, res0_r, res0_rr;
logic [DAT_BITS:0]   res1_c, res1_m_c, res1_m_c_;

// Most of the code is generated
`include "accum_mult_mod_generated.inc"

logic [PIPE-1:0] val, sop, eop;
logic [PIPE-1:0][CTL_BITS-1:0] ctl;

genvar gx, gy;

// Flow control
always_comb begin
  i_mul.rdy = o_mul.rdy;
  o_mul.val = val[PIPE-1];
  o_mul.sop = sop[PIPE-1];
  o_mul.eop = eop[PIPE-1];
  o_mul.ctl = ctl[PIPE-1];
  o_mul.err = 0;
  o_mul.mod = 0;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    val <= 0;
    sop <= 0;
    eop <= 0;
    ctl <= 0;
  end else begin
    if (o_mul.rdy) begin
      val <= {val, i_mul.val};
      sop <= {sop, i_mul.sop};
      eop <= {eop, i_mul.eop};
      ctl <= {ctl, i_mul.ctl};
    end
  end
end

// Logic for handling multiple pipelines
always_ff @ (posedge i_clk) begin
  if (o_mul.rdy) begin
    for (int i = 0; i < NUM_COL; i++)
      dat_a <= 0;
      dat_b <= 0;
      dat_a <= i_mul.dat[0+:DAT_BITS];
      dat_b <= i_mul.dat[DAT_BITS+:DAT_BITS];
  end
end


always_ff @ (posedge i_clk) begin
  for (int i = 0; i < NUM_COL; i++)
    for (int j = 0; j < NUM_ROW; j++) begin
      if (o_mul.rdy)
        mul_grid[i][j] <= dat_a[i*A_DSP_W +: A_DSP_W] * dat_b[j*B_DSP_W +: B_DSP_W];
    end
end

// Register lower half accumulator output while we lookup BRAM
always_ff @ (posedge i_clk)
  for (int i = 0; i < MAX_COEF/2; i++) begin
    if (o_mul.rdy) begin
      accum_grid_o_r[i] <= accum_grid_o[i];
      accum_grid_o_rr[i] <= accum_grid_o_r[i];
    end
  end

// Two paths to make sure we are < MODULUS
always_comb begin
  res0_c = 0;
  for (int i = 0; i < MAX_COEF/2; i++)
      res0_c += accum2_grid_o[i] << (i*GRID_BIT);
end

// We do a second level reduction to get back within MODULUS bits

always_ff @ (posedge i_clk) begin
  if (o_mul.rdy) begin
    res0_r <= res0_c;
    res0_rr <= res0_r;
    // Do final adjustment
    o_mul.dat <= res1_m_c_ < res1_c ? res1_m_c_ : res1_c < res1_m_c ? res1_c : res1_m_c;
  end
end

endmodule