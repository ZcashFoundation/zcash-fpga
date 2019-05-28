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

module adder_pipe_tb ();
import common_pkg::*;
import bls12_381_pkg::*;

localparam CLK_PERIOD = 100;

logic clk, rst;

localparam IN_BITS = bls12_381_pkg::DAT_BITS;
localparam OUT_BITS = IN_BITS;
localparam P = bls12_381_pkg::P;

if_axi_stream #(.DAT_BYTS((IN_BITS+7)/8)) ina_if(clk);
if_axi_stream #(.DAT_BYTS((IN_BITS+7)/8)) inb_if(clk);
if_axi_stream #(.DAT_BYTS((OUT_BITS+7)/8)) out_if(clk);

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

logic [IN_BITS-1:0] out;
always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
  out_if.ctl = 0;
  out_if.mod = 0;
  inb_if.rdy = ina_if.rdy;
  out_if.dat = 0;
  out_if.dat = out;
end

// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err)
    $error(1, "%m %t ERROR: output .err asserted", $time);

adder_pipe # (
  .BITS     ( IN_BITS ),
  .P        ( P   ),
  .CTL_BITS ( 8   ),
  .LEVEL    ( 3   )
)
adder_pipe (
  .i_clk ( clk        ),
  .i_rst ( rst        ),
  .i_dat_a ( ina_if.dat[IN_BITS-1:0] ),
  .i_dat_b ( inb_if.dat[IN_BITS-1:0] ),
  .i_ctl ( ina_if.ctl ),
  .i_val ( ina_if.val  ),
  .o_rdy ( ina_if.rdy  ),
  .o_dat ( out ),
  .o_val ( out_if.val ),
  .o_ctl ( out_if.ctl ),
  .i_rdy ( out_if.rdy )
);

task test_loop();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [512*8-1:0] a, b;
  integer i, max;

  $display("Running test_loop...");
  i = 0;
  max = 1000;

  while (i < max) begin
    a = random_vector((IN_BITS+7)/8) % P;
    b = random_vector((IN_BITS+7)/8) % P;
    expected = (a+b) % P;

    fork
      ina_if.put_stream(a, IN_BITS/8);
      inb_if.put_stream(b, IN_BITS/8);
      out_if.get_stream(get_dat, get_len);
    join
    common_pkg::compare_and_print(get_dat, expected);
    $display("test_loop PASSED loop %d/%d", i, max);
    i = i + 1;
  end

  $display("test_loop PASSED");
end
endtask;

initial begin
  out_if.rdy = 0;
  ina_if.val = 0;
  inb_if.val = 0;
  #(40*CLK_PERIOD);

  test_loop();

  #1us $finish();
end
endmodule