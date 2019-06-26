/*
  Takes in PCIs and OCL connections and converts to interfaces for use in the zcash FPGA project.

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

module cl_zcash_aws_wrapper (
  input i_rst,
  input i_clk,
  // AWS facing interfaces
  if_axi_lite.sink     rx_axi_lite_if,      // OCL interface
  if_axi4.sink         rx_axi4_if,          // PCIS interface
  // Zcash interfaces
  if_axi_lite.source   zcash_axi_lite_if,
  if_axi_stream.sink   rx_zcash_if,
  if_axi_stream.source tx_zcash_if
);

`include "cl_zcash_defines.vh"

if_axi_lite #(.A_BITS(32)) axi_fifo_if (i_clk);

if_axi_stream #(.DAT_BYTS(64), .CTL_BITS(1)) rx_aws_if (i_clk);
if_axi_stream #(.DAT_BYTS(64), .CTL_BITS(1)) tx_aws_if (i_clk);

logic [7:0] rx_zcash_if_keep, tx_zcash_if_keep;
logic [63:0] rx_aws_if_keep, tx_aws_if_keep;


always_comb begin
  rx_zcash_if_keep = rx_zcash_if.get_keep_from_mod();
  tx_zcash_if.set_mod_from_keep( tx_zcash_if_keep );
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    tx_zcash_if.ctl <= 0;
    tx_zcash_if.err <= 0;
    tx_zcash_if.sop <= 1;
    tx_aws_if.ctl <= 0;
    tx_aws_if.err <= 0;
    tx_aws_if.sop <= 1;
  end else begin
    if (tx_zcash_if.val && tx_zcash_if.rdy) tx_zcash_if.sop <= tx_zcash_if.eop;
    if (tx_aws_if.val && tx_aws_if.rdy) tx_aws_if.sop <= tx_aws_if.eop;
  end
end

// Map the AXI-lite signals
logic        wr_active, rd_active;
logic [31:0] wr_addr, araddr;

logic axi_fifo_dec;
logic zcash_dec;

always_comb begin
  zcash_dec = (wr_active && wr_addr >= `ZCASH_OFFSET && wr_addr < (`ZCASH_OFFSET + `AXI_MEMORY_SIZE)) ||
              (rd_active && araddr >= `ZCASH_OFFSET && araddr < (`ZCASH_OFFSET + `AXI_MEMORY_SIZE));

  axi_fifo_dec = (wr_active && wr_addr >= `AXI_FIFO_OFFSET && wr_addr < (`AXI_FIFO_OFFSET + `AXI_MEMORY_SIZE)) ||
                 (rd_active && araddr >= `AXI_FIFO_OFFSET && araddr < (`AXI_FIFO_OFFSET + `AXI_MEMORY_SIZE));
end

always_comb begin
  zcash_axi_lite_if.awvalid = rx_axi_lite_if.awvalid && zcash_dec;
  zcash_axi_lite_if.awaddr  = rx_axi_lite_if.awaddr - `ZCASH_OFFSET;
  zcash_axi_lite_if.wvalid  = rx_axi_lite_if.wvalid && zcash_dec;
  zcash_axi_lite_if.wdata   = rx_axi_lite_if.wdata;
  zcash_axi_lite_if.wstrb   = rx_axi_lite_if.wstrb;
  zcash_axi_lite_if.bready  = rx_axi_lite_if.bready;
  zcash_axi_lite_if.arvalid = rx_axi_lite_if.arvalid && zcash_dec;
  zcash_axi_lite_if.rready  = rx_axi_lite_if.rready;
  zcash_axi_lite_if.araddr  = rx_axi_lite_if.araddr - `ZCASH_OFFSET;
  zcash_axi_lite_if.arvalid = rx_axi_lite_if.arvalid && zcash_dec;

  axi_fifo_if.awvalid = rx_axi_lite_if.awvalid && axi_fifo_dec;
  axi_fifo_if.awaddr  = rx_axi_lite_if.awaddr - `AXI_FIFO_OFFSET;
  axi_fifo_if.wvalid  = rx_axi_lite_if.wvalid && axi_fifo_dec;
  axi_fifo_if.wdata   = rx_axi_lite_if.wdata;
  axi_fifo_if.wstrb   = rx_axi_lite_if.wstrb;
  axi_fifo_if.bready  = rx_axi_lite_if.bready;
  axi_fifo_if.arvalid = rx_axi_lite_if.arvalid && axi_fifo_dec;
  axi_fifo_if.rready  = rx_axi_lite_if.rready;
  axi_fifo_if.araddr  = rx_axi_lite_if.araddr - `AXI_FIFO_OFFSET;
  axi_fifo_if.arvalid = rx_axi_lite_if.arvalid && axi_fifo_dec;


  rx_axi_lite_if.awready = zcash_dec ? zcash_axi_lite_if.awready : axi_fifo_dec ? axi_fifo_if.awready : 0;
  rx_axi_lite_if.wready  = zcash_dec ? zcash_axi_lite_if.wready : axi_fifo_dec ? axi_fifo_if.wready : 0;
  rx_axi_lite_if.bvalid  = zcash_dec ? zcash_axi_lite_if.bvalid : axi_fifo_dec ? axi_fifo_if.bvalid : 0;
  rx_axi_lite_if.bresp   = 0;
  rx_axi_lite_if.arready = zcash_dec ? zcash_axi_lite_if.arready : axi_fifo_dec ? axi_fifo_if.arready : 0;
  rx_axi_lite_if.rvalid  = zcash_dec ? zcash_axi_lite_if.rvalid : axi_fifo_dec ? axi_fifo_if.rvalid : 0;
  rx_axi_lite_if.rdata   = zcash_dec ? zcash_axi_lite_if.rdata : axi_fifo_dec ?  axi_fifo_if.rdata : 32'h0;
  rx_axi_lite_if.rresp   = 0;
end

// Write Request
always_ff @(posedge i_clk) begin
  if (i_rst) begin
    wr_active <= 0;
    wr_addr   <= 0;
  end else begin

    if (rx_axi_lite_if.bvalid && rx_axi_lite_if.bready) wr_active <= 0;
    if (rx_axi_lite_if.awvalid) wr_active <= 1;
    if (rx_axi_lite_if.awvalid && ~wr_active) wr_addr <= rx_axi_lite_if.awaddr;

  end
end

// Read Request
always_ff @(posedge i_clk) begin
  if (i_rst) begin
    araddr  <= 0;
    rd_active <= 0;
  end else begin

    if (rx_axi_lite_if.rvalid && rx_axi_lite_if.rready) rd_active <= 0;
    if (rx_axi_lite_if.arvalid) rd_active <= 1;
    if (rx_axi_lite_if.arvalid && ~rd_active ) araddr <= rx_axi_lite_if.araddr;

  end
end

// Convert 8 bytes to 64 bytes
axis_dwidth_converter_8_to_64 converter_8_to_64 (
  .aclk   ( i_clk  ),
  .aresetn( ~i_rst ),
  .s_axis_tvalid( rx_zcash_if.val  ),
  .s_axis_tready( rx_zcash_if.rdy  ),
  .s_axis_tdata ( rx_zcash_if.dat  ),
  .s_axis_tlast ( rx_zcash_if.eop  ),
  .s_axis_tkeep ( rx_zcash_if_keep ),
  .m_axis_tvalid( tx_aws_if.val    ),
  .m_axis_tready( tx_aws_if.rdy    ),
  .m_axis_tdata ( tx_aws_if.dat    ),
  .m_axis_tlast ( tx_aws_if.eop    ),
  .m_axis_tkeep ( tx_aws_if_keep   )
);

// Convert 64 bytes to 8 bytes
axis_dwidth_converter_64_to_8 converter_64_to_8 (
  .aclk   ( i_clk  ),
  .aresetn( ~i_rst ),
  .s_axis_tvalid( rx_aws_if.val    ),
  .s_axis_tready( rx_aws_if.rdy    ),
  .s_axis_tdata ( rx_aws_if.dat    ),
  .s_axis_tlast ( rx_aws_if.eop    ),
  .s_axis_tkeep ( rx_aws_if_keep   ),
  .m_axis_tvalid( tx_zcash_if.val  ),
  .m_axis_tready( tx_zcash_if.rdy  ),
  .m_axis_tdata ( tx_zcash_if.dat  ),
  .m_axis_tlast ( tx_zcash_if.eop  ),
  .m_axis_tkeep ( tx_zcash_if_keep )
);


// Convert our AXI stream interfaces into AXI4 on PCIS
axi_fifo_mm_s_0 axi_fifo_mm_s_0 (
  .interrupt(),
  .s_axi_aclk     ( i_clk  ),
  .s_axi_aresetn  ( ~i_rst ),

  .s_axi_awaddr   ( axi_fifo_if.awaddr  ),
  .s_axi_awvalid  ( axi_fifo_if.awvalid ),
  .s_axi_awready  ( axi_fifo_if.awready ),
  .s_axi_wdata    ( axi_fifo_if.wdata   ),
  .s_axi_wstrb    ( axi_fifo_if.wstrb   ),
  .s_axi_wvalid   ( axi_fifo_if.wvalid  ),
  .s_axi_wready   ( axi_fifo_if.wready  ),
  .s_axi_bresp    ( axi_fifo_if.bresp   ),
  .s_axi_bvalid   ( axi_fifo_if.bvalid  ),
  .s_axi_bready   ( axi_fifo_if.bready  ),
  .s_axi_araddr   ( axi_fifo_if.araddr  ),
  .s_axi_arvalid  ( axi_fifo_if.arvalid ),
  .s_axi_arready  ( axi_fifo_if.arready ),
  .s_axi_rdata    ( axi_fifo_if.rdata   ),
  .s_axi_rresp    ( axi_fifo_if.rresp   ),
  .s_axi_rvalid   ( axi_fifo_if.rvalid  ),
  .s_axi_rready   ( axi_fifo_if.rready  ),

  .s_axi4_awid   ( rx_axi4_if.awid    ),
  .s_axi4_awaddr ( rx_axi4_if.awaddr  ),
  .s_axi4_awlen  ( rx_axi4_if.awlen   ),
  .s_axi4_awsize ( rx_axi4_if.awsize  ),
  .s_axi4_awburst( rx_axi4_if.awburst ),
  .s_axi4_awlock ( rx_axi4_if.awlock  ),
  .s_axi4_awcache( rx_axi4_if.awcache ),
  .s_axi4_awprot ( rx_axi4_if.awprot  ),
  .s_axi4_awvalid( rx_axi4_if.awvalid ),
  .s_axi4_awready( rx_axi4_if.awready ),
  .s_axi4_wdata  ( rx_axi4_if.wdata   ),
  .s_axi4_wstrb  ( rx_axi4_if.wstrb   ),
  .s_axi4_wlast  ( rx_axi4_if.wlast   ),
  .s_axi4_wvalid ( rx_axi4_if.wvalid  ),
  .s_axi4_wready ( rx_axi4_if.wready  ),
  .s_axi4_bid    ( rx_axi4_if.bid     ),
  .s_axi4_bresp  ( rx_axi4_if.bresp   ),
  .s_axi4_bvalid ( rx_axi4_if.bvalid  ),
  .s_axi4_bready ( rx_axi4_if.bready  ),
  .s_axi4_arid   ( rx_axi4_if.arid    ),
  .s_axi4_araddr ( rx_axi4_if.araddr  ),
  .s_axi4_arlen  ( rx_axi4_if.arlen   ),
  .s_axi4_arsize ( rx_axi4_if.arsize  ),
  .s_axi4_arburst( rx_axi4_if.arburst ),
  .s_axi4_arlock ( rx_axi4_if.arlock  ),
  .s_axi4_arcache( rx_axi4_if.arcache ),
  .s_axi4_arprot ( rx_axi4_if.arprot  ),
  .s_axi4_arvalid( rx_axi4_if.arvalid ),
  .s_axi4_arready( rx_axi4_if.arready ),
  .s_axi4_rid    ( ),
  .s_axi4_rdata  ( rx_axi4_if.rdata   ),
  .s_axi4_rresp  ( rx_axi4_if.rresp   ),
  .s_axi4_rlast  ( rx_axi4_if.rlast   ),
  .s_axi4_rvalid ( rx_axi4_if.rvalid  ),
  .s_axi4_rready ( rx_axi4_if.rready  ),

  .mm2s_prmry_reset_out_n(),
  .axi_str_txd_tvalid ( rx_aws_if.val  ),
  .axi_str_txd_tready ( rx_aws_if.rdy  ),
  .axi_str_txd_tlast  ( rx_aws_if.eop  ),
  .axi_str_txd_tkeep  ( rx_aws_if_keep ),
  .axi_str_txd_tdata  ( rx_aws_if.dat  ),

  .s2mm_prmry_reset_out_n(),
  .axi_str_rxd_tvalid( tx_aws_if.val  ),
  .axi_str_rxd_tready( tx_aws_if.rdy  ),
  .axi_str_rxd_tlast ( tx_aws_if.eop  ),
  .axi_str_rxd_tkeep ( tx_aws_if_keep ),
  .axi_str_rxd_tdata ( tx_aws_if.dat  )
);

always_comb begin
  rx_axi4_if.rid = 0;
end

endmodule
