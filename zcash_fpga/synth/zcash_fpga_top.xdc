create_clock -period 3.333 -name i_clk_core1 -waveform {0.000 1.500} [get_ports -filter { NAME =~  "i_clk_core1" && DIRECTION == "IN" }]
create_clock -period 5.000 -name i_clk_core0 -waveform {0.000 2.500} [get_ports -filter { NAME =~  "i_clk_core0" && DIRECTION == "IN" }]
create_clock -period 10.000 -name i_clk_if -waveform {0.000 5.000} [get_ports -filter { NAME =~  "i_clk_if" && DIRECTION == "IN" }]

#Just for when we are synth a test block
create_clock -period 5.000 -name i_clk -waveform {0.000 2.500} [get_ports -filter { NAME =~  "i_clk" && DIRECTION == "IN" }]
create_clock -period 3.333 -name i_clk_300 -waveform {0.000 1.666} [get_ports -filter { NAME =~  "i_clk_300" && DIRECTION == "IN" }]

set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 5.000
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 5.000
set_bus_skew -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] 5.000
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] 5.000
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 5.000
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 5.000
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 5.000
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 5.000
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_wr_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 5.000
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_rx/cdc_fifo/synchronizer_rd_ptr/* }]] 5.000
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_tx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_tx/cdc_fifo/synchronizer_wr_ptr/* }]] 5.000
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_tx/cdc_fifo/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_tx/cdc_fifo/synchronizer_wr_ptr/* }]] 5.000
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_tx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_tx/cdc_fifo/synchronizer_rd_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_tx/cdc_fifo/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ control_top/cdc_fifo_tx/cdc_fifo/synchronizer_rd_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_wr_ptr/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/synchronizer_rd_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_in/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] 2.500
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_wr_ptr/* }]] 2.500
set_bus_skew -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*dat_reg[0]*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] -to [get_pins -filter { NAME =~  "*dat_reg[1]*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/synchronizer_rd_ptr/* }]] 1.667
set_bus_skew -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] 1.667
set_max_delay -datapath_only -from [get_pins -filter { NAME =~  "*ram*C" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] -to [get_pins -filter { NAME =~  "*o_dat_b*D" } -of_objects [get_cells -hierarchical -filter {NAME =~ equihash_verif_top/dup_check_fifo_out/* }]] 1.667



set_false_path -from [get_pins {core_rst1_sync/dat_reg[0][0]/C}] -to [get_pins {core_rst1_sync/dat_reg[2][0]_srl2/D}]
set_false_path -from [get_pins {if_rst_sync/dat_reg[0][0]/C}] -to [get_pins {if_rst_sync/dat_reg[2][0]_srl2/D}]

#For test
set_property PACKAGE_PIN BG23 [get_ports i_rst_core0] # PCIE Active Low Reset
set_property IOSTANDARD LVCMOS12 [get_ports i_rst_core0]
set_property PULLUP true [get_ports i_rst_core0]
set_property PACKAGE_PIN AR15 [get_ports i_clk_core1]
set_property PACKAGE_PIN AR14 [get_ports i_clk_core0]



create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_wiz_mmcm/inst/clk_300]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 20 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[0]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[1]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[2]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[3]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[4]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[5]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[6]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[7]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[8]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[9]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[10]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[11]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[12]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[13]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[14]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[15]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[16]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[17]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[18]} {zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_dat_a[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 4 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {uart_axi_awaddr[0]} {uart_axi_awaddr[1]} {uart_axi_awaddr[2]} {uart_axi_awaddr[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 4 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {uart_axi_araddr[0]} {uart_axi_araddr[1]} {uart_axi_araddr[2]} {uart_axi_araddr[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {uart_axi_rdata[0]} {uart_axi_rdata[1]} {uart_axi_rdata[2]} {uart_axi_rdata[3]} {uart_axi_rdata[4]} {uart_axi_rdata[5]} {uart_axi_rdata[6]} {uart_axi_rdata[7]} {uart_axi_rdata[8]} {uart_axi_rdata[9]} {uart_axi_rdata[10]} {uart_axi_rdata[11]} {uart_axi_rdata[12]} {uart_axi_rdata[13]} {uart_axi_rdata[14]} {uart_axi_rdata[15]} {uart_axi_rdata[16]} {uart_axi_rdata[17]} {uart_axi_rdata[18]} {uart_axi_rdata[19]} {uart_axi_rdata[20]} {uart_axi_rdata[21]} {uart_axi_rdata[22]} {uart_axi_rdata[23]} {uart_axi_rdata[24]} {uart_axi_rdata[25]} {uart_axi_rdata[26]} {uart_axi_rdata[27]} {uart_axi_rdata[28]} {uart_axi_rdata[29]} {uart_axi_rdata[30]} {uart_axi_rdata[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {uart_axi_wdata[0]} {uart_axi_wdata[1]} {uart_axi_wdata[2]} {uart_axi_wdata[3]} {uart_axi_wdata[4]} {uart_axi_wdata[5]} {uart_axi_wdata[6]} {uart_axi_wdata[7]} {uart_axi_wdata[8]} {uart_axi_wdata[9]} {uart_axi_wdata[10]} {uart_axi_wdata[11]} {uart_axi_wdata[12]} {uart_axi_wdata[13]} {uart_axi_wdata[14]} {uart_axi_wdata[15]} {uart_axi_wdata[16]} {uart_axi_wdata[17]} {uart_axi_wdata[18]} {uart_axi_wdata[19]} {uart_axi_wdata[20]} {uart_axi_wdata[21]} {uart_axi_wdata[22]} {uart_axi_wdata[23]} {uart_axi_wdata[24]} {uart_axi_wdata[25]} {uart_axi_wdata[26]} {uart_axi_wdata[27]} {uart_axi_wdata[28]} {uart_axi_wdata[29]} {uart_axi_wdata[30]} {uart_axi_wdata[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 2 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {uart_axi_rresp[0]} {uart_axi_rresp[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list eop_l]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list zcash_fpga_top/control_top/cdc_fifo_rx/cdc_fifo/i_val_a]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list interrupt]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list sop_l]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list uart_axi_arready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list uart_axi_arvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list uart_axi_awready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list uart_axi_awvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list uart_axi_rvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list uart_axi_wready]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_300]
