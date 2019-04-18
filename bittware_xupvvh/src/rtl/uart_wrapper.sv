/*
  Wraps around the UART block and provides basic functionality
  
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

module uart_wrapper #(
  parameter MODE = "STREAM"  // [STREAM, LOOPBACK]
)(
  input i_clk,
  input i_rst,
  // Interfaces to UART
  input        i_rx_uart,
  output logic o_tx_uart,
  // Interfaces to user logic
  if_axi_stream.source tx_if,
  if_axi_stream.sink   rx_if
);
  
enum {UART_STARTUP, UART_LOOPBACK, UART_TX_STREAM, UART_RX_STREAM, UART_WAIT_STREAM} uart_state;

// Interfaces before data width conversion
if_axi_stream #(.DAT_BYTS(1), .CTL_BYTS(1)) tx_int_if (i_clk);
if_axi_stream #(.DAT_BYTS(8), .CTL_BYTS(1)) rx_int_if (i_clk);

logic interrupt;
logic [31:0] uart_axi_wdata, uart_axi_rdata;
logic [3:0] uart_axi_awaddr, uart_axi_araddr;
logic [1:0] uart_axi_rresp, uart_axi_bresp;
logic uart_axi_awready, uart_axi_awvalid, uart_axi_arvalid, uart_axi_arready, uart_axi_rvalid, uart_axi_wready;

logic [15:0] tx_byt_cnt, tx_byt_len, rx_byt_cnt, rx_byt_len;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    uart_axi_wdata <= 0;
    uart_axi_awvalid <= 0;
    uart_axi_arvalid <= 0;
    uart_axi_araddr <= 0;
    uart_state <= UART_STARTUP;
    tx_int_if.reset_source();
    rx_int_if.rdy <= 0;
    tx_byt_cnt <= 0;
    tx_byt_len <= 0;
    rx_byt_cnt <= 0;
    rx_byt_len <= 0;
  end else begin
  
    if (uart_axi_awvalid && uart_axi_awready) uart_axi_awvalid <= 0;
    if (uart_axi_arvalid && uart_axi_arready) uart_axi_arvalid <= 0;
    if (tx_int_if.val && tx_int_if.rdy) tx_int_if.val <= 0;
  
    case (uart_state) 
      UART_STARTUP: begin
        uart_axi_wdata[4] <= 1; // Enable interrupt
        uart_axi_awvalid <= 1;
        uart_axi_awaddr <= 'hc;
        if (uart_axi_awvalid && uart_axi_awready) begin
          uart_state <= (MODE == "STREAM" ? UART_WAIT_STREAM : UART_LOOPBACK);
          uart_axi_awaddr <= 'h4;
          uart_axi_awvalid <= 0;
        end
      end
      UART_LOOPBACK: begin
        tx_byt_cnt <= 0;
        tx_byt_len <= 0;
        rx_byt_cnt <= 0;
        rx_byt_len <= 0;
        // Just read data and put it back on write interface
        uart_axi_araddr <= 0;
        if (interrupt) uart_axi_arvalid <= 1;
        if (uart_axi_rvalid && uart_axi_rresp == 0) begin
          uart_axi_wdata <= uart_axi_rdata;
          uart_axi_awvalid <= 1;
          uart_axi_awaddr <= 'h4;
        
          // Switch modes if we detect a null character
          // We can't exit STREAM mode without FPGA reset
          if (uart_axi_rdata == 0) begin
            uart_state <= UART_WAIT_STREAM;
          end
        end
      end
      UART_WAIT_STREAM: begin
        uart_axi_arvalid <= 1;
        uart_axi_araddr <= 'h8;
        if (tx_int_if.val || uart_axi_awvalid) begin
          // Wait
        end else 
        if (uart_axi_rvalid && uart_axi_rdata[0]) begin
          uart_state <= UART_RX_STREAM;
        end else
        if (rx_int_if.val) begin
          uart_state <= UART_TX_STREAM;
        end
      end
      // Receiving data from host
      UART_RX_STREAM: begin
        // In this mode we connect to an axi stream, and create the sop/eop signals based on line return - the first 2 bytes
        // are taken to be the stream length (so smallest stream is 2 bytes)
        
        // Swap between checking data and status register
        // Check status
        uart_axi_arvalid <= 1;
        if (uart_axi_araddr == 'h8) begin
          if (uart_axi_rvalid && uart_axi_rdata[0]) begin
            uart_axi_araddr <= 0;
          end
        // Then check data
        end else
        // Check for valid data byte          
        if (uart_axi_rvalid) begin
          uart_axi_araddr <= 'h8;
          tx_int_if.dat <= uart_axi_rdata;
          tx_int_if.val <= 1;
          tx_int_if.sop <= 0;
          tx_int_if.eop <= 0;
          
          tx_byt_cnt <= tx_byt_cnt + 1;
          
          if (tx_byt_cnt == 0)  begin
            tx_byt_len[0 +: 8] <= uart_axi_rdata; 
            tx_int_if.sop <= 1;
          end else
          if (tx_byt_cnt == 1)  begin
            tx_byt_len[8 +: 8] <= uart_axi_rdata;
            if (tx_byt_len[0 +: 8] <= 2 && uart_axi_rdata == 0) begin
              tx_int_if.eop <= 1;
              tx_byt_cnt <= 0;
              tx_byt_len <= 0;
              uart_state <= UART_WAIT_STREAM;
            end
          end else begin
            // If we hit our length       
            if (tx_byt_cnt + 1 >= tx_byt_len) begin
              tx_int_if.eop <= 1;
              tx_byt_cnt <= 0;
              tx_byt_len <= 0;
              uart_state <= UART_WAIT_STREAM;
            end
          end   
        end
      end
      // Sending data to host
      UART_TX_STREAM: begin
        uart_axi_araddr <= 'h8;
        // Swap between sending data and status register (checking for full)
        // Check status
        if (~rx_int_if.rdy && ~uart_axi_awvalid) begin
          uart_axi_arvalid <= 1;
          if (uart_axi_rvalid && ~uart_axi_rdata[3]) begin
              rx_int_if.rdy <= 1;
              uart_axi_arvalid <= 0;
          end          
        end else begin
          if (~uart_axi_awvalid) begin
            // Then check data
            if (rx_int_if.val && rx_int_if.rdy) begin
              rx_int_if.rdy <= 0;
              uart_axi_wdata <= rx_int_if.dat;
              uart_axi_awvalid <= 1;
              uart_axi_awaddr <= 'h4;
              if (rx_int_if.eop) begin
                uart_state <= UART_WAIT_STREAM;
              end
            end
          end
        end
      end
    endcase
  end
end

axi_uartlite_0 uart (
  .s_axi_aclk(i_clk),        // input wire s_axi_aclk
  .s_axi_aresetn(~i_rst),  // input wire s_axi_aresetn
  .interrupt(interrupt),          // output wire interrupt
  .s_axi_awaddr(uart_axi_awaddr),    // input wire [3 : 0] s_axi_awaddr
  .s_axi_awvalid(uart_axi_awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(uart_axi_awready),  // output wire s_axi_awready
  .s_axi_wdata(uart_axi_wdata),      // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb('d0),      // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(uart_axi_awvalid),    // input wire s_axi_wvalid
  .s_axi_wready(uart_axi_wready),    // output wire s_axi_wready
  .s_axi_bresp(uart_axi_bresp),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(),    // output wire s_axi_bvalid
  .s_axi_bready(1'b1),    // input wire s_axi_bready
  .s_axi_araddr(uart_axi_araddr),    // input wire [3 : 0] s_axi_araddr
  .s_axi_arvalid(uart_axi_arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(uart_axi_arready),  // output wire s_axi_arready
  .s_axi_rdata(uart_axi_rdata),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(uart_axi_rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(uart_axi_rvalid),    // output wire s_axi_rvalid
  .s_axi_rready(1'd1),    // input wire s_axi_rready
  .rx(i_rx_uart),                        // input wire rx
  .tx(o_tx_uart)                        // output wire tx
);

// Modules for data width converstion (UART is 1 byte, we want 8)
logic [7:0] tx_tkeep;
axis_dwidth_converter_1_to_8 tx_dwidth_converter (
  .aclk(i_clk),                    // input wire aclk
  .aresetn(~i_rst),              // input wire aresetn
  .s_axis_tvalid(tx_int_if.val),  // input wire s_axis_tvalid
  .s_axis_tready(tx_int_if.rdy),  // output wire s_axis_tready
  .s_axis_tdata (tx_int_if.dat),    // input wire [7 : 0] s_axis_tdata
  .s_axis_tlast (tx_int_if.eop),    // input wire s_axis_tlast
  .m_axis_tvalid(tx_if.val),  // output wire m_axis_tvalid
  .m_axis_tready(tx_if.rdy),  // input wire m_axis_tready
  .m_axis_tdata (tx_if.dat),    // output wire [63 : 0] m_axis_tdata
  .m_axis_tkeep (tx_tkeep),    // output wire [7 : 0] m_axis_tkeep
  .m_axis_tlast (tx_if.eop)    // output wire m_axis_tlast
);

always_comb begin
  tx_if.mod = $countones(tx_tkeep);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    tx_if.ctl <= 0;
    tx_if.err <= 0;
    tx_if.sop <= 1;
  end else begin
    if (tx_if.val && tx_if.rdy) begin
      tx_if.sop <= tx_if.eop;    
    end 
  end
end

logic [7:0] rx_tkeep;
axis_dwidth_converter_8_to_1 rx_dwidth_converter (
  .aclk(i_clk),                    // input wire aclk
  .aresetn(~i_rst),              // input wire aresetn
  .s_axis_tvalid(rx_if.val),  // input wire s_axis_tvalid
  .s_axis_tready(rx_if.rdy),  // output wire s_axis_tready
  .s_axis_tdata(rx_if.dat),    // input wire [63 : 0] s_axis_tdata
  .s_axis_tlast(rx_if.eop),    // input wire s_axis_tlast
  .s_axis_tkeep(rx_tkeep),    // input wire [7 : 0] s_axis_tkeep
  .m_axis_tvalid(rx_int_if.val),  // output wire m_axis_tvalid
  .m_axis_tready(rx_int_if.rdy),  // input wire m_axis_tready
  .m_axis_tdata(rx_int_if.dat),    // output wire [7 : 0] m_axis_tdata
  .m_axis_tlast(rx_int_if.eop)    // output wire m_axis_tlast
);

always_comb begin
  rx_tkeep = {8{1'b1}};
  for (int i = 0; i < 7; i++)
    if (rx_if.mod > 0 && rx_if.mod <= i)
      rx_tkeep[i] = 0; 
end


endmodule