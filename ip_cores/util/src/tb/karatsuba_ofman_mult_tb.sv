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

module karatsuba_ofman_mult_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 100;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(512/8), .CTL_BITS(8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(512/8), .CTL_BITS(8)) out_if(clk);

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

localparam LEVEL = 1;
karatsuba_ofman_mult # (
  .BITS     ( 256   ),
  .CTL_BITS ( 8     ),
  .LEVEL    ( LEVEL )
)
karatsuba_ofman_mult (
  .i_clk  ( clk                   ),
  .i_rst  ( rst                   ),
  .i_dat_a( in_if.dat[0 +: 256]   ),
  .i_dat_b( in_if.dat[256 +: 256] ),
  .i_val  ( in_if.val  ),
  .o_val  ( out_if.val ),
  .i_ctl  ( in_if.ctl  ),
  .o_ctl  ( out_if.ctl ),
  .i_rdy  ( out_if.rdy ),
  .o_rdy  ( in_if.rdy  ),
  
  .o_dat  ( out_if.dat )
);

task test_pipeline();
begin
  
  $display("Running test_pipeline...");
  fork
    begin
      logic [255:0] in_a, in_b;
      integer i = 1;
      integer max = 10;
      while (i < max) begin
        in_a = i;
        in_b = i;
        //in_if.put_stream({in_b, in_a}, 512/8, i);
        in_if.sop = 1;
        in_if.eop = 1;
        in_if.ctl = i;
        in_if.dat = {in_a, in_b};
        in_if.val = 1;
        @(posedge in_if.i_clk);
        i = i + 1;
      end
      in_if.val = 0;
    end
    begin
      integer i = 1;
      integer max = 10;
      integer signed get_len;
      logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
      while (i < max) begin
        expected = i*i;
        out_if.get_stream(get_dat, get_len);
        common_pkg::compare_and_print(get_dat, expected);
        $display("test_pipeline PASSED loop %d/%d", i, max);
        i = i + 1;
      end
    end
  join    

  $display("test_pipeline PASSED");
end
endtask;

task test_loop();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [255:0] in_a, in_b;
  integer i, max;
  
  $display("Running test_loop...");
  i = 0;
  max = 10000;
  
  while (i < max) begin
    in_a = random_vector(256/8);
    in_b = random_vector(256/8);
    expected = (in_a * in_b);
    
    fork
      in_if.put_stream({in_b, in_a}, 512/8, i);
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
  in_if.val = 0;
  #(40*CLK_PERIOD);
  
  test_pipeline();
  test_loop();

  #1us $finish();
end
endmodule