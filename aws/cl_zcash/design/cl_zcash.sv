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

module cl_zcash

(
   `include "cl_ports.vh" // Fixed port definition

);

`include "cl_common_defines.vh"      // CL Defines for all examples
`include "cl_id_defines.vh"          // Defines for ID0 and ID1 (PCI ID's)
`include "cl_zcash_defines.vh"       // CL Defines for cl_hello_world

localparam USE_AXI4 = "NO";

logic rst_main_n_sync;

logic clk_if, clk_100, clk_200, clk_300;
logic rst_if, rst_100, rst_200, rst_300;

if_axi_stream #(.DAT_BYTS(8), .CTL_BITS(1)) zcash_if_rx (clk_if);
if_axi_stream #(.DAT_BYTS(8), .CTL_BITS(1)) zcash_if_tx (clk_if);

if_axi_lite #(.A_BITS(32)) zcash_axi_lite_if (clk_if);
if_axi_lite #(.A_BITS(32)) rx_axi_lite_if (clk_if);
if_axi4 #(.A_WIDTH(64), .D_WIDTH(512), .ID_WIDTH(6)) rx_axi4_if (clk_if);

//--------------------------------------------0
// Start with Tie-Off of Unused Interfaces
//---------------------------------------------
// the developer should use the next set of `include
// to properly tie-off any unused interface
// The list is put in the top of the module
// to avoid cases where developer may forget to
// remove it from the end of the file

`include "unused_flr_template.inc"
`include "unused_ddr_a_b_d_template.inc"
`include "unused_ddr_c_template.inc"
`include "unused_pcim_template.inc"
if (USE_AXI4 == "NO")
  `include "unused_dma_pcis_template.inc"
`include "unused_cl_sda_template.inc"
`include "unused_sh_bar1_template.inc"
`include "unused_apppf_irq_template.inc"


//-------------------------------------------------
// ID Values (cl_id_defines.vh)
//-------------------------------------------------
  assign cl_sh_id0[31:0] = `CL_SH_ID0;
  assign cl_sh_id1[31:0] = `CL_SH_ID1;

//-------------------------------------------------
// Reset Synchronization
//-------------------------------------------------
logic pre_sync_rst_n;

always_ff @(negedge rst_main_n or posedge clk_main_a0)
   if (!rst_main_n)
   begin
      pre_sync_rst_n  <= 0;
      rst_main_n_sync <= 0;
   end
   else
   begin
      pre_sync_rst_n  <= 1;
      rst_main_n_sync <= pre_sync_rst_n;
   end

//-------------------------------------------------
// PCIe OCL AXI-L (SH to CL) Timing Flops
//-------------------------------------------------

// Write address
logic        sh_ocl_awvalid_q;
logic [31:0] sh_ocl_awaddr_q;
logic        ocl_sh_awready_q;

// Write data
logic        sh_ocl_wvalid_q;
logic [31:0] sh_ocl_wdata_q;
logic [ 3:0] sh_ocl_wstrb_q;
logic        ocl_sh_wready_q;

// Write response
logic        ocl_sh_bvalid_q;
logic [ 1:0] ocl_sh_bresp_q;
logic        sh_ocl_bready_q;

// Read address
logic        sh_ocl_arvalid_q;
logic [31:0] sh_ocl_araddr_q;
logic        ocl_sh_arready_q;

// Read data/response
logic        ocl_sh_rvalid_q;
logic [31:0] ocl_sh_rdata_q;
logic [ 1:0] ocl_sh_rresp_q;
logic        sh_ocl_rready_q;

axi_register_slice_light AXIL_OCL_REG_SLC (
 .aclk          (clk_main_a0),
 .aresetn       (rst_main_n_sync),
 .s_axi_awaddr  (sh_ocl_awaddr),
 .s_axi_awprot   (2'h0),
 .s_axi_awvalid (sh_ocl_awvalid),
 .s_axi_awready (ocl_sh_awready),
 .s_axi_wdata   (sh_ocl_wdata),
 .s_axi_wstrb   (sh_ocl_wstrb),
 .s_axi_wvalid  (sh_ocl_wvalid),
 .s_axi_wready  (ocl_sh_wready),
 .s_axi_bresp   (ocl_sh_bresp),
 .s_axi_bvalid  (ocl_sh_bvalid),
 .s_axi_bready  (sh_ocl_bready),
 .s_axi_araddr  (sh_ocl_araddr),
 .s_axi_arvalid (sh_ocl_arvalid),
 .s_axi_arready (ocl_sh_arready),
 .s_axi_rdata   (ocl_sh_rdata),
 .s_axi_rresp   (ocl_sh_rresp),
 .s_axi_rvalid  (ocl_sh_rvalid),
 .s_axi_rready  (sh_ocl_rready),
 .m_axi_awaddr  (rx_axi_lite_if.awaddr),
 .m_axi_awprot  (),
 .m_axi_awvalid (rx_axi_lite_if.awvalid),
 .m_axi_awready (rx_axi_lite_if.awready),
 .m_axi_wdata   (rx_axi_lite_if.wdata),
 .m_axi_wstrb   (rx_axi_lite_if.wstrb),
 .m_axi_wvalid  (rx_axi_lite_if.wvalid),
 .m_axi_wready  (rx_axi_lite_if.wready),
 .m_axi_bresp   (rx_axi_lite_if.bresp),
 .m_axi_bvalid  (rx_axi_lite_if.bvalid),
 .m_axi_bready  (rx_axi_lite_if.bready),
 .m_axi_araddr  (rx_axi_lite_if.araddr),
 .m_axi_arvalid (rx_axi_lite_if.arvalid),
 .m_axi_arready (rx_axi_lite_if.arready),
 .m_axi_rdata   (rx_axi_lite_if.rdata),
 .m_axi_rresp   (rx_axi_lite_if.rresp),
 .m_axi_rvalid  (rx_axi_lite_if.rvalid),
 .m_axi_rready  (rx_axi_lite_if.rready)
);

always_comb begin
  clk_if = clk_main_a0;
  clk_100 = clk_main_a0;  // 125MHz
  clk_200 = clk_main_a0; // 187MHz
  clk_300 = clk_extra_b0; // 300MHz
end

always_ff @(posedge clk_if) rst_if  <= !rst_main_n;
always_ff @(posedge clk_100) rst_100  <= !rst_main_n;
always_ff @(posedge clk_200) rst_200  <= !rst_main_n;
always_ff @(posedge clk_300) rst_300  <= !rst_main_n;

always_comb begin
  rx_axi4_if.awid = sh_cl_dma_pcis_awid;
  rx_axi4_if.awaddr   = sh_cl_dma_pcis_awaddr;
  rx_axi4_if.awlen    = sh_cl_dma_pcis_awlen;
  rx_axi4_if.awsize   = sh_cl_dma_pcis_awsize;
  rx_axi4_if.awvalid  = sh_cl_dma_pcis_awvalid;
  cl_sh_dma_pcis_awready = rx_axi4_if.awready;
  rx_axi4_if.wdata  = sh_cl_dma_pcis_wdata;
  rx_axi4_if.wstrb  = sh_cl_dma_pcis_wstrb;
  rx_axi4_if.wlast  = sh_cl_dma_pcis_wlast;
  rx_axi4_if.wvalid = sh_cl_dma_pcis_wvalid;
  cl_sh_dma_pcis_wready = rx_axi4_if.wready;
  cl_sh_dma_pcis_bid = rx_axi4_if.bid;
  cl_sh_dma_pcis_bresp = rx_axi4_if.bresp;
  cl_sh_dma_pcis_bvalid = rx_axi4_if.bvalid;
  rx_axi4_if.bready = sh_cl_dma_pcis_bready;
  rx_axi4_if.arid   = sh_cl_dma_pcis_arid;
  rx_axi4_if.araddr = sh_cl_dma_pcis_araddr;
  rx_axi4_if.arlen = sh_cl_dma_pcis_arlen;
  rx_axi4_if.arsize  = sh_cl_dma_pcis_arsize;
  rx_axi4_if.arvalid  =  sh_cl_dma_pcis_arvalid;
  cl_sh_dma_pcis_arready = rx_axi4_if.arready;
  cl_sh_dma_pcis_rid = rx_axi4_if.rid;
  cl_sh_dma_pcis_rdata = rx_axi4_if.rdata;
  cl_sh_dma_pcis_rresp  = rx_axi4_if.rresp;
  cl_sh_dma_pcis_rlast  = rx_axi4_if.rlast;
  cl_sh_dma_pcis_rvalid = rx_axi4_if.rvalid;
  rx_axi4_if.rready =  sh_cl_dma_pcis_rready;
end

cl_zcash_aws_wrapper #(
  .USE_AXI4 ( USE_AXI4 )
)
cl_zcash_aws_wrapper (
  .i_rst ( rst_if ),
  .i_clk ( clk_if ),
  .rx_axi_lite_if    ( rx_axi_lite_if    ),
  .rx_axi4_if        ( rx_axi4_if        ),
  .zcash_axi_lite_if ( zcash_axi_lite_if ),
  .rx_zcash_if       ( zcash_if_tx       ),
  .tx_zcash_if       ( zcash_if_rx       )
);


zcash_fpga_top #(
  .DAT_BYTS ( 8 )
)
zcash_fpga_top (
  // Clocks and resets
  .i_clk_100 ( clk_100 ),
  .i_rst_100 ( rst_100 ),
  .i_clk_200 ( clk_200 ),
  .i_rst_200 ( rst_200 ),
  .i_clk_300 ( clk_300 ),
  .i_rst_300 ( rst_300 ),
  .i_clk_if  ( clk_if ),
  .i_rst_if  ( rst_if ),
  .rx_if ( zcash_if_rx ),
  .tx_if ( zcash_if_tx ),
  .axi_lite_if (zcash_axi_lite_if)
);

endmodule
