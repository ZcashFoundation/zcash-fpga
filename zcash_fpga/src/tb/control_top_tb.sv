/*
  The control top testbench.
  
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
module control_top_tb();

import common_pkg::*;
import zcash_fpga_pkg::*;
import equihash_pkg::*;

localparam CORE_CLK_PERIOD = 600;
localparam UART_CLK_PERIOD = 1000;

localparam CORE_BYTS = 8;
localparam UART_BYTS = 1; 

logic core_clk, core_rst, uart_clk, uart_rst, usr_rst;

equihash_bm_t equihash_mask;
logic equihash_mask_val;

if_axi_stream #(.DAT_BYTS(CORE_BYTS)) equihash_axi(core_clk);

if_axi_stream #(.DAT_BYTS(CORE_BYTS)) secp256k1_tx_if(core_clk);
if_axi_stream #(.DAT_BYTS(CORE_BYTS)) secp256k1_rx_if(core_clk);

if_axi_stream #(.DAT_BYTS(UART_BYTS)) uart_rx_if (uart_clk);
if_axi_stream #(.DAT_BYTS(UART_BYTS)) uart_tx_if (uart_clk);

initial begin
  core_rst = 0;
  repeat(10) #CORE_CLK_PERIOD core_rst = ~core_rst;
end

initial begin
  core_clk = 0;
  forever #CORE_CLK_PERIOD core_clk = ~core_clk;
end

initial begin
  uart_rst = 0;
  repeat(10) #UART_CLK_PERIOD uart_rst = ~uart_rst;
end

initial begin
  uart_clk = 0;
  forever #UART_CLK_PERIOD uart_clk = ~uart_clk;
end

always_comb begin
  secp256k1_tx_if.reset_source();
  secp256k1_tx_if.rdy = 1;
end

control_top #(
  .IN_DAT_BYTS(UART_BYTS)
)
DUT (
  .i_clk_core ( core_clk   ),
  .i_rst_core ( core_rst   ),
  .i_rst_core_perm (core_rst),
  .o_usr_rst  ( usr_rst    ),
  .i_clk_if   ( uart_clk   ),
  .i_rst_if   ( uart_rst   ),
  .rx_if      ( uart_tx_if ),
  .tx_if      ( uart_rx_if ),
  .o_equihash_if ( equihash_axi ),
  .i_equihash_mask ( equihash_mask ),
  .i_equihash_mask_val ( equihash_mask_val ),
  .o_secp256k1_if( secp256k1_tx_if ),
  .i_secp256k1_if( secp256k1_tx_if )
);

// This is a tests sending a request for FPGA status
task test_status_message();
begin
  header_t  header;
  fpga_status_rpl_t fpga_status_rpl;
  integer signed get_len, in_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  logic fail = 0;
  $display("Running test_status_message...");
  header.cmd = FPGA_STATUS;
  header.len = $bits(header_t)/8;
 
  fork
    uart_tx_if.put_stream(header, $bits(header)/8);
    uart_rx_if.get_stream(get_dat, get_len, 0);
  join
  
  fpga_status_rpl = get_dat;
  
  fail |= fpga_status_rpl.hdr.cmd != FPGA_STATUS_RPL;
  fail |= fpga_status_rpl.hdr.len != $bits(fpga_status_rpl_t)/8;
  fail |= fpga_status_rpl.hdr.len != get_len;
  fail |= fpga_status_rpl.version != FPGA_VERSION;
  fail |= fpga_status_rpl.build_host != "test";
  fail |= fpga_status_rpl.build_date != "20180311"; 
  fail |= fpga_status_rpl.fpga_state != 0; 
  
  assert (~fail) else $fatal(1, "%m %t ERROR: test_status_message status reply was wrong:\n%p", $time, fpga_status_rpl);
  
  $display("test_status_message PASSED");
  
end
endtask

// Test sending a reset command to the FPGA
task test_reset_message();
begin
  header_t  header;
  fpga_reset_rpl_t fpga_reset_rpl;
  integer signed get_len, in_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  $display("Running test_reset_message...");
  header.cmd = RESET_FPGA;
  header.len = $bits(header_t)/8;
 
  fork
    uart_tx_if.put_stream(header, $bits(header)/8);
    uart_rx_if.get_stream(get_dat, get_len);
    begin
      while (!usr_rst) @(posedge core_clk);
      while (usr_rst) @(posedge core_clk);
    end
  join
  
  fpga_reset_rpl = get_dat;
 
  $display("test_reset_message PASSED");
end
endtask

// Test sending a eh command to the FPGA
task test_eh_verify_message();
begin
  verify_equihash_t  msg;
  verify_equihash_rpl_t verify_equihash_rpl;
  integer signed get_len, in_len, eh_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat, get_dat_eh;
  logic fail = 0;
  $display("Running test_eh_verify_message...");
  msg.hdr.cmd = VERIFY_EQUIHASH;
  msg.hdr.len = $bits(verify_equihash_t)/8;
  msg.index = 1;
 
  fork
    uart_tx_if.put_stream(msg, $bits(msg)/8);
    begin
      equihash_axi.get_stream(get_dat_eh, eh_len);
      equihash_mask_val = 1;
      equihash_mask = 0;
    end
    uart_rx_if.get_stream(get_dat, get_len);
  join
  
  equihash_mask_val = 0;
  
  verify_equihash_rpl = get_dat;
  
  fail |= eh_len != $bits(cblockheader_sol_t)/8;
  fail |= verify_equihash_rpl.hdr.cmd != VERIFY_EQUIHASH_RPL;
  fail |= verify_equihash_rpl.hdr.len != $bits(verify_equihash_rpl_t)/8;
  fail |= verify_equihash_rpl.index != 1;
  fail |= verify_equihash_rpl.bm != 0;
  
  assert (~fail) else $fatal(1, "%m %t ERROR: test_eh_verify_message was wrong:\n%p", $time, verify_equihash_rpl);
  
  $display("test_eh_verify_message PASSED");
end
endtask

// Main testbench calls
initial begin
  equihash_axi.rdy = 0;
  equihash_mask_val = 0;
  equihash_mask = 0;
  uart_tx_if.val = 0;
  uart_rx_if.rdy = 0;
  #200ns;
  
  test_reset_message();
  test_status_message();
  test_eh_verify_message();
  test_status_message();

  #1us $finish();

end

endmodule