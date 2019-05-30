/*
  Package for the bls12_381 core

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

package bls12_381_pkg;
  localparam DAT_BITS = 381;
  localparam MUL_BITS = 384;
  localparam [DAT_BITS-1:0] P = 381'h1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
  localparam [DAT_BITS-1:0] Gx = 381'h17F1D3A73197D7942695638C4FA9AC0FC3688C4F9774B905A14E3A3F171BAC586C55E83FF97A1AEFFB3AF00ADB22C6BB;
  localparam [DAT_BITS-1:0] Gy = 381'h08B3F481E3AAA0F1A09E30ED741D8AE4FCF5E095D5D00AF600DB18CB2C04B3EDD03CC744A2888AE40CAA232946C5E7E1;



  // Jacobian coordinates for Fp elements
  typedef struct packed {
    logic [DAT_BITS-1:0] x, y, z;
  } jb_point_t;

  // Jacobian coordinates for Fp^2 elements
  typedef struct packed {
    jb_point_t fp1_a, fp1_b;
  } fp2_jb_point_t;

  // Instruction codes
  typedef enum logic [7:0] {
    NOOP_WAIT = 8'h0,
    FP_POINT_MULT = 8'h20
  } code_t;

  // Instruction format
  typedef struct packed {
    logic [15:0] c, b, a;
    code_t code;
  } inst_t;

  localparam DATA_RAM_WIDTH = 381;
  localparam DATA_RAM_DEPTH = $clog2(64);
  localparam INST_RAM_WIDTH = $bits(inst_t);
  localparam INST_RAM_DEPTH = $clog2(1024);

  jb_point_t g_point = '{x:Gx, y:Gy, z:1};

  function is_zero(jb_point_t p);
    is_zero = (p.x == 0 && p.y == 0 && p.z == 1);
    return is_zero;
  endfunction

   // Function to double point in Jacobian coordinates (for comparison in testbench)
   // Here a is 0, and we also mod the result
   function jb_point_t dbl_jb_point(input jb_point_t p);
     logic signed [1023:0] I_X, I_Y, I_Z, A, B, C, D, X, Y, Z;

     if (p.z == 0) return p;

     I_X = p.x;
     I_Y = p.y;
     I_Z = p.z;
     A = (I_Y*I_Y) % P;
     B = (((4*I_X) % P)*A) % P;
     C = (((8*A) % P)*A) % P;
     D = (((3*I_X)% P)*I_X) % P;
     X = (D*D)% P;
     X = X + ((2*B) % P > X ? P : 0) - (2*B) % P;

     Y = (D*((B + (X > B ? P : 0)-X) % P)) % P;
     Y = Y + (C > Y ? P : 0) - C;
     Z = (((2*I_Y)% P)*I_Z) % P;

     dbl_jb_point.x = X;
     dbl_jb_point.y = Y;
     dbl_jb_point.z = Z;
     return dbl_jb_point;
   endfunction

   function jb_point_t add_jb_point(jb_point_t p1, p2);
     logic signed [1023:0] A, U1, U2, S1, S2, H, H3, R;

     if (p1.z == 0) return p2;
     if (p2.z == 0) return p1;

     if (p1.y == p2.y && p1.x == p2.x)
       return (dbl_jb_point(p1));

     U1 = (p1.x*p2.z) % P;
     U1 = (U1*p2.z) % P;

     U2 = (p2.x*p1.z) % P;
     U2 = (U2 *p1.z) % P;
     S1 = p1.y *p2.z % P;
     S1 = (S1*p2.z % P) *p2.z % P;
     S2 = p2.y * p1.z % P;
     S2 = (S2*p1.z  % P) *p1.z % P;

     H = U2 + (U1 > U2 ? P : 0) -U1;
     R = S2 + (S1 > S2 ? P : 0) -S1;
     H3 = ((H * H %P ) * H ) % P;
     A = (((2*U1 % P) *H % P) * H % P);

     add_jb_point.z = ((H * p1.z % P) * p2.z) % P;
     add_jb_point.x = R*R % P;

     add_jb_point.x = add_jb_point.x + (H3 > add_jb_point.x ? P : 0) - H3;
     add_jb_point.x = add_jb_point.x + (A > add_jb_point.x ? P : 0) - A;

     A = (U1*H % P) * H % P;
     A = A + (add_jb_point.x > A ? P : 0) - add_jb_point.x;
     A = A*R % P;
     add_jb_point.y = S1*H3 % P;

     add_jb_point.y = A + (add_jb_point.y > A ? P : 0) - add_jb_point.y;

   endfunction

   function jb_point_t point_mult(logic [DAT_BITS-1:0] c, jb_point_t p);
     jb_point_t result, addend;
     result = 0;
     addend = p;
     while (c > 0) begin
       if (c[0]) begin
         result = add_jb_point(result, addend);
       end
       addend = dbl_jb_point(addend);
       c = c >> 1;
     end
     return result;
   endfunction

   function on_curve(jb_point_t p);
     return (p.y*p.y - p.x*p.x*p.x - secp256k1_pkg::a*p.x*p.z*p.z*p.z*p.z - secp256k1_pkg::b*p.z*p.z*p.z*p.z*p.z*p.z);
   endfunction

   function print_jb_point(jb_point_t p);
     $display("x:%h", p.x);
     $display("y:%h", p.y);
     $display("z:%h", p.z);
     return;
   endfunction

endpackage