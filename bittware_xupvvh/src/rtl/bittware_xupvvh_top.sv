`timescale 1ps/1ps

module bittware_xupvvh_top ( 
  output logic [3:0] led_pins,
  input              user_ref_100_p,    // 100MHz referennce clock
  input              user_ref_100_n,    // 100MHz referennce clock
  input              sys_reset_n,       // Global reset
  input              usb_uart_txd,      // USB UART
  output logic       usb_uart_rxd       // USB UART
);
    
logic clk_100, clk_200, clk_300;
logic rst_100, rst_200, rst_300;
logic [2:0] rst_100_r, rst_200_r, rst_300_r;

clk_wiz_0 clk_wiz_mmcm (
  .clk_100 ( clk_100     ),
  .clk_200 ( clk_200     ),
  .clk_300 ( clk_300     ),
  .clk_in1_p  ( user_ref_100_p ),
  .clk_in1_n  ( user_ref_100_n )
);

always_comb begin
  rst_100 = rst_100_r[2];
  rst_200 = rst_200_r[2];
  rst_300 = rst_300_r[2];
end

always_ff @ (posedge clk_100) rst_100_r <= {rst_100_r, ~sys_reset_n};
always_ff @ (posedge clk_200) rst_200_r <= {rst_200_r, ~sys_reset_n};
always_ff @ (posedge clk_300) rst_300_r <= {rst_300_r, ~sys_reset_n};

if_axi_stream #(.DAT_BYTS(8)) uart_axi_rx(clk_300);
if_axi_stream #(.DAT_BYTS(8)) uart_axi_tx(clk_300);

always_comb begin
  led_pins[3:0] = 0;
end
  
uart_wrapper uart_wrapper (
  .i_clk     ( clk_300      ),
  .i_rst     ( rst_300      ),
  .i_rx_uart ( usb_uart_txd ),
  .o_tx_uart ( usb_uart_rxd ),
  .tx_if     ( uart_axi_tx  ),
  .rx_if     ( uart_axi_rx  )
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
  .i_clk_if    ( clk_300 ),
  .i_rst_if    ( rst_300 ),
  .rx_if ( uart_axi_tx ),
  .tx_if ( uart_axi_rx )
);

endmodule
