// Amazon FPGA Hardware Development Kit
//
// Copyright 2016-2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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


// CL Streaming


module zcash_cl

  (
`include "cl_ports.vh"
   );

   logic clk;
   assign clk = clk_main_a0; // 125MHz
   assign rst_n = rst_main_n;


`ifndef CL_VERSION
   `define CL_VERSION 32'h10df_f002
`endif

`include "cl_id_defines.vh"

   assign cl_sh_id0 = `CL_SH_ID0;
   assign cl_sh_id1 = `CL_SH_ID1;

   logic         zcash_h2c_axis_valid;
   logic [511:0] zcash_h2c_axis_data;
   logic [63:0]  zcash_h2c_axis_keep;
   logic         zcash_h2c_axis_last;
   logic         zcash_h2c_axis_ready;
   logic [2:0]   zcash_h2c_axis_id;

   logic         zcash_c2h_axis_valid;
   logic [511:0] zcash_c2h_axis_data;
   logic [63:0]  zcash_c2h_axis_keep;
   logic         zcash_c2h_axis_last;
   logic         zcash_c2h_axis_ready;
   logic [2:0]   zcash_c2h_axis_id;

   logic         sh_ocl_awvalid_q;
   logic [31:0]  sh_ocl_awaddr_q;
   logic         ocl_sh_awready_q;
   logic         sh_ocl_wvalid_q;
   logic [31:0]  sh_ocl_wdata_q;
   logic [ 3:0]  sh_ocl_wstrb_q;
   logic         ocl_sh_wready_q;
   logic         ocl_sh_bvalid_q;
   logic [ 1:0]  ocl_sh_bresp_q;
   logic         sh_ocl_bready_q;
   logic         sh_ocl_arvalid_q;
   logic [31:0]  sh_ocl_araddr_q;
   logic         ocl_sh_arready_q;
   logic         ocl_sh_rvalid_q;
   logic [31:0]  ocl_sh_rdata_q;
   logic [ 1:0]  ocl_sh_rresp_q;
   logic         sh_ocl_rready_q;

   logic         sh_ocl_awvalid_q2;
   logic [31:0]  sh_ocl_awaddr_q2;
   logic         ocl_sh_awready_q2;
   logic         sh_ocl_wvalid_q2;
   logic [31:0]  sh_ocl_wdata_q2;
   logic [ 3:0]  sh_ocl_wstrb_q2;
   logic         ocl_sh_wready_q2;
   logic         ocl_sh_bvalid_q2;
   logic [ 1:0]  ocl_sh_bresp_q2;
   logic         sh_ocl_bready_q2;
   logic         sh_ocl_arvalid_q2;
   logic [31:0]  sh_ocl_araddr_q2;
   logic         ocl_sh_arready_q2;
   logic         ocl_sh_rvalid_q2;
   logic [31:0]  ocl_sh_rdata_q2;
   logic [ 1:0]  ocl_sh_rresp_q2;
   logic         sh_ocl_rready_q2;

   logic [15:0]   sh_cl_dma_pcis_awid_q   ;
   logic [63:0]  sh_cl_dma_pcis_awaddr_q ;
   logic [7:0]   sh_cl_dma_pcis_awlen_q  ;
   logic [2:0]   sh_cl_dma_pcis_awsize_q ;
   logic         sh_cl_dma_pcis_awvalid_q;
   logic         cl_sh_dma_pcis_awready_q;
   logic [511:0] sh_cl_dma_pcis_wdata_q  ;
   logic [63:0]  sh_cl_dma_pcis_wstrb_q  ;
   logic         sh_cl_dma_pcis_wlast_q  ;
   logic         sh_cl_dma_pcis_wvalid_q ;
   logic         cl_sh_dma_pcis_wready_q ;
   logic [15:0]   cl_sh_dma_pcis_bid_q    ;
   logic [1:0]   cl_sh_dma_pcis_bresp_q  ;
   logic         cl_sh_dma_pcis_bvalid_q ;
   logic         sh_cl_dma_pcis_bready_q ;
   logic [15:0]   sh_cl_dma_pcis_arid_q   ;
   logic [63:0]  sh_cl_dma_pcis_araddr_q ;
   logic [7:0]   sh_cl_dma_pcis_arlen_q  ;
   logic [2:0]   sh_cl_dma_pcis_arsize_q ;
   logic         sh_cl_dma_pcis_arvalid_q;
   logic         cl_sh_dma_pcis_arready_q;
   logic [15:0]   cl_sh_dma_pcis_rid_q    ;
   logic [511:0] cl_sh_dma_pcis_rdata_q  ;
   logic [1:0]   cl_sh_dma_pcis_rresp_q  ;
   logic         cl_sh_dma_pcis_rlast_q  ;
   logic         cl_sh_dma_pcis_rvalid_q ;
   logic         sh_cl_dma_pcis_rready_q ;

   logic [15:0] sh_cl_dma_pcis_awid_q2   ;
   logic [63:0] sh_cl_dma_pcis_awaddr_q2 ;
   logic [7:0]  sh_cl_dma_pcis_awlen_q2  ;
   logic [2:0]  sh_cl_dma_pcis_awsize_q2 ;
   logic        sh_cl_dma_pcis_awvalid_q2;
   logic        cl_sh_dma_pcis_awready_q2;
   logic [511:0] sh_cl_dma_pcis_wdata_q2  ;
   logic [63:0]  sh_cl_dma_pcis_wstrb_q2  ;
   logic         sh_cl_dma_pcis_wlast_q2  ;
   logic         sh_cl_dma_pcis_wvalid_q2 ;
   logic         cl_sh_dma_pcis_wready_q2 ;
   logic [15:0]   cl_sh_dma_pcis_bid_q2    ;
   logic [1:0]   cl_sh_dma_pcis_bresp_q2  ;
   logic         cl_sh_dma_pcis_bvalid_q2 ;
   logic         sh_cl_dma_pcis_bready_q2 ;
   logic [15:0]   sh_cl_dma_pcis_arid_q2   ;
   logic [63:0]  sh_cl_dma_pcis_araddr_q2 ;
   logic [7:0]   sh_cl_dma_pcis_arlen_q2  ;
   logic [2:0]   sh_cl_dma_pcis_arsize_q2 ;
   logic         sh_cl_dma_pcis_arvalid_q2;
   logic         cl_sh_dma_pcis_arready_q2;
   logic [15:0]  cl_sh_dma_pcis_rid_q2    ;
   logic [511:0] cl_sh_dma_pcis_rdata_q2  ;
   logic [1:0]   cl_sh_dma_pcis_rresp_q2  ;
   logic         cl_sh_dma_pcis_rlast_q2  ;
   logic         cl_sh_dma_pcis_rvalid_q2 ;
   logic         sh_cl_dma_pcis_rready_q2 ;

   logic         rst_main_n_sync;


`include "unused_flr_template.inc"
`include "unused_ddr_a_b_d_template.inc"
`include "unused_ddr_c_template.inc"
`include "unused_cl_sda_template.inc"
`include "unused_sh_bar1_template.inc"
`include "unused_apppf_irq_template.inc"
`include "unused_pcim_template.inc"

//-------------------------------------------------
// Reset Synchronization
//-------------------------------------------------

logic pre_sync_rst_n;

always @(posedge clk_main_a0)
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

//////////////////////////////////////////////////////////////////////////////////
// zcash logic

logic cfg_wire_zcash_enb;
localparam DAT_BYTS = 8;

logic clk_if, clk_100, clk_200, clk_300;
logic rst_if, rst_100, rst_200, rst_300;

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

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(1)) zcash_if_rx (clk_if);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(1)) zcash_if_tx (clk_if);
if_axi_stream #(.DAT_BYTS(64), .CTL_BITS(1)) aws_if_rx (clk_if);
if_axi_stream #(.DAT_BYTS(64), .CTL_BITS(1)) aws_if_tx (clk_if);

 zcash_aws_wrapper zcash_aws_wrapper (
  .i_rst ( rst_if ),
  .i_clk ( clk_if ),
  .rx_aws_if ( aws_if_tx ),
  .tx_aws_if ( aws_if_rx ),
  .rx_zcash_if ( zcash_if_tx ),
  .tx_zcash_if ( zcash_if_rx )
);

zcash_fpga_top #(
  .DAT_BYTS ( DAT_BYTS )
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
  .tx_if ( zcash_if_tx )
);

(* dont_touch = "true" *)    logic         rst_main_n_sync_bot_slr;
   lib_pipe #(.WIDTH(1), .STAGES(2)) PIPE_RST_N_BOT_SLR (.clk(clk_main_a0), .rst_n(1'b1), .in_bus(rst_main_n_sync), .out_bus(rst_main_n_sync_bot_slr));

(* dont_touch = "true" *)    logic         rst_main_n_sync_mid_slr;
   lib_pipe #(.WIDTH(1), .STAGES(4)) PIPE_RST_N_MID_SLR (.clk(clk_main_a0), .rst_n(1'b1), .in_bus(rst_main_n_sync), .out_bus(rst_main_n_sync_mid_slr));

   logic cfg_sde_rst;
   logic sde_rst_n_d;
   logic sde_rst_n;
   logic cfg_sde_wire_loopback;

   assign sde_rst_n_d = ~cfg_sde_rst & rst_main_n_sync_mid_slr;

   lib_pipe #(.WIDTH(1), .STAGES(1)) SDE_RST_LIB_PIPE
     (.clk (clk_main_a0), .rst_n(1'b1), .in_bus(sde_rst_n_d), .out_bus(sde_rst_n));

   logic pcim_wr_incomplete_error;
   logic pcim_wr_last_error;
   always @(posedge clk_main_a0)
     if (!sde_rst_n)
       pcim_wr_incomplete_error <= 0;
     else
       pcim_wr_incomplete_error <= pcim_wr_last_error; /*sh_cl_ctl1[8];*/


  always_comb begin
    sde_awvalid_q = 0;
    sde_awid_q = 0;
    sde_awaddr_q = 0;
    sde_wvalid_q = 0;

    sde_bready_q = 0;
    sde_arvalid_q = 0;
    sde_rready_q = 0;
  end

  // Test loopback

  always_comb begin
    // Defaults
    zcash_c2h_axis_valid = 0;
    zcash_h2c_axis_ready = 1;

    aws_if_tx.val = 0;
    aws_if_rx.rdy = 1;

    if (cfg_sde_wire_loopback) begin
      zcash_c2h_axis_valid = zcash_h2c_axis_valid;
      zcash_h2c_axis_ready = zcash_c2h_axis_ready;
      zcash_c2h_axis_data = zcash_h2c_axis_data;
      zcash_c2h_axis_keep = zcash_h2c_axis_keep;
      zcash_c2h_axis_last = zcash_h2c_axis_last;
      zcash_c2h_axis_id = zcash_h2c_axis_id;
    end

    if (cfg_wire_zcash_enb) begin
      zcash_c2h_axis_valid = aws_if_rx.val;
      aws_if_rx.rdy = zcash_c2h_axis_ready;
      zcash_c2h_axis_data = aws_if_rx.dat;
      zcash_c2h_axis_keep = aws_if_rx.get_keep_from_mod();
      zcash_c2h_axis_last = aws_if_rx.eop;
      zcash_c2h_axis_id = 3'd0;

      aws_if_tx.val = zcash_h2c_axis_valid;
      zcash_h2c_axis_ready = aws_if_tx.rdy;
      aws_if_tx.dat = zcash_h2c_axis_data;
      aws_if_tx.set_mod_from_keep(zcash_h2c_axis_keep);
      aws_if_tx.eop = zcash_h2c_axis_last;
    end
  end

  axi_mm2s_mapper axi_mm2s_mapper (
    .aclk     ( clk_main_a0),                    // input wire aclk
    .aresetn  ( sde_rst_n  ),              // input wire aresetn

    .s_axi_awid   (sh_cl_dma_pcis_awid_q2),        // input wire [15 : 0] s_axi_awid
    .s_axi_awaddr (sh_cl_dma_pcis_awaddr_q2),    // input wire [63 : 0] s_axi_awaddr
    .s_axi_awlen  (sh_cl_dma_pcis_awlen_q2),      // input wire [7 : 0] s_axi_awlen
    .s_axi_awsize (sh_cl_dma_pcis_awsize_q2),    // input wire [2 : 0] s_axi_awsize
    .s_axi_awburst( 2'd0 ),  // input wire [1 : 0] s_axi_awburst
    .s_axi_awlock ( 1'd0 ),    // input wire [0 : 0] s_axi_awlock
    .s_axi_awcache( 4'd0 ),  // input wire [3 : 0] s_axi_awcache
    .s_axi_awprot ( 3'd0 ),    // input wire [2 : 0] s_axi_awprot
    .s_axi_awqos  ( 4'd0 ),      // input wire [3 : 0] s_axi_awqos
    .s_axi_awvalid(sh_cl_dma_pcis_awvalid_q2),  // input wire s_axi_awvalid
    .s_axi_awready(cl_sh_dma_pcis_awready_q2),  // output wire s_axi_awready
    .s_axi_wdata  (sh_cl_dma_pcis_wdata_q2),      // input wire [511 : 0] s_axi_wdata
    .s_axi_wstrb  (sh_cl_dma_pcis_wstrb_q2),      // input wire [63 : 0] s_axi_wstrb
    .s_axi_wlast  (sh_cl_dma_pcis_wlast_q2),      // input wire s_axi_wlast
    .s_axi_wvalid (sh_cl_dma_pcis_wvalid_q2),    // input wire s_axi_wvalid
    .s_axi_wready (cl_sh_dma_pcis_wready_q2),    // output wire s_axi_wready
    .s_axi_bid    (cl_sh_dma_pcis_bid_q2),          // output wire [15 : 0] s_axi_bid
    .s_axi_bresp  (cl_sh_dma_pcis_bresp_q2),      // output wire [1 : 0] s_axi_bresp
    .s_axi_bvalid (cl_sh_dma_pcis_bvalid_q2),    // output wire s_axi_bvalid
    .s_axi_bready (sh_cl_dma_pcis_bready_q2),    // input wire s_axi_bready
    .s_axi_arid   (sh_cl_dma_pcis_arid_q2),        // input wire [15 : 0] s_axi_arid
    .s_axi_araddr (sh_cl_dma_pcis_araddr_q2),    // input wire [63 : 0] s_axi_araddr
    .s_axi_arlen  (sh_cl_dma_pcis_arlen_q2),      // input wire [7 : 0] s_axi_arlen
    .s_axi_arsize (sh_cl_dma_pcis_arsize_q2),    // input wire [2 : 0] s_axi_arsize
    .s_axi_arburst( 2'd0 ),  // input wire [1 : 0] s_axi_arburst
    .s_axi_arlock ( 1'd0 ),    // input wire [0 : 0] s_axi_arlock
    .s_axi_arcache( 4'd0 ),  // input wire [3 : 0] s_axi_arcache
    .s_axi_arprot ( 3'd0 ),    // input wire [2 : 0] s_axi_arprot
    .s_axi_arqos  ( 4'd0 ),      // input wire [3 : 0] s_axi_arqos
    .s_axi_arvalid(sh_cl_dma_pcis_arvalid_q2),  // input wire s_axi_arvalid
    .s_axi_arready(cl_sh_dma_pcis_arready_q2),  // output wire s_axi_arready
    .s_axi_rid    (cl_sh_dma_pcis_rid_q2),          // output wire [15 : 0] s_axi_rid
    .s_axi_rdata  (cl_sh_dma_pcis_rdata_q2),      // output wire [511 : 0] s_axi_rdata
    .s_axi_rresp  (cl_sh_dma_pcis_rresp_q2),      // output wire [1 : 0] s_axi_rresp
    .s_axi_rlast  (cl_sh_dma_pcis_rlast_q2),      // output wire s_axi_rlast
    .s_axi_rvalid (cl_sh_dma_pcis_rvalid_q2),    // output wire s_axi_rvalid
    .s_axi_rready (sh_cl_dma_pcis_rready_q2),    // input wire s_axi_rready

    .s_axis_tvalid  (zcash_c2h_axis_valid),  // input wire s_axis_tvalid
    .s_axis_tready  (zcash_c2h_axis_ready),  // output wire s_axis_tready
    .s_axis_tdata   (zcash_c2h_axis_data),    // input wire [511 : 0] s_axis_tdata
    .s_axis_tkeep   (zcash_c2h_axis_keep),    // input wire [63 : 0] s_axis_tkeep
    .s_axis_tlast   (zcash_c2h_axis_last),    // input wire s_axis_tlast
    .s_axis_tid     (zcash_c2h_axis_id),        // input wire [2 : 0] s_axis_tid

    .m_axis_tvalid  (zcash_h2c_axis_valid),  // output wire m_axis_tvalid
    .m_axis_tready  (zcash_h2c_axis_ready),  // input wire m_axis_tready
    .m_axis_tdata   (zcash_h2c_axis_data),    // output wire [511 : 0] m_axis_tdata
    .m_axis_tkeep   (zcash_h2c_axis_keep),    // output wire [63 : 0] m_axis_tkeep
    .m_axis_tlast   (zcash_h2c_axis_last),    // output wire m_axis_tlast
    .m_axis_tid     (zcash_h2c_axis_id)        // output wire [2 : 0] m_axis_tid
  );


//-------------------------------------
// OCL AXI-L Handling (CSRs)
//-------------------------------------
//--------------------------------------------------------------
// PCIe OCL AXI-L Slave Accesses (accesses from PCIe AppPF BAR0)
//--------------------------------------------------------------
// Only supports single-beat accesses.

   // Address Range
   // 0x0000 - 0x0ffc : CL_SDE_SRM
   // 0x2000 - General Purpose Config Reg  0
   //          Bit 0 - Reset SDE
   //
   // 0x2004 - General Purpose Config Reg  1
   // 0x2008 - General Purpose Config Reg  2
   // 0x200c - General Purpose Config Reg  3

   logic        awvalid;
   logic [31:0] awaddr;
   logic        wvalid;
   logic [31:0] wdata;
   logic [3:0]  wstrb;
   logic        bready;
   logic        arvalid;
   logic [31:0] araddr;
   logic        rready;

   logic        awready;
   logic        wready;
   logic        bvalid;
   logic [1:0]  bresp;
   logic        arready;
   logic        rvalid;
   logic [31:0] rdata;
   logic [1:0]  rresp;

   // Inputs
   assign awvalid         = sh_ocl_awvalid_q2;
   assign awaddr[31:0]    = sh_ocl_awaddr_q2;
   assign wvalid          = sh_ocl_wvalid_q2;
   assign wdata[31:0]     = sh_ocl_wdata_q2;
   assign wstrb[3:0]      = sh_ocl_wstrb_q2;
   assign bready          = sh_ocl_bready_q2;
   assign arvalid         = sh_ocl_arvalid_q2;
   assign araddr[31:0]    = sh_ocl_araddr_q2;
   assign rready          = sh_ocl_rready_q2;

   // Outputs
   assign ocl_sh_awready_q2 = awready;
   assign ocl_sh_wready_q2  = wready;
   assign ocl_sh_bvalid_q2  = bvalid;
   assign ocl_sh_bresp_q2   = bresp[1:0];
   assign ocl_sh_arready_q2 = arready;
   assign ocl_sh_rvalid_q2  = rvalid;
   assign ocl_sh_rdata_q2   = rdata;
   assign ocl_sh_rresp_q2   = rresp[1:0];

// Write Request
logic        wr_active;
logic [31:0] wr_addr;
logic wr_req;              //Note these are pulses
logic rd_req;              //Note these are pulses
logic[31:0] wdata_q;

logic wr_req_lvl;          //Level versions of the requests
logic rd_req_lvl;

logic        arvalid_q;
logic [31:0] araddr_q;


logic wr_done;
logic rd_done;
logic[31:0] cfg_ctl_reg[3:0] = '{default:'0};

always @(posedge clk_main_a0)
  if (!rst_main_n_sync_mid_slr) begin
     wr_active <= 0;
     wr_addr   <= 0;
     wr_req <= 0;
     wdata_q <= 0;
     wr_req_lvl <= 0;
  end
  else begin
     wr_active <=  wr_active && bvalid  && bready ? 1'b0     :
                  ~wr_active && awvalid           ? 1'b1     :
                                                    wr_active;
     wr_addr <= awvalid && ~wr_active ? awaddr : wr_addr     ;

     //Request is a pulse
     wr_req <= (wr_active && wvalid && wready);

     wdata_q <= (wvalid && wready)? wdata: wdata_q;

     wr_req_lvl <= (wr_active && wvalid && wready) || (wr_req_lvl && !wr_done);
  end

assign awready = ~wr_active;
assign wready  =  wr_active && wvalid;

// Write Response
always @(posedge clk_main_a0)
  if (!rst_main_n_sync_mid_slr)
    bvalid <= 0;
  else
    bvalid <=  bvalid &&  bready            ? 1'b0  :
                         ~bvalid && wr_done ? 1'b1  :
                                             bvalid;
assign bresp = 0;


// Read Request
always @(posedge clk_main_a0)
   if (!rst_main_n_sync_mid_slr) begin
      arvalid_q <= 0;
      araddr_q  <= 0;
      rd_req <= 0;
      rd_req_lvl <= 0;
   end
   else begin
      arvalid_q <= arvalid;
      araddr_q  <= arvalid ? araddr : araddr_q;
      rd_req <= (arvalid && arready);
      rd_req_lvl <= (arvalid && arready) || (rd_req_lvl && !rd_done);
   end

assign arready = !arvalid_q && !rvalid;
// Read Response
always @(posedge clk_main_a0)
   if (!rst_main_n_sync_mid_slr)
   begin
      rvalid <= 0;
      rdata  <= 0;
      rresp  <= 0;
   end
   else if (rvalid && rready)
   begin
      rvalid <= 0;
      rdata  <= 0;
      rresp  <= 0;
   end
   else if (rd_done)
   begin
      rvalid <= 1;
      rdata  <= {16'hbeef, cfg_ctl_reg[araddr_q[3:2]][15:0]};
   end

   assign rd_done = rd_req;
   assign wr_done = wr_req;


//5 general purpose control registers
always @(posedge clk_main_a0)
   if (wr_req)
      cfg_ctl_reg[wr_addr[3:2]] <= wdata_q;

assign cfg_sde_wire_loopback = cfg_ctl_reg[0][1];
assign cfg_wire_zcash_enb = cfg_ctl_reg[2][0];


//Needed for board_tb simulation
logic[3:0] all_ddr_is_ready;

endmodule // cl_sde
