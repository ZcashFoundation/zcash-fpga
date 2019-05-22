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

module ec_fp_mult_mod_tb ();

import common_pkg::*;
import bls12_381_pkg::*;

localparam CLK_PERIOD = 100;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(384*2/8), .CTL_BITS(16)) in_if(clk);
if_axi_stream #(.DAT_BYTS(384/8), .CTL_BITS(16))   out_if(clk);

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
  out_if.ctl = 0;
  out_if.mod = 0;
end

// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err)
    $error(1, "%m %t ERROR: output .err asserted", $time);

logic [380:0] out_dat;

always_comb out_if.dat = {3'd0, out_dat};

ec_fp_mult_mod #(
  .P             ( bls12_381_pkg::P ),
  .KARATSUBA_LVL ( 3                ),
  .CTL_BITS      ( 8               )
)
ec_fp_mult_mod (
  .i_clk( clk         ),
  .i_rst( rst         ),
  .i_ctl ( 8'd0       ),
  .i_dat_a( in_if.dat[0 +: 384]   ),
  .i_dat_b( in_if.dat[384 +: 384] ),
  .i_val( in_if.val   ),
  .i_err( in_if.err   ),
  .o_rdy( in_if.rdy   ),
  .o_dat( out_dat  ),
  .i_rdy( out_if.rdy  ),
  .o_val( out_if.val  )
);

task test_loop();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [383:0] in_a, in_b;
  integer i, max;

  $display("Running test_loop...");
  i = 0;
  max = 10000;

  while (i < max) begin
    in_a = random_vector(384/8) % bls12_381_pkg::P;
    in_b = random_vector(384/8) % bls12_381_pkg::P;
    expected = (in_a * in_b) % bls12_381_pkg::P;

    fork
      in_if.put_stream({in_b, in_a}, (384*2)/8, 0);
      out_if.get_stream(get_dat, get_len, 0);
    join

    common_pkg::compare_and_print(get_dat, expected);
    $display("test_loop PASSED loop %d/%d", i, max);
    i = i + 1;
  end

  $display("test_loop PASSED");
end
endtask;

task test_pipeline();
begin
  integer  max;

  $display("Running test_pipeline...");
  max = 100;

    fork
      begin
        logic [383:0] i;
        i = 0;
        while (i < max) begin
          in_if.put_stream({i, i}, (384*2)/8, 0);
          i++;
        end
      end
      begin
        integer i;
        integer signed get_len;
        logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
        i = 0;
        while (i < max) begin
          out_if.get_stream(get_dat, get_len, 0);
          common_pkg::compare_and_print(get_dat, (i * i) % bls12_381_pkg::P);
          i++;
        end
      end
    join

  $display("test_pipeline PASSED");
end
endtask;

initial begin
  out_if.rdy = 0;
  in_if.reset_source();
  #(40*CLK_PERIOD);

  test_pipeline();
  test_loop();

  #1us $finish();
end
endmodule