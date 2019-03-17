/*
  This performs modular reduction using Algorithm 2.4 from 
  D. Hankerson, A. Menezes, S. Vanstone, “Guide to Elliptic Curve Cryptography”
  but with data width 256, for the prime field used in secp256k1
  
  p = 2^256 - 2^32 - 2^9 - 2^8 - 2^7 - 2^6 - 2^4 - 1
  
  Implemented with 2 stages of 8x 256b adds and one final optional
  subtract in the case we are >= p.
  
  returns o_dat = i_dat % p, where i_dat < p^2
 
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

module secp256k1_mod (
  input i_clk, i_rst,
  // Input value
  input [256*2-1:0] i_dat,
  input             i_val,
  output logic      o_rdy,
  // output
  output logic [255:0] o_dat,
  input                i_rdy,
  output logic         o_val
);
  
import secp256k1_pkg::*;
  
logic [256*2-1:0] b, a, a_;

always_comb begin
  a_ = (a << 32) + (a << 9) + (a << 8) + (a << 7) + (a << 6) + (a << 4) + a + b;
end

enum {IDLE, S1, S2} state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    a <= 0;
    b <= 0;
    state <= IDLE;
    o_val <= 0;
    o_rdy <= 0;
  end else begin
    o_rdy <= 0;
    o_dat <= a_ >= p_eq ? (a_ - p_eq) : a_;
    case(state)
      IDLE: begin
        o_rdy <= 1;
        o_val <= 0;
        if (i_val && o_rdy) begin
          a <= i_dat[511:256];
          b <= i_dat[255:0];
          o_rdy <= 0;
          state <= S1;
        end
      end
      S1: begin
        a <= a_[511:256];
        b <= a_[255:0];
        state <= S2;
      end
      S2: begin
        o_val <= 1;
        if (o_val && i_rdy) begin
          state <=IDLE;
          o_rdy <= 1;
          o_val <= 0;
        end
      end
    endcase
  end
end

endmodule