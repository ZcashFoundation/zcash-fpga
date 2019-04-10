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



# Timing paths for CDC
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_tx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_tx/cdc_fifo/synchronizer_wr_ptr/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_tx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_tx/cdc_fifo/synchronizer_wr_ptr/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_tx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_tx/cdc_fifo/synchronizer_rd_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_tx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/control_top/cdc_fifo_tx/cdc_fifo/synchronizer_rd_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_in/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ zcash_fpga_top/equihash_verif_top/dup_check_fifo_out/* }]] 1.667

# Reset syncs
set_false_path -from [get_pins {zcash_fpga_top/core_rst1_sync/dat_reg[0][0]/C}] -to [get_pins {zcash_fpga_top/core_rst1_sync/dat_reg[2][0]_srl2/D}]
set_false_path -from [get_pins {zcash_fpga_top/if_rst_sync/dat_reg[0][0]/C}] -to [get_pins {zcash_fpga_top/if_rst_sync/dat_reg[2][0]_srl2/D}]

