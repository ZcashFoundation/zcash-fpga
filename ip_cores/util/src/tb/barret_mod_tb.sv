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

module barret_mod_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 100;

logic clk, rst;

localparam IN_BITS = 512;
localparam OUT_BITS = 256;
localparam [OUT_BITS-1:0] P = secp256k1_pkg::n;
localparam USE_MULT = 0;

if_axi_stream #(.DAT_BYTS(IN_BITS/8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(OUT_BITS/8)) out_if(clk);
if_axi_stream #(.DAT_BYTS(2*((OUT_BITS+16))/8)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS((OUT_BITS+8)/8)) mult_out_if(clk);

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

generate
  if (USE_MULT == 0) begin: MULT_GEN
    always_ff @ (posedge clk) begin
      if (rst) begin
        mult_in_if.rdy <= 0;
        mult_out_if.reset_source();
      end else begin
        mult_in_if.rdy <= 1;
        if (mult_in_if.rdy && mult_in_if.val) begin
          mult_out_if.dat <= mult_in_if.dat[0 +: OUT_BITS] * mult_in_if.dat[OUT_BITS +: OUT_BITS];
          mult_out_if.val <= 1;
        end
        if (mult_out_if.val && mult_out_if.rdy) mult_out_if.val <= 0;
      end
    end
  end else begin
  
  end
endgenerate

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

barret_mod #(
  .IN_BITS  ( IN_BITS  ),
  .OUT_BITS ( OUT_BITS ),
  .P        ( P        )
) 
barret_mod (
  .i_clk ( clk        ),
  .i_rst ( rst        ),
  .i_dat ( in_if.dat  ),
  .i_val ( in_if.val  ),
  .o_rdy ( in_if.rdy  ),
  .o_dat ( out_if.dat ),
  .o_val ( out_if.val ),
  .i_rdy ( out_if.rdy ),
  
  .o_mult     ( mult_in_if  ),
  .i_mult_res ( mult_out_if )
);


task test_loop();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [512*8-1:0] in;
  integer i, max;
  
  $display("Running test_loop...");
  i = 0;
  max = 10000;
  
  while (i < max) begin
    in = random_vector(IN_BITS/8);
    expected = (in % P);
    
    fork
      in_if.put_stream(in, IN_BITS/8);
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
  
  test_loop();

  #1us $finish();
end
endmodule