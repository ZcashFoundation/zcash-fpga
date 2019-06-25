// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.

// This runs several tests for the Zcash FPGA:
// Status message (AXI stream interface)
// AXI-lite interface
// BLS12_381 coprocessor

module test_zcash();

import tb_type_defines_pkg::*;
`include "cl_common_defines.vh" // CL Defines with register addresses

// AXI ID
parameter [5:0] AXI_ID = 6'h0;

import zcash_fpga_pkg::*;
import secp256k1_pkg::*;
import equihash_pkg::*;
import common_pkg::*;

zcash_fpga_pkg::header_t  header;
zcash_fpga_pkg::fpga_status_rpl_t fpga_status_rpl;

logic [31:0] rdata;
logic [1024*8-1:0] stream_data;
integer stream_len;


initial begin

  tb.power_up();

  // Setup the AXI streaming interface
  read_ocl_reg(.addr(`AXI_FIFO_OFFSET), .exp_data(32'h01D00000), .rdata(rdata)); //ISR
  write_ocl_reg(.addr(`AXI_FIFO_OFFSET), .data(32'hFFFFFFFF)); // Reset ISR
  read_ocl_reg(.addr(`AXI_FIFO_OFFSET+32'hC), .exp_data(32'h000001FC), .rdata(rdata)); //TDFV
  read_ocl_reg(.addr(`AXI_FIFO_OFFSET+32'h1C), .exp_data(32'h00000000), .rdata(rdata)); //RDFO
  write_ocl_reg(.addr(`AXI_FIFO_OFFSET+32'h4), .data(32'h0C000000)); //IER

  // Run our test cases
  test_status_message();
  test_block_secp256k1();

  $display("INFO: All tests passed");
  tb.kernel_reset();

  tb.power_down();

  $finish;
end

task read_ocl_reg(input logic [31:0] addr, output logic [31:0] rdata, input logic [31:0] exp_data = 32'hXXXXXXXX);

  tb.peek(.addr(addr), .data(rdata), .id(AXI_ID), .intf(AxiPort::PORT_OCL));
  $display ("INFO: read_ocl_reg::Read 0x%x from address 0x%x", rdata, addr);
  if (rdata != exp_data) $fatal(1, "ERROR: AXI-FIFO ISR Register returned wrong value");

endtask

task write_ocl_reg(input logic [31:0] addr, input logic [31:0] data);

  tb.poke(.addr(addr), .data(data), .id(AXI_ID), .intf(AxiPort::PORT_OCL));
  $display ("INFO: write_ocl_reg::Wrote 0x%x to address 0x%x", data, addr);

endtask

task write_stream(input logic [1024*8-1:0] data, input integer len);

  logic [31:0] rdata;
  integer len_;
  len_ = len;
  read_ocl_reg(.addr(`AXI_FIFO_OFFSET+32'hC), .rdata(rdata));
  if (len > rdata) $fatal(1, "ERROR: write_pcis::AXI-FIFO does not have enough space to write %d bytes (%d free)", len, rdata);

  while(len_ > 0) begin
    tb.poke_pcis(.addr(0), .data(data[511:0]), .strb(0));
    len_ = len_ - 512/8;
    data = data >> 512;
  end
  write_ocl_reg(.addr(`AXI_FIFO_OFFSET+32'h14), .data(len));

  $display ("INFO: write_pcis::Wrote %d bytes of data", len);

  // Check transmit complete bit and reset it
  read_ocl_reg(.addr(`AXI_FIFO_OFFSET), .rdata(rdata));
  if(rdata[27] == 0) $display("WARNING: write_stream transmit complete bit not set");
  write_ocl_reg(.addr(`AXI_FIFO_OFFSET), .data(32'h08000000));

endtask

task read_stream(output logic [1024*8-1:0] data, integer len);

  logic [31:0] rdata;
  logic [511:0] pcis_data;
  len = 0;
  data = 0;
  read_ocl_reg(.addr(`AXI_FIFO_OFFSET), .rdata(rdata));
  if (rdata[26] == 0) return;
  write_ocl_reg(.addr(`AXI_FIFO_OFFSET), .data(32'h04000000)); //clear ISR

  read_ocl_reg(.addr(`AXI_FIFO_OFFSET+ 32'h1C), .rdata(rdata)); //RDFO should be non-zero (slots used in FIFO)
  if (rdata == 0) return;

  read_ocl_reg(.addr(`AXI_FIFO_OFFSET+ 32'h24), .rdata(rdata)); //RLR - length of packet in bytes
  while(rdata > 0) begin
    tb.peek_pcis(.addr(32'h1000), .data(pcis_data));
    data[len*8 +: 512] = pcis_data;
    len = len + rdata > (512/8) ? 512/8 : rdata/8;
    rdata = rdata < 512/8 ? 0 : rdata - 512/8;
  end

endtask

/////////////////////////////////////////////////////////////////////////////////////////////////
// Various test cases below
/////////////////////////////////////////////////////////////////////////////////////////////////

// Build a status message and send it
task test_status_message();

  header.cmd = zcash_fpga_pkg::FPGA_STATUS;
  header.len = $bits(header_t)/8;

  write_stream(.data(header), .len(header.len));
  stream_len = 0;
  fork
    begin
      while(stream_len == 0) read_stream(.data(stream_data), .len(stream_len));
    end
    begin
      while(10000) @(posedge tb.card.fpga.clk_main_a0);
      $fatal(1, "ERROR: No reply received from status_request");
    end
  join_any
  disable fork;

  fpga_status_rpl = stream_data;

  $display("INFO: Received status reply");
  $display("%p", fpga_status_rpl);
  $display("INFO: FPGA Version: 0x%x", fpga_status_rpl.version);

  if (fpga_status_rpl.version != zcash_fpga_pkg::FPGA_VERSION)
    $fatal(1, "ERROR: FPGA Version was wrong");

  $display("INFO: test_status_message() PASSED");

endtask

// Test secp256k1 signature verification
task test_block_secp256k1();
begin
  logic fail = 0;
  verify_secp256k1_sig_t verify_secp256k1_sig;
  verify_secp256k1_sig_rpl_t verify_secp256k1_sig_rpl;

  $display("Running test_block_secp256k1...");
  verify_secp256k1_sig.hdr.cmd = VERIFY_SECP256K1_SIG;
  verify_secp256k1_sig.hdr.len = $bits(verify_secp256k1_sig_t)/8;
  verify_secp256k1_sig.index = 1;
  verify_secp256k1_sig.hash = 256'h4c7dbc46486ad9569442d69b558db99a2612c4f003e6631b593942f531e67fd4;
  verify_secp256k1_sig.r = 256'h1375af664ef2b74079687956fd9042e4e547d57c4438f1fc439cbfcb4c9ba8b;
  verify_secp256k1_sig.s = 256'hde0f72e442f7b5e8e7d53274bf8f97f0674f4f63af582554dbecbb4aa9d5cbcb;
  verify_secp256k1_sig.Qx = 256'h808a2c66c5b90fa1477d7820fc57a8b7574cdcb8bd829bdfcf98aa9c41fde3b4;
  verify_secp256k1_sig.Qy = 256'heed249ffde6e46d784cb53b4df8c9662313c1ce8012da56cb061f12e55a32249;


  write_stream(verify_secp256k1_sig, $bits(verify_secp256k1_sig)/8);
  stream_len = 0;
  fork
    begin
      while(stream_len == 0) read_stream(.data(stream_data), .len(stream_len));
    end
    begin
      while(100000) @(posedge tb.card.fpga.clk_main_a0);
      $fatal(1, "ERROR: No reply received from verify_secp256k1");
    end
  join_any
  disable fork;

  verify_secp256k1_sig_rpl = stream_data;

  fail |= verify_secp256k1_sig_rpl.hdr.cmd != VERIFY_SECP256K1_SIG_RPL;
  fail |= (verify_secp256k1_sig_rpl.bm != 0);
  fail |= (verify_secp256k1_sig_rpl.index != verify_secp256k1_sig.index);
  assert (~fail) else $fatal(1, "%m ERROR: test_block_secp256k1 failed :\n%p", verify_secp256k1_sig_rpl);


  $display("test_block_secp256k1 PASSED");
end
endtask;

endmodule
