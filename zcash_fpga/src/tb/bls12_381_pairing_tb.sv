/*
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
`timescale 1ps/1ps

module bls12_381_pairing_tb ();

import common_pkg::*;
import bls12_381_pkg::*;

parameter type FE_TYPE   = bls12_381_pkg::fe_t;
parameter type FE2_TYPE  = bls12_381_pkg::fe2_t;
parameter type FE12_TYPE = bls12_381_pkg::fe12_t;
parameter P              = bls12_381_pkg::P;

localparam CTL_BITS = 32;

localparam CLK_PERIOD = 100;

logic clk, rst;

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

if_axi_stream #(.DAT_BYTS(($bits(af_point_t) + $bits(fp2_af_point_t)+7)/8), .CTL_BITS(CTL_BITS)) in_if(clk);
if_axi_stream #(.DAT_BYTS(($bits(fe12_t)+7)/8), .CTL_BITS(CTL_BITS)) out_if(clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_in_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_out_if(clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) add_fe2_in_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) add_fe2_out_if (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe2_in_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe2_out_if (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_in_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_out_if(clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE12_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe12_in_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE12_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe12_out_if(clk);

bls12_381_pairing #(
  .FE_TYPE     ( FE_TYPE   ),
  .FE2_TYPE    ( FE2_TYPE  ),
  .FE12_TYPE   ( FE12_TYPE ),
  .CTL_BITS    ( CTL_BITS  ),
  .OVR_WRT_BIT ( 0         )
)
bls12_381_pairing (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_val ( in_if.val ),
  .o_rdy ( in_if.rdy ),
  .i_g1_af ( in_if.dat[0 +: $bits(af_point_t)] ),
  .i_g2_af ( in_if.dat[$bits(af_point_t) +: $bits(fp2_af_point_t)] ),
  .o_val  ( out_if.val ),
  .i_rdy  ( out_if.rdy ),
  .o_fe12 ( out_if.dat ),
  .o_mul_fe2_if ( mul_fe2_in_if ),
  .i_mul_fe2_if ( mul_fe2_out_if ),
  .o_add_fe2_if ( add_fe2_in_if ),
  .i_add_fe2_if ( add_fe2_out_if ),
  .o_sub_fe2_if ( sub_fe2_in_if ),
  .i_sub_fe2_if ( sub_fe2_out_if ),
  .o_mul_fe12_if ( mul_fe12_in_if ),
  .i_mul_fe12_if ( mul_fe12_out_if ),
  .o_mul_fe_if ( mul_fe_in_if ),
  .i_mul_fe_if ( mul_fe_out_if )
);

always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
end

initial begin
  af_point_t P;
  fp2_af_point_t Q;
  fe12_t f, f_exp;

  in_if.reset_source();
  out_if.rdy = 0;
  #100ns;

  P.x = Gx;
  P.y = Gy;
  Q.x = G2x;
  Q.y = G2y;

  f = FE12_zero;
  f_exp =  {381'h1562633d4f2387ff79a0f625a6989072296a946ca6bbfa3fef879defde15ed96d205b2eebb454f48fb76fa8a845bcba7,
            381'h1868172fbbeb861d69c6c10f315c273d08312812c643dbf60588d0de3d2c4b3e9b21acd402f7ddee53f1c4797646ba96,
            381'h07508024863ec263bded120e45deb29c1f1303a056b279e116cb5fdb03013db19f81e78fa2b2b409cb2ce8e3ba96f4e6,
            381'h1431225e128c5e2bfafb9eba23746150907688583f52e07fcde4cc93452b0c2bcd0f0893b48a696c403c6980d0940741,
            381'h159bfbbdc31bb5cb0082c59e5f744773335ef1fdddb8ed86a1c23f61f18800b647ff7dae335fb9ab5fcf2188cb64d72d,
            381'h05d928cb508feeb3329e51aa0bec4f33ba865a22da5a4e97eb31b78c0150c0c6134f0f94bd0154b28430ee4c6052e82b,
            381'h087d1320fe5bad5c2d8e12c49e6aff41a0b80e1497bbe85682e22ed853f256041bdf97ef02bdb5d80a5f9bc31d85f25e,
            381'h159ef660e2d84185f55c0ccae1dd7f8f71b12c0beb7a431fede9e62794d9154e9a0ce4715f64b032492459076224c99b,
            381'h0cbc592a19a3f60c9938676b257b9c01ed9d708f9428b29e272a811d13d734485970d9d3f1c097b12bfa3d1678096b1d,
            381'h0751a051e0beb4a0e2351a7527d813b371e189056307d718a446e4016a3df787568a842f3401768dc03b966bd1db90ac,
            381'h0e760e96f911ae38a6042da82d7b0e30787864e725e9d5462d224c91c4497104d838d566d894564bc19e09d8af706c3f,
            381'h05194f5785436c8debf0eb2bab4c6ef3de7dc0633c85769173777b782bf897fa45025fd03e7be941123c4ee19910e62e};
            
  miller_loop(P, Q, f);

  assert(f == f_exp) else $fatal(1, "Miller loop did not match result");
  print_fe12(f);


  #1us $finish();
end
endmodule