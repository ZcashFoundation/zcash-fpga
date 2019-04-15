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

module pipeline_if_tb ();
import common_pkg::*;

localparam CLK_PERIOD = 100;


logic clk, rst;

if_axi_stream #(.DAT_BYTS(8), .CTL_BITS(8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(8), .CTL_BITS(8)) out_if(clk);

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

localparam LEVEL = 2;

pipeline_if  #(
  .DAT_BYTS (in_if.DAT_BYTS),
  .CTL_BITS (in_if.CTL_BITS),
  .NUM_STAGES (LEVEL)
)
pipeline_if (
  .i_rst (rst),
  .i_if(in_if),
  .o_if(out_if)
);


task test_pipeline();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  integer unsigned size;
  integer i, max;

  $display("Running test_pipeline...");
  i = 0;
  max = 1000;

  #100ns;

  while (i < max) begin
    size = 1 + ($urandom() % (max-1));
    expected = random_vector(size);
    fork
      in_if.put_stream(expected, size, i);
      out_if.get_stream(get_dat, get_len);
    join

    common_pkg::compare_and_print(get_dat, expected);
    $display("test_pipeline PASSED loop %d/%d", i, max);
    i = i + 1;
  end

  $display("test_pipeline PASSED");
end
endtask;

initial begin
  out_if.rdy = 0;
  in_if.reset_source();
  #(40*CLK_PERIOD);

  test_pipeline();

  #1us $finish();
end
endmodule