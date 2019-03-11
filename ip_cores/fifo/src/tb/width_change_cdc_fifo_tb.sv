/*
  The width_change testbench.
  
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
module width_change_cdc_fifo_tb();
  
import common_pkg::*;
  
logic clk_a, rst_a;
logic clk_b, rst_b;

parameter DAT_BYTS_IN = 4;
parameter DAT_BYTS_OUT = 12;

parameter CLK_A_PERIOD = 1000;
parameter CLK_B_PERIOD = 1500;

if_axi_stream #(.DAT_BYTS(DAT_BYTS_IN), .CTL_BITS(8)) in_if(clk_a);
if_axi_stream #(.DAT_BYTS(DAT_BYTS_OUT), .CTL_BITS(8)) out_if(clk_b);

if_axi_stream #(.DAT_BYTS(DAT_BYTS_OUT), .CTL_BITS(8)) in1_if(clk_a);
if_axi_stream #(.DAT_BYTS(DAT_BYTS_IN), .CTL_BITS(8)) out1_if(clk_b);

initial begin
  rst_a = 0;
  repeat(10) #CLK_A_PERIOD rst_a = ~rst_a;
end

initial begin
  rst_b = 0;
  repeat(10) #CLK_B_PERIOD rst_b = ~rst_b;
end

initial begin
  clk_a = 0;
  forever #(CLK_A_PERIOD/2) clk_a = ~clk_a;
end

initial begin
  clk_b = 0;
  forever #(CLK_B_PERIOD/2) clk_b = ~clk_b;
end

width_change_cdc_fifo #(
  .IN_DAT_BYTS ( DAT_BYTS_IN  ),
  .OUT_DAT_BYTS( DAT_BYTS_OUT ),
  .CTL_BITS ( 8 ),
  .FIFO_ABITS ( 4 ),
  .USE_BRAM (1)
) 
DUT0 (
  .i_clk_a ( clk_a ),
  .i_rst_a ( rst_a ),
  .i_clk_b ( clk_b ),
  .i_rst_b ( rst_b ), 

  .i_axi_a ( in_if  ), 
  .o_axi_b ( out_if )
);

// This one has the in and out swapped
width_change_cdc_fifo #(
  .IN_DAT_BYTS ( DAT_BYTS_OUT ),
  .OUT_DAT_BYTS( DAT_BYTS_IN ),
  .CTL_BITS ( 8 ),
  .FIFO_ABITS ( 4 ),
  .USE_BRAM (0)
) 
DUT1 (
  .i_clk_a ( clk_a ),
  .i_rst_a ( rst_a ),
  .i_clk_b ( clk_b ),
  .i_rst_b ( rst_b ), 

  .i_axi_a ( in1_if  ), 
  .o_axi_b ( out1_if )
);

task test0();
begin
  integer signed get_len, in_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] data, get_dat;
  
  $display("Running test0...");
  
  data = 'hbeefdead12341234aa55aa55deadbeef;
  fork
    in_if.put_stream(data, 32);
    out_if.get_stream(get_dat, get_len);
  join
  common_pkg::compare_and_print(get_dat, data);
  
  data = 'hbeef;
  fork 
    in_if.put_stream(data, 2);
    out_if.get_stream(get_dat, get_len);
  join
  common_pkg::compare_and_print(get_dat, data);
  
  in_len = 100;
  data = random_vector(in_len);
  fork 
    in_if.put_stream(data, in_len);
    out_if.get_stream(get_dat, get_len);
  join
  common_pkg::compare_and_print(get_dat, data);
  
  $display("test0 PASSED");
  
end
endtask

task test1();
begin
  integer signed get_len, in_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] data, get_dat;
  
  $display("Running test1...");
  
  data = 'hbeefdead12341234aa55aa55deadbeef;
  fork
    in1_if.put_stream(data, 32);
    out1_if.get_stream(get_dat, get_len);
  join
  common_pkg::compare_and_print(get_dat, data);
  
  data = 'hbeef;
  fork 
    in1_if.put_stream(data, 2);
    out1_if.get_stream(get_dat, get_len);
  join
  common_pkg::compare_and_print(get_dat, data);
  
  in_len = 100;
  data = random_vector(in_len);
  fork 
    in1_if.put_stream(data, in_len);
    out1_if.get_stream(get_dat, get_len);
  join
  common_pkg::compare_and_print(get_dat, data);
  
  $display("test1 PASSED");
  
end
endtask

// Main testbench calls
initial begin
  $srandom(10);
  out_if.rdy = 0;
  in_if.val = 0;
  out1_if.rdy = 0;
  in1_if.val = 0;
  #(10*CLK_A_PERIOD + 10*CLK_B_PERIOD);
  
  test0(); 
  test1(); 

  #10us $finish();

end

endmodule