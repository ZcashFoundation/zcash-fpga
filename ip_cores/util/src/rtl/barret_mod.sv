/*
  Calculates a mod n, using barret reduction.
  
  We provide an external interface to be hooked up to a multiplier.
  
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

module barret_mod #(
  parameter                OUT_BITS = 256,
  parameter                IN_BITS = 512,
  parameter [OUT_BITS-1:0] P = 256'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFE_BAAEDCE6_AF48A03B_BFD25E8C_D0364141,
  parameter                K = $clog2(P) + 1
)(
  input                       i_clk,
  input                       i_rst,
  input [IN_BITS-1:0]         i_dat,
  input                       i_val,
  output logic                o_rdy,
  output logic [OUT_BITS-1:0] o_dat,
  output logic                o_val,
  input                       i_rdy,
  
  // Multiplier interface
  if_axi_stream.source o_mult,
  if_axi_stream.sink   i_mult_res
);


localparam                   MAX_IN_BITS = 2*K;
localparam [MAX_IN_BITS:0] U = (1 << (2*K)) / P;
localparam [MAX_IN_BITS-1:0] P_ = P;
logic [MAX_IN_BITS-1:0] c1, c2, c3, c4, c2_;


typedef enum {IDLE, S0, S1, S2, FINISHED, WAIT_MULT} state_t;
state_t state, prev_state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_rdy <= 0;
    o_dat <= 0;
    o_val <= 0;
    state <= IDLE;
    prev_state <= IDLE;
    c1 <= 0;
    c2 <= 0;
    c3 <= 0;
    c4 <= 0;
    o_mult.reset_source();
    i_mult_res.rdy <= 1;
  end else begin
    i_mult_res.rdy <= 1;
    case (state)
      {IDLE}: begin
        o_rdy <= 1;
        o_val <= 0;
        c2 <= (i_dat >> (K-1))*U; // Using multiplier interface TODO
        c4 <= i_dat;
        if (i_val && o_rdy) begin
          o_rdy <= 0;
          state <= S0;// WAIT_MULT;
          o_mult.val <= 1;
          o_mult.dat[0 +: OUT_BITS + 8] <= i_dat >> (K-1);
          o_mult.dat[OUT_BITS + 8 +: OUT_BITS + 8] <= U;
          prev_state <= S0;
          c2_ <= (i_dat >> (K-1))*U; // Using multiplier interface
        end
      end
      {S0}: begin
        c3 <= c2 >> (K + 1);
        state <= S1;
      end
      {S1}: begin
        c4 <= c4 - c3*P; // Using multiplier interface TODO
        o_mult.val <= 1;
        o_mult.dat[0 +: OUT_BITS] <= c3;
        o_mult.dat[OUT_BITS +: OUT_BITS] <= P;
        state <= S2; //WAIT_MULT;
        prev_state <= S2;
      end
      {S2}: begin
        if (c4 >= P_) begin
          c4 <= c4 - P_;
        end else begin
          state <= FINISHED;
          o_dat <= c4;
          o_val <= 1;
        end
      end
      {FINISHED}: begin
        if (o_val && i_rdy) begin
          o_val <= 0;
          state <= IDLE;
        end
      end
      // In this state we are waiting for a multiply to be finished
      {WAIT_MULT}: begin
        if (o_mult.val && o_mult.rdy) o_mult.val <= 0;
        if (i_mult_res.rdy && i_mult_res.val) begin
          state <= prev_state;
          case(prev_state)
            S0: c2 <= i_mult_res.dat;
            S2: c4 <= c4 - i_mult_res.dat;
          endcase
        end
      end
    endcase
  end
end

initial assert (IN_BITS <= MAX_IN_BITS) else $fatal(1, "%m ERROR: IN_BITS[%d] > MAX_IN_BITS[%d] in barret_mod", IN_BITS, MAX_IN_BITS);

endmodule