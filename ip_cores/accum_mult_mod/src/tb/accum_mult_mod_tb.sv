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

module accum_mult_mod_tb ();
import common_pkg::*;

localparam CLK_PERIOD = 100;

logic clk, rst;

parameter            BITS = 381;
parameter [BITS-1:0] MODULUS = 'h1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
parameter            A_DSP_W = 26;
parameter            B_DSP_W = 17;
parameter            GRID_BIT = 64;
parameter            RAM_A_W = 10;
parameter            RAM_D_W = 32;

// This is the max size we can expect on the output

if_axi_stream #(.DAT_BYTS((2*BITS+7)/8), .CTL_BITS(8)) in_if(clk);
if_axi_stream #(.DAT_BYTS((BITS+7)/8), .CTL_BITS(8)) out_if(clk);

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err)
    $error(1, "%m %t ERROR: output .err asserted", $time);


accum_mult_mod #(
  .DAT_BITS ( BITS     ),
  .MODULUS  ( MODULUS  ),
  .CTL_BITS ( 8        ),
  .A_DSP_W  ( A_DSP_W  ),
  .B_DSP_W  ( B_DSP_W  ),
  .GRID_BIT ( GRID_BIT ),
  .RAM_A_W  ( RAM_A_W  ),
  .RAM_D_W  ( RAM_D_W  )
)
accum_mult_mod (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_mul ( in_if  ),
  .o_mul ( out_if ),
  .i_ram_d (),
  .i_ram_we (),
  .i_ram_se ()
);

task test_loop();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  logic [BITS-1:0] in_a, in_b, out;
  logic [BITS*2-1:0] expected;
  integer t;
  integer i, max;

  $display("Running test_loop...");
  i = 0;
  max = 1000;

  while (i < max) begin
    in_a = random_vector((BITS+7)/8);
    in_b = random_vector((BITS+7)/8);
    expected = (in_a * in_b);
    expected = expected % MODULUS;

    fork
      in_if.put_stream({in_b, in_a}, ((BITS*2)+7)/8, i);
      out_if.get_stream(get_dat, get_len, 0);
    join

    out = get_dat;

    t = out / MODULUS;
    out = out % MODULUS;

    assert(out == expected) else begin
      $display("Expected: 0x%0x", expected);
      $display("Was:      0x%0x (t=%0d)", out, t);
      $fatal(1, "ERROR: Output did not match");
    end
    $display("test_loop PASSED loop %d/%d - 0x%0x (t=%0d)", i, max, out, t);
    i = i + 1;
  end

  $display("test_loop PASSED");
end
endtask;

initial begin
  out_if.rdy = 0;
  in_if.reset_source();
  #(40*CLK_PERIOD);

  test_loop();

  #1us $finish();
end
endmodule