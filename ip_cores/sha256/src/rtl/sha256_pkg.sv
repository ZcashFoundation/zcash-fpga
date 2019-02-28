/*
  The SHA256 package file.
  
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

package sha256_pkg;

  // K values used during each round
  parameter [63:0][31:0] K  = {
    32'hc67178f2,32'hbef9a3f7,32'ha4506ceb,32'h90befffa,32'h8cc70208,32'h84c87814,32'h78a5636f,32'h748f82ee,
    32'h682e6ff3,32'h5b9cca4f,32'h4ed8aa4a,32'h391c0cb3,32'h34b0bcb5,32'h2748774c,32'h1e376c08,32'h19a4c116,
    32'h106aa070,32'hf40e3585,32'hd6990624,32'hd192e819,32'hc76c51a3,32'hc24b8b70,32'ha81a664b,32'ha2bfe8a1,
    32'h92722c85,32'h81c2c92e,32'h766a0abb,32'h650a7354,32'h53380d13,32'h4d2c6dfc,32'h2e1b2138,32'h27b70a85,
    32'h14292967,32'h06ca6351,32'hd5a79147,32'hc6e00bf3,32'hbf597fc7,32'hb00327c8,32'ha831c66d,32'h983e5152,
    32'h76f988da,32'h5cb0a9dc,32'h4a7484aa,32'h2de92c6f,32'h240ca1cc,32'h0fc19dc6,32'hefbe4786,32'he49b69c1,
    32'hc19bf174,32'h9bdc06a7,32'h80deb1fe,32'h72be5d74,32'h550c7dc3,32'h243185be,32'h12835b01,32'hd807aa98,
    32'hab1c5ed5,32'h923f82a4,32'h59f111f1,32'h3956c25b,32'he9b5dba5,32'hb5c0fbcf,32'h71374491,32'h428a2f98
  };

  // Initial values used for H
  parameter [7:0][31:0] IV = {
    32'h5be0cd19, 32'h1f83d9ab, 32'h9b05688c, 32'h510e527f,
    32'ha54ff53a, 32'h3c6ef372, 32'hbb67ae85, 32'h6a09e667
  };
  
  // Functions used in bit manipulations
  function [31:0] little_sig0(input logic [31:0] in);
    little_sig0 = {rotr(in, 7)} ^ {rotr(in, 18)} ^ {shr(in, 3)};  
  endfunction
  
  function [31:0] little_sig1(input logic [31:0] in);
    little_sig1 = {rotr(in, 17)} ^ {rotr(in, 19)} ^ {shr(in, 10)};  
  endfunction
  
  function [31:0] big_sig0(input logic [31:0] in);
    big_sig0 = {rotr(in, 2)} ^ {rotr(in, 13)} ^ {rotr(in, 22)}; 
  endfunction
  
  function [31:0] big_sig1(input logic [31:0] in);
    big_sig1 = {rotr(in, 6)} ^ {rotr(in, 11)} ^ {rotr(in, 25)};  
  endfunction
  
  function [31:0] ch(input logic [31:0] x, y, z);
    ch = (x & y) ^ (~x & z);  
  endfunction
  
  function [31:0] maj(input logic [31:0] x, y, z);
    maj = (x & y) ^ (x & z) ^ (y & z);
  endfunction
  
  function [31:0] rotr(input logic [31:0] in, input int bits);
    for (int i = 0; i < 32; i++) rotr[i] = in[(i+bits) % 32];
  endfunction
  
  function [31:0] shr(input logic [31:0] in, input int bits);
    shr = 0; 
    shr = in >> bits;
  endfunction
  
  // Swap bytes (used to convert between little and big endian)
  function [31:0] bs32(input logic [31:0] in);
    for (int i = 0; i < 4; i++) bs32[i*8 +: 8] = in[(4-1-i)*8 +: 8];
  endfunction
  
    function [63:0] bs64(input logic [63:0] in);
    for (int i = 0; i < 8; i++) bs64[i*8 +: 8] = in[(8-1-i)*8 +: 8];
  endfunction

endpackage