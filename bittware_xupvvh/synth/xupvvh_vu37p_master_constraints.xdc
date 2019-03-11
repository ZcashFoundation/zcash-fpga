#**************************************************************************
#*************             BittWare Incorporated              *************
#*************      45 S. Main Street, Concord, NH 03301      *************
#**************************************************************************
# LEGAL NOTICE:
#                 Copyright (c) 2018 BittWare, Inc.
#   The user is hereby granted a non-exclusive license to use and or
#     modify this code provided that it runs on BittWare hardware.
#   Usage of this code on non-BittWare hardware without the express
#      written permission of BittWare is strictly prohibited.
#
# E-mail: support@bittware.com                    Tel: 603-226-0404
#**************************************************************************

##############################################
##########      Configuration       ##########
##############################################
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CONFIG_MODE SPIx4  [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design] # Bitstream configuration settings
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]  # Must set to "NO" if loading from backup flash partition
set_property BITSTREAM.CONFIG.CONFIGRATE 85.0 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]

##############################################
##########    Board Clocks/Reset    ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_l] # Active Low Global Reset
set_property PACKAGE_PIN F18 [get_ports sys_rst_l]

##############################################
##########   Misc. Board-specific   ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports fpga_i2c_master_l] # FPGA I2C Master. 0 = FPGA has control of I2C chains shared with the BMC.
set_property PACKAGE_PIN E17 [get_ports fpga_i2c_master_l]
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_ctl_en] # QSFP I2C Control Enable. 1 = Connect QSFP I2C/Status to FPGA
set_property PACKAGE_PIN C18 [get_ports qsfp_ctl_en]
set_property IOSTANDARD LVCMOS18 [get_ports sas_ctl_en] # SAS I2C Control Enable. 1 = Connect SAS GPIO to FPGA
set_property PACKAGE_PIN C17 [get_ports sas_ctl_en]
set_property IOSTANDARD LVCMOS18 [get_ports rd_prsnt_l_1] # Active Low RDIMM 1 Presence
set_property PACKAGE_PIN D17 [get_ports rd_prsnt_l_1]
set_property IOSTANDARD LVCMOS18 [get_ports rd_prsnt_l_2] # Active Low RDIMM 2 Presence
set_property PACKAGE_PIN D16 [get_ports rd_prsnt_l_2]
set_property IOSTANDARD LVCMOS18 [get_ports pcie_bp_l] # Active Low Back Plane Detect
set_property PACKAGE_PIN C20 [get_ports pcie_bp_l]
set_property IOSTANDARD LVCMOS18 [get_ports xtp1] # Test Point 1
set_property PACKAGE_PIN F16 [get_ports xtp1]
set_property IOSTANDARD LVCMOS18 [get_ports xtp2] # Test Point 2
set_property PACKAGE_PIN E16 [get_ports xtp2]
set_property IOSTANDARD LVCMOS18 [get_ports xtp3] # Test Point 3
set_property PACKAGE_PIN E21 [get_ports xtp3]
set_property IOSTANDARD LVCMOS18 [get_ports xtp4] # Test Point 4
set_property PACKAGE_PIN D21 [get_ports xtp4]

##############################################
##########     UART I/F's     ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports avr_rxd] # AVR UART Rx Data
set_property PACKAGE_PIN F19 [get_ports avr_rxd]
set_property IOSTANDARD LVCMOS18 [get_ports avr_txd] # AVR UART Tx Data
set_property PACKAGE_PIN J16 [get_ports avr_txd]
set_property IOSTANDARD LVCMOS18 [get_ports usb_uart_txd] # FTDI UART Tx Data
set_property PACKAGE_PIN G21 [get_ports usb_uart_txd]
set_property IOSTANDARD LVCMOS18 [get_ports usb_uart_rxd] # FTDI UART Rx Data
set_property PACKAGE_PIN F21 [get_ports usb_uart_rxd]

##############################################
##########     I2C I/F's     ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports i2c_sda_3] # I2C SDA 3 MAC-ID
set_property PACKAGE_PIN K16 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS18 [get_ports i2c_scl_3] # I2C SCL 3 MAC-ID
set_property PACKAGE_PIN K17 [get_ports i2c_scl]

##############################################
##########        USB-C Misc.       ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports usbc_cbl_dir] # USB C Cable Direction (input from connector)
set_property PACKAGE_PIN G18 [get_ports usbc_cbl_dir]
set_property IOSTANDARD LVCMOS18 [get_ports usbc_pps] USB C PPS
set_property PACKAGE_PIN G17 [get_ports usbc_pps]
set_property IOSTANDARD LVCMOS18 [get_ports usbc_clk] USB C CLK
set_property PACKAGE_PIN F20 [get_ports usbc_clk]

##############################################
##########  QSFP Status & Control   ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_prsnt_l_1] # QSFP 1 Active Low Present
set_property PACKAGE_PIN B17 [get_ports qsfp_prsnt_l_1]
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_rst_l_1] # QSFP 1 Active Low Reset
set_property PACKAGE_PIN A21 [get_ports qsfp_rst_l_1]

set_property IOSTANDARD LVCMOS18 [get_ports qsfp_prsnt_l_2] # QSFP 2 Active Low Present
set_property PACKAGE_PIN A20 [get_ports qsfp_prsnt_l_2]
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_rst_l_2] # QSFP 2 Active Low Reset
set_property PACKAGE_PIN A19 [get_ports qsfp_rst_l_2]

set_property IOSTANDARD LVCMOS18 [get_ports qsfp_prsnt_l_3] # QSFP 3 Active Low Present
set_property PACKAGE_PIN A18 [get_ports qsfp_prsnt_l_3]
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_rst_l_3] # QSFP 3 Active Low Reset
set_property PACKAGE_PIN B16 [get_ports qsfp_rst_l_3]

set_property IOSTANDARD LVCMOS18 [get_ports qsfp_prsnt_l_4] # QSFP 4 Active Low Present
set_property PACKAGE_PIN A16 [get_ports qsfp_prsnt_l_4]
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_rst_l_4] # QSFP 4 Active Low Reset
set_property PACKAGE_PIN C19 [get_ports qsfp_rst_l_4]

set_property IOSTANDARD LVCMOS18 [get_ports qsfp_lp] # QSFP Low Power Mode Enable (output to all QSFPs)
set_property PACKAGE_PIN B18 [get_ports qsfp_lp]
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_int_l] # QSFP Active Low Interrupt (wire-OR'ed input from all QSFPs)
set_property PACKAGE_PIN B20 [get_ports qsfp_int_l]

##############################################
##########         SAS GPIO         ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports sas1_gprx[0]] # SAS1 GPRX 0
set_property PACKAGE_PIN K19 [get_ports sas1_gprx[0]]
set_property IOSTANDARD LVCMOS18 [get_ports sas1_gprx[1]] # SAS1 GPRX 1
set_property PACKAGE_PIN K18 [get_ports sas1_gprx[1]]
set_property IOSTANDARD LVCMOS18 [get_ports sas1_gptx[0]] # SAS1 GPTX 0
set_property PACKAGE_PIN K21 [get_ports sas1_gptx[0]]
set_property IOSTANDARD LVCMOS18 [get_ports sas1_gptx[1]] # SAS1 GPTX 1
set_property PACKAGE_PIN J21 [get_ports sas1_gptx[1]]
set_property IOSTANDARD LVCMOS18 [get_ports sas1_gpio[0]] # SAS1 GPIO 0
set_property PACKAGE_PIN J20 [get_ports sas1_gpio[0]]
set_property IOSTANDARD LVCMOS18 [get_ports sas1_gpio[1]] # SAS1 GPIO 1
set_property PACKAGE_PIN J19 [get_ports sas1_gpio[1]]
set_property IOSTANDARD LVCMOS18 [get_ports sas2_gprx[0]] # SAS2 GPRX 0
set_property PACKAGE_PIN J17 [get_ports sas2_gprx[0]]
set_property IOSTANDARD LVCMOS18 [get_ports sas2_gprx[1]] # SAS2 GPRX 1
set_property PACKAGE_PIN H17 [get_ports sas2_gprx[1]]
set_property IOSTANDARD LVCMOS18 [get_ports sas2_gptx[0]] # SAS2 GPTX 0
set_property PACKAGE_PIN G16 [get_ports sas2_gptx[0]]
set_property IOSTANDARD LVCMOS18 [get_ports sas2_gptx[1]] # SAS2 GPTX 1
set_property PACKAGE_PIN H20 [get_ports sas2_gptx[1]]
set_property IOSTANDARD LVCMOS18 [get_ports sas2_gpio[0]] # SAS2 GPIO 0
set_property PACKAGE_PIN G20 [get_ports sas2_gpio[0]]
set_property IOSTANDARD LVCMOS18 [get_ports sas2_gpio[1]] # SAS2 GPIO 1
set_property PACKAGE_PIN H19 [get_ports sas2_gpio[1]]

##############################################
##########           LEDs           ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports {led_l[0]}] # Active Low Led 0
set_property PACKAGE_PIN L19 [get_ports {led_l[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_l[1]}] # Active Low Led 1
set_property PACKAGE_PIN L18 [get_ports {led_l[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_l[2]}] # Active Low Led 2
set_property PACKAGE_PIN L21 [get_ports {led_l[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_l[3]}] # Active Low Led 3
set_property PACKAGE_PIN L20 [get_ports {led_l[3]}]

##############################################
##########           PCIe           ##########
##############################################
set_property PACKAGE_PIN BJ26 [get_ports progclk_b5_p] # SI5341B_P_5
set_property PACKAGE_PIN BJ25 [get_ports progclk_b5_n] # SI5341B_N_5
set_property IOSTANDARD DIFF_SSTL18_I [get_ports progclk_b5_p]
set_property PACKAGE_PIN BG23 [get_ports pcie_sys_reset_l] # PCIE Active Low Reset
set_property IOSTANDARD LVCMOS12 [get_ports pcie_sys_reset_l]
set_property PULLUP true [get_ports pcie_sys_reset_l]
set_property PACKAGE_PIN AR15 [get_ports pcie_sys_clkn] # PCIE Reference Clock 0
set_property PACKAGE_PIN AR14 [get_ports pcie_sys_clkp]
#set_property PACKAGE_PIN AL15 [get_ports pcie_sys_clkn] # PCIE Reference Clock 1
#set_property PACKAGE_PIN AL14 [get_ports pcie_sys_clkp]
create_clock -period 10.000 -name refclk_100 [get_ports pcie_sys_clkp] # PCIe Reference Clock Frequency (100 MHz)

# NOTE: All GTY pins are automatically assigned by Vivado. Shown here for reference only.
#GTH BANK 227 PCIE 3:0
#set_property PACKAGE_PIN AL2  [get_ports pcie_7x_mgt_rxp[0]] # PCIE_RX_P_0
#set_property PACKAGE_PIN AL1  [get_ports pcie_7x_mgt_rxn[0]] # PCIE_RX_N_0
#set_property PACKAGE_PIN AM4  [get_ports pcie_7x_mgt_rxp[1]] # PCIE_RX_P_1
#set_property PACKAGE_PIN AM3  [get_ports pcie_7x_mgt_rxn[1]] # PCIE_RX_N_1
#set_property PACKAGE_PIN AN5  [get_ports pcie_7x_mgt_rxp[2]] # PCIE_RX_P_2
#set_property PACKAGE_PIN AN6  [get_ports pcie_7x_mgt_rxn[2]] # PCIE_RX_N_2
#set_property PACKAGE_PIN AN2  [get_ports pcie_7x_mgt_rxp[3]] # PCIE_RX_P_3
#set_property PACKAGE_PIN AN1  [get_ports pcie_7x_mgt_rxn[3]] # PCIE_RX_N_3
#set_property PACKAGE_PIN AL11 [get_ports pcie_7x_mgt_txp[0]] # PCIE_TX_P_0
#set_property PACKAGE_PIN AL10 [get_ports pcie_7x_mgt_txn[0]] # PCIE_TX_N_0
#set_property PACKAGE_PIN AM9  [get_ports pcie_7x_mgt_txp[1]] # PCIE_TX_P_1
#set_property PACKAGE_PIN AM8  [get_ports pcie_7x_mgt_txn[1]] # PCIE_TX_N_1
#set_property PACKAGE_PIN AN11 [get_ports pcie_7x_mgt_txp[2]] # PCIE_TX_P_2
#set_property PACKAGE_PIN AN10 [get_ports pcie_7x_mgt_txn[2]] # PCIE_TX_N_2
#set_property PACKAGE_PIN AP9  [get_ports pcie_7x_mgt_txp[3]] # PCIE_TX_P_3
#set_property PACKAGE_PIN AP8  [get_ports pcie_7x_mgt_txn[3]] # PCIE_TX_N_3

#GTH BANK 226 PCIE 7:4
#set_property PACKAGE_PIN AP4  [get_ports pcie_7x_mgt_rxp[4]] # PCIE_RX_P_4
#set_property PACKAGE_PIN AP3  [get_ports pcie_7x_mgt_rxn[4]] # PCIE_RX_N_4
#set_property PACKAGE_PIN AR2  [get_ports pcie_7x_mgt_rxp[5]] # PCIE_RX_P_5
#set_property PACKAGE_PIN AR1  [get_ports pcie_7x_mgt_rxn[5]] # PCIE_RX_N_5
#set_property PACKAGE_PIN AT4  [get_ports pcie_7x_mgt_rxp[6]] # PCIE_RX_P_6
#set_property PACKAGE_PIN AT3  [get_ports pcie_7x_mgt_rxn[6]] # PCIE_RX_N_6
#set_property PACKAGE_PIN AU2  [get_ports pcie_7x_mgt_rxp[7]] # PCIE_RX_P_7
#set_property PACKAGE_PIN AU1  [get_ports pcie_7x_mgt_rxn[7]] # PCIE_RX_N_7
#set_property PACKAGE_PIN AR11 [get_ports pcie_7x_mgt_txp[4]] # PCIE_TX_P_4
#set_property PACKAGE_PIN AR10 [get_ports pcie_7x_mgt_txn[4]] # PCIE_TX_N_4
#set_property PACKAGE_PIN AR7  [get_ports pcie_7x_mgt_txp[5]] # PCIE_TX_P_5
#set_property PACKAGE_PIN AR6  [get_ports pcie_7x_mgt_txn[5]] # PCIE_TX_N_5
#set_property PACKAGE_PIN AT9  [get_ports pcie_7x_mgt_txp[6]] # PCIE_TX_P_6
#set_property PACKAGE_PIN AT8  [get_ports pcie_7x_mgt_txn[6]] # PCIE_TX_N_6
#set_property PACKAGE_PIN AU11 [get_ports pcie_7x_mgt_txp[7]] # PCIE_TX_P_7
#set_property PACKAGE_PIN AU10 [get_ports pcie_7x_mgt_txn[7]] # PCIE_TX_N_7

#GTH BANK 225 PCIE Lanes 11:8
#set_property PACKAGE_PIN AV4  [get_ports pcie_7x_mgt_rxp[8]]  # PCIE_RX_P_8
#set_property PACKAGE_PIN AV3  [get_ports pcie_7x_mgt_rxn[8]]  # PCIE_RX_N_8
#set_property PACKAGE_PIN AW6  [get_ports pcie_7x_mgt_rxp[9]]  # PCIE_RX_P_9
#set_property PACKAGE_PIN AW5  [get_ports pcie_7x_mgt_rxn[9]]  # PCIE_RX_N_9
#set_property PACKAGE_PIN AW2  [get_ports pcie_7x_mgt_rxp[10]] # PCIE_RX_P_10
#set_property PACKAGE_PIN AW1  [get_ports pcie_7x_mgt_rxn[10]] # PCIE_RX_N_10
#set_property PACKAGE_PIN AY4  [get_ports pcie_7x_mgt_rxp[11]] # PCIE_RX_P_11
#set_property PACKAGE_PIN AY3  [get_ports pcie_7x_mgt_rxn[11]] # PCIE_RX_N_11
#set_property PACKAGE_PIN AU7  [get_ports pcie_7x_mgt_txp[8]]  # PCIE_TX_P_8
#set_property PACKAGE_PIN AU6  [get_ports pcie_7x_mgt_txn[8]]  # PCIE_TX_N_8
#set_property PACKAGE_PIN AV9  [get_ports pcie_7x_mgt_txp[9]]  # PCIE_TX_P_9
#set_property PACKAGE_PIN AV8  [get_ports pcie_7x_mgt_txn[9]]  # PCIE_TX_N_9
#set_property PACKAGE_PIN AW11 [get_ports pcie_7x_mgt_txp[10]] # PCIE_TX_P_10
#set_property PACKAGE_PIN AW10 [get_ports pcie_7x_mgt_txn[10]] # PCIE_TX_N_10
#set_property PACKAGE_PIN AY9  [get_ports pcie_7x_mgt_txp[11]] # PCIE_TX_P_11
#set_property PACKAGE_PIN AY8  [get_ports pcie_7x_mgt_txn[11]] # PCIE_TX_N_11

#GTH BANK 224 PCIE Lanes 15:12
#set_property PACKAGE_PIN BA6  [get_ports pcie_7x_mgt_rxp[12]] # PCIE_RX_P_12
#set_property PACKAGE_PIN BA5  [get_ports pcie_7x_mgt_rxn[12]] # PCIE_RX_N_12
#set_property PACKAGE_PIN BA2  [get_ports pcie_7x_mgt_rxp[13]] # PCIE_RX_P_13
#set_property PACKAGE_PIN BA1  [get_ports pcie_7x_mgt_rxn[13]] # PCIE_RX_N_13
#set_property PACKAGE_PIN BB4  [get_ports pcie_7x_mgt_rxp[14]] # PCIE_RX_P_14
#set_property PACKAGE_PIN BB3  [get_ports pcie_7x_mgt_rxn[14]] # PCIE_RX_N_14
#set_property PACKAGE_PIN BC2  [get_ports pcie_7x_mgt_rxp[15]] # PCIE_RX_P_15
#set_property PACKAGE_PIN BC1  [get_ports pcie_7x_mgt_rxn[15]] # PCIE_RX_N_15
#set_property PACKAGE_PIN BA11 [get_ports pcie_7x_mgt_txp[12]] # PCIE_TX_P_12
#set_property PACKAGE_PIN BA10 [get_ports pcie_7x_mgt_txn[12]] # PCIE_TX_N_12
#set_property PACKAGE_PIN BB9  [get_ports pcie_7x_mgt_txp[13]] # PCIE_TX_P_13
#set_property PACKAGE_PIN BB8  [get_ports pcie_7x_mgt_txn[13]] # PCIE_TX_N_13
#set_property PACKAGE_PIN BC11 [get_ports pcie_7x_mgt_txp[14]] # PCIE_TX_P_14
#set_property PACKAGE_PIN BC10 [get_ports pcie_7x_mgt_txn[14]] # PCIE_TX_N_14
#set_property PACKAGE_PIN BC7  [get_ports pcie_7x_mgt_txp[15]] # PCIE_TX_P_15
#set_property PACKAGE_PIN BC6  [get_ports pcie_7x_mgt_txn[15]] # PCIE_TX_N_15

##############################################
##########      Memory Clocks       ##########
##############################################
set_property PACKAGE_PIN G35  [get_ports ddr4_sys_clk_1_p] # DIMM 1 Reference Clock
set_property PACKAGE_PIN G36  [get_ports ddr4_sys_clk_1_n]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports ddr4_sys_clk_1_p]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports ddr4_sys_clk_1_n]
set_property ODT RTT_48 [get_ports ddr4_sys_clk_1_p]

set_property PACKAGE_PIN BK43  [get_ports ddr4_sys_clk_2_p] # DIMM 2 Reference Clock
set_property PACKAGE_PIN BK44  [get_ports ddr4_sys_clk_2_n]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports ddr4_sys_clk_2_p]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports ddr4_sys_clk_2_n]
set_property ODT RTT_48 [get_ports ddr4_sys_clk_2_p]

##############################################
##########   Memory DIMM Pins       ##########
##############################################
# NOTE: The following assignments are for two 16GB RDIMMs. Please see example projects for other memory type pinouts
### RDIMM 1
set_property PACKAGE_PIN J34 [get_ports "m0_ddr4_act_n"] # Dimm 1 Activation Command Low
set_property PACKAGE_PIN D35 [get_ports "m0_ddr4_adr[0]"] # Dimm 1 Address Pin 0
set_property PACKAGE_PIN D36 [get_ports "m0_ddr4_adr[1]"] # Dimm 1 Address Pin 10
set_property PACKAGE_PIN B38 [get_ports "m0_ddr4_adr[10]"] # Dimm 1 Address Pin 11
set_property PACKAGE_PIN C35 [get_ports "m0_ddr4_adr[11]"] # Dimm 1 Address Pin 12
set_property PACKAGE_PIN B36 [get_ports "m0_ddr4_adr[12]"] # Dimm 1 Address Pin 13
set_property PACKAGE_PIN B35 [get_ports "m0_ddr4_adr[13]"] # Dimm 1 Address Pin 14
set_property PACKAGE_PIN A36 [get_ports "m0_ddr4_adr[14]"] # Dimm 1 Address Pin 15
set_property PACKAGE_PIN A34 [get_ports "m0_ddr4_adr[15]"] # Dimm 1 Address Pin 16
set_property PACKAGE_PIN A35 [get_ports "m0_ddr4_adr[16]"] # Dimm 1 Address Pin 17
#set_property PACKAGE_PIN C38 [get_ports "m0_ddr4_adr[17]"] # Dimm 1 Address Pin 1
set_property PACKAGE_PIN F34 [get_ports "m0_ddr4_adr[2]"] # Dimm 1 Address Pin 2
set_property PACKAGE_PIN E34 [get_ports "m0_ddr4_adr[3]"] # Dimm 1 Address Pin 3
set_property PACKAGE_PIN E36 [get_ports "m0_ddr4_adr[4]"] # Dimm 1 Address Pin 4
set_property PACKAGE_PIN D37 [get_ports "m0_ddr4_adr[5]"] # Dimm 1 Address Pin 5
set_property PACKAGE_PIN C39 [get_ports "m0_ddr4_adr[6]"] # Dimm 1 Address Pin 6
set_property PACKAGE_PIN D34 [get_ports "m0_ddr4_adr[7]"] # Dimm 1 Address Pin 7
set_property PACKAGE_PIN C34 [get_ports "m0_ddr4_adr[8]"] # Dimm 1 Address Pin 8
set_property PACKAGE_PIN C37 [get_ports "m0_ddr4_adr[9]"] # Dimm 1 Address Pin 9
#set_property PACKAGE_PIN B37 [get_ports "m0_ddr4_alert_n"] # Dimm 1 Active Low Alert
set_property PACKAGE_PIN F35 [get_ports "m0_ddr4_ba[0]"] # Dimm 1 Bank Address 0
set_property PACKAGE_PIN F36 [get_ports "m0_ddr4_ba[1]"] # Dimm 1 Bank Address 1
set_property PACKAGE_PIN E37 [get_ports "m0_ddr4_bg[0]"] # Dimm 1 Bank Group 0
set_property PACKAGE_PIN E38 [get_ports "m0_ddr4_bg[1]"] # Dimm 1 Bank Address 1
#set_property PACKAGE_PIN H39 [get_ports "m0_ddr4_c[0]"] # Dimm 1 Active Low Chip Select2
#set_property PACKAGE_PIN H37 [get_ports "m0_ddr4_c[1]"] # Dimm 1 Active Low Chip Select3
#set_property PACKAGE_PIN A38 [get_ports "m0_ddr4_c[2]"] # Dimm 1 Die Select
#set_property PACKAGE_PIN C33 [get_ports "m0_ddr4_c[3]"] # Dimm 1 RFU
#set_property PACKAGE_PIN B43 [get_ports "m0_ddr4_c[4]"] # Dimm 1 RFU
set_property PACKAGE_PIN D39 [get_ports "m0_ddr4_ck_c"] # Dimm 1 Clock
set_property PACKAGE_PIN H35 [get_ports "m0_ddr4_cke[0]"] # Dimm 1 Clock Enable 0
#set_property PACKAGE_PIN G38 [get_ports "m0_ddr4_cke[1]"] # Dimm 1 Clock Enable 1
set_property PACKAGE_PIN E39 [get_ports "m0_ddr4_ck_t"] # Dimm 1 Clock
set_property PACKAGE_PIN H38 [get_ports "m0_ddr4_cs_n[0]"] # Dimm 1 Active Low Chip Select0
#set_property PACKAGE_PIN H34 [get_ports "m0_ddr4_cs_n[1]"] # Dimm 1 Active Low Chip Select1
set_property PACKAGE_PIN A28 [get_ports "m0_ddr4_dq[0]"] # Dimm 1 Data pin 0
set_property PACKAGE_PIN B28 [get_ports "m0_ddr4_dq[1]"] # Dimm 1 Data pin 10
set_property PACKAGE_PIN C32 [get_ports "m0_ddr4_dq[10]"] # Dimm 1 Data pin 11
set_property PACKAGE_PIN D32 [get_ports "m0_ddr4_dq[11]"] # Dimm 1 Data pin 12
set_property PACKAGE_PIN E33 [get_ports "m0_ddr4_dq[12]"] # Dimm 1 Data pin 13
set_property PACKAGE_PIN F33 [get_ports "m0_ddr4_dq[13]"] # Dimm 1 Data pin 14
set_property PACKAGE_PIN E29 [get_ports "m0_ddr4_dq[14]"] # Dimm 1 Data pin 15
set_property PACKAGE_PIN F29 [get_ports "m0_ddr4_dq[15]"] # Dimm 1 Data pin 16
set_property PACKAGE_PIN F30 [get_ports "m0_ddr4_dq[16]"] # Dimm 1 Data pin 17
set_property PACKAGE_PIN G30 [get_ports "m0_ddr4_dq[17]"] # Dimm 1 Data pin 18
set_property PACKAGE_PIN F31 [get_ports "m0_ddr4_dq[18]"] # Dimm 1 Data pin 19
set_property PACKAGE_PIN G31 [get_ports "m0_ddr4_dq[19]"] # Dimm 1 Data pin 1
set_property PACKAGE_PIN A30 [get_ports "m0_ddr4_dq[2]"] # Dimm 1 Data pin 20
set_property PACKAGE_PIN G32 [get_ports "m0_ddr4_dq[20]"] # Dimm 1 Data pin 21
set_property PACKAGE_PIN H32 [get_ports "m0_ddr4_dq[21]"] # Dimm 1 Data pin 22
set_property PACKAGE_PIN H30 [get_ports "m0_ddr4_dq[22]"] # Dimm 1 Data pin 23
set_property PACKAGE_PIN H29 [get_ports "m0_ddr4_dq[23]"] # Dimm 1 Data pin 24
set_property PACKAGE_PIN J29 [get_ports "m0_ddr4_dq[24]"] # Dimm 1 Data pin 25
set_property PACKAGE_PIN K29 [get_ports "m0_ddr4_dq[25]"] # Dimm 1 Data pin 26
set_property PACKAGE_PIN J31 [get_ports "m0_ddr4_dq[26]"] # Dimm 1 Data pin 27
set_property PACKAGE_PIN J30 [get_ports "m0_ddr4_dq[27]"] # Dimm 1 Data pin 28
set_property PACKAGE_PIN K31 [get_ports "m0_ddr4_dq[28]"] # Dimm 1 Data pin 29
set_property PACKAGE_PIN L31 [get_ports "m0_ddr4_dq[29]"] # Dimm 1 Data pin 2
set_property PACKAGE_PIN A29 [get_ports "m0_ddr4_dq[3]"] # Dimm 1 Data pin 30
set_property PACKAGE_PIN L30 [get_ports "m0_ddr4_dq[30]"] # Dimm 1 Data pin 31
set_property PACKAGE_PIN L29 [get_ports "m0_ddr4_dq[31]"] # Dimm 1 Data pin 32
set_property PACKAGE_PIN A40 [get_ports "m0_ddr4_dq[32]"] # Dimm 1 Data pin 33
set_property PACKAGE_PIN A39 [get_ports "m0_ddr4_dq[33]"] # Dimm 1 Data pin 34
set_property PACKAGE_PIN B42 [get_ports "m0_ddr4_dq[34]"] # Dimm 1 Data pin 35
set_property PACKAGE_PIN B41 [get_ports "m0_ddr4_dq[35]"] # Dimm 1 Data pin 36
set_property PACKAGE_PIN D41 [get_ports "m0_ddr4_dq[36]"] # Dimm 1 Data pin 37
set_property PACKAGE_PIN E41 [get_ports "m0_ddr4_dq[37]"] # Dimm 1 Data pin 38
set_property PACKAGE_PIN C40 [get_ports "m0_ddr4_dq[38]"] # Dimm 1 Data pin 39
set_property PACKAGE_PIN D40 [get_ports "m0_ddr4_dq[39]"] # Dimm 1 Data pin 3
set_property PACKAGE_PIN A33 [get_ports "m0_ddr4_dq[4]"] # Dimm 1 Data pin 40
set_property PACKAGE_PIN A44 [get_ports "m0_ddr4_dq[40]"] # Dimm 1 Data pin 41
set_property PACKAGE_PIN A43 [get_ports "m0_ddr4_dq[41]"] # Dimm 1 Data pin 42
set_property PACKAGE_PIN B45 [get_ports "m0_ddr4_dq[42]"] # Dimm 1 Data pin 43
set_property PACKAGE_PIN C44 [get_ports "m0_ddr4_dq[43]"] # Dimm 1 Data pin 44
set_property PACKAGE_PIN B46 [get_ports "m0_ddr4_dq[44]"] # Dimm 1 Data pin 45
set_property PACKAGE_PIN C45 [get_ports "m0_ddr4_dq[45]"] # Dimm 1 Data pin 46
set_property PACKAGE_PIN C43 [get_ports "m0_ddr4_dq[46]"] # Dimm 1 Data pin 47
set_property PACKAGE_PIN D42 [get_ports "m0_ddr4_dq[47]"] # Dimm 1 Data pin 48
set_property PACKAGE_PIN D45 [get_ports "m0_ddr4_dq[48]"] # Dimm 1 Data pin 49
set_property PACKAGE_PIN D44 [get_ports "m0_ddr4_dq[49]"] # Dimm 1 Data pin 4
set_property PACKAGE_PIN B32 [get_ports "m0_ddr4_dq[5]"] # Dimm 1 Data pin 50
set_property PACKAGE_PIN E44 [get_ports "m0_ddr4_dq[50]"] # Dimm 1 Data pin 51
set_property PACKAGE_PIN F44 [get_ports "m0_ddr4_dq[51]"] # Dimm 1 Data pin 52
set_property PACKAGE_PIN G45 [get_ports "m0_ddr4_dq[52]"] # Dimm 1 Data pin 53
set_property PACKAGE_PIN H45 [get_ports "m0_ddr4_dq[53]"] # Dimm 1 Data pin 54
set_property PACKAGE_PIN F46 [get_ports "m0_ddr4_dq[54]"] # Dimm 1 Data pin 55
set_property PACKAGE_PIN F45 [get_ports "m0_ddr4_dq[55]"] # Dimm 1 Data pin 56
set_property PACKAGE_PIN G43 [get_ports "m0_ddr4_dq[56]"] # Dimm 1 Data pin 57
set_property PACKAGE_PIN H43 [get_ports "m0_ddr4_dq[57]"] # Dimm 1 Data pin 58
set_property PACKAGE_PIN G42 [get_ports "m0_ddr4_dq[58]"] # Dimm 1 Data pin 59
set_property PACKAGE_PIN G41 [get_ports "m0_ddr4_dq[59]"] # Dimm 1 Data pin 5
set_property PACKAGE_PIN C29 [get_ports "m0_ddr4_dq[6]"] # Dimm 1 Data pin 60
set_property PACKAGE_PIN J41 [get_ports "m0_ddr4_dq[60]"] # Dimm 1 Data pin 61
set_property PACKAGE_PIN J40 [get_ports "m0_ddr4_dq[61]"] # Dimm 1 Data pin 62
set_property PACKAGE_PIN H42 [get_ports "m0_ddr4_dq[62]"] # Dimm 1 Data pin 63
set_property PACKAGE_PIN J42 [get_ports "m0_ddr4_dq[63]"] # Dimm 1 Data pin 64
set_property PACKAGE_PIN J37 [get_ports "m0_ddr4_dq[64]"] # Dimm 1 Data pin 65
set_property PACKAGE_PIN K37 [get_ports "m0_ddr4_dq[65]"] # Dimm 1 Data pin 66
set_property PACKAGE_PIN K34 [get_ports "m0_ddr4_dq[66]"] # Dimm 1 Data pin 67
set_property PACKAGE_PIN L34 [get_ports "m0_ddr4_dq[67]"] # Dimm 1 Data pin 68
set_property PACKAGE_PIN J36 [get_ports "m0_ddr4_dq[68]"] # Dimm 1 Data pin 69
set_property PACKAGE_PIN K36 [get_ports "m0_ddr4_dq[69]"] # Dimm 1 Data pin 6
set_property PACKAGE_PIN C28 [get_ports "m0_ddr4_dq[7]"] # Dimm 1 Data pin 70
set_property PACKAGE_PIN K39 [get_ports "m0_ddr4_dq[70]"] # Dimm 1 Data pin 71
set_property PACKAGE_PIN L39 [get_ports "m0_ddr4_dq[71]"] # Dimm 1 Data pin 7
set_property PACKAGE_PIN D29 [get_ports "m0_ddr4_dq[8]"] # Dimm 1 Data pin 8
set_property PACKAGE_PIN E28 [get_ports "m0_ddr4_dq[9]"] # Dimm 1 Data pin 9
set_property PACKAGE_PIN A31 [get_ports "m0_ddr4_dqs_c[0]"] # Dimm 1 Data Strobe 0
set_property PACKAGE_PIN B31 [get_ports "m0_ddr4_dqs_c[1]"] # Dimm 1 Data Strobe 10
set_property PACKAGE_PIN A46 [get_ports "m0_ddr4_dqs_c[10]"] # Dimm 1 Data Strobe 11
set_property PACKAGE_PIN E43 [get_ports "m0_ddr4_dqs_c[11]"] # Dimm 1 Data Strobe 12
set_property PACKAGE_PIN D46 [get_ports "m0_ddr4_dqs_c[12]"] # Dimm 1 Data Strobe 13
set_property PACKAGE_PIN H44 [get_ports "m0_ddr4_dqs_c[13]"] # Dimm 1 Data Strobe 14
set_property PACKAGE_PIN G40 [get_ports "m0_ddr4_dqs_c[14]"] # Dimm 1 Data Strobe 15
set_property PACKAGE_PIN K42 [get_ports "m0_ddr4_dqs_c[15]"] # Dimm 1 Data Strobe 16
set_property PACKAGE_PIN K38 [get_ports "m0_ddr4_dqs_c[16]"] # Dimm 1 Data Strobe 17
set_property PACKAGE_PIN L36 [get_ports "m0_ddr4_dqs_c[17]"] # Dimm 1 Data Strobe 1
set_property PACKAGE_PIN D31 [get_ports "m0_ddr4_dqs_c[2]"] # Dimm 1 Data Strobe 2
set_property PACKAGE_PIN E32 [get_ports "m0_ddr4_dqs_c[3]"] # Dimm 1 Data Strobe 3
set_property PACKAGE_PIN F28 [get_ports "m0_ddr4_dqs_c[4]"] # Dimm 1 Data Strobe 4
set_property PACKAGE_PIN G33 [get_ports "m0_ddr4_dqs_c[5]"] # Dimm 1 Data Strobe 5
set_property PACKAGE_PIN J32 [get_ports "m0_ddr4_dqs_c[6]"] # Dimm 1 Data Strobe
set_property PACKAGE_PIN K33 [get_ports "m0_ddr4_dqs_c[7]"] # Dimm 1 Data Strobe 7
set_property PACKAGE_PIN A41 [get_ports "m0_ddr4_dqs_c[8]"] # Dimm 1 Data Strobe 8
set_property PACKAGE_PIN F41 [get_ports "m0_ddr4_dqs_c[9]"] # Dimm 1 Data Strobe 9
set_property PACKAGE_PIN B30 [get_ports "m0_ddr4_dqs_t[0]"] # Dimm 1 Data Strobe 0
set_property PACKAGE_PIN C30 [get_ports "m0_ddr4_dqs_t[1]"] # Dimm 1 Data Strobe 10
set_property PACKAGE_PIN A45 [get_ports "m0_ddr4_dqs_t[10]"] # Dimm 1 Data Strobe 11
set_property PACKAGE_PIN E42 [get_ports "m0_ddr4_dqs_t[11]"] # Dimm 1 Data Strobe 12
set_property PACKAGE_PIN E46 [get_ports "m0_ddr4_dqs_t[12]"] # Dimm 1 Data Strobe 13
set_property PACKAGE_PIN J44 [get_ports "m0_ddr4_dqs_t[13]"] # Dimm 1 Data Strobe 14
set_property PACKAGE_PIN H40 [get_ports "m0_ddr4_dqs_t[14]"] # Dimm 1 Data Strobe 15
set_property PACKAGE_PIN K41 [get_ports "m0_ddr4_dqs_t[15]"] # Dimm 1 Data Strobe 16
set_property PACKAGE_PIN L38 [get_ports "m0_ddr4_dqs_t[16]"] # Dimm 1 Data Strobe 17
set_property PACKAGE_PIN L35 [get_ports "m0_ddr4_dqs_t[17]"] # Dimm 1 Data Strobe 1
set_property PACKAGE_PIN D30 [get_ports "m0_ddr4_dqs_t[2]"] # Dimm 1 Data Strobe 2
set_property PACKAGE_PIN E31 [get_ports "m0_ddr4_dqs_t[3]"] # Dimm 1 Data Strobe 3
set_property PACKAGE_PIN G28 [get_ports "m0_ddr4_dqs_t[4]"] # Dimm 1 Data Strobe 4
set_property PACKAGE_PIN H33 [get_ports "m0_ddr4_dqs_t[5]"] # Dimm 1 Data Strobe 5
set_property PACKAGE_PIN K32 [get_ports "m0_ddr4_dqs_t[6]"] # Dimm 1 Data Strobe 6
set_property PACKAGE_PIN L33 [get_ports "m0_ddr4_dqs_t[7]"] # Dimm 1 Data Strobe 7
set_property PACKAGE_PIN B40 [get_ports "m0_ddr4_dqs_t[8]"] # Dimm 1 Data Strobe 8
set_property PACKAGE_PIN F40 [get_ports "m0_ddr4_dqs_t[9]"] # Dimm 1 Data Strobe 9
set_property PACKAGE_PIN F39 [get_ports "m0_ddr4_odt[0]"] # Dimm 1 On Die Termination 0
#set_property PACKAGE_PIN G37 [get_ports "m0_ddr4_odt[1]"] # Dimm 1 On Die Termination 1
set_property PACKAGE_PIN F38 [get_ports "m0_ddr4_parity"] # Dimm 1 Parity
set_property PACKAGE_PIN J39 [get_ports "m0_ddr4_reset_n"] # Dimm 1 Active Low Reset

### RDIMM 2
set_property PACKAGE_PIN BM42  [get_ports "m1_ddr4_act_n"] # Dimm 2 Activation Command Low
set_property PACKAGE_PIN BJ41  [get_ports "m1_ddr4_adr[0]"]  # Dimm 2 Address 0
set_property PACKAGE_PIN BK41  [get_ports "m1_ddr4_adr[1]"]  # Dimm 2 Address 10
set_property PACKAGE_PIN BF46  [get_ports "m1_ddr4_adr[10]"]  # Dimm 2 Address 11
set_property PACKAGE_PIN BF42  [get_ports "m1_ddr4_adr[11]"]  # Dimm 2 Address 12
set_property PACKAGE_PIN BF43  [get_ports "m1_ddr4_adr[12]"]  # Dimm 2 Address 13
set_property PACKAGE_PIN BC42  [get_ports "m1_ddr4_adr[13]"]  # Dimm 2 Address 14
set_property PACKAGE_PIN BD42  [get_ports "m1_ddr4_adr[14]"]  # Dimm 2 Address 15
set_property PACKAGE_PIN BE43  [get_ports "m1_ddr4_adr[15]"]  # Dimm 2 Address 16
set_property PACKAGE_PIN BE44  [get_ports "m1_ddr4_adr[16]"]  # Dimm 2 Address 17
#set_property PACKAGE_PIN BF41  [get_ports "m1_ddr4_adr[17]"]  # Dimm 2 Address 1
set_property PACKAGE_PIN BG42  [get_ports "m1_ddr4_adr[2]"]  # Dimm 2 Address 2
set_property PACKAGE_PIN BG43  [get_ports "m1_ddr4_adr[3]"]  # Dimm 2 Address 3
set_property PACKAGE_PIN BG44  [get_ports "m1_ddr4_adr[4]"]  # Dimm 2 Address 4
set_property PACKAGE_PIN BG45  [get_ports "m1_ddr4_adr[5]"]  # Dimm 2 Address 5
set_property PACKAGE_PIN BH41  [get_ports "m1_ddr4_adr[6]"]  # Dimm 2 Address 6
set_property PACKAGE_PIN BD41  [get_ports "m1_ddr4_adr[7]"]  # Dimm 2 Address 7
set_property PACKAGE_PIN BE41  [get_ports "m1_ddr4_adr[8]"]  # Dimm 2 Address 8
set_property PACKAGE_PIN BF45  [get_ports "m1_ddr4_adr[9]"]  # Dimm 2 Address 9
#set_property PACKAGE_PIN BE45  [get_ports "m1_ddr4_alert_n"] # Dimm 2 Active Low Alert
set_property PACKAGE_PIN BH42  [get_ports "m1_ddr4_ba[0]"] # Dimm 2 Bank Address 0
set_property PACKAGE_PIN BJ42  [get_ports "m1_ddr4_ba[1]"]  # Dimm 2 Bank Address 1
set_property PACKAGE_PIN BH44  [get_ports "m1_ddr4_bg[0]"]  # Dimm 2 Bank Group 0
set_property PACKAGE_PIN BH45  [get_ports "m1_ddr4_bg[1]"]  # Dimm 2 Bank Group 1
#set_property PACKAGE_PIN BM47  [get_ports "m1_ddr4_c[0]"] # Dimm 2 Active Low Chip Select2
#set_property PACKAGE_PIN BL45  [get_ports "m1_ddr4_c[1]"] # Dimm 2 Active Low Chip Select3
#set_property PACKAGE_PIN BE46  [get_ports "m1_ddr4_c[2]"] # Dimm 2 Die Select
#set_property PACKAGE_PIN BG33  [get_ports "m1_ddr4_c[3]"] # Dimm 2 RFU
#set_property PACKAGE_PIN BF53  [get_ports "m1_ddr4_c[4]"] # Dimm 2 RFU
set_property PACKAGE_PIN BJ46  [get_ports "m1_ddr4_ck_c"]  # Dimm 2 Clock
set_property PACKAGE_PIN BL43  [get_ports "m1_ddr4_cke[0]"] # Dimm 2 Clock Enable 0
#set_property PACKAGE_PIN BK45  "5 [get_ports "m1_ddr4_cke[1]"] # Dimm 2 Clock Enable 1
set_property PACKAGE_PIN BH46  [get_ports "m1_ddr4_ck_t"]  # Dimm 2 Clock
set_property PACKAGE_PIN BL46  [get_ports "m1_ddr4_cs_n[0]"] # Dimm 2 Active Low Chip Select0
#set_property PACKAGE_PIN BL42  "2 [get_ports "m1_ddr4_cs_n[1]"] # Dimm 2 Active Low Chip Select1
set_property PACKAGE_PIN BJ31  [get_ports "m1_ddr4_dq[0]"] # Dimm 2 Data Pin 0
set_property PACKAGE_PIN BH31  [get_ports "m1_ddr4_dq[1]"] # Dimm 2 Data Pin 10
set_property PACKAGE_PIN BF36  [get_ports "m1_ddr4_dq[10]"] # Dimm 2 Data Pin 11
set_property PACKAGE_PIN BF35  [get_ports "m1_ddr4_dq[11]"] # Dimm 2 Data Pin 12
set_property PACKAGE_PIN BG35  [get_ports "m1_ddr4_dq[12]"] # Dimm 2 Data Pin 13
set_property PACKAGE_PIN BG34  [get_ports "m1_ddr4_dq[13]"] # Dimm 2 Data Pin 14
set_property PACKAGE_PIN BJ34  [get_ports "m1_ddr4_dq[14]"] # Dimm 2 Data Pin 15
set_property PACKAGE_PIN BJ33  [get_ports "m1_ddr4_dq[15]"] # Dimm 2 Data Pin 16
set_property PACKAGE_PIN BL33  [get_ports "m1_ddr4_dq[16]"] # Dimm 2 Data Pin 17
set_property PACKAGE_PIN BK33  [get_ports "m1_ddr4_dq[17]"] # Dimm 2 Data Pin 18
set_property PACKAGE_PIN BL31  [get_ports "m1_ddr4_dq[18]"] # Dimm 2 Data Pin 19
set_property PACKAGE_PIN BK31  [get_ports "m1_ddr4_dq[19]"] # Dimm 2 Data Pin 1
set_property PACKAGE_PIN BF33  [get_ports "m1_ddr4_dq[2]"] # Dimm 2 Data Pin 20
set_property PACKAGE_PIN BM33  [get_ports "m1_ddr4_dq[20]"] # Dimm 2 Data Pin 21
set_property PACKAGE_PIN BL32  [get_ports "m1_ddr4_dq[21]"] # Dimm 2 Data Pin 22
set_property PACKAGE_PIN BP34  [get_ports "m1_ddr4_dq[22]"] # Dimm 2 Data Pin 23
set_property PACKAGE_PIN BN34  [get_ports "m1_ddr4_dq[23]"] # Dimm 2 Data Pin 24
set_property PACKAGE_PIN BP32  [get_ports "m1_ddr4_dq[24]"] # Dimm 2 Data Pin 25
set_property PACKAGE_PIN BN32  [get_ports "m1_ddr4_dq[25]"] # Dimm 2 Data Pin 26
set_property PACKAGE_PIN BM30  [get_ports "m1_ddr4_dq[26]"] # Dimm 2 Data Pin 27
set_property PACKAGE_PIN BL30  [get_ports "m1_ddr4_dq[27]"] # Dimm 2 Data Pin 28
set_property PACKAGE_PIN BP31  [get_ports "m1_ddr4_dq[28]"] # Dimm 2 Data Pin 29
set_property PACKAGE_PIN BN31  [get_ports "m1_ddr4_dq[29]"] # Dimm 2 Data Pin 2
set_property PACKAGE_PIN BF32  [get_ports "m1_ddr4_dq[3]"] # Dimm 2 Data Pin 30
set_property PACKAGE_PIN BP29  [get_ports "m1_ddr4_dq[30]"] # Dimm 2 Data Pin 31
set_property PACKAGE_PIN BP28  [get_ports "m1_ddr4_dq[31]"] # Dimm 2 Data Pin 32
set_property PACKAGE_PIN BE51  [get_ports "m1_ddr4_dq[32]"] # Dimm 2 Data Pin 33
set_property PACKAGE_PIN BD51  [get_ports "m1_ddr4_dq[33]"] # Dimm 2 Data Pin 34
set_property PACKAGE_PIN BE50  [get_ports "m1_ddr4_dq[34]"] # Dimm 2 Data Pin 35
set_property PACKAGE_PIN BE49  [get_ports "m1_ddr4_dq[35]"] # Dimm 2 Data Pin 36
set_property PACKAGE_PIN BF52  [get_ports "m1_ddr4_dq[36]"] # Dimm 2 Data Pin 37
set_property PACKAGE_PIN BF51  [get_ports "m1_ddr4_dq[37]"] # Dimm 2 Data Pin 38
set_property PACKAGE_PIN BG50  [get_ports "m1_ddr4_dq[38]"] # Dimm 2 Data Pin 39
set_property PACKAGE_PIN BF50  [get_ports "m1_ddr4_dq[39]"] # Dimm 2 Data Pin 3
set_property PACKAGE_PIN BG32  [get_ports "m1_ddr4_dq[4]"] # Dimm 2 Data Pin 40
set_property PACKAGE_PIN BE54  [get_ports "m1_ddr4_dq[40]"] # Dimm 2 Data Pin 41
set_property PACKAGE_PIN BE53  [get_ports "m1_ddr4_dq[41]"] # Dimm 2 Data Pin 42
set_property PACKAGE_PIN BG54  [get_ports "m1_ddr4_dq[42]"] # Dimm 2 Data Pin 43
set_property PACKAGE_PIN BG53  [get_ports "m1_ddr4_dq[43]"] # Dimm 2 Data Pin 44
set_property PACKAGE_PIN BK54  [get_ports "m1_ddr4_dq[44]"] # Dimm 2 Data Pin 45
set_property PACKAGE_PIN BK53  [get_ports "m1_ddr4_dq[45]"] # Dimm 2 Data Pin 46
set_property PACKAGE_PIN BH52  [get_ports "m1_ddr4_dq[46]"] # Dimm 2 Data Pin 47
set_property PACKAGE_PIN BG52  [get_ports "m1_ddr4_dq[47]"] # Dimm 2 Data Pin 48
set_property PACKAGE_PIN BH50  [get_ports "m1_ddr4_dq[48]"] # Dimm 2 Data Pin 49
set_property PACKAGE_PIN BH49  [get_ports "m1_ddr4_dq[49]"] # Dimm 2 Data Pin 4
set_property PACKAGE_PIN BF31  [get_ports "m1_ddr4_dq[5]"] # Dimm 2 Data Pin 50
set_property PACKAGE_PIN BJ51  [get_ports "m1_ddr4_dq[50]"] # Dimm 2 Data Pin 51
set_property PACKAGE_PIN BH51  [get_ports "m1_ddr4_dq[51]"] # Dimm 2 Data Pin 52
set_property PACKAGE_PIN BJ49  [get_ports "m1_ddr4_dq[52]"] # Dimm 2 Data Pin 53
set_property PACKAGE_PIN BJ48  [get_ports "m1_ddr4_dq[53]"] # Dimm 2 Data Pin 54
set_property PACKAGE_PIN BK51  [get_ports "m1_ddr4_dq[54]"] # Dimm 2 Data Pin 55
set_property PACKAGE_PIN BK50  [get_ports "m1_ddr4_dq[55]"] # Dimm 2 Data Pin 56
set_property PACKAGE_PIN BL53  [get_ports "m1_ddr4_dq[56]"] # Dimm 2 Data Pin 57
set_property PACKAGE_PIN BL52  [get_ports "m1_ddr4_dq[57]"] # Dimm 2 Data Pin 58
set_property PACKAGE_PIN BM52  [get_ports "m1_ddr4_dq[58]"] # Dimm 2 Data Pin 59
set_property PACKAGE_PIN BL51  [get_ports "m1_ddr4_dq[59]"] # Dimm 2 Data Pin 5
set_property PACKAGE_PIN BH30  [get_ports "m1_ddr4_dq[6]"] # Dimm 2 Data Pin 60
set_property PACKAGE_PIN BN49  [get_ports "m1_ddr4_dq[60]"] # Dimm 2 Data Pin 61
set_property PACKAGE_PIN BM48  [get_ports "m1_ddr4_dq[61]"] # Dimm 2 Data Pin 62
set_property PACKAGE_PIN BN51  [get_ports "m1_ddr4_dq[62]"] # Dimm 2 Data Pin 63
set_property PACKAGE_PIN BN50  [get_ports "m1_ddr4_dq[63]"] # Dimm 2 Data Pin 64
set_property PACKAGE_PIN BN45  [get_ports "m1_ddr4_dq[64]"] # Dimm 2 Data Pin 65
set_property PACKAGE_PIN BM45  [get_ports "m1_ddr4_dq[65]"] # Dimm 2 Data Pin 66
set_property PACKAGE_PIN BN44  [get_ports "m1_ddr4_dq[66]"] # Dimm 2 Data Pin 67
set_property PACKAGE_PIN BM44  [get_ports "m1_ddr4_dq[67]"] # Dimm 2 Data Pin 68
set_property PACKAGE_PIN BP44  [get_ports "m1_ddr4_dq[68]"] # Dimm 2 Data Pin 69
set_property PACKAGE_PIN BP43  [get_ports "m1_ddr4_dq[69]"] # Dimm 2 Data Pin 6
set_property PACKAGE_PIN BH29  [get_ports "m1_ddr4_dq[7]"] # Dimm 2 Data Pin 70
set_property PACKAGE_PIN BP47  [get_ports "m1_ddr4_dq[70]"] # Dimm 2 Data Pin 71
set_property PACKAGE_PIN BN47  [get_ports "m1_ddr4_dq[71]"] # Dimm 2 Data Pin 7
set_property PACKAGE_PIN BH35  [get_ports "m1_ddr4_dq[8]"] # Dimm 2 Data Pin 8
set_property PACKAGE_PIN BH34  [get_ports "m1_ddr4_dq[9]"] # Dimm 2 Data Pin 9
set_property PACKAGE_PIN BK30  [get_ports "m1_ddr4_dqs_c[0]"] # Dimm 2 Data Strobe 0
set_property PACKAGE_PIN BG30  [get_ports "m1_ddr4_dqs_c[1]"] # Dimm 2 Data Strobe 10
set_property PACKAGE_PIN BJ54  [get_ports "m1_ddr4_dqs_c[10]"] # Dimm 2 Data Strobe 11
set_property PACKAGE_PIN BJ53  [get_ports "m1_ddr4_dqs_c[11]"] # Dimm 2 Data Strobe 12
set_property PACKAGE_PIN BJ47  [get_ports "m1_ddr4_dqs_c[12]"] # Dimm 2 Data Strobe 13
set_property PACKAGE_PIN BK49  [get_ports "m1_ddr4_dqs_c[13]"] # Dimm 2 Data Strobe 14
set_property PACKAGE_PIN BM50  [get_ports "m1_ddr4_dqs_c[14]"] # Dimm 2 Data Strobe 15
set_property PACKAGE_PIN BP49  [get_ports "m1_ddr4_dqs_c[15]"] # Dimm 2 Data Strobe 16
set_property PACKAGE_PIN BP46  [get_ports "m1_ddr4_dqs_c[16]"] # Dimm 2 Data Strobe 17
set_property PACKAGE_PIN BP42  [get_ports "m1_ddr4_dqs_c[17]"] # Dimm 2 Data Strobe 1
set_property PACKAGE_PIN BK35  [get_ports "m1_ddr4_dqs_c[2]"] # Dimm 2 Data Strobe 2
set_property PACKAGE_PIN BJ32  [get_ports "m1_ddr4_dqs_c[3]"] # Dimm 2 Data Strobe 3
set_property PACKAGE_PIN BM35  [get_ports "m1_ddr4_dqs_c[4]"] # Dimm 2 Data Strobe 4
set_property PACKAGE_PIN BN35  [get_ports "m1_ddr4_dqs_c[5]"] # Dimm 2 Data Strobe 5
set_property PACKAGE_PIN BN30  [get_ports "m1_ddr4_dqs_c[6]"] # Dimm 2 Data Strobe 6
set_property PACKAGE_PIN BM29  [get_ports "m1_ddr4_dqs_c[7]"] # Dimm 2 Data Strobe 7
set_property PACKAGE_PIN BF48  [get_ports "m1_ddr4_dqs_c[8]"] # Dimm 2 Data Strobe 8
set_property PACKAGE_PIN BG49  [get_ports "m1_ddr4_dqs_c[9]"] # Dimm 2 Data Strobe 9
set_property PACKAGE_PIN BJ29  [get_ports "m1_ddr4_dqs_t[0]"] # Dimm 2 Data Strobe 0
set_property PACKAGE_PIN BG29  [get_ports "m1_ddr4_dqs_t[1]"] # Dimm 2 Data Strobe 10
set_property PACKAGE_PIN BH54  [get_ports "m1_ddr4_dqs_t[10]"] # Dimm 2 Data Strobe 11
set_property PACKAGE_PIN BJ52  [get_ports "m1_ddr4_dqs_t[11]"] # Dimm 2 Data Strobe 12
set_property PACKAGE_PIN BH47  [get_ports "m1_ddr4_dqs_t[12]"] # Dimm 2 Data Strobe 13
set_property PACKAGE_PIN BK48  [get_ports "m1_ddr4_dqs_t[13]"] # Dimm 2 Data Strobe 14
set_property PACKAGE_PIN BM49  [get_ports "m1_ddr4_dqs_t[14]"] # Dimm 2 Data Strobe 15
set_property PACKAGE_PIN BP48  [get_ports "m1_ddr4_dqs_t[15]"] # Dimm 2 Data Strobe 16
set_property PACKAGE_PIN BN46  [get_ports "m1_ddr4_dqs_t[16]"] # Dimm 2 Data Strobe 17
set_property PACKAGE_PIN BN42  [get_ports "m1_ddr4_dqs_t[17]"] # Dimm 2 Data Strobe 1
set_property PACKAGE_PIN BK34  [get_ports "m1_ddr4_dqs_t[2]"] # Dimm 2 Data Strobe 2
set_property PACKAGE_PIN BH32  [get_ports "m1_ddr4_dqs_t[3]"] # Dimm 2 Data Strobe 3
set_property PACKAGE_PIN BL35  [get_ports "m1_ddr4_dqs_t[4]"] # Dimm 2 Data Strobe 4
set_property PACKAGE_PIN BM34  [get_ports "m1_ddr4_dqs_t[5]"] # Dimm 2 Data Strobe 5
set_property PACKAGE_PIN BN29  [get_ports "m1_ddr4_dqs_t[6]"] # Dimm 2 Data Strobe 6
set_property PACKAGE_PIN BM28  [get_ports "m1_ddr4_dqs_t[7]"] # Dimm 2 Data Strobe 7
set_property PACKAGE_PIN BF47  [get_ports "m1_ddr4_dqs_t[8]"] # Dimm 2 Data Strobe 8
set_property PACKAGE_PIN BG48  [get_ports "m1_ddr4_dqs_t[9]"] # Dimm 2 Data Strobe 9
set_property PACKAGE_PIN BK46  [get_ports "m1_ddr4_odt[0]"] # Dimm 2 On Die Termination 0
#set_property PACKAGE_PIN BJ43  [get_ports "m1_ddr4_odt[1]"] # Dimm 2 On Die Termination 1
set_property PACKAGE_PIN BJ44  [get_ports "m1_ddr4_parity"] # Dimm 2 Parity
set_property PACKAGE_PIN BL47  [get_ports "m1_ddr4_reset_n"] # Dimm 2 Active Low Reset

##############################################
##########        HBM Clocks        ##########
##############################################
set_property PACKAGE_PIN BH27 [get_ports hbm_ref_clk_0_p] # HBM Refclk 0
set_property PACKAGE_PIN BJ27 [get_ports hbm_ref_clk_0_n]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports hbm_ref_clk_0_p]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports hbm_ref_clk_0_n]
set_property ODT RTT_48 [get_ports hbm_ref_clk_0_p]

set_property PACKAGE_PIN BH26 [get_ports hbm_ref_clk_1_p] # HBM Refclk 1
set_property PACKAGE_PIN BH25 [get_ports hbm_ref_clk_1_n]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports hbm_ref_clk_1_p]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports hbm_ref_clk_1_n]
set_property ODT RTT_48 [get_ports hbm_ref_clk_1_p]

##############################################
########## GTY Reference Clocks ##########
##############################################
# NOTE: Period constraint represents 322/265625 MHz reference clock - Modify as necessary
set_property PACKAGE_PIN AJ15 [get_ports gty_refclk0p_i[0]] # GTY Bank 228 Refclk 0 / SI5341A CLK 3
set_property PACKAGE_PIN AJ14 [get_ports gty_refclk0n_i[0]]
create_clock -name gtrefclk0_22 -period 3.104 [get_ports gty_refclk0p_i[0]]

set_property PACKAGE_PIN AH13 [get_ports gty_refclk1p_i[0]] # GTY Bank 228 Refclk 1 / SI5341B CLK 9
set_property PACKAGE_PIN AH12 [get_ports gty_refclk1n_i[0]]
create_clock -name gtrefclk1_22 -period 3.104 [get_ports gty_refclk1p_i[0]]

set_property PACKAGE_PIN AD13 [get_ports gty_refclk0p_i[1]] # GTY Bank 229 Refclk 0 / SI5341A CLK 2
set_property PACKAGE_PIN AD12 [get_ports gty_refclk0n_i[1]]
create_clock -name gtrefclk0_23 -period 3.104 [get_ports gty_refclk0p_i[1]]

set_property PACKAGE_PIN AC15 [get_ports gty_refclk1p_i[1]] # GTY Bank 229 Refclk 1 / SI5341B CLK 8
set_property PACKAGE_PIN AC14 [get_ports gty_refclk1n_i[1]]
create_clock -name gtrefclk1_23 -period 3.104 [get_ports gty_refclk1p_i[1]]

set_property PACKAGE_PIN V13 [get_ports gty_refclk0p_i[2]] # GTY Bank 232 Refclk 0 / SI5341A CLK 1
set_property PACKAGE_PIN V12 [get_ports gty_refclk0n_i[2]]
create_clock -name gtrefclk0_26 -period 3.104 [get_ports gty_refclk0p_i[2]]

set_property PACKAGE_PIN U15 [get_ports gty_refclk1p_i[2]] # GTY Bank 232 Refclk 1 / SI5341B CLK 7
set_property PACKAGE_PIN U14 [get_ports gty_refclk1n_i[2]]
create_clock -name gtrefclk1_26 -period 3.104 [get_ports gty_refclk1p_i[2]]

set_property PACKAGE_PIN P13 [get_ports gty_refclk0p_i[3]] # GTY Bank 233 Refclk 0 / SI5341A CLK 0
set_property PACKAGE_PIN P12 [get_ports gty_refclk0n_i[3]]
create_clock -name gtrefclk0_26 -period 3.104 [get_ports gty_refclk0p_i[3]]

set_property PACKAGE_PIN M13 [get_ports gty_refclk1p_i[3]] # GTY Bank 233 Refclk 1 / SI5341 CLK 6
set_property PACKAGE_PIN M12 [get_ports gty_refclk1n_i[3]]
create_clock -name gtrefclk1_27 -period 3.104 [get_ports gty_refclk1p_i[3]]

##############################################
########## GTY QSFP Connector Pins  ##########
##############################################
# NOTE: All GTY pins are automatically assigned by Vivado. Shown here for reference only.

#GTY BANK 228 QSFP4 3:0
#set_property PACKAGE_PIN AL6  [get_ports gty_rxp_i[0]] # QSFP4_RX_P_0 QSFP Port 3 Input Pin 0
#set_property PACKAGE_PIN AL5  [get_ports gty_rxn_i[0]] # QSFP4_RX_N_0
#set_property PACKAGE_PIN AK4  [get_ports gty_rxp_i[1]] # QSFP4_RX_P_1 QSFP Port 3 Input Pin 1
#set_property PACKAGE_PIN AK3  [get_ports gty_rxn_i[1]] # QSFP4_RX_N_1
#set_property PACKAGE_PIN AJ2  [get_ports gty_rxp_i[2]] # QSFP4_RX_P_2 QSFP Port 3 Input Pin 2
#set_property PACKAGE_PIN AJ1  [get_ports gty_rxn_i[2]] # QSFP4_RX_N_2
#set_property PACKAGE_PIN AH4  [get_ports gty_rxp_i[3]] # QSFP4_RX_P_3 QSFP Port 3 Input Pin 3
#set_property PACKAGE_PIN AH3  [get_ports gty_rxn_i[3]] # QSFP4_RX_N_3
#set_property PACKAGE_PIN AK9  [get_ports gty_txp_o[0]] # QSFP4_TX_P_0 QSFP Port 3 Output Pin 0
#set_property PACKAGE_PIN AK8  [get_ports gty_txn_o[0]] # QSFP4_TX_N_0
#set_property PACKAGE_PIN AJ7  [get_ports gty_txp_o[1]] # QSFP4_TX_P_1 QSFP Port 3 Output Pin 1
#set_property PACKAGE_PIN AJ6  [get_ports gty_txn_o[1]] # QSFP4_TX_N_1
#set_property PACKAGE_PIN AJ11 [get_ports gty_txp_o[2]] # QSFP4_TX_P_2 QSFP Port 3 Output Pin 2
#set_property PACKAGE_PIN AJ10 [get_ports gty_txn_o[2]] # QSFP4_TX_N_2
#set_property PACKAGE_PIN AD9  [get_ports gty_txp_o[3]] # QSFP4_TX_P_3 QSFP Port 3 Output Pin 3
#set_property PACKAGE_PIN AD8  [get_ports gty_txn_o[3]] # QSFP4_TX_N_3

#GTY BANK 230 QSFP3 3:0
#set_property PACKAGE_PIN AD4  [get_ports gty_rxp_i[4]] # QSFP3_RX_P_0 QSFP Port 1 Input Pin 0
#set_property PACKAGE_PIN AD3  [get_ports gty_rxn_i[4]] # QSFP3_RX_N_0
#set_property PACKAGE_PIN AC2  [get_ports gty_rxp_i[5]] # QSFP3_RX_P_1 QSFP Port 1 Input Pin 1
#set_property PACKAGE_PIN AC1  [get_ports gty_rxn_i[5]] # QSFP3_RX_N_1
#set_property PACKAGE_PIN AC6  [get_ports gty_rxp_i[6]] # QSFP3_RX_P_2 QSFP Port 1 Input Pin 2
#set_property PACKAGE_PIN AC5  [get_ports gty_rxn_i[6]] # QSFP3_RX_N_2
#set_property PACKAGE_PIN AB4  [get_ports gty_rxp_i[7]] # QSFP3_RX_P_3 QSFP Port 1 Input Pin 3
#set_property PACKAGE_PIN AB3  [get_ports gty_rxn_i[7]] # QSFP3_RX_N_3
#set_property PACKAGE_PIN AD9  [get_ports gty_txp_o[4]] # QSFP3_TX_P_0 QSFP Port 1 Output Pin 0
#set_property PACKAGE_PIN AD8  [get_ports gty_txn_o[4]] # QSFP3_TX_N_0
#set_property PACKAGE_PIN AC11 [get_ports gty_txp_o[5]] # QSFP3_TX_P_1 QSFP Port 1 Output Pin 1
#set_property PACKAGE_PIN AC10 [get_ports gty_txn_o[5]] # QSFP3_TX_N_1
#set_property PACKAGE_PIN AB9  [get_ports gty_txp_o[6]] # QSFP3_TX_P_2 QSFP Port 1 Output Pin 2
#set_property PACKAGE_PIN AB8  [get_ports gty_txn_o[6]] # QSFP3_TX_N_2
#set_property PACKAGE_PIN AA7  [get_ports gty_txp_o[7]] # QSFP3_TX_P_3 QSFP Port 1 Output Pin 3
#set_property PACKAGE_PIN AA6  [get_ports gty_txn_o[7]] # QSFP3_TX_N_3

#GTY BANK 233 QSFP2 3:0
#set_property PACKAGE_PIN R6   [get_ports gty_rxp_i[8]] # QSFP2_RX_P_0 QSFP Port 2 Input Pin 0
#set_property PACKAGE_PIN R5   [get_ports gty_rxn_i[8]] # QSFP2_RX_N_0
#set_property PACKAGE_PIN P4   [get_ports gty_rxp_i[9]] # QSFP2_RX_P_1 QSFP Port 2 Input Pin 1
#set_property PACKAGE_PIN P3   [get_ports gty_rxn_i[9]] # QSFP2_RX_N_1
#set_property PACKAGE_PIN N2   [get_ports gty_rxp_i[10]] # QSFP2_RX_P_2 QSFP Port 2 Input Pin 2
#set_property PACKAGE_PIN N1   [get_ports gty_rxn_i[10]] # QSFP2_RX_N_2
#set_property PACKAGE_PIN M4   [get_ports gty_rxp_i[11]] # QSFP2_RX_P_3 QSFP Port 2 Input Pin 3
#set_property PACKAGE_PIN M3   [get_ports gty_rxn_i[11] # QSFP2_RX_P_3
#set_property PACKAGE_PIN P9   [get_ports gty_txp_o[8]] # QSFP2_TX_P_0 QSFP Port 2 Output Pin 0
#set_property PACKAGE_PIN P8   [get_ports gty_txn_o[8]] # QSFP2_TX_N_0
#set_property PACKAGE_PIN N7   [get_ports gty_txp_o[9]] # QSFP2_TX_P_1 QSFP Port 2 Output Pin 1
#set_property PACKAGE_PIN N6   [get_ports gty_txn_o[9]] # QSFP2_TX_N_1
#set_property PACKAGE_PIN N11  [get_ports gty_txp_o[10]] # QSFP2_TX_P_2 QSFP Port 2 Output Pin 2
#set_property PACKAGE_PIN N10  [get_ports gty_txn_o[10]] # QSFP2_TX_N_2
#set_property PACKAGE_PIN M9   [get_ports gty_txp_o[11]] # QSFP2_TX_P_3 QSFP Port 2 Output Pin 3
#set_property PACKAGE_PIN M8   [get_ports gty_txn_o[11]] # QSFP2_TX_N_3

#GTY BANK 235 QSFP1 3:0
#set_property PACKAGE_PIN G2   [get_ports gty_rxp_i[12]] # QSFP1_RX_P_0 QSFP Port 0 Input Pin 0
#set_property PACKAGE_PIN G1   [get_ports gty_rxn_i[12]] # QSFP1_RX_N_0
#set_property PACKAGE_PIN F4   [get_ports gty_rxp_i[13]] # QSFP1_RX_P_1 QSFP Port 0 Input Pin 1
#set_property PACKAGE_PIN F3   [get_ports gty_rxn_i[13]] # QSFP1_RX_N_1
#set_property PACKAGE_PIN E2   [get_ports gty_rxp_i[14]] # QSFP1_RX_P_2 QSFP Port 0 Input Pin 2
#set_property PACKAGE_PIN E1   [get_ports gty_rxn_i[14]] # QSFP1_RX_N_2
#set_property PACKAGE_PIN D4   [get_ports gty_rxp_i[15]] # QSFP1_RX_P_3 QSFP Port 0 Input Pin 3
#set_property PACKAGE_PIN D3   [get_ports gty_rxn_i[15]] # QSFP1_RX_P_3
#set_property PACKAGE_PIN G7   [get_ports gty_txp_o[12]] # QSFP1_TX_P_0 QSFP Port 0 Output Pin 0
#set_property PACKAGE_PIN G6   [get_ports gty_txn_o[12]] # QSFP1_TX_N_0
#set_property PACKAGE_PIN E7   [get_ports gty_txp_o[13]] # QSFP1_TX_P_1 QSFP Port 0 Output Pin 1
#set_property PACKAGE_PIN E6   [get_ports gty_txn_o[13]] # QSFP1_TX_N_1
#set_property PACKAGE_PIN C7   [get_ports gty_txp_o[14]] # QSFP1_TX_P_2 QSFP Port 0 Output Pin 2
#set_property PACKAGE_PIN C6   [get_ports gty_txn_o[14]] # QSFP1_TX_N_2
#set_property PACKAGE_PIN A6   [get_ports gty_txp_o[15]] # QSFP1_TX_P_3 QSFP Port 0 Output Pin 3
#set_property PACKAGE_PIN A5   [get_ports gty_txn_o[15]] # QSFP1_TX_N_3

##############################################
########## GTY SAS Reference Clocks ##########
##############################################
# NOTE: Clock periods below assume a 322.265625 MHz clock, please adjust as necessary based on your application

set_property PACKAGE_PIN AN40 [get_ports gty_sas_refclk0p_i[0]] # GTY Bank 120 SAS 2 OSC 1
set_property PACKAGE_PIN AN41 [get_ports gty_sas_refclk0n_i[0]]
create_clock -name gtrefclk0_1 -period 3.104 [get_ports gty_sas_refclk0p_i[0]]

set_property PACKAGE_PIN AM42 [get_ports gty_sas_refclk1p_i[0]] # GTY Bank 120 SAS 2 CLK 0
set_property PACKAGE_PIN AM43 [get_ports gty_sas_refclk1n_i[0]]
create_clock -name gtrefclk1_1 -period 3.104 [get_ports gty_sas_refclk1p_i[0]]

set_property PACKAGE_PIN AL40 [get_ports gty_sas_refclk0p_i[1]] # GTY Bank 121 SAS 2 OSC 0
set_property PACKAGE_PIN AL41 [get_ports gty_sas_refclk0n_i[1]]
create_clock -name gtrefclk0_3 -period 3.104 [get_ports gty_sas_refclk0p_i[1]]

set_property PACKAGE_PIN AK42 [get_ports gty_sas_refclk1p_i[1]] # GTY Bank 121 SAS 2 CLK 1
set_property PACKAGE_PIN AK43 [get_ports gty_sas_refclk1n_i[1]]
create_clock -name gtrefclk1_3 -period 3.104 [get_ports gty_sas_refclk1p_i[1]]

set_property PACKAGE_PIN AD42 [get_ports gty_sas_refclk0p_i[2]] # GTY Bank 129 SAS 1 OSC 0
set_property PACKAGE_PIN AD43 [get_ports gty_sas_refclk0n_i[2]]
create_clock -name gtrefclk0_6 -period 3.104 [get_ports gty_sas_refclk0p_i[2]]

set_property PACKAGE_PIN AC40 [get_ports gty_sas_refclk1p_i[2]] # GTY Bank 129 SAS 1 CLK 0
set_property PACKAGE_PIN AC41 [get_ports gty_sas_refclk1n_i[2]]
create_clock -name gtrefclk1_6 -period 3.104 [get_ports gty_sas_refclk1p_i[2]]

set_property PACKAGE_PIN V42 [get_ports gty_sas_refclk0p_i[3]] # GTY Bank 133 SAS 1 OSC 1
set_property PACKAGE_PIN V43 [get_ports gty_sas_refclk0n_i[3]]
create_clock -name gtrefclk0_8 -period 3.104 [get_ports gty_sas_refclk0p_i[3]]

set_property PACKAGE_PIN U40 [get_ports gty_sas_refclk1p_i[3]] # GTY Bank 133 SAS 1 CLK 1
set_property PACKAGE_PIN U41 [get_ports gty_sas_refclk1n_i[3]]
create_clock -name gtrefclk1_8 -period 3.104 [get_ports gty_sas_refclk1p_i[3]]

##############################################
##########      GTY SAS Pins        ##########
##############################################
# NOTE: All GTY pins are automatically assigned by Vivado. Shown here for reference only.

#GTY BANK 126 SAS 2 3:0
#set_property PACKAGE_PIN AU53 [get_ports gty_sas_rxp_i[0]] # SAS2_RX_P_0
#set_property PACKAGE_PIN AU54 [get_ports gty_sas_rxn_i[0]] # SAS2_RX_N_0
#set_property PACKAGE_PIN AT51 [get_ports gty_sas_rxp_i[1]] # SAS2_RX_P_1
#set_property PACKAGE_PIN AT52 [get_ports gty_sas_rxn_i[1]] # SAS2_RX_N_1
#set_property PACKAGE_PIN AR53 [get_ports gty_sas_rxp_i[2]] # SAS2_RX_P_2
#set_property PACKAGE_PIN AR54 [get_ports gty_sas_rxn_i[2]] # SAS2_RX_N_2
#set_property PACKAGE_PIN AP51 [get_ports gty_sas_rxp_i[3]] # SAS2_RX_P_3
#set_property PACKAGE_PIN AP52 [get_ports gty_sas_rxn_i[3]] # SAS2_RX_P_3
#set_property PACKAGE_PIN AU48 [get_ports gty_sas_txp_o[0]] # SAS2_TX_P_0
#set_property PACKAGE_PIN AU49 [get_ports gty_sas_txn_o[0]] # SAS2_TX_N_0
#set_property PACKAGE_PIN AT46 [get_ports gty_sas_txp_o[1]] # SAS2_TX_P_1
#set_property PACKAGE_PIN AT47 [get_ports gty_sas_txn_o[1]] # SAS2_TX_N_1
#set_property PACKAGE_PIN AR48 [get_ports gty_sas_txp_o[2]] # SAS2_TX_P_2
#set_property PACKAGE_PIN AR49 [get_ports gty_sas_txn_o[2]] # SAS2_TX_N_2
#set_property PACKAGE_PIN AR44 [get_ports gty_sas_txp_o[3]] # SAS2_TX_P_3
#set_property PACKAGE_PIN AR45 [get_ports gty_sas_txn_o[3]] # SAS2_TX_N_3

#GTY BANK 127 SAS 2 7:4
#set_property PACKAGE_PIN AN53 [get_ports gty_sas_rxp_i[4]] # SAS2_RX_P_4
#set_property PACKAGE_PIN AN54 [get_ports gty_sas_rxn_i[4]] # SAS2_RX_N_4
#set_property PACKAGE_PIN AN49 [get_ports gty_sas_rxp_i[5]] # SAS2_RX_P_5
#set_property PACKAGE_PIN AN50 [get_ports gty_sas_rxn_i[5]] # SAS2_RX_N_5
#set_property PACKAGE_PIN AM51 [get_ports gty_sas_rxp_i[6]] # SAS2_RX_P_6
#set_property PACKAGE_PIN AM52 [get_ports gty_sas_rxn_i[6]] # SAS2_RX_N_6
#set_property PACKAGE_PIN AL53 [get_ports gty_sas_rxp_i[7]] # SAS2_RX_P_7
#set_property PACKAGE_PIN AL54 [get_ports gty_sas_rxn_i[7]] # SAS2_RX_N_7
#set_property PACKAGE_PIN AP46 [get_ports gty_sas_txp_o[4]] # SAS2_TX_P_4
#set_property PACKAGE_PIN AP47 [get_ports gty_sas_txn_o[4]] # SAS2_TX_N_4
#set_property PACKAGE_PIN AN44 [get_ports gty_sas_txp_o[5]] # SAS2_TX_P_5
#set_property PACKAGE_PIN AN45 [get_ports gty_sas_txn_o[5]] # SAS2_TX_N_5
#set_property PACKAGE_PIN AM46 [get_ports gty_sas_txp_o[6]] # SAS2_TX_P_6
#set_property PACKAGE_PIN AM47 [get_ports gty_sas_txn_o[6]] # SAS2_TX_N_6
#set_property PACKAGE_PIN AL44 [get_ports gty_sas_txp_o[7]] # SAS2_TX_P_7
#set_property PACKAGE_PIN AL45 [get_ports gty_sas_txn_o[7]] # SAS2_TX_N_7

#GTY BANK 130 SAS 1 3:0
#set_property PACKAGE_PIN AD46 [get_ports gty_sas_rxp_i[8]]  # SAS1_RX_P_0
#set_property PACKAGE_PIN AD47 [get_ports gty_sas_rxn_i[8]]  # SAS1_RX_N_0
#set_property PACKAGE_PIN AC53 [get_ports gty_sas_rxp_i[9]]  # SAS1_RX_P_1
#set_property PACKAGE_PIN AC54 [get_ports gty_sas_rxn_i[9]]  # SAS1_RX_N_1
#set_property PACKAGE_PIN AC49 [get_ports gty_sas_rxp_i[10]] # SAS1_RX_P_2
#set_property PACKAGE_PIN AC50 [get_ports gty_sas_rxn_i[10]] # SAS1_RX_N_2
#set_property PACKAGE_PIN AB51 [get_ports gty_sas_rxp_i[11]] # SAS1_RX_P_3
#set_property PACKAGE_PIN AB52 [get_ports gty_sas_rxn_i[11]] # SAS1_RX_N_3
#set_property PACKAGE_PIN AD46 [get_ports gty_sas_txp_o[8]]  # SAS1_TX_P_0
#set_property PACKAGE_PIN AD47 [get_ports gty_sas_txn_o[8]]  # SAS1_TX_N_0
#set_property PACKAGE_PIN AC44 [get_ports gty_sas_txp_o[9]]  # SAS1_TX_P_1
#set_property PACKAGE_PIN AC45 [get_ports gty_sas_txn_o[9]]  # SAS1_TX_N_1
#set_property PACKAGE_PIN AB46 [get_ports gty_sas_txp_o[10]] # SAS1_TX_P_2
#set_property PACKAGE_PIN AB47 [get_ports gty_sas_txn_o[10]] # SAS1_TX_N_2
#set_property PACKAGE_PIN AA48 [get_ports gty_sas_txp_o[11]] # SAS1_TX_P_3
#set_property PACKAGE_PIN AA49 [get_ports gty_sas_txn_o[11]] # SAS1_TX_N_3

#GTY BANK 133 SAS 1 7:4
#set_property PACKAGE_PIN R49  [get_ports gty_sas_rxp_i[12]] # SAS1_RX_P_4
#set_property PACKAGE_PIN R50  [get_ports gty_sas_rxn_i[12]] # SAS1_RX_N_4
#set_property PACKAGE_PIN P51  [get_ports gty_sas_rxp_i[13]] # SAS1_RX_P_5
#set_property PACKAGE_PIN P52  [get_ports gty_sas_rxn_i[13]] # SAS1_RX_N_5
#set_property PACKAGE_PIN N53  [get_ports gty_sas_rxp_i[14]] # SAS1_RX_P_6
#set_property PACKAGE_PIN N54  [get_ports gty_sas_rxn_i[14]] # SAS1_RX_N_6
#set_property PACKAGE_PIN M51  [get_ports gty_sas_rxp_i[15]] # SAS1_RX_P_7
#set_property PACKAGE_PIN M52  [get_ports gty_sas_rxn_i[15]] # SAS1_RX_N_7
#set_property PACKAGE_PIN P46  [get_ports gty_sas_txp_o[12]] # SAS1_TX_P_4
#set_property PACKAGE_PIN P47  [get_ports gty_sas_txn_o[12]] # SAS1_TX_N_4
#set_property PACKAGE_PIN N48  [get_ports gty_sas_txp_o[13]] # SAS1_TX_P_5
#set_property PACKAGE_PIN N49  [get_ports gty_sas_txn_o[13]] # SAS1_TX_N_5
#set_property PACKAGE_PIN N44  [get_ports gty_sas_txp_o[14]] # SAS1_TX_P_6
#set_property PACKAGE_PIN N45  [get_ports gty_sas_txn_o[14]] # SAS1_TX_N_6
#set_property PACKAGE_PIN M46  [get_ports gty_sas_txp_o[15]] # SAS1_TX_P_7
#set_property PACKAGE_PIN M47  [get_ports gty_sas_txn_o[15]] # SAS1_TX_N_7

###############################################
########## GTY USB C Reference Clocks ##########
###############################################
# NOTE: Clock periods below assume a 322.265625 MHz clock, please adjust as necessary based on your application
set_property PACKAGE_PIN Y13 [get_ports gty_usbc_refclk0p_i[0]] # GTY Bank 230 Clk 0
set_property PACKAGE_PIN Y12 [get_ports gty_usbc_refclk0n_i[0]]
create_clock -name gtrefclk0_usbc_24 -period 3.104 [get_ports gty_usbc_refclk0p_i[0]]

set_property PACKAGE_PIN W15 [get_ports gty_usbc_refclk1p_i[0]] # GTY Bank 230 Clk 1
set_property PACKAGE_PIN W14 [get_ports gty_usbc_refclk1n_i[0]]
create_clock -name gtrefclk1_usbc_24 -period 3.104 [get_ports gty_usbc_refclk1p_i[0]]

##############################################
##########       GTY USB C Pins      ##########
##############################################
# NOTE: All GTY pins are automatically assigned by Vivado. Shown here for reference only.

#GTY BANK 230 USBC
#set_property PACKAGE_PIN U2  [get_ports gty_usbc_rxp_i[0]] # USBC_RX_P_1
#set_property PACKAGE_PIN U1  [get_ports gty_usbc_rxn_i[0]] # USBC_RX_N_1
#set_property PACKAGE_PIN U6  [get_ports gty_usbc_rxp_i[1]] # USBC_RX_P_2
#set_property PACKAGE_PIN U5  [get_ports gty_usbc_rxn_i[1]] # USBC_RX_N_2
#set_property PACKAGE_PIN V9  [get_ports gty_usbc_txp_i[1]] # USBC_TX_P_1
#set_property PACKAGE_PIN V8  [get_ports gty_usbc_txn_i[1]] # USBC_TX_N_1
#set_property PACKAGE_PIN U11 [get_ports gty_usbc_txp_i[2]] # USBC_TX_P_2
#set_property PACKAGE_PIN U10 [get_ports gty_usbc_txn_i[2]] # USBC_TX_N_2
