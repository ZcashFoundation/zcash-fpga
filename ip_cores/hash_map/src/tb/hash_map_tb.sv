/*
  The hash_map testbench.
  
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

module hash_map_tb();

parameter KEY_BITS = 4;
parameter DAT_BITS = KEY_BITS;
parameter HASH_MEM_SIZE = 4;
parameter LL_MEM_SIZE = 8;

logic clk, rst;

logic [KEY_BITS-1:0] i_key;
logic                i_val;
logic [DAT_BITS-1:0] i_dat;
logic                o_rdy;
logic [DAT_BITS-1:0] o_dat;
logic                o_val;
logic                o_fnd;
logic [1:0]          i_opcode;
  
  // Configuration
logic                i_cfg_clr, o_cfg_full;
  
initial begin
  rst = 0;
  #100ns rst = 1;
  #100ns rst = 0;
end

initial begin
  clk = 0;
  forever #10ns clk = ~clk;
end

hash_map #(
  .KEY_BITS      ( KEY_BITS      ),
  .DAT_BITS      ( DAT_BITS      ),
  .HASH_MEM_SIZE ( HASH_MEM_SIZE ),
  .LL_MEM_SIZE   ( LL_MEM_SIZE   )
)
DUT (
  .i_clk ( clk ),
  .i_rst ( rst ),
  
  .i_key    ( i_key    ),
  .i_val    ( i_val    ),
  .i_dat    ( i_dat    ),
  .i_opcode ( i_opcode ),
  .o_rdy    ( o_rdy ),
  .o_dat    ( o_dat ),
  .o_val    ( o_val ),
  .o_fnd    ( o_fnd ),
  .i_cfg_clr     ( i_cfg_clr     ),
  .o_cfg_full    ( o_cfg_full    )
);
  
task add(input [KEY_BITS-1:0] key, [DAT_BITS-1:0] dat);
  i_val = 0;
  @(negedge clk);
  i_opcode = 1;  
  i_key = key;
  i_dat = dat;
  i_val = 1;
  @(posedge clk);
  while (1) begin
    if (o_rdy) break;
    @(posedge clk);
  end
  @(negedge clk) i_val = 0;
  while (!o_val) @(posedge clk);
endtask 

task delete(input [KEY_BITS-1:0] key);
  i_val = 0;
  @(negedge clk);
  i_opcode = 2;  
  i_key = key;
  i_val = 1;
  @(posedge clk);
  while (1) begin
    if (o_rdy) break;
    @(posedge clk);
  end
  @(negedge clk) i_val = 0;
  while (!o_val) @(posedge clk);
endtask 

initial begin
  i_opcode = 0;
  i_key = 0;
  i_val = 0;
  i_cfg_clr = 0;
  
  #200ns;
  
  repeat (5) @(posedge clk);
  
  for (int i = 0; i < 11; i++) begin
    add(i,i);
    @(posedge clk);
  end
 
 repeat (10) @(posedge clk);
 // Try deleting from col and ll
  delete(6);
  delete(2);
  add(6, 0);
  add(2, 0);

end

endmodule