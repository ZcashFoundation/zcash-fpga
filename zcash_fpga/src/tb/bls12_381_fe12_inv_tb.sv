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

module bls12_381_fe12_inv_tb ();

import common_pkg::*;
import bls12_381_pkg::*;

parameter type FE_TYPE   = bls12_381_pkg::fe_t;
parameter type FE2_TYPE  = bls12_381_pkg::fe2_t;
parameter type FE6_TYPE  = bls12_381_pkg::fe6_t;
parameter type FE12_TYPE = bls12_381_pkg::fe12_t;
parameter P              = bls12_381_pkg::P;

localparam CTL_BITS = 64;

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

if_axi_stream #(.DAT_BYTS(($bits(FE_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) i_inv_fe12_if(clk);
if_axi_stream #(.DAT_BYTS(($bits(FE_TYPE)+7)/8), .CTL_BITS(CTL_BITS)) o_inv_fe12_if(clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_fe_o_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_fe_i_if(clk);

ec_fp_mult_mod #(
  .P             ( P        ),
  .KARATSUBA_LVL ( 3        ),
  .CTL_BITS      ( CTL_BITS )
)
ec_fp_mult_mod (
  .i_clk( clk          ),
  .i_rst( rst          ),
  .i_mul ( mul_fe_o_if ),
  .o_mul ( mul_fe_i_if )
);

bls12_381_fe12_inv_wrapper #(
  .FE_TYPE  ( FE_TYPE ),
  .CTL_BITS ( CTL_BITS ),
  .OVR_WRT_BIT ( 0 )
)
bls12_381_fe12_inv_wrapper (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_inv_fe12_if ( i_inv_fe12_if ),
  .i_inv_fe12_if ( o_inv_fe12_if ),
  .o_mul_fe_if   ( mul_fe_o_if   ),
  .i_mul_fe_if   ( mul_fe_i_if   )
);


task test();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] dat_in, get_dat;
  integer start_time, finish_time;
  FE12_TYPE  f_in, f_out, f_exp;
  $display("Running test ...");

  for (int lp = 0; lp < 10; lp++) begin
    $display("Loop %d", lp);
    dat_in = 0;
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 2; k++) begin
          f_in[i][j][k] = random_vector(384/8) % P;
          dat_in[(i*6+j*2+k)*384 +: $bits(FE_TYPE)] = {f_in[i][j][k]};
        end

    f_exp = fe12_inv(f_in);

    start_time = $time;
    fork
      o_inv_fe12_if.put_stream(dat_in, 12*384/8);
      i_inv_fe12_if.get_stream(get_dat, get_len);
    join
    finish_time = $time;

    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 2; k++)
          f_out[i][j][k] = get_dat[(i*6+j*2+k)*384 +: $bits(FE_TYPE)];

    $display("test finished in %d clocks", (finish_time-start_time)/(CLK_PERIOD));
    
    if (f_exp != f_out) begin
      $fatal(1, "%m %t ERROR: output was wrong", $time);
    end
    
    if (fe12_mul(f_out, f_in) != FE12_one) begin
      $fatal(1, "%m %t ERROR: output did not reduce to one", $time);
    end

  end

  $display("all tests PASSED");
end
endtask;

initial begin
  o_inv_fe12_if.reset_source();
  i_inv_fe12_if.rdy = 0;
  #100ns;

  test();

  #1us $finish();
end

endmodule