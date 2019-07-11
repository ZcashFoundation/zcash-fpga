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

  typedef logic [DAT_BITS-1:0] fe_t;

  fe_t Gx = 381'h17F1D3A73197D7942695638C4FA9AC0FC3688C4F9774B905A14E3A3F171BAC586C55E83FF97A1AEFFB3AF00ADB22C6BB;
  fe_t Gy = 381'h08B3F481E3AAA0F1A09E30ED741D8AE4FCF5E095D5D00AF600DB18CB2C04B3EDD03CC744A2888AE40CAA232946C5E7E1;

  typedef enum logic [2:0] {
    SCALAR = 0,
    FE = 1,
    FE2 = 2,
    FE12 = 3,
    FP_AF = 4,
    FP_JB = 5,
    FP2_AF = 6,
    FP2_JB = 7
  } point_type_t;

  function integer unsigned get_point_type_size(point_type_t pt);
    case(pt)
      SCALAR: get_point_type_size = 1;
      FE: get_point_type_size = 1;
      FE2: get_point_type_size = 2;
      FE12: get_point_type_size = 12;
      FP_AF: get_point_type_size = 2;
      FP_JB: get_point_type_size = 3;
      FP2_AF: get_point_type_size = 4;
      FP2_JB: get_point_type_size = 6;
    endcase
  endfunction


  // Jacobian coordinates for Fp elements
  typedef struct packed {
    fe_t z;
    fe_t y;
    fe_t x;
  } jb_point_t;

  typedef fe_t  [1:0] fe2_t;
  typedef fe2_t [2:0] fe6_t;
  typedef fe6_t [1:0] fe12_t;

  fe2_t G2x = {381'd3059144344244213709971259814753781636986470325476647558659373206291635324768958432433509563104347017837885763365758,
               381'd352701069587466618187139116011060144890029952792775240219908644239793785735715026873347600343865175952761926303160};

  fe2_t G2y = {381'd927553665492332455747201965776037880757740193453592970025027978793976877002675564980949289727957565575433344219582,
               381'd1985150602287291935568054521177171638300868978215655730859378665066344726373823718423869104263333984641494340347905};

  fe2_t FE2_one =  {381'd0, 381'd1};

  jb_point_t g_point = '{x:Gx, y:Gy, z:381'd1};

  // Jacobian coordinates for Fp^2 elements
  typedef struct packed {
    fe2_t z;
    fe2_t y;
    fe2_t x;
  } fp2_jb_point_t;

  typedef struct packed {
    fe12_t z;
    fe12_t y;
    fe12_t x;
  } fp12_jb_point_t;

  fp2_jb_point_t g2_point = '{x:G2x, y:G2y, z:FE2_one};

  fp2_jb_point_t g_point_fp2 = '{x:{381'd0, Gx}, y:{381'd0, Gy}, z:FE2_one};  // Fp Generator point used in dual mode point multiplication

  // Instruction codes
  typedef enum logic [7:0] {
    NOOP_WAIT       = 8'h0,
    COPY_REG        = 8'h1,
    SEND_INTERRUPT  = 8'h6,

    SUB_ELEMENT     = 8'h10,
    ADD_ELEMENT     = 8'h11,
    MUL_ELEMENT     = 8'h12,
    INV_ELEMENT     = 8'h13,

    POINT_MULT      = 8'h24,
    FP_FPOINT_MULT  = 8'h25,
    FP2_FPOINT_MULT = 8'h26
  } code_t;

  // Instruction format
  typedef struct packed {
    logic [15:0] c, b, a;
    code_t code;
  } inst_t;

  typedef struct packed {
    point_type_t pt;
    fe_t dat;
  } data_t;


  localparam CONFIG_MEM_SIZE = 1024;

  localparam READ_CYCLE = 3;

  localparam DATA_RAM_WIDTH = $bits(data_t);
  localparam DATA_RAM_ALIGN_BYTE = 64;
  localparam DATA_RAM_DEPTH = 8;
  localparam DATA_RAM_USR_WIDTH = 4;
  localparam DATA_RAM_USR_DEPTH = DATA_RAM_DEPTH*DATA_RAM_ALIGN_BYTE/DATA_RAM_USR_WIDTH;
  localparam DATA_AXIL_START = 32'h2000;

  localparam INST_RAM_WIDTH = $bits(inst_t);
  localparam INST_RAM_ALIGN_BYTE = 8;
  localparam INST_RAM_DEPTH = 8;
  localparam INST_RAM_USR_WIDTH = 4;
  localparam INST_RAM_USR_DEPTH = INST_RAM_DEPTH*INST_RAM_ALIGN_BYTE/INST_RAM_USR_WIDTH;
  localparam INST_AXIL_START = 32'h1000;

  function is_zero(jb_point_t p);
    is_zero = (p.x == 0 && p.y == 0 && p.z == 1);
    return is_zero;
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

   function fe_t fe_add(fe_t a, b);
     logic [$bits(fe_t):0] a_, b_;
     a_ = a;
     b_ = b;
     fe_add = a_ + b_ >= P ? a_ + b_ - P : a_ + b_;
   endfunction

   function fe2_t fe2_add(fe2_t a, b);
     fe2_add[0] = fe_add(a[0], b[0]);
     fe2_add[1] = fe_add(a[1] ,b[1]);
   endfunction

   function fe_t fe_sub(fe_t a, b);
     logic [$bits(fe_t):0] a_, b_;
     a_ = a;
     b_ = b;
     fe_sub = b_ > a_ ? a_- b_ + P : a_ - b_;
   endfunction

   function fe2_t fe2_sub(fe2_t a, b);
     fe2_sub[0] = fe_sub(a[0], b[0]);
     fe2_sub[1] = fe_sub(a[1], b[1]);
   endfunction

   function fe_t fe_mul(fe_t a, b);
     logic [$bits(fe_t)*2:0] m_;
     m_ = a * b;
     fe_mul = m_ % P;
   endfunction

   function fe2_t fe2_mul(fe2_t a, b);
     fe2_mul[0] = fe_sub(fe_mul(a[0], b[0]), fe_mul(a[1], b[1]));
     fe2_mul[1] = fe_add(fe_mul(a[0], b[1]), fe_mul(a[1], b[0]));
   endfunction

      // Function to double point in Jacobian coordinates (for comparison in testbench)
   // Here a is 0, and we also mod the result
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

   function fp2_jb_point_t dbl_fp2_jb_point(input fp2_jb_point_t p);
     fe2_t I_X, I_Y, I_Z, A, B, C, D, X, Y, Z;

     if (p.z == 0) return p;

     I_X = p.x;
     I_Y = p.y;
     I_Z = p.z;
     A = fe2_mul(I_Y, I_Y);
     B = fe2_mul(fe2_mul(4, I_X), A);
     C = fe2_mul(fe2_mul(8, A), A);
     D = fe2_mul(fe2_mul(3, I_X), I_X);
     X = fe2_mul(D, D);
     X = fe2_sub(X, fe2_mul(2, B));

     Y = fe2_mul(D, fe2_sub(B, X));
     Y = fe2_sub(Y, C);
     Z = fe2_mul(fe2_mul(2, I_Y), I_Z);

     dbl_fp2_jb_point.x = X;
     dbl_fp2_jb_point.y = Y;
     dbl_fp2_jb_point.z = Z;
     return dbl_fp2_jb_point;
   endfunction

  function fp2_jb_point_t add_fp2_jb_point(fp2_jb_point_t p1, p2);
    fe2_t A, U1, U2, S1, S2, H, H3, R;

    if (p1.z == 0) return p2;
    if (p2.z == 0) return p1;

    if (p1.y == p2.y && p1.x == p2.x)
      return (dbl_fp2_jb_point(p1));

    U1 = fe2_mul(p1.x, p2.z);
    U1 = fe2_mul(U1, p2.z);

    U2 = fe2_mul(p2.x, p1.z);
    U2 = fe2_mul(U2, p1.z);
    S1 = fe2_mul(p1.y, p2.z);
    S1 = fe2_mul(fe2_mul(S1, p2.z), p2.z);
    S2 = fe2_mul(p2.y, p1.z);
    S2 = fe2_mul(fe2_mul(S2, p1.z), p1.z);

    H = fe2_sub(U2, U1);
    R = fe2_sub(S2, S1);
    H3 = fe2_mul(fe2_mul(H, H), H);
    A = fe2_mul(fe2_mul(fe2_mul(2, U1), H), H);

    add_fp2_jb_point.z = fe2_mul(fe2_mul(H, p1.z), p2.z);
    add_fp2_jb_point.x = fe2_mul(R, R);

    add_fp2_jb_point.x = fe2_sub(add_fp2_jb_point.x, H3);
    add_fp2_jb_point.x = fe2_sub(add_fp2_jb_point.x, A);

    A = fe2_mul(fe2_mul(U1, H), H);
    A = fe2_sub(A, add_fp2_jb_point.x);
    A = fe2_mul(A, R);
    add_fp2_jb_point.y = fe2_mul(S1, H3);

    add_fp2_jb_point.y = fe2_sub(A, add_fp2_jb_point.y);

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

   function fp2_jb_point_t fp2_point_mult(logic [DAT_BITS-1:0] c, fp2_jb_point_t p);
     fp2_jb_point_t result, addend;
     result = 0;
     addend = p;
     while (c > 0) begin
       if (c[0]) begin
         result = add_fp2_jb_point(result, addend);
       end
       addend = dbl_fp2_jb_point(addend);
       c = c >> 1;
     end
     return result;
   endfunction

   function on_curve(jb_point_t p);
     return (p.y*p.y - p.x*p.x*p.x - secp256k1_pkg::a*p.x*p.z*p.z*p.z*p.z - secp256k1_pkg::b*p.z*p.z*p.z*p.z*p.z*p.z);
   endfunction

   // Inversion using extended euclidean algorithm
   function fe_t fe_inv(fe_t a, b = 1);
      fe_t u, v;
      logic [$bits(fe_t):0] x1, x2;

      u = a; v = P;
      x1 = b; x2 = 0;
      while (u != 1 && v != 1) begin
        while (u % 2 == 0) begin
          u = u / 2;
          if (x1 % 2 == 0)
            x1 = x1 / 2;
          else
            x1 = (x1 + P) / 2;
        end
        while (v % 2 == 0) begin
          v = v / 2;
          if (x2 % 2 == 0)
            x2 = x2 / 2;
         else
           x2 = (x2 + P) / 2;
        end
        if (u >= v) begin
          u = u - v;
          x1 = fe_sub(x1, x2);
        end else begin
          v = v - u;
          x2 = fe_sub(x2, x1);
        end
      end
      if (u == 1)
        return x1;
      else
        return x2;
   endfunction

   // This algorithm can also be used for division
   function fe_t fe_div(fe_t a, b);
     return fe_inv(a, b);
   endfunction

   function fe2_t fe2_inv(fe2_t a);
     fe_t factor, t0, t1;
     t0 = fe_mul(a[0], a[0]);
     t1 = fe_mul(a[1], a[1]);
     factor = fe_inv(fe_add(t0, t1));
     fe2_inv[0]= fe_mul(a[0], factor);
     fe2_inv[1] = fe_mul(fe_sub(P, a[1]), factor);
   endfunction

   // Taken from Zcash Rust implementation of Fp6
   // https://github.com/zkcrypto/pairing/blob/master/src/bls12_381/fq6.rs
   function fe2_t fe2_mul_by_nonresidue(fe2_t a);
     fe2_mul_by_nonresidue[0] = fe_sub(a[0], a[1]);
     fe2_mul_by_nonresidue[1] = fe_add(a[0], a[1]);
   endfunction

   function fe6_t fe6_mul_by_nonresidue(fe6_t a);
     fe6_mul_by_nonresidue[1] = a[0];
     fe6_mul_by_nonresidue[2] = a[1];
     fe6_mul_by_nonresidue[0] = fe2_mul_by_nonresidue(a[2]);
   endfunction

   function fe6_t fe6_add(fe6_t a, b);
     for(int i = 0; i < 3; i++)
       fe6_add[i] = fe2_add(a[i], b[i]);
   endfunction

   function fe6_t fe6_sub(fe6_t a, b);
     for(int i = 0; i < 3; i++)
       fe6_sub[i] = fe2_sub(a[i], b[i]);
   endfunction

   function fe6_t fe6_mul(fe6_t a, b);
     fe2_t a_a, b_b, c_c;
     a_a = fe2_mul(a[0], b[0]);
     b_b = fe2_mul(a[1], b[1]);
     c_c = fe2_mul(a[2], b[2]);

     fe6_mul[0] = fe2_mul(fe2_add(a[1], a[2]), fe2_add(b[1], b[2]));
     fe6_mul[1] = fe2_mul(fe2_add(b[0], b[1]), fe2_add(a[0], a[1]));
     fe6_mul[2] = fe2_mul(fe2_add(b[0], b[2]), fe2_add(a[0], a[2]));

     fe6_mul[0] = fe2_sub(fe6_mul[0], b_b);
     fe6_mul[0] = fe2_sub(fe6_mul[0], c_c);
     fe6_mul[0] = fe2_add(fe2_mul_by_nonresidue(fe6_mul[0]), a_a);

     fe6_mul[1] = fe2_sub(fe6_mul[1], a_a);
     fe6_mul[1] = fe2_sub(fe6_mul[1], b_b);
     fe6_mul[1] = fe2_add(fe2_mul_by_nonresidue(c_c), fe6_mul[1]);

     fe6_mul[2] = fe2_sub(fe6_mul[2], a_a);
     fe6_mul[2] = fe2_add(fe6_mul[2], b_b);
     fe6_mul[2] = fe2_add(fe6_mul[2], c_c);
   endfunction

   function fe12_t fe12_mul(fe12_t a, b);
     fe6_t aa, bb;
     aa = fe6_mul(a[0], b[0]);
     bb = fe6_mul(a[1], b[1]);

     fe12_mul[1] = fe6_add(a[1], a[0]);
     fe12_mul[1] = fe6_mul(fe12_mul[1], fe6_add(b[0], b[1]));
     fe12_mul[1] = fe6_sub(fe12_mul[1], aa);
     fe12_mul[1] = fe6_sub(fe12_mul[1], bb);
     fe12_mul[0] = fe6_add(fe6_mul_by_nonresidue(bb), aa);
   endfunction

   function fp12_jb_point_t untiwst(fp2_jb_point_t P);

   endfunction

   function jb_point_t to_affine(jb_point_t p);
     fe_t z_;
     z_ = fe_mul(p.z, p.z);
     to_affine.z = 1;
     to_affine.x = fe_mul(p.x, fe_inv(z_));
     z_ = fe_mul(z_, p.z);
     to_affine.y = fe_mul(p.y, fe_inv(z_));
   endfunction

   function fp2_jb_point_t fp2_to_affine(fp2_jb_point_t p);
     fe2_t z_;
     z_ = fe2_mul(p.z, p.z);
     fp2_to_affine.z = FE2_one;
     fp2_to_affine.x = fe2_mul(p.x, fe2_inv(z_));
     z_ = fe2_mul(z_, p.z);
     fp2_to_affine.y = fe2_mul(p.y, fe2_inv(z_));
   endfunction

   function print_jb_point(jb_point_t p);
     $display("x:%h", p.x);
     $display("y:%h", p.y);
     $display("z:%h", p.z);
     return;
   endfunction

   function print_fp2_jb_point(fp2_jb_point_t p);
     $display("x:(c1:%h, c0:%h)", p.x[1], p.x[0]);
     $display("y:(c1:%h, c0:%h)", p.y[1], p.y[0]);
     $display("z:(c1:%h, c0:%h)", p.z[1], p.z[0]);
     return;
   endfunction

endpackage