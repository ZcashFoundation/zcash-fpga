set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR NO [current_design]

# Global reset
set_property IOSTANDARD LVCMOS18 [get_ports sys_reset_n]
set_property PACKAGE_PIN F18 [get_ports sys_reset_n]

# 100MHz reference clock
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports user_ref_100_p]
set_property ODT RTT_48 [get_ports user_ref_100_p]
set_property PACKAGE_PIN BH27 [get_ports user_ref_100_p]
create_clock -period 10.000 -name user_ref_100_p [get_ports user_ref_100_p]

# LED pins for debug
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[3]}]
set_property PACKAGE_PIN L19 [get_ports {led_pins[0]}]
set_property PACKAGE_PIN L18 [get_ports {led_pins[1]}]
set_property PACKAGE_PIN L21 [get_ports {led_pins[2]}]
set_property PACKAGE_PIN L20 [get_ports {led_pins[3]}]

# USB-UART connections
set_property IOSTANDARD LVCMOS18 [get_ports usb_uart_txd]
set_property IOSTANDARD LVCMOS18 [get_ports usb_uart_rxd]
set_property PACKAGE_PIN G21 [get_ports usb_uart_txd]
set_property PACKAGE_PIN F21 [get_ports usb_uart_rxd]


#Debug
connect_debug_port u_ila_0/probe6 [get_nets [list interrupt_r]]
connect_debug_port u_ila_0/probe7 [get_nets [list tx]]
connect_debug_port u_ila_0/probe8 [get_nets [list tx2]]
connect_debug_port u_ila_0/probe15 [get_nets [list usb_uart_txd_IBUF]]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_wiz_pll/inst/clk_out300]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {uart_axi_wdata[0]} {uart_axi_wdata[1]} {uart_axi_wdata[2]} {uart_axi_wdata[3]} {uart_axi_wdata[4]} {uart_axi_wdata[5]} {uart_axi_wdata[6]} {uart_axi_wdata[7]} {uart_axi_wdata[8]} {uart_axi_wdata[9]} {uart_axi_wdata[10]} {uart_axi_wdata[11]} {uart_axi_wdata[12]} {uart_axi_wdata[13]} {uart_axi_wdata[14]} {uart_axi_wdata[15]} {uart_axi_wdata[16]} {uart_axi_wdata[17]} {uart_axi_wdata[18]} {uart_axi_wdata[19]} {uart_axi_wdata[20]} {uart_axi_wdata[21]} {uart_axi_wdata[22]} {uart_axi_wdata[23]} {uart_axi_wdata[24]} {uart_axi_wdata[25]} {uart_axi_wdata[26]} {uart_axi_wdata[27]} {uart_axi_wdata[28]} {uart_axi_wdata[29]} {uart_axi_wdata[30]} {uart_axi_wdata[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 4 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {uart_axi_awaddr[0]} {uart_axi_awaddr[1]} {uart_axi_awaddr[2]} {uart_axi_awaddr[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 8 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {check_rst[0]} {check_rst[1]} {check_rst[2]} {check_rst[3]} {check_rst[4]} {check_rst[5]} {check_rst[6]} {check_rst[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {uart_state[0]} {uart_state[1]} {uart_state[2]} {uart_state[3]} {uart_state[4]} {uart_state[5]} {uart_state[6]} {uart_state[7]} {uart_state[8]} {uart_state[9]} {uart_state[10]} {uart_state[11]} {uart_state[12]} {uart_state[13]} {uart_state[14]} {uart_state[15]} {uart_state[16]} {uart_state[17]} {uart_state[18]} {uart_state[19]} {uart_state[20]} {uart_state[21]} {uart_state[22]} {uart_state[23]} {uart_state[24]} {uart_state[25]} {uart_state[26]} {uart_state[27]} {uart_state[28]} {uart_state[29]} {uart_state[30]} {uart_state[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 2 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {uart_axi_rresp[0]} {uart_axi_rresp[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 3 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {clk_out300_rst_r[0]} {clk_out300_rst_r[1]} {clk_out300_rst_r[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 4 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {uart_axi_araddr[0]} {uart_axi_araddr[1]} {uart_axi_araddr[2]} {uart_axi_araddr[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 32 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {uart_axi_rdata[0]} {uart_axi_rdata[1]} {uart_axi_rdata[2]} {uart_axi_rdata[3]} {uart_axi_rdata[4]} {uart_axi_rdata[5]} {uart_axi_rdata[6]} {uart_axi_rdata[7]} {uart_axi_rdata[8]} {uart_axi_rdata[9]} {uart_axi_rdata[10]} {uart_axi_rdata[11]} {uart_axi_rdata[12]} {uart_axi_rdata[13]} {uart_axi_rdata[14]} {uart_axi_rdata[15]} {uart_axi_rdata[16]} {uart_axi_rdata[17]} {uart_axi_rdata[18]} {uart_axi_rdata[19]} {uart_axi_rdata[20]} {uart_axi_rdata[21]} {uart_axi_rdata[22]} {uart_axi_rdata[23]} {uart_axi_rdata[24]} {uart_axi_rdata[25]} {uart_axi_rdata[26]} {uart_axi_rdata[27]} {uart_axi_rdata[28]} {uart_axi_rdata[29]} {uart_axi_rdata[30]} {uart_axi_rdata[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list interrupt]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list uart_axi_arready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list uart_axi_arvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list uart_axi_awready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list uart_axi_awvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list uart_axi_rvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list usb_uart_rxd_OBUF]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list clk_wiz_pll/inst/clk_out100]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 3 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {clk_out100_rst_r[0]} {clk_out100_rst_r[1]} {clk_out100_rst_r[2]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_out100]
