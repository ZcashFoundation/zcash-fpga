/*
  Accumulating multiplier. Inputs can be of different bit size and the
  level each is accumulated over can be different.
  
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

module accum_mult # (
  parameter BITS_A = 256,
  parameter BITS_B = BITS_A,
  parameter LEVEL_A = 1,
  parameter LEVEL_B = LEVEL_A,
  parameter ADD_PIPELINE = 0
) (
  input                            i_clk,
  input                            i_rst,
  input [BITS_A-1:0]               i_dat_a,
  input [BITS_B-1:0]               i_dat_b,
  input                            i_val,
  output logic                     o_rdy,
  output logic [BITS_A+BITS_B-1:0] o_dat,
  output logic                     o_val,
  input                            i_rdy
);
  
localparam BITS_A_LVL = BITS_A/LEVEL_A;
localparam BITS_B_LVL = BITS_B/LEVEL_B;

logic [$clog2(LEVEL_A)-1:0] level_a, level_a_;
logic [$clog2(LEVEL_B)-1:0] level_b, level_b_;
logic [BITS_A-1:0]          dat_a;
logic [BITS_B-1:0]          dat_b;
logic [BITS_A_LVL-1:0]      dat_a_;
logic [BITS_B_LVL-1:0]      dat_b_;

logic c;

logic [BITS_A_LVL + BITS_B_LVL - 1:0] mult_res;
logic [BITS_A_LVL + BITS_B_LVL:0] add_res;
always_comb begin
  add_res = o_dat[level_a_*BITS_A_LVL + level_b_*BITS_B_LVL +: (BITS_A_LVL + BITS_B_LVL)] + mult_res;
end

// Pipeline the values
always_ff @ (posedge i_clk) begin
  mult_res <= dat_a_ * dat_b_;
  level_a_ <= level_a;
  level_b_ <= level_b;
end

enum {IDLE, MULT, FINISH} state;
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_dat <= 0;
    o_val <= 0;
    o_rdy <= 0;
    level_a <= 0;
    level_b <= 0;
    dat_a <= 0;
    dat_b <= 0;
    state <= IDLE;
    c <= 0;
    dat_a_ <= 0;
    dat_b_ <= 0;
  end else begin
    case(state)
      {IDLE}: begin
        o_rdy <= 1;
        o_val <= 0;
        level_a <= 0;
        level_b <= 0;
        dat_a <= i_dat_a;
        dat_b <= i_dat_b;
        dat_a_ <= i_dat_a[0 +: BITS_A_LVL];
        dat_b_ <= i_dat_b[0 +: BITS_B_LVL];
        o_dat <= 0;
        c <= 0;
        if (o_rdy && i_val) begin
          o_rdy <= 0;
          state <= MULT;
        end
      end
      {MULT}: begin
        dat_a_ <= dat_a[(level_a+1)*BITS_A_LVL +: BITS_A_LVL];
        level_a <= level_a + 1;
        c <= add_res[BITS_A_LVL + BITS_B_LVL];
        if (level_a != 0 || level_b != 0)
          o_dat[level_a_*BITS_A_LVL + level_b_*BITS_B_LVL +: (BITS_A_LVL + BITS_B_LVL)] <= add_res[BITS_A_LVL + BITS_B_LVL -1:0] + {c, {BITS_B_LVL{1'd0}}};
          
        if ((level_a+1) == LEVEL_A) begin
          level_b <= level_b + 1;
          level_a <= 0;
          dat_b_ <= dat_b[(level_b+1)*BITS_B_LVL +: BITS_B_LVL];
          dat_a_ <= dat_a[0 +: BITS_A_LVL];
        end
        if ((level_a+1) == LEVEL_A && (level_b+1) == LEVEL_B) begin
          state <= FINISH;
        end
      end
      {FINISH}: begin
        if (~o_val || (i_rdy && o_val)) begin
          o_dat[level_a_*BITS_A_LVL + level_b_*BITS_B_LVL +: (BITS_A_LVL + BITS_B_LVL)] <= add_res[BITS_A_LVL + BITS_B_LVL -1:0] + {c, {BITS_B_LVL{1'd0}}};
          o_val <= 1;
          if ((i_rdy && o_val)) begin
            o_rdy <= 1;
            o_val <= 0;
            state <= IDLE;
          end
        end
      end
    endcase
  end
end

endmodule