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
parameter type FE6_TYPE  = bls12_381_pkg::fe6_t;
parameter type FE12_TYPE = bls12_381_pkg::fe12_t;
parameter P              = bls12_381_pkg::P;

af_point_t G1 = {Gy, Gx};
fp2_af_point_t G2 = {G2y, G2x};

localparam CTL_BITS = 36;

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
if_axi_stream #(.DAT_BYTS(($bits(FE12_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) out_if(clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_o_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_i_if(clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_i_if (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_i_if (clk);

ec_fp_mult_mod #(
  .P             ( P        ),
  .KARATSUBA_LVL ( 3        ),
  .CTL_BITS      ( CTL_BITS )
)
ec_fp_mult_mod (
  .i_clk( clk         ),
  .i_rst( rst         ),
  .i_mul ( mul_fe_o_if ),
  .o_mul ( mul_fe_i_if )
);

adder_pipe # (
  .BITS     ( bls12_381_pkg::DAT_BITS ),
  .P        ( P        ),
  .CTL_BITS ( CTL_BITS ),
  .LEVEL    ( 2        )
)
adder_pipe (
  .i_clk ( clk        ),
  .i_rst ( rst        ),
  .i_add ( add_fe_o_if ),
  .o_add ( add_fe_i_if )
);

subtractor_pipe # (
  .BITS     ( bls12_381_pkg::DAT_BITS ),
  .P        ( P        ),
  .CTL_BITS ( CTL_BITS ),
  .LEVEL    ( 2        )
)
subtractor_pipe (
  .i_clk ( clk        ),
  .i_rst ( rst        ),
  .i_sub ( sub_fe_o_if ),
  .o_sub ( sub_fe_i_if )
);

bls12_381_pairing_wrapper #(
  .CTL_BITS    ( CTL_BITS ),
  .OVR_WRT_BIT ( 0        )
)
bls12_381_pairing_wrapper (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_val ( in_if.val ),
  .o_rdy ( in_if.rdy ),
  .i_g1_af ( in_if.dat[0 +: $bits(af_point_t)] ),
  .i_g2_af ( in_if.dat[$bits(af_point_t) +: $bits(fp2_af_point_t)] ),
  .o_val  ( out_if.val ),
  .i_rdy  ( out_if.rdy ),
  .o_fe12 ( out_if.dat ),
  .o_mul_fe_if ( mul_fe_o_if ),
  .i_mul_fe_if ( mul_fe_i_if ),
  .o_add_fe_if ( add_fe_o_if ),
  .i_add_fe_if ( add_fe_i_if ),
  .o_sub_fe_if ( sub_fe_o_if ),
  .i_sub_fe_if ( sub_fe_i_if )
);

always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
end

// This just tests our software model vs a known good result
task test0();
  af_point_t P;
  fp2_af_point_t Q;
  fe12_t f, f_exp;
  
  $display("Running test0 ...");
  f = FE12_zero;
  f_exp =  {381'h049eaeacea5c5e9ad17ab1909cb31c653b0cb7184cc9187f77a934b1189b088d4ca64d0ff60eb0b6be8805757ba3df04,
            381'h0198faba7d94607ce154e6a711ef859a5c4623722d4136c961a801c2b984aae5838a532aae5c2211660d3b8689b8f015,
            381'h12b091c5b34124368d2e95a7fd6cfa3b456447e49cd298de506572c5f3afb8727f2a186f0ea14bf5eed2171c4568b5c5,
            381'h05cfef8c26f3886e502008fc1fd74b86d400c32cb432323f994c060db185e9f8519cf76afcc9969379c2967f2f6ba36a,
            381'h0465162c766430cf4a98e217e3d765643118598715cc2538c56e933f0528f56dd6ac82507df446545a2fde77349ad37e,
            381'h1427e91ee8eff7e7187d560c375f5da3a9f0f162192ac4277bff1b14f560355e0b5cf069f452ab4d35ce11b39facc280,
            381'h087d1320fe5bad5c2d8e12c49e6aff41a0b80e1497bbe85682e22ed853f256041bdf97ef02bdb5d80a5f9bc31d85f25e,
            381'h159ef660e2d84185f55c0ccae1dd7f8f71b12c0beb7a431fede9e62794d9154e9a0ce4715f64b032492459076224c99b,
            381'h0cbc592a19a3f60c9938676b257b9c01ed9d708f9428b29e272a811d13d734485970d9d3f1c097b12bfa3d1678096b1d,
            381'h0751a051e0beb4a0e2351a7527d813b371e189056307d718a446e4016a3df787568a842f3401768dc03b966bd1db90ac,
            381'h0e760e96f911ae38a6042da82d7b0e30787864e725e9d5462d224c91c4497104d838d566d894564bc19e09d8af706c3f,
            381'h05194f5785436c8debf0eb2bab4c6ef3de7dc0633c85769173777b782bf897fa45025fd03e7be941123c4ee19910e62e};
            
  miller_loop(G1, G2, f);

  assert(f == f_exp) else $fatal(1, "Test0 Miller loop did not match known good result");
  $display("test0 PASSED");
endtask


task test1(input af_point_t G1_p, fp2_af_point_t G2_p);
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  integer start_time, finish_time;
  FE12_TYPE  f_out, f_exp;
  $display("Running test1 ...");
  
  miller_loop(G1_p, G2_p, f_exp);
  
  start_time = $time;
  fork
    in_if.put_stream({G2_p, G1_p}, (($bits(af_point_t) + $bits(fp2_af_point_t))+7)/8);
    out_if.get_stream(get_dat, get_len);
  join
  finish_time = $time;

  f_out = get_dat;

  $display("Expected:");
  print_fe12(f_exp);
  $display("Was:");
  print_fe12(f_out);

  if (f_exp != f_out) begin
    $fatal(1, "%m %t ERROR: output was wrong", $time);
  end

  $display("test1 PASSED in %d clocks", (finish_time-start_time)/CLK_PERIOD);
end
endtask; 

initial begin
  in_if.reset_source();
  out_if.rdy = 0;
  #100ns;

  test0(); // Test SW model
  test1(G1, G2);

  #1us $finish();
end

endmodule