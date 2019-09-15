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
`define SIMULATION
`define BL12_381_NEWMULT

module ec_fe12_pow_s_tb ();

import common_pkg::*;
import bls12_381_pkg::*;

parameter type FE_TYPE   = bls12_381_pkg::fe_t;
parameter type FE2_TYPE   = bls12_381_pkg::fe2_t;
parameter type FE6_TYPE   = bls12_381_pkg::fe6_t;
parameter type FE12_TYPE = bls12_381_pkg::fe12_t;
parameter P              = bls12_381_pkg::P;
parameter POW_BITS       = $bits(bls12_381_pkg::ATE_X);


localparam CTL_BITS = 32;
localparam SQ_BIT = 24;

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

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe_i_if  (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_o_if [4:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   add_fe_i_if [4:0] (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_o_if [5:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   sub_fe_i_if [5:0] (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe2_i_if (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe6_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe6_i_if (clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mnr_fe2_o_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mnr_fe2_i_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mnr_fe6_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mnr_fe6_i_if (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe12_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe12_i_if (clk);

if_axi_stream #(.DAT_BYTS(($bits(FE_TYPE)+7)/8), .CTL_BITS(POW_BITS)) pow_fe12_o_if (clk);
if_axi_stream #(.DAT_BYTS(($bits(FE_TYPE)+7)/8), .CTL_BITS(POW_BITS)) pow_fe12_i_if (clk);

accum_mult_mod #(
  .DAT_BITS ( $bits(FE_TYPE)),
  .CTL_BITS ( CTL_BITS ),
  .A_DSP_W  ( 26 ),
  .B_DSP_W  ( 17 ),
  .GRID_BIT ( 64 ),
  .RAM_A_W  ( 8  ),
  .RAM_D_W  ( 32 )
)
accum_mult_mod (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_mul ( mul_fe_o_if ),
  .o_mul ( mul_fe_i_if ),
  .i_ram_d (),
  .i_ram_we (),
  .i_ram_se ()
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
  .i_sub ( sub_fe_o_if[5] ),
  .o_sub ( sub_fe_i_if[5] )
);

ec_fe2_mul_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .CTL_BITS ( CTL_BITS )
)
ec_fe2_mul_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe2_if ( mul_fe2_i_if ),
  .i_mul_fe2_if ( mul_fe2_o_if ),
  .o_add_fe_if ( add_fe_o_if[0] ),
  .i_add_fe_if ( add_fe_i_if[0] ),
  .o_sub_fe_if ( sub_fe_o_if[0] ),
  .i_sub_fe_if ( sub_fe_i_if[0] ),
  .o_mul_fe_if ( mul_fe_o_if ),
  .i_mul_fe_if ( mul_fe_i_if )
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
  .CTL_BITS ( CTL_BITS ),
  .OVR_WRT_BIT ( 0 )
)
ec_fe6_mul_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe2_if ( mul_fe2_o_if ),
  .i_mul_fe2_if ( mul_fe2_i_if ),
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
  .OVR_WRT_BIT ( 16 ),
  .SQ_BIT(SQ_BIT)
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
  .o_mul_fe12_if ( mul_fe12_i_if ),
  .i_mul_fe12_if ( mul_fe12_o_if )
);

ec_fe12_pow_s #(
  .FE_TYPE  ( FE_TYPE  ),
  .CTL_BIT_POW ( 0     ),
  .POW_BITS ( POW_BITS ),
  .SQ_BIT   ( SQ_BIT   )
)
ec_fe12_pow_s (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe12_if ( mul_fe12_o_if ),
  .i_mul_fe12_if ( mul_fe12_i_if),
  .o_sub_fe_if ( sub_fe_o_if[4] ),
  .i_sub_fe_if ( sub_fe_i_if[4] ),
  .o_pow_fe12_if ( pow_fe12_i_if ),
  .i_pow_fe12_if ( pow_fe12_o_if )
);

resource_share # (
  .NUM_IN       ( 4                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 8                ),
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
  .NUM_IN       ( 5                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 8                ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 1                )
)
resource_share_fe_sub (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( sub_fe_o_if[4:0] ),
  .o_res ( sub_fe_o_if[5]   ),
  .i_res ( sub_fe_i_if[5]   ),
  .o_axi ( sub_fe_i_if[4:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 12               ),
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

task test(input [POW_BITS-1:0] pow);
  fe12_t a, f_exp, f_exp2, f_out;
  integer signed get_len;
  integer start_time, finish_time;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat, dat_in;

  $display("Running test ...");
  for (int lp = 0; lp < 10; lp++) begin
    $display("Loop %d", lp);
    dat_in = 0;
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 2; k++) begin
          a[i][j][k] = random_vector(384/8) % P;
          dat_in[(i*6+j*2+k)*384 +: $bits(FE_TYPE)] = a[i][j][k];
        end

    f_exp = fe12_pow(a, pow);

    start_time = $time;
    fork
      pow_fe12_o_if.put_stream(dat_in, 12*384/8, pow);
      pow_fe12_i_if.get_stream(get_dat, get_len);
    join
    finish_time = $time;

    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 2; k++)
          f_out[i][j][k] = get_dat[(i*6+j*2+k)*384 +: $bits(FE_TYPE)];

    if (f_exp != f_out) begin
      $display("Input a was:");
      print_fe12(a);
      $display("Output  was:");
      print_fe12(f_out);
      $display("Output Expected:");
      print_fe12(f_exp);
      $fatal(1, "%m %t ERROR: output was wrong", $time);
    end

    $display("test PASSED in %d clocks", (finish_time-start_time)/CLK_PERIOD);
  end

endtask


initial begin
  pow_fe12_o_if.reset_source();
  pow_fe12_i_if.rdy = 0;
  #(50*CLK_PERIOD)

  test(bls12_381_pkg::ATE_X);

  #50ns $finish();
end

endmodule