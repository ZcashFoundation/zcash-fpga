/*
  Package for the secp256k1 core
 
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

package secp256k1_pkg;
  
  // TODO might have to flip these
  parameter [255:0] p = 256'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFE_FFFFFC2F;
  parameter [255:0] a = 256'h0;
  parameter [255:0] b = 256'h7;
  parameter [255:0] Gx = 256'h79BE667E_F9DCBBAC_55A06295_CE870B07_029BFCDB_2DCE28D9_59F2815B_16F81798;
  parameter [255:0] Gy = 256'h483ADA77_26A3C465_5DA4FBFC_0E1108A8_FD17B448_A6855419_9C47D08F_FB10D4B8;
  parameter [255:0] n = 256'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFE_BAAEDCE6_AF48A03B_BFD25E8C_D0364141;
  parameter [255:0] h = 256'h1;
  
  parameter [255:0] p_eq =  (1 << 256) - (1 << 32) - (1 << 9) - (1 << 8) - (1 << 7) - (1 << 6) - (1 << 4) - 1;
  
  // Use register map for debug, holds information on current operation
  parameter REGISTER_SIZE = 64;
  // The mapping to index
  parameter CURR_CMD = 0;     // What command are we processing
  parameter CURR_STATE = 1;   // What state are we in
  // If it is processing a signature verification, these bits will be populated:
  parameter SIG_VER_HASH = 8; // 256 bits
  parameter SIG_VER_S = 12;   // 256 bits
  parameter SIG_VER_R = 16;   // 256 bits
  parameter SIG_VER_Q = 20;   // 512 bits
  parameter SIG_VER_W = 28;   // 256 bits - Result of invert(s)
  
  // Expected to be in Jacobian coordinates
  typedef struct packed {
    logic [255:0] x, y, z;
  } jb_point_t;
  
  typedef struct packed {
    logic [5:0] padding;
    logic X_INFINITY_POINT;
    logic OUT_OF_RANGE_S;
    logic OUT_OF_RANGE_R;
  } secp256k1_ver_t; 
  
  function is_zero(jb_point_t p);
    is_zero = (p.x == 0 && p.y == 0 && p.z == 1);
  endfunction
  
  // Function to double point in Jacobian coordinates (for comparison in testbench)
  // Here a is 0, and we also mod p the result
  function jb_point_t dbl_jb_point(jb_point_t p);
    logic [1023:0] A, B, C, D;
    A = (p.y*p.y) % p_eq;
    B = (4*p.x*A) % p_eq;
    C = (8*A*A) % p_eq;
    D = (3*p.x*p.x) % p_eq;
    dbl_jb_point.x = (D*D - 2*B) % p_eq;
    dbl_jb_point.y = (D*(B-dbl_jb_point.x) - C) % p_eq;
    dbl_jb_point.z = (2*p.y*p.z) % p_eq;
  endfunction
  
  function print_jb_point(jb_point_t p);
    $display("x:%h", p.x);
    $display("y:%h", p.y);
    $display("z:%h", p.z);
  endfunction
  
endpackage