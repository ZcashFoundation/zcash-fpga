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

module bls12_381_fmap_tb ();

import common_pkg::*;
import bls12_381_pkg::*;

parameter type FE_TYPE   = bls12_381_pkg::fe_t;
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

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_o_if [2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_i_if [2:0] (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_fe_i_if (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_fe_i_if (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_o_if (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe2_i_if (clk);

if_axi_stream #(.DAT_BYTS(($bits(FE_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) fmap_fe12_o_if (clk);
if_axi_stream #(.DAT_BYTS(($bits(FE_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) fmap_fe12_i_if (clk);

ec_fp_mult_mod #(
  .P             ( P        ),
  .KARATSUBA_LVL ( 3        ),
  .CTL_BITS      ( CTL_BITS )
)
ec_fp_mult_mod (
  .i_clk( clk         ),
  .i_rst( rst         ),
  .i_mul ( mul_fe_o_if[2] ),
  .o_mul ( mul_fe_i_if[2] )
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

ec_fe2_mul #(
  .FE_TYPE  ( FE_TYPE  ),
  .CTL_BITS ( CTL_BITS )
)
ec_fe2_mul (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe2_if ( mul_fe2_i_if ),
  .i_mul_fe2_if ( mul_fe2_o_if ),
  .o_add_fe_if ( add_fe_o_if ),
  .i_add_fe_if ( add_fe_i_if ),
  .o_sub_fe_if ( sub_fe_o_if),
  .i_sub_fe_if ( sub_fe_i_if ),
  .o_mul_fe_if ( mul_fe_o_if[1] ),
  .i_mul_fe_if ( mul_fe_i_if[1] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 4                ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_fe_mul (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( mul_fe_o_if[1:0] ),
  .o_res ( mul_fe_o_if[2]   ),
  .i_res ( mul_fe_i_if[2]   ),
  .o_axi ( mul_fe_i_if[1:0] )
);

bls12_381_fe12_fmap_wrapper #(
  .FE_TYPE     ( FE_TYPE  ),
  .CTL_BITS    ( CTL_BITS ),
  .CTL_BIT_POW ( 0        )
)
bls12_381_fe12_fmap_wrapper (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_fmap_fe12_if ( fmap_fe12_o_if ),
  .i_fmap_fe12_if ( fmap_fe12_i_if ),
  .o_mul_fe2_if ( mul_fe2_o_if ),
  .i_mul_fe2_if ( mul_fe2_i_if ),
  .o_mul_fe_if ( mul_fe_o_if[0] ),
  .i_mul_fe_if ( mul_fe_i_if[0] )
);

task test();
  fe12_t f, f_exp, f_out;
  integer signed get_len;
  integer pow;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat, dat_in;

  $display("Running test ...");
  dat_in = 0;
  
  for (int pow = 0; pow < 4; pow++) begin
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 2; k++) begin
          dat_in[(i*6+j*2+k)*384 +: $bits(FE_TYPE)] = random_vector(384/8) % P;
          f[i][j][k] = dat_in[(i*6+j*2+k)*384 +: $bits(FE_TYPE)];
        end

    f_exp = fe12_fmap(f, pow);
  
    fork
      fmap_fe12_i_if.put_stream(dat_in, 12*384/8, pow);
      fmap_fe12_o_if.get_stream(get_dat, get_len, 0);
    join
  
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 2; k++)
          f_out[i][j][k] = get_dat[(i*6+j*2+k)*384 +: $bits(FE_TYPE)];
  
    if (f_exp != f_out) begin
      $display("Input  was:");
      print_fe12(f);  
      $display("Output  was:");
      print_fe12(f_out);
      $display("Output Expected:");
      print_fe12(f_exp);
      $fatal(1, "%m %t ERROR: output was wrong", $time);
    end
    $display("test OK with pow=%d", pow);
  end
  $display("test PASSED");

endtask



initial begin
  fmap_fe12_i_if.reset_source();
  fmap_fe12_o_if.rdy = 0;
  #10ns;

  test();

  #50ns $finish();
end

endmodule