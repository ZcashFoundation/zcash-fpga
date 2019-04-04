`timescale 1ps/1ps

module bittware_xupvvh_top ( 
  output logic [3:0] led_pins,
  input              user_ref_100_p,    // 100MHz referennce clock
  input              user_ref_100_n,    // 100MHz referennce clock
  input              sys_reset_n,       // Global reset
  input              usb_uart_txd,      // USB UART
  output logic       usb_uart_rxd       // USB UART
);
    
logic clk_out100, clk_out200, clk_out300;
logic clk_out100_rst, clk_out200_rst, clk_out300_rst;
logic [2:0] clk_out100_rst_r, clk_out200_rst_r, clk_out300_rst_r;

clk_wiz_0 clk_wiz_mmcm (
  .clk_out100 ( clk_out100     ),
  .clk_out200 ( clk_out200     ),
  .clk_out300 ( clk_out300     ),
  .clk_in1_p  ( user_ref_100_p ),
  .clk_in1_n  ( user_ref_100_n )
);

always_comb begin
  clk_out100_rst = clk_out100_rst_r[2];
  clk_out200_rst = clk_out200_rst_r[2];
  clk_out300_rst = clk_out300_rst_r[2];
end

always @ (posedge clk_out200) clk_out200_rst_r <= {clk_out200_rst_r, ~sys_reset_n};
always @ (posedge clk_out300) clk_out300_rst_r <= {clk_out300_rst_r, ~sys_reset_n};
always @ (posedge clk_out100) clk_out100_rst_r <= {clk_out100_rst_r, ~sys_reset_n};


// Logic for programming UART core
(* mark_debug = "true" *) logic interrupt;
enum {UART_STARTUP, UART_LOOPBACK, UART_STREAM} uart_state;
(* mark_debug = "true" *) logic [31:0] uart_axi_wdata, uart_axi_rdata;
(* mark_debug = "true" *) logic [3:0] uart_axi_awaddr, uart_axi_araddr;
(* mark_debug = "true" *) logic [1:0] uart_axi_rresp;
(* mark_debug = "true" *) logic uart_axi_awready, uart_axi_awvalid, uart_axi_arvalid, uart_axi_arready, uart_axi_rvalid, uart_axi_wready;

logic sop_l;

always_comb begin
  led_pins[3:0] = 0;
end
  
always_ff @ (posedge clk_out300) begin
  if (clk_out300_rst) begin
    uart_axi_wdata <= 0;
    uart_axi_awvalid <= 0;
    uart_axi_arvalid <= 0;
    uart_axi_araddr <= 0;
    uart_state <= UART_STARTUP;
    sop_l <= 0;
  end else begin
    
    if (uart_axi_awvalid && uart_axi_awready) uart_axi_awvalid <= 0;
    if (uart_axi_arvalid && uart_axi_arready) uart_axi_arvalid <= 0;
    
    case (uart_state) 
      UART_STARTUP: begin
        uart_axi_wdata[4] <= 1; // Enable interrupt
        uart_axi_awvalid <= 1;
        uart_axi_awaddr <= 'hc;
        if (uart_axi_awvalid && uart_axi_awready) begin
          uart_state <= UART_LOOPBACK;
          uart_axi_awaddr <= 'h4;
        end
      end
      UART_LOOPBACK: begin
        // Just read data and put it back on write interface
        uart_axi_araddr <= 0;
        if (interrupt) uart_axi_arvalid <= 1;
        if (uart_axi_rvalid && uart_axi_rresp == 0) begin
          uart_axi_wdata <= uart_axi_rdata;
          uart_axi_awvalid <= 1;
          uart_axi_awaddr <= 'h4;
        end
        // If we detect a 
      end
      UART_STREAM: begin
        // In this mode we connect to an axi stream, and create the sop/eop signals based on line return - eop is 8'h0a
        // Data is decoded as hex
        uart_axi_araddr <= 0;
        if (interrupt) uart_axi_arvalid <= 1;
        // Code for rx
        if (uart_axi_rvalid && uart_axi_rresp == 0) begin
          if (~sop_l) begin
            sop_l <= 1;
          end
          uart_axi_wdata <= uart_axi_rdata;
          uart_axi_awvalid <= 1;
          uart_axi_awaddr <= 'h4;
        end
        
        
        // Logic for tx
        
      end
    endcase
  end
end
  
axi_uartlite_0 uart (
  .s_axi_aclk(clk_out300),        // input wire s_axi_aclk
  .s_axi_aresetn(~clk_out300_rst),  // input wire s_axi_aresetn
  .interrupt(interrupt),          // output wire interrupt
  .s_axi_awaddr(uart_axi_awaddr),    // input wire [3 : 0] s_axi_awaddr
  .s_axi_awvalid(uart_axi_awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(uart_axi_awready),  // output wire s_axi_awready
  .s_axi_wdata(uart_axi_wdata),      // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb('d0),      // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(uart_axi_awvalid),    // input wire s_axi_wvalid
  .s_axi_wready(uart_axi_wready),    // output wire s_axi_wready
  .s_axi_bresp(),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(),    // output wire s_axi_bvalid
  .s_axi_bready(1'b1),    // input wire s_axi_bready
  .s_axi_araddr(uart_axi_araddr),    // input wire [3 : 0] s_axi_araddr
  .s_axi_arvalid(uart_axi_arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(uart_axi_arready),  // output wire s_axi_arready
  .s_axi_rdata(uart_axi_rdata),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(uart_axi_rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(uart_axi_rvalid),    // output wire s_axi_rvalid
  .s_axi_rready(1'd1),    // input wire s_axi_rready
  .rx(usb_uart_txd),                        // input wire rx
  .tx(usb_uart_rxd)                        // output wire tx
);

endmodule
