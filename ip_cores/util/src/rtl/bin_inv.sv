/*
  Calculates inversion mod P using binary gcd algorithm.
  
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

module bin_inv #(
  parameter            BITS,
  parameter [BITS-1:0] P
)(
  input                   i_clk,
  input                   i_rst,
  input [BITS-1:0]        i_dat,
  input                   i_val,
  output logic            o_rdy,
  output logic [BITS-1:0] o_dat,
  output logic            o_val,
  input                   i_rdy
);
  
logic [BITS:0] x1, x2, u, v;

enum {IDLE,
      U_STATE,
      V_STATE,
      UPDATE,
      FINISHED} state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    x1 <= 0;
    x2 <= 0;
    u <= 0;
    v <= 0;
    o_rdy <= 0;
    o_val <= 0;
    o_dat <= 0;
    state <= IDLE;
  end else begin
    o_rdy <= 0;
    case(state)
      IDLE: begin
        o_rdy <= 1;
        o_val <= 0;
        if (o_rdy && i_val) begin
          o_rdy <= 0;
          u <= i_dat;
          v <= P;
          x1 <= 1;
          x2 <= 0;
          state <= U_STATE;
        end
      end
      U_STATE: begin
        if (u % 2 == 1) begin
          state <= V_STATE;
        end else begin
          u <= u/2;
          if (x1 % 2 == 0) begin
            x1 <= x1/2;
          end else begin
            x1 <= (x1 + P)/2;
          end
          if ((u/2) % 2 == 1) begin
            state <= V_STATE;
          end
        end
      end
      V_STATE: begin
        if (v % 2 == 1) begin
          state <= UPDATE;
        end else begin
          v <= v/2;
          if (x2 % 2 == 0) begin
            x2 <= x2/2;
          end else begin
            x2 <= (x2 + P)/2;
          end
          if ((v/2 % 2) == 1) begin
            state <= UPDATE;
          end
        end
      end
      UPDATE: begin
        state <= U_STATE;
        if (u >= v) begin
          u <= u - v;
          x1 <= x1 + (x1 >= x2 ? 0 : P) - x2;
          if (u - v == 1 || v == 1) begin
            state <= FINISHED;
          end 
        end else begin
          v <= v - u;
          x2 <= x2 + (x2 >= x1 ? 0 : P) - x1;
          if (v - u == 1 || u == 1) begin
            state <= FINISHED;
          end
        end
      end
      FINISHED: begin
        if (~o_val || (o_val && i_rdy)) begin
          o_val <= 1;
          o_dat <= (u == 1) ? x1 : x2;
          if (o_val && i_rdy) begin
            o_val <= 0;
            o_rdy <= 1;
            state <= IDLE;
          end
        end
      end
    endcase
  end
end

endmodule