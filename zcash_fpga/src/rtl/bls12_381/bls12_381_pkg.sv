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

  localparam [63:0] ATE_X = 64'hd201000000010000;
  localparam ATE_X_START = 63;

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

  // Affine points
  typedef struct packed {
    fe_t y;
    fe_t x;
  } af_point_t;

  typedef fe_t  [1:0] fe2_t;
  typedef fe2_t [2:0] fe6_t;
  typedef fe6_t [1:0] fe12_t;

  // These are used in the final exponentiation of the pairing.
  // We only list coeff needed for powers of 0,1,2,3
  parameter fe2_t FROBENIUS_COEFF_FQ12_C1 [3:0] = {
     {381'h06af0e0437ff400b6831e36d6bd17ffe48395dabc2d3435e77f76e17009241c5ee67992f72ec05f4c81084fbede3cc09,
      381'h135203e60180a68ee2e9c448d77a2cd91c3dedd930b1cf60ef396489f61eb45e304466cf3e67fa0af1ee7b04121bdea2},
     {381'h0,
      381'h00000000000000005f19672fdf76ce51ba69c6076a0f77eaddb3a93be6f89688de17d813620a00022e01fffffffeffff},
     {381'h00fc3e2b36c4e03288e9e902231f9fb854a14787b6c7b36fec0c8ec971f63c5f282d5ac14d6c7ec22cf78a126ddc4af3,
      381'h1904d3bf02bb0667c231beb4202c0d1f0fd603fd3cbd5f4f7b2443d784bab9c4f67ea53d63e7813d8d0775ed92235fb8},
     {381'h0,
      381'h1}};

  parameter fe2_t FROBENIUS_COEFF_FQ6_C1 [3:0] = {
     {381'h1,
      381'h0},
     {381'h0,
      381'h00000000000000005f19672fdf76ce51ba69c6076a0f77eaddb3a93be6f89688de17d813620a00022e01fffffffefffe},
     {381'h1a0111ea397fe699ec02408663d4de85aa0d857d89759ad4897d29650fb85f9b409427eb4f49fffd8bfd00000000aaac,
      381'h0},
     {381'h0,
      381'h1}};


  parameter fe2_t FROBENIUS_COEFF_FQ6_C2 [3:0] = {
     {381'h0,
      381'h1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaaa},
     {381'h0,
      381'h1a0111ea397fe699ec02408663d4de85aa0d857d89759ad4897d29650fb85f9b409427eb4f49fffd8bfd00000000aaac},
     {381'h0,
      381'h1a0111ea397fe699ec02408663d4de85aa0d857d89759ad4897d29650fb85f9b409427eb4f49fffd8bfd00000000aaad},
     {381'h0,
      381'h1}};

  parameter fe_t FROBENIUS_COEFF_FQ2_C1 [1:0] = {
      381'h1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaaa,
      381'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001};



  // Generator points for G2
  fe2_t G2x = {381'h13e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e,
               381'h024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8};

  fe2_t G2y = {381'h606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79be,
               381'hce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b82801};

  fe2_t FE2_one = {381'd0, 381'd1};
  fe2_t FE2_zero = {381'd0, 381'd0};
  fe6_t FE6_one = {FE2_zero, FE2_zero, FE2_one};
  fe6_t FE6_zero = {FE2_zero, FE2_zero, FE2_zero};
  fe12_t FE12_one = {FE6_zero, FE6_one};
  fe12_t FE12_zero = {FE6_zero, FE6_zero};

  jb_point_t g_point = '{x:Gx, y:Gy, z:381'd1};

  // Jacobian coordinates for Fp^2, Fp^12 elements
  typedef struct packed {
    fe2_t z;
    fe2_t y;
    fe2_t x;
  } fp2_jb_point_t;

  typedef struct packed {
    fe2_t y;
    fe2_t x;
  } fp2_af_point_t;

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
    FP2_FPOINT_MULT = 8'h26,

    ATE_PAIRING     = 8'h28
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

   function jb_point_t point_mult(input logic [DAT_BITS-1:0] c, jb_point_t p);
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

   function fp2_jb_point_t fp2_point_mult(input logic [DAT_BITS-1:0] c, fp2_jb_point_t p);
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

   task print_fe2(fe2_t a);
     for (int i = 0; i < 2; i++)
       $display("c%d: 0x%h", i, a[i]);
   endtask

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

   function fe6_t fe6_inv(fe6_t a);
     fe2_t t0, t1, t2, t3, t4, t5;

     t3 = fe2_mul_by_nonresidue(a[2]);  // 0. [a]
     t3 = fe2_mul(t3, a[1]); // 1. [0]
     t3 = fe2_sub(0, t3); // 2. [1]
     t0 =  fe2_mul(a[0], a[0]); // 3. [a]
     t3 = fe2_add(t0, t3); // 4. [2,3]
     t4 = fe2_mul(a[2], a[2]); // 5. [a]
     t4 = fe2_mul_by_nonresidue(t4); // 6. [5]
     t2 = fe2_mul(a[0], a[1]); // 7. [a]
     t4 = fe2_sub(t4, t2); // 8. [6,7]
     t5 = fe2_mul(a[1], a[1]); // 9. [a]
     t2 = fe2_mul(a[2], a[0]); // 10. [a, wait 8]
     t5 = fe2_sub(t5, t2); // 11. [9, 10]
     t0 = fe2_mul(a[2], t4); // 12. [8, wait 4]
     t1 = fe2_mul(a[1], t5); // 13. [11]
     t1 = fe2_add(t0, t1); // 14. [13, 12]
     t1 = fe2_mul_by_nonresidue(t1); // 15. [14]
     t0 = fe2_mul(a[0], t3); // 16. [4, wait 14]
     t1 = fe2_add(t1, t0); // 17. [16, 15]
     t1 = fe2_inv(t1); // 18. [17]
     t3 = fe2_mul(t3, t1); // 19. [18, 4]
     t4 = fe2_mul(t4, t1); // 20. [18, 8]
     t5 = fe2_mul(t5, t1); // 21. [18, 11]
     fe6_inv = {t5, t4, t3};

   endfunction

   function fe12_t fe12_inv(fe12_t a);
     fe6_t  t0, t1;

     t0 = fe6_mul(a[0], a[0]);    // 0. [a]
     t1 = fe6_mul(a[1], a[1]); // 1. [a]
     t1 = fe6_mul_by_nonresidue(t1); // 2. [1]
     t0 = fe6_sub(t0, t1); // 3. [0, 2]
     t0 = fe6_inv(t0); // 4. [3]
     t1 = fe6_mul(a[0], t0); // 5. [4]
     t0 = fe6_mul(a[1], t0); // 6. [4, wait 5]
     t0 = fe6_sub(0, t0); // 7. [6]
     fe12_inv[0] = t1;
     fe12_inv[1] = t0;
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
     fe2_t a_a, b_b, c_c, t;
     a_a = fe2_mul(a[0], b[0]);  // 0. a_a = fe2_mul(a[0], b[0])
     b_b = fe2_mul(a[1], b[1]);  // 1. b_b = fe2_mul(a[1], b[1])
     c_c = fe2_mul(a[2], b[2]);  // 2. c_c = fe2_mul(a[2], b[2])

     fe6_mul[0] = fe2_add(a[1], a[2]); // 3. fe6_mul[0] = fe2_add(a[1], a[2])
     t = fe2_add(b[1], b[2]);         // 4. t =  fe2_add(b[1], b[2])

     fe6_mul[0] = fe2_mul(fe6_mul[0], t); // 5. fe6_mul[0] = fe2_mul(fe6_mul[0], t)   [3, 4]
     fe6_mul[0] = fe2_sub(fe6_mul[0], b_b); // 6. fe6_mul[0] = fe2_sub(fe6_mul[0], b_b) [5, 1]
     fe6_mul[0] = fe2_sub(fe6_mul[0], c_c); // 7. fe6_mul[0] = fe2_sub(fe6_mul[0], c_c)  [6, 2]

     fe6_mul[2] = fe2_add(b[0], b[2]);  // 8. fe6_mul[2] = fe2_add(b[0], b[2])
     t = fe2_add(a[0], a[2]);           // 9. t = fe2_add(a[0], a[2])    [wait 5]

     fe6_mul[2] = fe2_mul(fe6_mul[2], t);  // 10. fe6_mul[2] = fe2_mul(fe6_mul[2], t)   [8, 9]
     fe6_mul[2] = fe2_sub(fe6_mul[2], a_a); // 11. fe6_mul[2] = fe2_sub(fe6_mul[2], a_a)  [10, 0]
     fe6_mul[2] = fe2_add(fe6_mul[2], b_b);  // 12. fe6_mul[2] = fe2_add(fe6_mul[2], b_b) [11, 1]

     fe6_mul[1] = fe2_add(b[0], b[1]);  // 13. fe6_mul[1] = fe2_add(b[0], b[1])
     t = fe2_add(a[0], a[1]);  // 14. t = fe2_add(a[0], a[1])  [wait 10]   - can release input here

     fe6_mul[1] = fe2_mul(fe6_mul[1], t); // 15. fe6_mul[1] = fe2_mul(fe6_mul[1], t)   [13, 14]
     fe6_mul[1] = fe2_sub(fe6_mul[1], a_a);  // 16. fe6_mul[1] = fe2_sub(fe6_mul[1], a_a)   [15, 0]
     fe6_mul[1] = fe2_sub(fe6_mul[1], b_b);  // 17. fe6_mul[1] = fe2_sub(fe6_mul[1], b_b)   [16, 1]

     fe6_mul[0] = fe2_mul_by_nonresidue(fe6_mul[0]);  // 18. fe6_mul[0] = fe2_mul_by_nonresidue(fe6_mul[0])   [7]
     fe6_mul[0] = fe2_add(fe6_mul[0], a_a);  // 19. fe6_mul[0] = fe2_add(fe6_mul[0], a_a)    [18, 0]

     fe6_mul[2] = fe2_sub(fe6_mul[2], c_c);   // 20. fe6_mul[2] = fe2_sub(fe6_mul[2], c_c)  [12, 2]
     c_c = fe2_mul_by_nonresidue(c_c);  // 21. c_c = fe2_mul_by_nonresidue(c_c)   [20]

     fe6_mul[1] = fe2_add(c_c, fe6_mul[1]);   // 22. fe6_mul[1] = fe2_add(c_c, fe6_mul[1])   [17, 21]
   endfunction


   function fe12_t fe12_add(fe12_t a, b);
     for(int i = 0; i < 2; i++)
       fe12_add[i] = fe6_add(a[i], b[i]);
   endfunction

   function fe12_t fe12_sub(fe12_t a, b);
     for(int i = 0; i < 2; i++)
       fe12_sub[i] = fe6_sub(a[i], b[i]);
   endfunction

   function fe12_t fe12_mul(fe12_t a, b);
     fe6_t aa, bb;
     aa = fe6_mul(a[0], b[0]);  // 0. add_i0 = mul(a[0], b[0])
     bb = fe6_mul(a[1], b[1]);  // 1. bb = mul(a[1], b[1])

     fe12_mul[1] = fe6_add(a[1], a[0]); // 2. fe6_mul[1] = add(a[1], a[0])
     fe12_mul[0] = fe6_add(b[0], b[1]);  // 3. fe6_mul[0] = add(b[0], b[1])

     fe12_mul[1] = fe6_mul(fe12_mul[1], fe12_mul[0]); // 4. fe6_mul[1] = mul(fe6_mul[1], fe6_mul[0])  [2, 3]

     fe12_mul[1] = fe6_sub(fe12_mul[1], aa); // 5. fe6_mul[1] = sub(fe6_mul[1], add_i0) [4, 0]
     fe12_mul[1] = fe6_sub(fe12_mul[1], bb); // 6. fe6_mul[1] = sub(fe6_mul[1], bb) [5, 1]

     bb = fe6_mul_by_nonresidue(bb); // 7. bb = mnr(bb) [6]

     fe12_mul[0] = fe6_add(bb, aa); // 8. fe6_mul[0] = add(add_i0, bb) [0, 1, 7]
   endfunction

   function fe12_t fe12_sqr(fe12_t a);
     fe6_t ab, c0c1;

     ab = fe6_mul(a[0], a[1]);  // 0.
     c0c1 = fe6_add(a[0], a[1]);  // 1.   (wait eq0)

     fe12_sqr[0] = fe6_mul_by_nonresidue(a[1]);

     fe12_sqr[0] = fe6_add(fe12_sqr[0], a[0]);
     fe12_sqr[0] = fe6_mul(fe12_sqr[0], c0c1);

     fe12_sqr[0] = fe6_sub(fe12_sqr[0], ab);
     fe12_sqr[1] = fe6_add(ab, ab);

     ab = fe6_mul_by_nonresidue(ab);
     fe12_sqr[0] = fe6_sub(fe12_sqr[0], ab);
   endfunction


   // This performs the miller loop
   // P is an affine Fp point in G1
   // Q is an affine Fp^2 point in G2 on the twisted curve
   // f is a Fp^12 element, the result of the miller loop
  task miller_loop(input af_point_t P, input fp2_af_point_t Q, output fe12_t f);
    fp2_jb_point_t R;
    fe12_t lv_d, lv_a, f_sq;
    f = FE12_one;
    R.x = Q.x;
    R.y = Q.y;
    R.z = 1;

    for (int i = ATE_X_START-1; i >= 0; i--) begin
      f_sq = fe12_sqr(f);    // Full multiplication
      miller_double_step(R, P, lv_d);
      f = fe12_mul(f_sq, lv_d); // Sparse multiplication
      if (ATE_X[i] == 1) begin
        miller_add_step(R, Q, P, lv_a);
        f = fe12_mul(f, lv_a); // Sparse multiplication
      end
    end

  endtask

  task automatic ate_pairing(input af_point_t P, input fp2_af_point_t Q, ref fe12_t f);
    miller_loop(P, Q, f);
    final_exponent(f);
  endtask;

   // This performs both the line evaluation and the doubling
   // Returns a sparse f12 element
  task automatic miller_double_step(ref fp2_jb_point_t R, input af_point_t P, ref fe12_t f);
    fe2_t t0, t1, t2, t3, t4, t5, t6, zsquared;

     zsquared = fe2_mul(R.z, R.z); // 0.  [R.val]
     t0 = fe2_mul(R.x, R.x); // 1. [R.val]
     t4 = fe2_add(t0, t0); // 2. [1]
     t4 = fe2_add(t4, t0); // 3. [2]

     t1 = fe2_mul(R.y, R.y); // 4. [R.val]
     t2 = fe2_mul(t1, t1); // 5. [4]
     t3 = fe2_add(R.x, t1); // 6. [4]
     t3 = fe2_mul(t3, t3); // 7. [6]
     t3 = fe2_sub(t3, t0); // 8. [7, 1]

     t3 = fe2_sub(t3, t2); // 9. [8, 5]

     t3 = fe2_add(t3, t3); // 10. [9]

     t6 = fe2_add(R.x, t4); // 11. [3]
     t5 = fe2_mul(t4, t4); // 12. [3]

     R.x = fe2_sub(t5, t3); // 13. [12, 10]
     R.x = fe2_sub(R.x, t3); // 14. [13]

     R.z = fe2_add(R.z, R.y); // 15. [R.val, wait 0]
     R.z = fe2_mul(R.z, R.z); // 16. [15]
     R.z = fe2_sub(R.z, t1); // 17. [16, 4]
     R.z = fe2_sub(R.z, zsquared); // 18. [17, 0]

     R.y = fe2_sub(t3, R.x); // 19. [14, 10, wait 15]
     R.y = fe2_mul(R.y, t4); // 20. [19, 2],

     t2 = fe2_mul(t2, 8); // 21. [9 wait]

     R.y = fe2_sub(R.y, t2); // 22. [20, 21]

     t3 = fe2_mul(t4, zsquared); // 23. [0, 2, wait 14]
     t3 = fe2_add(t3, t3); // 24. [23]
     t3 = fe2_sub(0, t3); // 25. [24]

     t6 = fe2_mul(t6, t6); // 26. [11]
     t6 = fe2_sub(t6, t0); // 27. [26, 1]
     t6 = fe2_sub(t6, t5); // 28. [27, 12]

     t1 = fe2_mul(4, t1); // 29. [wait 17, 4, wait 5, wait 6]

     t6 = fe2_sub(t6, t1); // 30. [29, 28]

     t0 = fe2_mul(R.z, zsquared); // 31. [0, 18]
     t0 = fe2_add(t0, t0); // 32. [31]

     t0[0]  = fe_mul(t0[0], P.y); // 33. [P val, 32]
     t0[1]  = fe_mul(t0[1], P.y); // 34. [P val, 32]
     t3[0]  = fe_mul(t3[0], P.x); // 35. [P val, 25]
     t3[1]  = fe_mul(t3[1], P.x); // 36. [P val, 25]

     f = {{FE2_zero, t0, FE2_zero}, {FE2_zero, t3, t6}}; // [33, 34, 35, 36, 30]
   endtask

   // This performs both the line evaluation and the addition
   task automatic miller_add_step(ref fp2_jb_point_t R, input fp2_af_point_t Q, input af_point_t P, ref fe12_t f);
     fe2_t zsquared, ysquared, t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10;

     zsquared = fe2_mul(R.z, R.z); // 0. [R.val]
     ysquared = fe2_mul(Q.y, Q.y); // 1. [Q.val]

     t0 = fe2_mul(zsquared, Q.x); // 2. [0]

     t1 = fe2_add(R.z, Q.y); // 3. [R.val]
     t1 = fe2_mul(t1, t1); // 4. [3]
     t1 = fe2_sub(t1, ysquared); // 5. [4, 1]
     t1 = fe2_sub(t1, zsquared); // 6. [5, 0]
     t1 = fe2_mul(t1, zsquared); // 7. [6]

     t2 = fe2_sub(t0, R.x); // 8. [2, R.val]

     t3 = fe2_mul(t2, t2); // 9. [8]

     t4 = fe2_mul(t3, 4); // 10. [9]

     t5 = fe2_mul(t4, t2); // 11. [10, 8]

     t6 = fe2_sub(t1, R.y); // 12. [3]
     t6 = fe2_sub(t6, R.y); // 13. [12]

     t9 = fe2_mul(t6, Q.x); // 14. [13]

     t7 = fe2_mul(t4, R.x); // 15. [10]

     R.x = fe2_mul(t6, t6); // 16. [13]
     R.x = fe2_sub(R.x, t5); // 17. [11, 16]
     R.x = fe2_sub(R.x, t7); // 18. [17, 10]
     R.x = fe2_sub(R.x, t7); // 19. [18, 15]

     R.z = fe2_add(R.z, t2); // 20. [8]
     R.z = fe2_mul(R.z, R.z); // 21. [20]
     R.z = fe2_sub(R.z, zsquared); // 22. [21, 0]
     R.z = fe2_sub(R.z, t3); // 23. [22, 9]

     zsquared = fe2_mul(R.z, R.z);// 24. [23]

     t10 = fe2_add(Q.y, R.z); // 25.[23]
     t8 = fe2_sub(t7, R.x); // 26. [19, 15]
     t8 = fe2_mul(t8, t6); // 27. [26, 13]

     t0 = fe2_mul(R.y, t5); // 28. [11, 8 wait]
     t0 = fe2_add(t0, t0); // 29. [28]

     R.y = fe2_sub(t8, t0); // 30. [29, 27]

     t10 = fe2_mul(t10, t10); // 31. [23]
     t10 = fe2_sub(t10, ysquared); // 32. [31, 1]

     t10 = fe2_sub(t10, zsquared); // 33. [32, 24]

     t9 = fe2_add(t9, t9); // 34. [14]
     t9 = fe2_sub(t9, t10); // 35. [34, 33]

     t10 = fe2_add(R.z, R.z); // 36. [wait 35, 23]

     t6 = fe2_sub(0, t6); // 37. [wait 27]
     t1 = fe2_add(t6, t6); // 38. [37]

     t10[0]  = fe_mul(t10[0], P.y); // 39. [36]
     t10[1]  = fe_mul(t10[1], P.y); // 40. [36]
     t1[0]  = fe_mul(t1[0], P.x); // 41. [38]
     t1[1]  = fe_mul(t1[1], P.x); // 42. [38]

     f = {{FE2_zero, t10, FE2_zero}, {FE2_zero, t1, t9}};

   endtask

   function fe2_t fe2_fmap(input fe2_t a, input int pow);
     fe_t t0, t1;
     t0 = a[0];
     t1 = a[1]; // 0.
     t1 = fe_mul(t1, FROBENIUS_COEFF_FQ2_C1[pow % 2]); // 1. [0]
     fe2_fmap = {t1, t0};
   endfunction

   function fe6_t fe6_fmap(input fe6_t a, input int pow);
     fe2_t t0, t1, t2;
     t0 = a[0];
     t1 = a[1];
     t2 = a[2]; // 0.
     t0 = fe2_fmap(t0, pow); // 1. [0]
     t1 = fe2_fmap(t1, pow); // 2. [0]
     t2 = fe2_fmap(t2, pow); // 3. [0]
     t1 = fe2_mul(t1, FROBENIUS_COEFF_FQ6_C1[pow % 6]); // 4. [2]
     t2 = fe2_mul(t2, FROBENIUS_COEFF_FQ6_C2[pow % 6]); // 5. [3]
     fe6_fmap = {t2, t1, t0};
   endfunction


   function fe12_t fe12_fmap(input fe12_t a, input int pow);
     fe6_t t0, t1;
     t0 = a[0];
     t1 = a[1]; // 0. 
     t0 = fe6_fmap(t0, pow); // 1. [0]
     t1 = fe6_fmap(t1, pow); // 2. [0]
     t1[0] = fe2_mul(t1[0], FROBENIUS_COEFF_FQ12_C1[pow % 12]); // 3. [2]
     t1[1] = fe2_mul(t1[1], FROBENIUS_COEFF_FQ12_C1[pow % 12]); // 4. [2]
     t1[2] = fe2_mul(t1[2], FROBENIUS_COEFF_FQ12_C1[pow % 12]); // 5. [2]
     fe12_fmap = {t1, t0};
   endfunction

   // Max size is 1024 bit number
   function fe12_t fe12_pow(input fe12_t a, input logic [1023:0] pow);
      fe12_pow = FE12_one;

      while (pow != 0) begin
        if (pow[0])
          fe12_pow = fe12_mul(fe12_pow, a);
        a = fe12_mul(a, a);
        pow = pow >> 1;
      end

     fe12_pow[1] = fe6_sub(0, fe12_pow[1]);
   endfunction

   // Calculates the final exponent used in ate pairing
   task automatic final_exponent(ref fe12_t f);
     fe12_t t0, t1, t2, t3, t4;
     logic [63:0] bls_x;

     bls_x = ATE_X;

     t4 = f; // 0. [val]
     t0 = f; // 1. [val]
     t4[1] = fe6_sub(0, t4[1]); // 2. [0]
     t3 = fe12_inv(t4); // 3. [2]
     t4 = fe12_mul(t0, t3); // 4. [3]
     t2 = fe12_fmap(t4, 2); // 5. [4]
     t4 = fe12_mul(t2, t4); // 6. [4,5]
     t0 = fe12_mul(t4, t4); // 7. [6]
     t1 = fe12_pow(t0, bls_x); // 8. [7]

     t2 = fe12_pow(t1, bls_x >> 1); // 9. [8]
     t3[1] = fe6_sub(0, t4[1]); // 10. [6]
     t1 = fe12_mul(t1, {t3[1], t4[0]}); // 11. [wait 9, 6, 10]
     t1[1] = fe6_sub(0, t1[1]); // 12 . [11]
     
     t1 = fe12_mul(t1, t2); // 13. [12, 9]
     t2 = fe12_pow(t1, bls_x); // 14. [13]
     t3 = fe12_pow(t2, bls_x); // 15. [14]
     
     t1[1] = fe6_sub(0, t1[1]); // 16. [wait 14, 13]
     t3 = fe12_mul(t3, t1); // 17. [15, 16]
     
     t1[1] = fe6_sub(0, t1[1]); // 18. [wait 17]
     t1 = fe12_fmap(t1, 3); // 19. [18]
     t2 = fe12_fmap(t2, 2); // 20. [wait 15]
     
     
     t1 = fe12_mul(t1, t2); // 21. [20, 19]
     t2 = fe12_pow(t3, bls_x); // 22. [17, wait 21]


     t2 = fe12_mul(t2, t0); // 23. [22, 7]

     t2 = fe12_mul(t2, t4); // 24. [23, 6]
     t1 = fe12_mul(t1, t2); // 25. [21, 24]

     t2 = fe12_fmap(t3, 1); //26. [wait 25, 17]
     t1 = fe12_mul(t1, t2); // 27. [25, 26]

     f = t1;
   endtask


   function af_point_t to_affine(jb_point_t p);
     fe_t z_;
     z_ = fe_mul(p.z, p.z);
     to_affine.x = fe_mul(p.x, fe_inv(z_));
     z_ = fe_mul(z_, p.z);
     to_affine.y = fe_mul(p.y, fe_inv(z_));
   endfunction

   function fp2_af_point_t fp2_to_affine(fp2_jb_point_t p);
     fe2_t z_;
     z_ = fe2_mul(p.z, p.z);
     fp2_to_affine.x = fe2_mul(p.x, fe2_inv(z_));
     z_ = fe2_mul(z_, p.z);
     fp2_to_affine.y = fe2_mul(p.y, fe2_inv(z_));
   endfunction

   task print_fe6(fe6_t a);
     for (int i = 0; i < 3; i++)
       for (int j = 0; j < 2; j++)
         $display("c%d: 0x%h", i*2+j, a[i][j]);
   endtask

   task print_fe12(fe12_t a);
     for (int k = 0; k < 2; k++)
       for (int i = 0; i < 3; i++)
         for (int j = 0; j < 2; j++)
           $display("c%d: 0x%h", k*6+i*2+j, a[k][i][j]);
   endtask

   task print_jb_point(jb_point_t p);
     $display("x:0x%h", p.x);
     $display("y:0x%h", p.y);
     $display("z:0x%h", p.z);
   endtask

   task print_fp2_jb_point(fp2_jb_point_t p);
     $display("x:(c1:0x%h, c0:0x%h)", p.x[1], p.x[0]);
     $display("y:(c1:0x%h, c0:0x%h)", p.y[1], p.y[0]);
     $display("z:(c1:0x%h, c0:0x%h)", p.z[1], p.z[0]);
   endtask
   
   task print_af_point(af_point_t p);
     $display("x:(0x%h)", p.x);
     $display("y:(0x%h)", p.y);
   endtask  

   task print_fp2_af_point(fp2_af_point_t p);
     $display("x:(c1:0x%h, c0:0x%h)", p.x[1], p.x[0]);
     $display("y:(c1:0x%h, c0:0x%h)", p.y[1], p.y[0]);
   endtask

endpackage