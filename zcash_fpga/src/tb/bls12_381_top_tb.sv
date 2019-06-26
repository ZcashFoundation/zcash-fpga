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
import zcash_fpga_pkg::bls12_381_interrupt_rpl_t;
import zcash_fpga_pkg::BLS12_381_INTERRUPT_RPL;

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

if_axi_lite #(.A_BITS(32)) axi_lite_if(clk);


bls12_381_top bls12_381_top (
  .i_clk ( clk ),
  .i_rst ( rst ),
  // Only tx interface is used to send messages to SW on a SEND-INTERRUPT instruction
  .tx_if ( out_if ),
  // User access to the instruction and register RAM
  .axi_lite_if ( axi_lite_if )
);


task test_fp_fpoint_mult();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  inst_t inst;
  logic failed;
  data_t data;
  logic [31:0] rdata;
  jb_point_t out_p, exp_p;
  logic [DAT_BITS-1:0] in_k;
  bls12_381_interrupt_rpl_t interrupt_rpl;

  failed = 0;
  in_k = 381'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;
  exp_p =  point_mult(in_k, g_point);
  $display("Running test_fp_fpoint_mult...");

  axi_lite_if.peek(.addr(0), .data(rdata));
  assert(rdata == INST_AXIL_START) else $fatal("ERROR: AXI lite register returned wrong value");

  axi_lite_if.peek(.addr(4), .data(rdata));
  assert(rdata == DATA_AXIL_START) else $fatal("ERROR: AXI lite register returned wrong value");

  axi_lite_if.peek(.addr(8), .data(rdata));
  assert(rdata == DATA_RAM_DEPTH*DATA_RAM_ALIGN_BYTE) else $fatal("ERROR: AXI lite register returned wrong value");

  axi_lite_if.peek(.addr(12), .data(rdata));
  assert(rdata == INST_RAM_DEPTH*INST_RAM_ALIGN_BYTE) else $fatal("ERROR: AXI lite register returned wrong value");

  data = '{dat:in_k, pt:SCALAR};
  axi_lite_if.put_data_multiple(.data(data), .addr(DATA_AXIL_START), .len(48));

  inst = '{code:SEND_INTERRUPT, a:16'd1, b:16'hbeef, c:16'd0};
  axi_lite_if.put_data_multiple(.data(inst), .addr(INST_AXIL_START + 8), .len(8));

  // Write slot 0 to start
  inst = '{code:FP_FPOINT_MULT, a:16'd0, b:16'd1, c:16'd0};
  axi_lite_if.put_data_multiple(.data(inst), .addr(INST_AXIL_START), .len(8));

  fork
    begin
      out_if.get_stream(get_dat, get_len, 0);
      interrupt_rpl = get_dat;

      assert(interrupt_rpl.hdr.cmd == BLS12_381_INTERRUPT_RPL) else $fatal(1, "ERROR: Received non-interrupt message");
      assert(interrupt_rpl.index == 16'hbeef) else $fatal(1, "ERROR: Received wrong index value in message");
      assert(interrupt_rpl.data_type == FP_JB) else $fatal(1, "ERROR: Received wrong data type value in message");

      get_dat = get_dat >> $bits(bls12_381_interrupt_rpl_t);

      for (int i = 0; i < 3; i++)
        out_p[i*381 +: 381] = get_dat[i*(48*8) +: 381];

      if (out_p == exp_p) begin
        $display("INFO: Output point matched expected:");
        print_jb_point(out_p);
      end else begin
        $display("ERROR: Output point did NOT match expected:");
        print_jb_point(out_p);
        $display("Expected:");
        print_jb_point(exp_p);
        failed = 1;
      end
    end
    begin
      repeat(80000) @(posedge out_if.i_clk);
      $fatal("ERROR: Timeout while waiting for result");
    end
  join_any
  disable fork;

  axi_lite_if.peek(.addr(32'h14), .data(rdata));
  $display("INFO: Last cycle count was %d", rdata);

  if(failed)
   $fatal(1, "ERROR: test_fp_fpoint_mult FAILED");
  else
   $display("INFO: test_fp_fpoint_mult PASSED");
end
endtask;

task test_fp2_fpoint_mult();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  inst_t inst;
  logic failed;
  data_t data;
  logic [31:0] rdata;
  fp2_jb_point_t out_p, exp_p;
  logic [DAT_BITS-1:0] in_k;
  bls12_381_interrupt_rpl_t interrupt_rpl;

  failed = 0;
  in_k = 381'h33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333;
  exp_p =  fp2_point_mult(in_k, g2_point);
  $display("Running test_fp2_fpoint_mult...");

  // See what current instruction pointer is
  axi_lite_if.peek(.addr(32'h10), .data(rdata));

  data = '{dat:in_k, pt:SCALAR};
  axi_lite_if.put_data_multiple(.data(data), .addr(DATA_AXIL_START + 64), .len(48));  // Scalar to multiply by goes in data slot 1

  inst = '{code:SEND_INTERRUPT, a:16'd3, b:16'habcd, c:16'd0};
  axi_lite_if.put_data_multiple(.data(inst), .addr(INST_AXIL_START + (rdata+1)*8), .len(8));

  // Write to current slot to start
  inst = '{code:FP2_FPOINT_MULT, a:16'd1, b:16'd3, c:16'd0};
  axi_lite_if.put_data_multiple(.data(inst), .addr(INST_AXIL_START + (rdata)*8), .len(8));

  fork
    begin
      out_if.get_stream(get_dat, get_len, 0);
      interrupt_rpl = get_dat;

      assert(interrupt_rpl.hdr.cmd == BLS12_381_INTERRUPT_RPL) else $fatal(1, "ERROR: Received non-interrupt message");
      assert(interrupt_rpl.index == 16'habcd) else $fatal(1, "ERROR: Received wrong index value in message");
      assert(interrupt_rpl.data_type == FP2_JB) else $fatal(1, "ERROR: Received wrong data type value in message");

      get_dat = get_dat >> $bits(bls12_381_interrupt_rpl_t);

      for (int i = 0; i < 6; i++)
        out_p[i*381 +: 381] = get_dat[i*(48*8) +: 381];

      if (out_p == exp_p) begin
        $display("INFO: Output point matched expected:");
        print_fp2_jb_point(out_p);
      end else begin
        $display("ERROR: Output point did NOT match expected:");
        print_fp2_jb_point(out_p);
        $display("Expected:");
        print_fp2_jb_point(exp_p);
        failed = 1;
      end
    end
    begin
      repeat(100000) @(posedge out_if.i_clk);
      $fatal("ERROR: Timeout while waiting for result");
    end
  join_any
  disable fork;

  axi_lite_if.peek(.addr(32'h14), .data(rdata));
  $display("INFO: Last cycle count was %d", rdata);

  // See what current instruction pointer is
  axi_lite_if.peek(.addr(32'h10), .data(rdata));

  $display("INFO: Current instruction pointer is 0x%x, setting to 0 and writing NULL instruction", rdata);

  inst = '{code:NOOP_WAIT, a:16'd0, b:16'h0, c:16'd0};
  axi_lite_if.put_data_multiple(.data(inst), .addr(INST_AXIL_START), .len(8));

  axi_lite_if.poke(.addr(32'h10), .data(32'd0));
  repeat(10) @(posedge clk);
  axi_lite_if.peek(.addr(32'h10), .data(rdata));
  assert(rdata == 32'd0) else $fatal(1, "ERROR: could not set instruction pointer");

  if(failed)
   $fatal(1, "ERROR: test_fp2_fpoint_mult FAILED");
  else
   $display("INFO: test_fp2_fpoint_mult PASSED");
end
endtask;

initial begin
  axi_lite_if.reset_source();
  out_if.rdy = 0;
  #100ns;
  // Wait for memories to reset
  while(!bls12_381_top.inst_uram_reset.reset_done ||
       !bls12_381_top.data_uram_reset.reset_done)
    @(posedge clk);

  test_fp_fpoint_mult();
  test_fp2_fpoint_mult();


  #1us $finish();
end
endmodule