/*
  This performs modular reduction using Algorithm 2.4 from 
  D. Hankerson, A. Menezes, S. Vanstone, “Guide to Elliptic Curve Cryptography”
  but with data width 256, for the prime field used in secp256k1
  
  p = 2^256 - 2^32 - 2^9 - 2^8 - 2^7 - 2^6 - 2^4 - 1
  
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

module secp256k1_mod #(
  parameter USE_MULT = 0,   // Set to 1 to use multiple operation (should infer DSP and use less LUTs)
  parameter CTL_BITS = 8
)(
  input i_clk, i_rst,
  // Input value
  input [256*2-1:0]    i_dat,
  input                i_val,
  input                i_err,
  input [CTL_BITS-1:0] i_ctl,
  output logic         o_rdy,
  // output
  output logic [255:0]        o_dat,
  output logic [CTL_BITS-1:0] o_ctl,
  input                       i_rdy,
  output logic                o_val,
  output logic                o_err // Will go high if after 1 reduction we are still >= p
);
  
import secp256k1_pkg::*;
  
logic [256*2-1:0] res0, res1;
logic [1:0] val, err;
logic [1:0][CTL_BITS-1:0] ctl;

generate
  if (USE_MULT == 1) begin: GEN_MULT
    logic [256*2-1:0] c;
    always_comb begin
      c = (1 << 32) + (1 << 9) + (1 << 8) + (1 << 7) + (1 << 6) + (1 << 4) + 1;
    end
    always_ff @ (posedge i_clk) begin
      res0 <= i_dat[511:256]*c + i_dat[255:0];
      res1 <= res0[511:256]*c + res0[255:0];
    end    
  end else begin
    logic [256*2-1:0] res0_, res1_;
    always_comb begin
      res0_ = (i_dat[511:256] << 32) + (i_dat[511:256] << 9) + (i_dat[511:256] << 8) + (i_dat[511:256] << 7) + (i_dat[511:256] << 6) + (i_dat[511:256] << 4) + i_dat[511:256]+ i_dat[255:0];
      res1_ = (res0[511:256] << 32) + (res0[511:256] << 9) + (res0[511:256] << 8) + (res0[511:256] << 7) + (res0[511:256] << 6) + (res0[511:256] << 4) + res0[511:256]+ res0[255:0];
    end
    always_ff @ (posedge i_clk) begin
      res0 <= res0_;
      res1 <= res1_;
    end
  end    
endgenerate

always_comb o_rdy = i_rdy;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    val <= 0;
    err <= 0;
    o_val <= 0;
    ctl <= 0;
    o_err <= 0;
  end else begin
    o_val <= 0;
    val <= val << 1;
    ctl <= {ctl, i_ctl};
    err <= err << 1;
    val[0] <= i_val;
    err[0] <= i_err;
  
    o_dat <= res1 >= p_eq ? res1 - p_eq : res1;
    o_err <= err[1] || (res1 >= 2*p_eq);
    o_val <= val[1];
    o_ctl <= ctl[1];
  end
end

endmodule