/*
  Package for Fp fields

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

package ec_fp_pkg;

  // Expected to be in Jacobian coordinates
  typedef struct packed {
    logic [255:0] x, y, z;
  } jb_point_t;

  function is_zero(jb_point_t p);
    is_zero = (p.x == 0 && p.y == 0 && p.z == 1);
    return is_zero;
  endfunction

  // Function to double point in Jacobian coordinates (for comparison in testbench)
  // Here a is 0, and we also mod the result
  function jb_point_t dbl_jb_point(jb_point_t p, input logic [1023:0] mod);
    logic signed [1023:0] I_X, I_Y, I_Z, A, B, C, D, X, Y, Z;

    if (p.z == 0) return p;

    I_X = p.x;
    I_Y = p.y;
    I_Z = p.z;
    A = (I_Y*I_Y) % mod;
    B = (((4*I_X) % mod)*A) % mod;
    C = (((8*A) % mod)*A) % mod;
    D = (((3*I_X)% mod)*I_X) % mod;
    X = (D*D)% mod;
    X = X + ((2*B) % mod > X ? mod : 0) - (2*B) % mod;

    Y = (D*((B + (X > B ? mod : 0)-X) % mod)) % mod;
    Y = Y + (C > Y ? mod : 0) - C;
    Z = (((2*I_Y)% mod)*I_Z) % mod;

    dbl_jb_point.x = X;
    dbl_jb_point.y = Y;
    dbl_jb_point.z = Z;
    return dbl_jb_point;
  endfunction

  function jb_point_t add_jb_point(jb_point_t p1, p2, input logic [1023:0] mod);
    logic signed [1023:0] A, U1, U2, S1, S2, H, H3, R;

    if (p1.z == 0) return p2;
    if (p2.z == 0) return p1;

    if (p1.y == p2.y && p1.x == p2.x)
      return (dbl_jb_point(p1));

    U1 = p1.x*p2.z % mod;
    U1 = U1*p2.z % mod;

    U2 = p2.x*p1.z % mod;
    U2 = U2 *p1.z % mod;
    S1 = p1.y *p2.z % mod;
    S1 = (S1*p2.z % mod) *p2.z % mod;
    S2 = p2.y * p1.z % mod;
    S2 = (S2*p1.z  % mod) *p1.z % mod;

    H = U2 + (U1 > U2 ? mod : 0) -U1;
    R = S2 + (S1 > S2 ? mod : 0) -S1;
    H3 = ((H * H %mod ) * H ) % mod;
    A = (((2*U1 % mod) *H % mod) * H % mod);

    add_jb_point.z = ((H * p1.z % mod) * p2.z) % mod;
    add_jb_point.x = R*R % mod;

    add_jb_point.x = add_jb_point.x + (H3 > add_jb_point.x ? mod : 0) - H3;
    add_jb_point.x = add_jb_point.x + (A > add_jb_point.x ? mod : 0) - A;

    A = (U1*H % mod) * H % mod;
    A = A + (add_jb_point.x > A ? mod : 0) - add_jb_point.x;
    A = A*R % mod;
    add_jb_point.y = S1*H3 % mod;

    add_jb_point.y = A + (add_jb_point.y > A ? mod : 0) - add_jb_point.y;

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