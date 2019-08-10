/*
  Calculates inversion mod p using binary gcd algorithm.

  Streaming version with internal adder and sub module to improve
  critical path.

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

module bin_inv_s #(
  parameter P,
  parameter BITS  = $clog2(P),
  parameter LEVEL = 1 // Pipelines when adding / subtracting / comparing
)(
  input                i_clk,
  input                i_rst,
  if_axi_stream.source o_dat_if,
  if_axi_stream.sink   i_dat_if
);

logic [BITS:0] x1, x2, u, v;
logic wait_add;
logic [1:0] wait_sub;
logic sub_out;

if_axi_stream #(.DAT_BYTS(2*(BITS+8)/8), .DAT_BITS(2*(BITS+1)), .CTL_BITS(1)) add_i_if (i_clk);
if_axi_stream #(.DAT_BYTS((BITS+8)/8), .DAT_BITS(BITS+1), .CTL_BITS(1))       add_o_if (i_clk);

if_axi_stream #(.DAT_BYTS(2*(BITS+8)/8), .DAT_BITS(2*(BITS+1)), .CTL_BITS(1)) sub_i_if (i_clk);
if_axi_stream #(.DAT_BYTS((BITS+8)/8), .DAT_BITS(BITS+1), .CTL_BITS(1))       sub_o_if (i_clk);

enum {IDLE,
      U_STATE,
      V_STATE,
      UPDATE_X1,
      UPDATE_X2,
      FINISHED} state;
      
always_comb begin
  add_i_if.dat = 0;
  add_i_if.dat[BITS+1 +: BITS+1] = P;
  add_i_if.dat[0 +: BITS+1] = (state == U_STATE) ? x1 : x2;
  
  add_i_if.sop = 0;
  add_i_if.eop = 0;
  add_i_if.err = 0;
  add_i_if.mod = 0;
  add_i_if.ctl = 0;
  
  o_dat_if.sop = 1;
  o_dat_if.eop = 1;
  o_dat_if.err = 0;
  o_dat_if.mod = 0;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    x1 <= 0;
    x2 <= 0;
    u <= 0;
    v <= 0;
    i_dat_if.rdy <= 0;
    o_dat_if.val <= 0;
    o_dat_if.dat <= 0;
    o_dat_if.ctl <= 0;

    state <= IDLE;
    add_i_if.val <= 0;
    add_o_if.rdy <= 0;
    sub_i_if.reset_source();
    sub_o_if.rdy <= 0;

    wait_add <= 0;
    wait_sub <= 0;
    sub_out <= 0;

  end else begin

    if (o_dat_if.rdy) o_dat_if.val <= 0;
    if (add_i_if.rdy) add_i_if.val <= 0;
    if (sub_i_if.rdy) sub_i_if.val <= 0;

    add_o_if.rdy <= 1;
    sub_o_if.rdy <= 1;

    case(state)
      IDLE: begin
        i_dat_if.rdy <= 1;
        if (i_dat_if.val && i_dat_if.rdy) begin
          i_dat_if.rdy <= 0;
          u <= i_dat_if.dat;
          o_dat_if.ctl <= i_dat_if.ctl;
          v <= P;
          x1 <= 1;
          x2 <= 0;
          state <= U_STATE;
        end
      end
      U_STATE: begin
        if (~wait_add) begin
          if (u % 2 == 1) begin
            state <= (v % 2 == 1) ? (u >= v) ? UPDATE_X1 : UPDATE_X2 : V_STATE;
          end else begin
            u <= u/2;
            if (x1 % 2 == 0) begin
              x1 <= x1/2;
              if ((u/2) % 2 == 1) state <= (v % 2 == 1) ? (u/2 >= v) ? UPDATE_X1 : UPDATE_X2 : V_STATE;
            end else begin
              wait_add <= 1;
              add_i_if.val <= 1;
            end
          end
        end else begin
          if (add_o_if.val && add_o_if.rdy) begin
            x1 <= add_o_if.dat/2;
            wait_add <= 0;
            if (u % 2 == 1) state <= (v % 2 == 1) ? (u >= v) ? UPDATE_X1 : UPDATE_X2 : V_STATE;
          end
        end
      end
      V_STATE: begin
        if (~wait_add) begin
          if (v % 2 == 1) begin
            state <= (u >= v) ? UPDATE_X1 : UPDATE_X2;
          end else begin
            v <= v/2;
            if (x2 % 2 == 0) begin
              x2 <= x2/2;
              if ((v/2) % 2 == 1) state <= (u >= v/2) ? UPDATE_X1 : UPDATE_X2;
            end else begin
              wait_add <= 1;
              add_i_if.val <= 1;
            end
          end
        end else begin
          if (add_o_if.val && add_o_if.rdy) begin
            x2 <= add_o_if.dat/2;
            wait_add <= 0;
            if (v % 2 == 1) state <= (u >= v) ? UPDATE_X1 : UPDATE_X2;
          end
        end
      end
      UPDATE_X1: begin
          case(wait_sub)
            0: begin //u <= u - v;
              sub_i_if.dat[0 +: BITS+1] <= u;
              sub_i_if.dat[BITS+1 +: BITS+1] <= v;
              sub_i_if.val <= 1;
              wait_sub <= wait_sub + 1;
            end
            1: begin
              sub_i_if.dat[0 +: BITS+1] <= x1;
              sub_i_if.dat[BITS+1 +: BITS+1] <= x2;
              sub_i_if.val <= 1;
              wait_sub <= wait_sub + 1;
            end
            2: begin
              // Wait
            end
          endcase

          if (sub_o_if.val && sub_o_if.rdy) begin
            sub_out <= sub_out + 1;          
            case(sub_out)
              0: begin
                u <= sub_o_if.dat;
                end
              1: begin
                x1 <= sub_o_if.dat;
                wait_sub <= 0;
                if (u == 1 || v == 1)
                  state <= FINISHED;
                else
                  state <= (u % 2 == 1) ? (v % 2 == 1) ? (u >= v) ? UPDATE_X1 : UPDATE_X2 : V_STATE : U_STATE;
              end
            endcase
          end
        end
        UPDATE_X2: begin
          case(wait_sub)
            0: begin
              sub_i_if.dat[0 +: BITS+1] <= v;
              sub_i_if.dat[BITS+1 +: BITS+1] <= u;
              sub_i_if.val <= 1;
              wait_sub <= wait_sub + 1;
            end
            1: begin
              sub_i_if.dat[0 +: BITS+1] <= x2;
              sub_i_if.dat[BITS+1 +: BITS+1] <= x1;
              sub_i_if.val <= 1;
              wait_sub <= wait_sub + 1;
            end
            2: begin
              // Wait
            end
          endcase

          if (sub_o_if.val && sub_o_if.rdy) begin
            sub_out <= sub_out + 1;
            case(sub_out)
              0: begin
                v <= sub_o_if.dat;
                end
              1: begin
                wait_sub <= 0;
                x2 <= sub_o_if.dat;
                if (u == 1 || v == 1)
                  state <= FINISHED;
                else
                  state <= (u % 2 == 1) ? (v % 2 == 1) ? (u >= v) ? UPDATE_X1 : UPDATE_X2 : V_STATE : U_STATE;
              end
            endcase
          end
        end
      FINISHED: begin
        o_dat_if.val <= 1;
        o_dat_if.dat <= (u == 1) ? x1 : x2;
        if (o_dat_if.val && o_dat_if.rdy) begin
          o_dat_if.val <= 0;
          i_dat_if.rdy <= 1;
          state <= IDLE;
        end
      end
    endcase
  end
end

// Adder does not use modulus
adder_pipe # (
  .P        ( 0      ),
  .BITS     ( BITS+1 ),
  .CTL_BITS ( 1      ),
  .LEVEL    ( LEVEL  )
)
adder_pipe (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_add ( add_i_if ),
  .o_add ( add_o_if )
);

subtractor_pipe # (
  .P        ( P      ),
  .BITS     ( BITS+1 ),
  .CTL_BITS ( 1      ),
  .LEVEL    ( LEVEL  )
)
subtractor_pipe (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_sub ( sub_i_if ),
  .o_sub ( sub_o_if )
);

endmodule