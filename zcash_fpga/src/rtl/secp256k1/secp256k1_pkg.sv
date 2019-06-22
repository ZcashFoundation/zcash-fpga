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

  parameter DAT_BITS = 256;

  parameter [255:0] P = 256'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFE_FFFFFC2F;
  parameter [255:0] a = 256'h0;
  parameter [255:0] b = 256'h7;
  parameter [255:0] Gx = 256'h79BE667E_F9DCBBAC_55A06295_CE870B07_029BFCDB_2DCE28D9_59F2815B_16F81798;
  parameter [255:0] Gy = 256'h483ADA77_26A3C465_5DA4FBFC_0E1108A8_FD17B448_A6855419_9C47D08F_FB10D4B8;
  parameter [255:0] n = 256'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFE_BAAEDCE6_AF48A03B_BFD25E8C_D0364141;
  parameter [255:0] h = 256'h1;

  // These are used for endomorphisms
  parameter [255:0] lam = 256'd37718080363155996902926221483475020450927657555482586988616620542887997980018;
  parameter [255:0] beta = 256'd55594575648329892869085402983802832744385952214688224221778511981742606582254;
  parameter [255:0] a1 = 256'd64502973549206556628585045361533709077;
  parameter [255:0] a2 = 256'd367917413016453100223835821029139468248;
  parameter [255:0] b2 = 256'd64502973549206556628585045361533709077;
  parameter [255:0] b1_neg = 256'd303414439467246543595250775667605759171;
  parameter [255:0] c1_pre = 256'd64502973549206556628585045361533709077;   // Precalculated c1 without k (scaled 256 bits)
  parameter [255:0] c2_pre = 256'd303414439467246543595250775667605759172;  // Precalculated c2 without k (scaled 256 bits)

  parameter [255:0] p_eq =  (1 << 256) - (1 << 32) - (1 << 9) - (1 << 8) - (1 << 7) - (1 << 6) - (1 << 4) - 1;

  parameter DO_AFFINE_CHECK = "NO"; // Setting this to YES will convert the final result back to affine coordinates to check signature
                                    // Requires an inversion and so is slower than doing the check in jacobson coordinates
  parameter USE_ENDOMORPH = "YES";   // Use the secp256k1 endomorphism to reduce the key bit size. Improves throughput by 2x but uses
                                    // more FPGA logic

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
  parameter SIG_VER_U1 = 32;  // 256 bits
  parameter SIG_VER_U2 = 36;  // 256 bits
  parameter SIG_VER_X = 40;   // Result of (u1.P + u2.Q) 256 * 3 bits as is in jb coords.
  parameter SIG_VER_X_AFF = 52;   // 256 bits, SIG_VER_X result's X in affine coords.

  typedef logic [255:0] fe_t;
  
  logic [256:0] P_ = P;
  logic [255:0] p = P;  //TODO remove me

  // Expected to be in Jacobian coordinates
  typedef struct packed {
    fe_t x, y, z;
  } jb_point_t;
  
  jb_point_t g_point = {x:Gx, y:Gy, z:256'd1};
  

  typedef struct packed {
    logic [2:0] padding;
    logic TIMEOUT_FAIL;
    logic FAILED_SIG_VER;
    logic X_INFINITY_POINT;
    logic OUT_OF_RANGE_S;
    logic OUT_OF_RANGE_R;
  } secp256k1_ver_t;

  function is_zero(jb_point_t p);
    is_zero = (p.x == 0 && p.y == 0 && p.z == 1);
    return is_zero;
  endfunction
  
   function jb_point_t dbl_jb_point(input jb_point_t p);
     fe_t I_X, I_Y, I_Z, A, B, C, D, X, Y, Z;

     if (p.z == 0) return p;

     I_X = p.x;
     I_Y = p.y;
     I_Z = p.z;
     A = fe_mul(I_Y, I_Y);
     B = fe_mul(fe_mul(4, I_X), A);
     C = fe_mul(fe_mul(8, A), A);
     D = fe_mul(fe_mul(3, I_X), I_X);
     X = fe_mul(D, D);
     X = fe_sub(X, fe_mul(2, B));

     Y = fe_mul(D, fe_sub(B, X));
     Y = fe_sub(Y, C);
     Z = fe_mul(fe_mul(2, I_Y), I_Z);

     dbl_jb_point.x = X;
     dbl_jb_point.y = Y;
     dbl_jb_point.z = Z;
     return dbl_jb_point;
   endfunction
   
   function fe_t fe_add(fe_t a, b);
     logic [$bits(fe_t):0] a_, b_;
     a_ = a;
     b_ = b;
     fe_add = a_ + b_ >= P_ ? a_ + b_ - P_ : a_ + b_;
   endfunction

   function fe_t fe_sub(fe_t a, b);
     logic [$bits(fe_t):0] a_, b_;
     a_ = a;
     b_ = b;
     fe_sub = b_ > a_ ? a_- b_ + P_ : a_ - b_;
   endfunction


   function fe_t fe_mul(fe_t a, b);
     logic [$bits(fe_t)*2:0] m_;
     m_ = a * b;
     fe_mul = m_ % P;
   endfunction
   
   function jb_point_t add_jb_point(jb_point_t p1, p2);
     fe_t A, U1, U2, S1, S2, H, H3, R;

     if (p1.z == 0) return p2;
     if (p2.z == 0) return p1;

     if (p1.y == p2.y && p1.x == p2.x)
       return (dbl_jb_point(p1));

     U1 = fe_mul(p1.x, p2.z);
     U1 = fe_mul(U1, p2.z);

     U2 = fe_mul(p2.x, p1.z);
     U2 = fe_mul(U2, p1.z);
     S1 = fe_mul(p1.y, p2.z);
     S1 = fe_mul(fe_mul(S1, p2.z), p2.z);
     S2 = fe_mul(p2.y, p1.z);
     S2 = fe_mul(fe_mul(S2, p1.z), p1.z);

     H = fe_sub(U2, U1);
     R = fe_sub(S2, S1);
     H3 = fe_mul(fe_mul(H, H), H);
     A = fe_mul(fe_mul(fe_mul(2, U1), H), H);

     add_jb_point.z = fe_mul(fe_mul(H, p1.z), p2.z);
     add_jb_point.x = fe_mul(R, R);

     add_jb_point.x = fe_sub(add_jb_point.x, H3);
     add_jb_point.x = fe_sub(add_jb_point.x, A);

     A = fe_mul(fe_mul(U1, H), H);
     A = fe_sub(A, add_jb_point.x);
     A = fe_mul(A, R);
     add_jb_point.y = fe_mul(S1, H3);

     add_jb_point.y = fe_sub(A, add_jb_point.y);

   endfunction
   /*
  function jb_point_t add_jb_point(jb_point_t p1, p2);
    logic signed [512:0] A, U1, U2, S1, S2, H, H3, R;

    if (p1.z == 0) return p2;
    if (p2.z == 0) return p1;

    if (p1.y == p2.y && p1.x == p2.x)
      return (dbl_jb_point(p1));

    U1 = p1.x*p2.z % p_eq;
    U1 = U1*p2.z % p_eq;

    U2 = p2.x*p1.z % p_eq;
    U2 = U2 *p1.z % p_eq;
    S1 = p1.y *p2.z % p_eq;
    S1 = (S1*p2.z % p_eq) *p2.z % p_eq;
    S2 = p2.y * p1.z % p_eq;
    S2 = (S2*p1.z  % p_eq) *p1.z % p_eq;

    H = U2 + (U1 > U2 ? p_eq : 0) -U1;
    R = S2 + (S1 > S2 ? p_eq : 0) -S1;
    H3 = ((H * H %p_eq ) * H ) % p_eq;
    A = (((2*U1 % p_eq) *H % p_eq) * H % p_eq);

    add_jb_point.z = ((H * p1.z % p_eq) * p2.z) % p_eq;
    add_jb_point.x = R*R % p_eq;


    add_jb_point.x = add_jb_point.x + (H3 > add_jb_point.x ? p_eq : 0) - H3;
    add_jb_point.x = add_jb_point.x + (A > add_jb_point.x ? p_eq : 0) - A;

    A = (U1*H % p_eq) * H % p_eq;
    A = A + (add_jb_point.x > A ? p_eq : 0) - add_jb_point.x;
    A = A*R % p_eq;
    add_jb_point.y = S1*H3 % p_eq;

    add_jb_point.y = A + (add_jb_point.y > A ? p_eq : 0) - add_jb_point.y;

  endfunction
*/
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