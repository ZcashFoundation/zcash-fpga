//**************************************************************************
//*************             BittWare Incorporated              *************
//*************      45 S. Main Street, Concord, NH 03301      *************
//**************************************************************************
// LEGAL NOTICE:                                                             
//                 Copyright (c) 2018 BittWare, Inc.                       
//   The user is hereby granted a non-exclusive license to use and or      
//     modify this code provided that it runs on BittWare hardware.        
//   Usage of this code on non-BittWare hardware without the express       
//      written permission of BittWare is strictly prohibited.             
//                                                                         
// E-mail: support@bittware.com                    Tel: 603-226-0404        
//**************************************************************************

//# Created by: Jeff Sanders
//# Date: 20 Jun 2018
///
//**************************************************************************
// pcie_base: Default PCIe-based design incorporating the following functionality:
//  - PCIe Gen3x16 interface w/integrated PCIe-to-AXI4 conversion (within IPI subsystem)
//  - SPI controller (within IPI subsystem)
//  - I2C controller (within IPI subsystem)
//  - 16550-compatible UART (within IPI subsystem)
//  - STARTUPE3 primitive configured to allow writes to QSPI flash
//
// PCIe address map: (BAR0, 32-bit)
// 0x0000: CSR (0x0=Version(rd);LED[2:0](wr), 0x4=UAR timestamp(rd), 0x8=CSR(rd/wr))
// 0x1100: SPI core
// 0x2200: I2C Core
// 0x3300: UART Core
// 0x4000: 4KB scratchpad BRAM
//
//**************************************************************************

`timescale 1ps/1ps

`define DEV_SEL_HI_BIT 11
`define DEV_SEL_LO_BIT 8
`define VERSION_REG 32'h00600000

module bittware_xupvvh_top ( 
  led_pins,
  pcie_7x_mgt_rxn,
  pcie_7x_mgt_rxp,
  pcie_7x_mgt_txn,
  pcie_7x_mgt_txp,
  prog_b5_p,
  prog_b5_n,
  avr_rxd,
  avr_txd,
  usb_rxd,
  usb_txd,
  i2c_sda,
  i2c_scl,
  FPGA_I2C_MASTER_L,
  QSFP_CTL_EN,
  SAS_CTL_EN,
  sys_clkp,
  sys_clkn, 
  sys_reset_l);

  //#######  Misc. Board-specific  #######
  output [3:0]led_pins;              // On-board LEDs 0-3
  output FPGA_I2C_MASTER_L;          // Drive high to allow BMC to control QSFPs
  output QSFP_CTL_EN;                // Drive high for normal operation
  output SAS_CTL_EN;                // Drive high for normal operation
  //#######  PCIe Interface  #######
  input [15:0]pcie_7x_mgt_rxn;
  input [15:0]pcie_7x_mgt_rxp;
  output [15:0]pcie_7x_mgt_txn;
  output [15:0]pcie_7x_mgt_txp;
  //#######  I2C and UART I/F's  #######
  input avr_txd;                    // Tx UART data from the AVR
  output avr_rxd;                   // Rx UART data to the AVR
  inout i2c_sda;                    // I2C biderectional data
  inout i2c_scl;                    // I2C clock
  input usb_uart_txd;               // Tx UART data from the USB
  output logic usb_uart_rxd;              // Rx UART data to the USB  
  //#######  Clocks & Reset  #######
  input sys_clkp;                   // PCIe reference clock
  input sys_clkn; 
  input prog_b5_p;
  input prog_b5_n;
  input sys_reset_l;                // PCIe PERSTN


  wire [3:0]  spi_in;
  wire [3:0]  spi_out;
  wire [3:0]  spi_tri;
  wire        spi_sel;
  wire        spi_clk_o;
  wire        spi_clk_t;
  reg         spi_cs_l;
  reg  [31:0] clk_cnt; 
  reg  [3:0]  led_q;
  wire [3:0]  memtest_ok;
  reg         led_test_reg;
  reg [3:0]   qsfp_rst_reg;
  reg [3:0]   qsfp_lp_reg;
  reg [3:0]   qsfp_sel_oh;
  reg [3:0]   qsfp_i2c_ctri_vec;
  reg [3:0]   qsfp_i2c_dtri_vec;
  reg [3:0]   qsfp_i2c_cin_vec;
  reg [3:0]   qsfp_i2c_din_vec;
  wire [31:0] CSR_awaddr;
  wire [31:0] CSR_wdata;
  wire [31:0] CSR_araddr;
  reg  [31:0] CSR_rdata;
  reg         CSR_rvalid;
  reg         CSR_awready;
  reg         CSR_arready;
  reg         CSR_wready;
  reg         CSR_bvalid;
  wire        CSR_wdecode;
  wire        CSR_rdecode;
  wire        csr_ren;
  wire        csr_wen;
  wire        sys_clk;
  wire        sys_clk_gt;
  wire [31:0] UAR_DATA;


  IBUFDS_GTE4 refclk_ibuf (.O(sys_clk_gt), .ODIV2(sys_clk), .I(sys_clkp), .CEB(1'b0), .IB(sys_clkn));  

  // STARTUPE3 block: Allows FPGA logic connections to dedicated config. pins
  // From the UltraScale Configuration Guide:
  //   FCSBO: FPGA logic signal to external FCS_B configuration pin. FCSBO allows user
  //   control of FCS_B pin for Flash access.
  //   USRCCLKO (User CCLK input). USRCCLKO is an input from the FPGA logic. USERCCLKO drives a custom,
  //   FPGA-generated clock frequency onto the external FPGA CCLK pin. This is useful for
  //   post-configuration access of external SPI flash devices.
  
  // STARTUPE3: STARTUP Block
  // UltraScale
  // Xilinx HDL Libraries Guide, version 2014.4
  STARTUPE3 #(
      .PROG_USR("FALSE")     // Activate program event security feature. Requires encrypted bitstreams.
    )
    STARTUPE3_inst (
      .CFGCLK(),             // 1-bit output: Configuration main clock output
      .CFGMCLK(),            // 1-bit output: Configuration internal oscillator clock output
      .DI(spi_in),           // 4-bit output: Allow receiving on the D input pin
      .EOS(),                // 1-bit output: Active-High output signal indicating the End Of Startup
      .PREQ(),               // 1-bit output: PROGRAM request to fabric output
      .DO({3'b000,spi_mosi}),// 4-bit input: Allows control of the D pin output
      .DTS(4'b1110),         // 4-bit input: Allows tristate of the D pin
      .FCSBO(spi_cs_l),      // 1-bit input: Contols the FCS_B pin for flash access
      .FCSBTS(1'b0),         // 1-bit input: Tristate the FCS_B pin
      .GSR(),                // 1-bit input: Global Set/Reset input (GSR cannot be used for the port)
      .GTS(1'b0),            // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      .KEYCLEARB(),          // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      .PACK(),               // 1-bit input: PROGRAM acknowledge input
      .USRCCLKO(spi_sck_o),  // 1-bit input: User CCLK input
      .USRCCLKTS(1'b0),      // 1-bit input: User CCLK 3-state enable input
      .USRDONEO(1'b1),       // 1-bit input: User DONE pin output control
      .USRDONETS(1'b1)       // 1-bit input: User DONE 3-state enable output
    );
  
  //
  // PCIe IPI subsystem instantiation
  //
  pcie2axilite_sub pcie2axilite_sub_i(
      .sys_clk(sys_clk),
      .sys_clk_gt(sys_clk_gt),
      .clk_100_clk_p(prog_b5_p),
      .clk_100_clk_n(prog_b5_n),
      .sys_reset_l(sys_reset_l),
      .pcie_7x_mgt_rxn(pcie_7x_mgt_rxn),
      .pcie_7x_mgt_rxp(pcie_7x_mgt_rxp),
      .pcie_7x_mgt_txn(pcie_7x_mgt_txn),
      .pcie_7x_mgt_txp(pcie_7x_mgt_txp),
      .axi_aclk(axi_clk),
      .user_link_up(rst_l),
      .m00_axi_0_araddr(CSR_araddr),        
      .m00_axi_0_arprot(CSR_arprot),
      .m00_axi_0_arready(CSR_arready),
      .m00_axi_0_arvalid(CSR_arvalid),
      .m00_axi_0_awaddr(CSR_awaddr),
      .m00_axi_0_awprot(CSR_awprot),
      .m00_axi_0_awready(CSR_awready),
      .m00_axi_0_awvalid(CSR_awvalid),
      .m00_axi_0_bready(CSR_bready),
      .m00_axi_0_bresp(1'b0),
      .m00_axi_0_bvalid(CSR_bvalid),
      .m00_axi_0_rdata(CSR_rdata),
      .m00_axi_0_rready(CSR_rready),
      .m00_axi_0_rresp(1'b0),
      .m00_axi_0_rvalid(CSR_rvalid),
      .m00_axi_0_wdata(CSR_wdata),
      .m00_axi_0_wready(CSR_wready),
      .m00_axi_0_wstrb(CSR_wstrb),
      .m00_axi_0_wvalid(CSR_wvalid),
      .uart_0_baudoutn(),
      .uart_0_ctsn(1'b0),
      .uart_0_dcdn(1'b0),
      .uart_0_ddis(),
      .uart_0_dsrn(1'b0),
      .uart_0_dtrn(),
      .uart_0_out1n(),
      .uart_0_out2n(),
      .uart_0_ri(1'b0),
      .uart_0_rtsn(),
      .uart_0_rxd(avr_txd),
      .uart_0_rxrdyn(),
      .uart_0_txd(avr_rxd),
      .uart_0_txrdyn(),
      .iic_0_scl_i(i2c_cin),
      .iic_0_scl_o(i2c_cout),
      .iic_0_scl_t(i2c_ctri),
      .iic_0_sda_i(i2c_din),
      .iic_0_sda_o(i2c_dout),
      .iic_0_sda_t(i2c_dtri),
      .spi_0_io0_o(spi_io0_o),
      .spi_0_io1_i(spi_io1_i),
      .spi_0_sck_o(spi_sck_o),
      .spi_0_ss_o(spi_ss_o_0),
      .spi_0_ss_t(spi_ss_t)
    );

  assign spi_mosi = spi_io0_o;
  assign spi_io1_i = spi_miso;

  always@(posedge axi_clk) begin
    if (spi_ss_t == 0)
      spi_cs_l <= spi_ss_o_0;
    else
      spi_cs_l <= 1'b1;
  end

  //***************************************************************************
  // Buffers for I2C Tri-State I/O
  //***************************************************************************
  IOBUF IOBUF_i2c_clk_inst (
      .O(i2c_cin),
      .I(i2c_cout),
      .IO(i2c_scl),
      .T(i2c_ctri)
    );

  IOBUF IOBUF_i2c_data_inst (
      .O(i2c_din),
      .I(i2c_dout),
      .IO(i2c_sda),
      .T(i2c_dtri)
    );

  USR_ACCESSE2 USR_ACCESSE2_inst (
      .CFGCLK(), // 1-bit output: Configuration Clock
      .DATA(UAR_DATA), // 32-bit output: Configuration Data reflecting the contents of the AXSS register
      .DATAVALID() // 1-bit output: Active High Data Valid
    );

  // decode CSR Transaction
  assign CSR_wdecode        = (CSR_awaddr[`DEV_SEL_HI_BIT:`DEV_SEL_LO_BIT] == 0) | (CSR_awaddr[`DEV_SEL_HI_BIT:`DEV_SEL_LO_BIT] > 3);  // Decode 0x0 and out-of-range to CSR
  assign CSR_rdecode        = (CSR_araddr[`DEV_SEL_HI_BIT:`DEV_SEL_LO_BIT] == 0) | (CSR_araddr[`DEV_SEL_HI_BIT:`DEV_SEL_LO_BIT] > 3);  // Decode 0x0 and out-of-range to CSR
  assign csr_wen            = CSR_awready & CSR_wdecode;
  assign csr_ren            = CSR_arready & CSR_rdecode;

  always@(posedge axi_clk or negedge(rst_l)) begin
    if (rst_l == 1'b0) begin
      CSR_awready         <= 1'b0;
      CSR_arready         <= 1'b0;
      clk_cnt             <= 0;
      led_q               <= 0;
      led_test_reg        <= 1'b0;
      qsfp_rst_reg        <= 'h0;
      qsfp_lp_reg         <= 'h0;
      qsfp_sel_oh         <= 4'h0;
    end
    else begin
      clk_cnt             <= clk_cnt + 1;
      led_q[3]            <= clk_cnt[25];
      CSR_awready         <= CSR_awvalid;
      CSR_arready         <= CSR_arvalid;
      if (csr_wen & CSR_wvalid) begin
        CSR_wready          <= CSR_wvalid & ~(CSR_awvalid);
        if (CSR_awaddr[`DEV_SEL_LO_BIT-1]) begin
          qsfp_rst_reg      <= CSR_wdata[19:16];   // AXI Write to addr 0x80 Config Reg, R/W
          qsfp_lp_reg       <= CSR_wdata[15:12];
          qsfp_sel_oh       <= CSR_wdata[11:8];
          led_test_reg      <= CSR_wdata[7];
          led_q[2:0]        <= CSR_wdata[6:4];
        end
        CSR_bvalid        <= 1;
      end
      else if (csr_ren & CSR_rready) begin
        CSR_rvalid          <= CSR_rready & ~(CSR_arvalid);
        // AXI Read: 0x80 reads config reg, 0x0 reads VERSION REG, 0x4 reads UAR.  0x0 and 0x4 are READ ONLY
        CSR_rdata           <= CSR_araddr[`DEV_SEL_LO_BIT-1] ? {12'h0,
            qsfp_rst_reg,
            qsfp_lp_reg,
            qsfp_sel_oh,
            led_test_reg,
            led_q[2:0],
            4'b0000} : CSR_araddr[3] ? 32'h0 : (CSR_araddr[2] ? UAR_DATA : `VERSION_REG);
      end
      else begin
        CSR_rvalid          <= 0; 
        CSR_wready          <= 0;
      end
    end
  end

  assign spi_miso       = spi_in[1];

  assign led_pins          = ~led_q;
  assign FPGA_I2C_MASTER_L = 1'b1;    // Change to 1'b0 to allow FPGA control of QSFP I2C bus
  assign QSFP_CTL_EN       = 1'b1;
  assign SAS_CTL_EN        = 1'b1;

  // User logic
  
  

endmodule
