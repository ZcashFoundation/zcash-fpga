/*
  This is combinatorial CRC module that generates a function to calculate CRC
  based on parameters for input and output length, and polynomial function.
  Can optionally be pipelined.
  
  Default parameters are for CRC-32 (0x04C11DB7)
  
  To get uniformly distributed keys it is important to use the upper bits
  as the output into the hash function.
  
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
module crc #(
  parameter                IN_BITS = 8,
  parameter                OUT_BITS = 4,
  parameter [OUT_BITS-1:0] POLYNOMIAL = 'b1110, // = x^4 + x + 1
  parameter                PIPELINE = 0
)(
  input i_clk, i_rst,
  
  input        [IN_BITS-1:0]  in,
  output logic [OUT_BITS-1:0] out
);

generate
  if (PIPELINE) begin: GEN_PIPELINE
    always_ff @ (posedge i_clk) begin
      if (i_rst) begin
        out <= 0;
      end else begin
        out <= crc(in, {IN_BITS{1'd1}});
      end
    end
  end else begin
    always_comb  out = crc(in, {IN_BITS{1'd1}});
  end
endgenerate

  
function [OUT_BITS-1:0] crc(input logic [IN_BITS-1:0] in, last_crc);
  // For each bit we determine the equation based on input and last_crc
  // Each bit gets an equation as we loop through the input bits
  // In the end we will have an equation where each out bit is a XOR
  // of inputs and outbits
  logic [IN_BITS-1:0] d_in;

  for (int i = IN_BITS-1; i >= 0; i--) begin
    // And then we loop though each of the CRC bits
    d_in = in[i] ^ last_crc[OUT_BITS-1];
    for (int j = OUT_BITS - 1; j >= 0; j--) begin
      if (POLYNOMIAL[j]) begin
        last_crc[j] = (j == 0) ? d_in : last_crc[j-1] ^ d_in;
      end else begin
        last_crc[j] = last_crc[j-1];
      end
    end
  end
  crc = last_crc;
endfunction
 
// Some checks to make sure our parameters are correct:
initial begin
  assert (OUT_BITS <= IN_BITS) else $fatal(1, "%m %t ERROR: OUT_BITS must be less than or equal to IN_BITS", $time);
  assert (POLYNOMIAL[0]) else $fatal(1, "%m %t ERROR: Bit 0 of polynomial must be 1", $time);
end
  
endmodule