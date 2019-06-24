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


module test_zcash();

import tb_type_defines_pkg::*;
`include "cl_common_defines.vh" // CL Defines with register addresses

// AXI ID
parameter [5:0] AXI_ID = 6'h0;

import zcash_fpga_pkg::*;

zcash_fpga_pkg::header_t  header;
zcash_fpga_pkg::fpga_status_rpl_t fpga_status_rpl;

logic [31:0] rdata;
logic [1024*8-1:0] stream_data;
integer stream_len;
logic [15:0] vdip_value;
logic [15:0] vled_value;


   initial begin

      tb.power_up();
      
      
      read_ocl_reg(.addr(`AXI_FIFO_OFFSET), .exp_data(32'h01D00000), .rdata(rdata)); //ISR
      write_ocl_reg(.addr(`AXI_FIFO_OFFSET), .data(32'hFFFFFFFF)); // Reset ISR
      read_ocl_reg(.addr(`AXI_FIFO_OFFSET+32'hC), .exp_data(32'h000001FC), .rdata(rdata)); //TDFV
      read_ocl_reg(.addr(`AXI_FIFO_OFFSET+32'h1C), .exp_data(32'h00000000), .rdata(rdata)); //RDFO

      write_ocl_reg(.addr(`AXI_FIFO_OFFSET+32'h4), .data(32'h0C000000)); //IER

      // Build a status message and send it
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
$display("Version: 0x%x", fpga_status_rpl.version);

  if (fpga_status_rpl.version != zcash_fpga_pkg::FPGA_VERSION)
    $fatal(1, "FPGA Version was wrong");	  


 $display("INFO: Test passed");	
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

endmodule
