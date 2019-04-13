/*
  The BLAKE2b g function.
  
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


module blake2b_g
#(
  parameter PIPELINES = 1 // Do we want to optionally add pipeline stages
)
(
  input               i_clk,
  input        [63:0] i_a, i_b, i_c, i_d, i_m0, i_m1,
  input               i_rdy,
  output logic [63:0] o_a, o_b, o_c, o_d
);

logic [63:0] a0, b0, c0, d0, a1, b1, c1, d1, b2, d2, b3, d3;
logic [PIPELINES:0][64*4-1:0] pipeline;

// Logic used to implement G function
always_comb begin
  a0 = i_a + i_b + i_m0;
  d0 = i_d ^ a0;
  d1 = {d0[0 +: 32], d0[32 +: 32]};
  c0 = i_c + d1;
  b0 = i_b ^ c0;
  b1 = {b0[0 +: 24], b0[24 +: 40]};
  a1 = a0 + b1 + i_m1;
  d2 = d1 ^ a1;
  d3 = {d2[0 +: 16], d2[16 +: 48]};
  c1 = c0 + d3;
  b2 = b1 ^ c1;
  b3 = {b2[0 +: 63], b2[63]};
end

// Final output assignment
always_comb begin
  o_a = pipeline[PIPELINES][0*64 +: 64];
  o_b = pipeline[PIPELINES][1*64 +: 64];
  o_c = pipeline[PIPELINES][2*64 +: 64];
  o_d = pipeline[PIPELINES][3*64 +: 64];
end

// Optional pipelines
generate begin: PIPE_GEN
  genvar gv_p;
  always_comb begin
    pipeline[0][0*64 +: 64] = a1;
    pipeline[0][1*64 +: 64] = b3;
    pipeline[0][2*64 +: 64] = c1;
    pipeline[0][3*64 +: 64] = d3;
  end
  for (gv_p = 0; gv_p < PIPELINES; gv_p++) begin: PIPE_LOOP_GEN
    always_ff @ (posedge i_clk) begin
      if (i_rdy) begin
        pipeline[gv_p + 1][0*64 +: 64] <= pipeline[gv_p][0*64 +: 64];
        pipeline[gv_p + 1][1*64 +: 64] <= pipeline[gv_p][1*64 +: 64];
        pipeline[gv_p + 1][2*64 +: 64] <= pipeline[gv_p][2*64 +: 64];
        pipeline[gv_p + 1][3*64 +: 64] <= pipeline[gv_p][3*64 +: 64];
      end
    end
  end
end
endgenerate

endmodule