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

module bls12_381_fe12_final_exp_tb ();

import common_pkg::*;
import bls12_381_pkg::*;

parameter type FE_TYPE   = bls12_381_pkg::fe_t;
parameter type FE2_TYPE  = bls12_381_pkg::fe2_t;
parameter type FE6_TYPE  = bls12_381_pkg::fe6_t;
parameter type FE12_TYPE = bls12_381_pkg::fe12_t;
parameter P              = bls12_381_pkg::P;

localparam POW_BITS = $bits(ATE_X);
localparam POW_BIT =  64;
localparam FMAP_BIT = 56;
localparam SQ_BIT   = 60;
localparam CTL_BITS = POW_BIT + POW_BITS;

localparam CLK_PERIOD = 100;

logic clk, rst;

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #(CLK_PERIOD/2) clk = ~clk;
end

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_o_if [3:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe_i_if [3:0] (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_o_if [4:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   add_fe_i_if [4:0] (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_o_if [6:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   sub_fe_i_if [6:0] (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_o_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe2_i_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mnr_fe2_o_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mnr_fe2_i_if [2:0] (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe6_o_if       (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe6_i_if       (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mnr_fe6_o_if       (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mnr_fe6_i_if       (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe12_o_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe12_i_if [2:0] (clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   inv_fe12_o_if      (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   inv_fe12_i_if      (clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   fmap_fe12_o_if     (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   fmap_fe12_i_if     (clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   pow_fe12_o_if      (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   pow_fe12_i_if      (clk);

if_axi_stream #(.DAT_BYTS((7+$bits(FE_TYPE))/8), .CTL_BITS(CTL_BITS))   final_exp_fe12_o_if      (clk);
if_axi_stream #(.DAT_BYTS((7+$bits(FE_TYPE))/8), .CTL_BITS(CTL_BITS))   final_exp_fe12_i_if      (clk);

ec_fp_mult_mod #(
  .P             ( P        ),
  .KARATSUBA_LVL ( 3        ),
  .CTL_BITS      ( CTL_BITS )
)
ec_fp_mult_mod (
  .i_clk( clk          ),
  .i_rst( rst          ),
  .i_mul ( mul_fe_o_if[3] ),
  .o_mul ( mul_fe_i_if[3] )
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
  .i_add ( add_fe_o_if[4] ),
  .o_add ( add_fe_i_if[4] )
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
  .i_sub ( sub_fe_o_if[6] ),
  .o_sub ( sub_fe_i_if[6] )
);

ec_fe2_mul_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .CTL_BITS ( CTL_BITS )
)
ec_fe2_mul_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe2_if ( mul_fe2_i_if[2] ),
  .i_mul_fe2_if ( mul_fe2_o_if[2] ),
  .o_add_fe_if ( add_fe_o_if[0] ),
  .i_add_fe_if ( add_fe_i_if[0] ),
  .o_sub_fe_if ( sub_fe_o_if[0] ),
  .i_sub_fe_if ( sub_fe_i_if[0] ),
  .o_mul_fe_if ( mul_fe_o_if[0] ),
  .i_mul_fe_if ( mul_fe_i_if[0] )
);

fe2_mul_by_nonresidue_s #(
  .FE_TYPE  ( FE_TYPE  )
)
fe2_mul_by_nonresidue_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mnr_fe2_if ( mnr_fe2_i_if[2] ),
  .i_mnr_fe2_if ( mnr_fe2_o_if[2] ),
  .o_add_fe_if ( add_fe_o_if[1] ),
  .i_add_fe_if ( add_fe_i_if[1] ),
  .o_sub_fe_if ( sub_fe_o_if[1] ),
  .i_sub_fe_if ( sub_fe_i_if[1] )
);

ec_fe6_mul_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .FE2_TYPE ( FE2_TYPE ),
  .FE6_TYPE ( FE6_TYPE ),
  .OVR_WRT_BIT ( 0 )
)
ec_fe6_mul_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe2_if ( mul_fe2_o_if[0] ),
  .i_mul_fe2_if ( mul_fe2_i_if[0] ),
  .o_add_fe_if ( add_fe_o_if[2] ),
  .i_add_fe_if ( add_fe_i_if[2] ),
  .o_sub_fe_if ( sub_fe_o_if[2] ),
  .i_sub_fe_if ( sub_fe_i_if[2] ),
  .o_mnr_fe2_if ( mnr_fe2_o_if[0] ),
  .i_mnr_fe2_if ( mnr_fe2_i_if[0] ),
  .o_mul_fe6_if ( mul_fe6_i_if ),
  .i_mul_fe6_if ( mul_fe6_o_if )
);

fe6_mul_by_nonresidue_s #(
  .FE_TYPE  ( FE_TYPE  )
)
fe6_mul_by_nonresidue_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mnr_fe2_if ( mnr_fe2_o_if[1] ),
  .i_mnr_fe2_if ( mnr_fe2_i_if[1] ),
  .o_mnr_fe6_if ( mnr_fe6_i_if ),
  .i_mnr_fe6_if ( mnr_fe6_o_if )
);

ec_fe12_mul_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .OVR_WRT_BIT ( 8 ),
  .SQ_BIT      ( SQ_BIT )
)
ec_fe12_mul_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe6_if ( mul_fe6_o_if ),
  .i_mul_fe6_if ( mul_fe6_i_if ),
  .o_add_fe_if ( add_fe_o_if[3] ),
  .i_add_fe_if ( add_fe_i_if[3] ),
  .o_sub_fe_if ( sub_fe_o_if[3] ),
  .i_sub_fe_if ( sub_fe_i_if[3] ),
  .o_mnr_fe6_if ( mnr_fe6_o_if ),
  .i_mnr_fe6_if ( mnr_fe6_i_if ),
  .o_mul_fe12_if ( mul_fe12_i_if[2] ),
  .i_mul_fe12_if ( mul_fe12_o_if[2] )
);

bls12_381_fe12_fmap_wrapper #(
  .FE_TYPE     ( FE_TYPE  ),
  .CTL_BITS    ( CTL_BITS ),
  .CTL_BIT_POW ( FMAP_BIT  )
)
bls12_381_fe12_fmap_wrapper (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_fmap_fe12_if ( fmap_fe12_i_if ),
  .i_fmap_fe12_if ( fmap_fe12_o_if ),
  .o_mul_fe2_if ( mul_fe2_o_if[1] ),
  .i_mul_fe2_if ( mul_fe2_i_if[1] ),
  .o_mul_fe_if ( mul_fe_o_if[1] ),
  .i_mul_fe_if ( mul_fe_i_if[1] )
);

bls12_381_fe12_inv_wrapper #(
  .FE_TYPE  ( FE_TYPE ),
  .CTL_BITS ( CTL_BITS ),
  .OVR_WRT_BIT ( 0 )
)
bls12_381_fe12_inv_wrapper (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_inv_fe12_if ( inv_fe12_i_if ),
  .i_inv_fe12_if ( inv_fe12_o_if ),
  .o_mul_fe_if   ( mul_fe_o_if[2]   ),
  .i_mul_fe_if   ( mul_fe_i_if[2]   )
);

ec_fe12_pow_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .CTL_BIT_POW ( POW_BIT   ),
  .POW_BITS ( POW_BITS ),
  .SQ_BIT   ( SQ_BIT   )
)
ec_fe12_pow_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe12_if ( mul_fe12_o_if[0] ),
  .i_mul_fe12_if ( mul_fe12_i_if[0] ),
  .o_sub_fe_if ( sub_fe_o_if[4] ),
  .i_sub_fe_if ( sub_fe_i_if[4] ),
  .o_pow_fe12_if ( pow_fe12_i_if ),
  .i_pow_fe12_if ( pow_fe12_o_if )
);

bls12_381_final_exponent #(
  .OVR_WRT_BIT ( 32 ),
  .FMAP_BIT    ( FMAP_BIT ),
  .POW_BIT     ( POW_BIT  ),
  .SQ_BIT      ( SQ_BIT   )
)
bls12_381_final_exponent (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe12_if ( mul_fe12_o_if[1] ),
  .i_mul_fe12_if ( mul_fe12_i_if[1] ),
  .o_pow_fe12_if ( pow_fe12_o_if ),
  .i_pow_fe12_if ( pow_fe12_i_if ),
  .o_fmap_fe12_if ( fmap_fe12_o_if ),
  .i_fmap_fe12_if ( fmap_fe12_i_if ),
  .o_inv_fe12_if ( inv_fe12_o_if ),
  .i_inv_fe12_if ( inv_fe12_i_if ),
  .o_sub_fe_if ( sub_fe_o_if[5] ),
  .i_sub_fe_if ( sub_fe_i_if[5] ),
  .o_final_exp_fe12_if ( final_exp_fe12_i_if ),
  .i_final_exp_fe12_if ( final_exp_fe12_o_if )
);


resource_share # (
  .NUM_IN       ( 4                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 40 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_add (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( add_fe_o_if[3:0] ),
  .o_res ( add_fe_o_if[4]   ),
  .i_res ( add_fe_i_if[4]   ),
  .o_axi ( add_fe_i_if[3:0] )
);

resource_share # (
  .NUM_IN       ( 6                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 40 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_sub (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( sub_fe_o_if[5:0] ),
  .o_res ( sub_fe_o_if[6]   ),
  .i_res ( sub_fe_i_if[6]   ),
  .o_axi ( sub_fe_i_if[5:0] )
);

resource_share # (
  .NUM_IN       ( 3                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 40 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_mul (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( mul_fe_o_if[2:0] ),
  .o_res ( mul_fe_o_if[3]   ),
  .i_res ( mul_fe_i_if[3]   ),
  .o_axi ( mul_fe_i_if[2:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 44               ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe2_mul (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( mul_fe2_o_if[1:0] ),
  .o_res ( mul_fe2_o_if[2]   ),
  .i_res ( mul_fe2_i_if[2]   ),
  .o_axi ( mul_fe2_i_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 48 ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe12_mul (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( mul_fe12_o_if[1:0] ),
  .o_res ( mul_fe12_o_if[2]   ),
  .i_res ( mul_fe12_i_if[2]   ),
  .o_axi ( mul_fe12_i_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 52               ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe2_mnr (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( mnr_fe2_o_if[1:0] ),
  .o_res ( mnr_fe2_o_if[2]   ),
  .i_res ( mnr_fe2_i_if[2]   ),
  .o_axi ( mnr_fe2_i_if[1:0] )
);


// This just tests our software model vs a known good result
task test_sw();
  af_point_t P;
  fp2_af_point_t Q;
  fe12_t f, f_exp;

  $display("Running test_sw ...");

  // Known good result from zcash rust code
  f_exp = {381'h0f41e58663bf08cf068672cbd01a7ec73baca4d72ca93544deff686bfd6df543d48eaa24afe47e1efde449383b676631,
           381'h04c581234d086a9902249b64728ffd21a189e87935a954051c7cdba7b3872629a4fafc05066245cb9108f0242d0fe3ef,
           381'h03350f55a7aefcd3c31b4fcb6ce5771cc6a0e9786ab5973320c806ad360829107ba810c5a09ffdd9be2291a0c25a99a2,
           381'h11b8b424cd48bf38fcef68083b0b0ec5c81a93b330ee1a677d0d15ff7b984e8978ef48881e32fac91b93b47333e2ba57,
           381'h06fba23eb7c5af0d9f80940ca771b6ffd5857baaf222eb95a7d2809d61bfe02e1bfd1b68ff02f0b8102ae1c2d5d5ab1a,
           381'h19f26337d205fb469cd6bd15c3d5a04dc88784fbb3d0b2dbdea54d43b2b73f2cbb12d58386a8703e0f948226e47ee89d,
           381'h018107154f25a764bd3c79937a45b84546da634b8f6be14a8061e55cceba478b23f7dacaa35c8ca78beae9624045b4b6,
           381'h01b2f522473d171391125ba84dc4007cfbf2f8da752f7c74185203fcca589ac719c34dffbbaad8431dad1c1fb597aaa5,
           381'h193502b86edb8857c273fa075a50512937e0794e1e65a7617c90d8bd66065b1fffe51d7a579973b1315021ec3c19934f,
           381'h1368bb445c7c2d209703f239689ce34c0378a68e72a6b3b216da0e22a5031b54ddff57309396b38c881c4c849ec23e87,
           381'h089a1c5b46e5110b86750ec6a532348868a84045483c92b7af5af689452eafabf1a8943e50439f1d59882a98eaa0170f,
           381'h1250ebd871fc0a92a7b2d83168d0d727272d441befa15c503dd8e90ce98db3e7b6d194f60839c508a84305aaca1789b6};

  // Output of miller loop - input to our model
  f =    {381'h049eaeacea5c5e9ad17ab1909cb31c653b0cb7184cc9187f77a934b1189b088d4ca64d0ff60eb0b6be8805757ba3df04,
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

  final_exponent(f);
  $display("After final exponent:");
  print_fe12(f);
  assert(f == f_exp) else $fatal(1, "Test_sw final exp. did not match known good result");
  $display("test_sw PASSED");

endtask


task test_hw();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] dat_in, get_dat;
  integer start_time, finish_time;
  FE12_TYPE  f_in, f_out, f_exp;
  $display("Running hw test ...");

  for (int lp = 0; lp < 10; lp++) begin
    $display("Loop %d", lp);
    dat_in = 0;
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 2; k++) begin
          f_in[i][j][k] = random_vector(384/8) % P;
          dat_in[(i*6+j*2+k)*384 +: $bits(FE_TYPE)] = {f_in[i][j][k]};
        end

    f_exp = f_in;
    final_exponent(f_exp);

    start_time = $time;
    fork
      final_exp_fe12_o_if.put_stream(dat_in, 12*384/8);
      final_exp_fe12_i_if.get_stream(get_dat, get_len);
    join
    finish_time = $time;

    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 2; k++)
          f_out[i][j][k] = get_dat[(i*6+j*2+k)*384 +: $bits(FE_TYPE)];

    $display("hw test finished in %d clocks", (finish_time-start_time)/(CLK_PERIOD));

    if (f_exp != f_out) begin
      $display("Input:");
      print_fe12(f_in);
      $display("Output:");
      print_fe12(f_out);
      $display("Expected:");
      print_fe12(f_exp);
       $fatal(1, "%m %t ERROR: output was wrong", $time);
    end
  end

  $display("all hw tests PASSED");
end
endtask;

initial begin
  final_exp_fe12_o_if.reset_source();
  final_exp_fe12_i_if.rdy = 0;
  #100ns;

  //test_sw();
  test_hw();

  #1us $finish();
end

endmodule