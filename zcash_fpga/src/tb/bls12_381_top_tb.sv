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

module bls12_381_top_tb ();

import common_pkg::*;
import bls12_381_pkg::*;

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

if_axi_stream #(.DAT_BYTS(8)) out_if(clk);

if_axi_mm #(.D_BITS(32), .A_BITS(8)) cfg_usr_if(clk);
if_axi_mm #(.D_BITS(32), .A_BITS(DATA_RAM_DEPTH * DATA_RAM_ALIGN_BYTE)) data_usr_if(clk);
if_axi_mm #(.D_BITS(32), .A_BITS(INST_RAM_DEPTH * INST_RAM_ALIGN_BYTE)) inst_usr_if(clk);

bls12_381_top bls12_381_top (
  .i_clk ( clk ),
  .i_rst ( rst ),
  // Only tx interface is used to send messages to SW on a SEND-INTERRUPT instruction
  .tx_if ( out_if ),
  // User access to the instruction and register RAM
  .inst_usr_if ( inst_usr_if ),
  .data_usr_if ( data_usr_if ),
  // Configuration memory
  .cfg_usr_if ( cfg_usr_if )
);


task test_fp_point_mult();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  inst_t inst;
  point_type_t pt;
  logic [DAT_BITS-1:0] data = 0;

  $display("Running test_0...");
  pt = SCALAR;
  data = 0;
  inst = '{code:FP_FPOINT_MULT, a:0, b:0, c:0};

  data_usr_if.put_data_multiple({pt, data}, 0);
  inst_usr_if.put_data_multiple(inst, 0);

  $display("test_0 PASSED");
end
endtask;


initial begin
  inst_usr_if.reset_source();
  data_usr_if.reset_source();
  cfg_usr_if.reset_source();
  #100ns;
  // Wait for memories to reset
  while(!bls12_381_top.inst_uram_reset.reset_done ||
       !bls12_381_top.data_uram_reset.reset_done)
    @(posedge clk);

  test_0();

  #1us $finish();
end
endmodule