/*
  This is the top level of the Zcash FPGA acceleration engine.

  We have different interfaces that are all muxed together to provide FPGA
  with commands and data.

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

module zcash_fpga_top
  import zcash_fpga_pkg::*, equihash_pkg::*;
#(
  parameter CORE_DAT_BYTS = 8     // Only tested at 8 byte data width
)(
  // Clocks and resets
  input i_clk_100, i_rst_100, // 100 MHz clock
  input i_clk_200, i_rst_200, // 200 MHz clock
  input i_clk_300, i_rst_300, // 300 MHz clock
  input i_clk_if, i_rst_if,   // Command interface clock (e.g. UART / PCIe)

  // Command interface input and output
  if_axi_stream.sink   rx_if,
  if_axi_stream.source tx_if
);

localparam CORE_DAT_BITS = CORE_DAT_BYTS*8;
localparam CORE_MOD_BITS = $clog2(CORE_DAT_BYTS);
localparam CORE_CTL_BITS = 8;

// These are the resets combined with the user reset
logic usr_rst_100, rst_100;
logic usr_rst_200, rst_200;
logic usr_rst_300, rst_300;
logic usr_rst;

if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BITS(CORE_CTL_BITS)) equihash_axi(i_clk_if);
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BITS(CORE_CTL_BITS)) equihash_axi_s(i_clk_100);

if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BITS(CORE_CTL_BITS)) secp256k1_out_if(i_clk_if);
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BITS(CORE_CTL_BITS)) secp256k1_in_if(i_clk_if);
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BITS(CORE_CTL_BITS)) secp256k1_out_if_s(i_clk_200);
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BITS(CORE_CTL_BITS)) secp256k1_in_if_s(i_clk_200);

equihash_bm_t equihash_mask, equihash_mask_s;
logic         equihash_mask_val, equihash_mask_val_s;

// Synchronize resets from interface into each clock domain
synchronizer  #(.DAT_BITS ( 1 ), .NUM_CLKS ( 3 )) rst_100_sync (
  .i_clk_a ( i_clk_if    ),
  .i_clk_b ( i_clk_100   ),
  .i_dat_a ( usr_rst     ),
  .o_dat_b ( usr_rst_100 )
);
always_ff @ (posedge i_clk_200) rst_200 <= i_rst_200 || usr_rst_200;

synchronizer  #(.DAT_BITS ( 1 ), .NUM_CLKS ( 3 )) rst_200_sync (
  .i_clk_a ( i_clk_if    ),
  .i_clk_b ( i_clk_200   ),
  .i_dat_a ( usr_rst     ),
  .o_dat_b ( usr_rst_200 )
);
always_ff @ (posedge i_clk_100) rst_100 <= i_rst_100 || usr_rst_100;

synchronizer  #(.DAT_BITS ( 1 ), .NUM_CLKS ( 3 )) rst_300_sync (
  .i_clk_a ( i_clk_if    ),
  .i_clk_b ( i_clk_300   ),
  .i_dat_a ( usr_rst     ),
  .o_dat_b ( usr_rst_300 )
);
always_ff @ (posedge i_clk_300) rst_300 <= i_rst_300 || usr_rst_300;


// This block takes in the interface signals and interfaces with other blocks
// This runs on the same clock as the interface but we might need to change data width
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) rx_int_if (i_clk_if);
width_change_cdc_fifo #(
  .IN_DAT_BYTS  ( rx_if.DAT_BYTS ),
  .OUT_DAT_BYTS ( CORE_DAT_BYTS  ),
  .CTL_BITS     ( 8              ),
  .FIFO_ABITS   ( 6              ),
  .USE_BRAM     ( 1              ),
  .CDC_ASYNC    ( "NO"           )
) 
cdc_fifo_rx (
  .i_clk_a ( i_clk_if ),
  .i_rst_a ( i_rst_if ),
  .i_clk_b ( i_clk_if ),
  .i_rst_b ( i_rst_if ),
  .i_axi_a ( rx_if     ),
  .o_axi_b ( rx_int_if )
);

if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS), .CTL_BYTS(1)) tx_int_if (i_clk_if);
width_change_cdc_fifo #(
  .IN_DAT_BYTS  ( CORE_DAT_BYTS  ),
  .OUT_DAT_BYTS ( rx_if.DAT_BYTS ),
  .CTL_BITS     ( 8              ),
  .FIFO_ABITS   ( 6              ),
  .USE_BRAM     ( 1              ),
  .CDC_ASYNC    ( "NO"           )
) 
cdc_fifo_tx (
  .i_clk_a ( i_clk_if ),
  .i_rst_a ( i_rst_if ),
  .i_clk_b ( i_clk_if ),
  .i_rst_b ( i_rst_if ),
  .i_axi_a ( tx_int_if ),
  .o_axi_b ( tx_if     )
);

control_top #(
  .DAT_BYTS ( CORE_DAT_BYTS )
)
control_top (
  .i_clk ( i_clk_if ),
  .i_rst ( i_rst_if ),
  .o_usr_rst ( usr_rst ),
  .rx_if ( rx_int_if ),
  .tx_if ( tx_int_if ),
  .o_equihash_if       ( equihash_axi      ),
  .i_equihash_mask     ( equihash_mask     ),
  .i_equihash_mask_val ( equihash_mask_val ),
  .o_secp256k1_if ( secp256k1_out_if ),
  .i_secp256k1_if ( secp256k1_in_if  )
);


// This block is used to verify a equihash solution
cdc_fifo_if #(
  .SIZE     ( 16            ),
  .USE_BRAM ( 0             ),
  .RAM_PERFORMANCE ("HIGH_PERFORMANCE")
) 
cdc_fifo_equihash_rx (
  .i_clk_a ( i_clk_if ),
  .i_rst_a ( usr_rst || i_rst_if ),
  .i_clk_b ( i_clk_100 ),
  .i_rst_b ( rst_100 || ENB_VERIFY_EQUIHASH == 0 ),
  .i_a ( equihash_axi ),
  .o_full_a(),
  .o_b ( equihash_axi_s ),
  .o_emp_b ()
);
 
cdc_fifo #(
  .SIZE     ( 16 ),
  .DAT_BITS ( $bits(equihash_bm_t) ),
  .USE_BRAM ( 0 )
) 
cdc_fifo_equihash_tx (
  .i_clk_a ( i_clk_100 ),
  .i_rst_a ( rst_100 || ENB_VERIFY_EQUIHASH == 0 ),
  .i_clk_b ( i_clk_if ),
  .i_rst_b ( usr_rst || i_rst_if ),
  .i_val_a ( equihash_mask_val_s ),
  .i_dat_a ( equihash_mask_s ),
  .o_rdy_a (),
  .o_full_a(),
  .o_val_b ( equihash_mask_val ),
  .o_dat_b ( equihash_mask ),
  .i_rdy_b ( 1'd1 ),
  .o_emp_b (),
  .o_rd_wrds_b()
);

equihash_verif_top #(
  .DAT_BYTS( CORE_DAT_BYTS )
)
equihash_verif_top (
  .i_clk ( i_clk_100 ),
  .i_rst ( rst_100 || ENB_VERIFY_EQUIHASH == 0 ),
  .i_clk_300 ( i_clk_300 ),
  .i_rst_300 ( rst_300 || ENB_VERIFY_EQUIHASH == 0 ),
  .i_axi      ( equihash_axi_s    ),
  .o_mask     ( equihash_mask_s     ),
  .o_mask_val ( equihash_mask_val_s )
);


// This block is the ECCDSA block for curve secp256k1

cdc_fifo_if #(
  .SIZE     ( 16 ),
  .USE_BRAM ( 0 ),
  .RAM_PERFORMANCE ("HIGH_PERFORMANCE")
) 
cdc_fifo_secp256k1_rx (
  .i_clk_a ( i_clk_if ),
  .i_rst_a ( usr_rst || i_rst_if ),
  .i_clk_b ( i_clk_200 ),
  .i_rst_b ( rst_200 || ENB_VERIFY_SECP256K1_SIG == 0 ),
  .i_a ( secp256k1_out_if ),
  .o_full_a(),
  .o_b ( secp256k1_out_if_s ),
  .o_emp_b ()
);

cdc_fifo_if #(
  .SIZE     ( 16 ),
  .USE_BRAM ( 0 ),
  .RAM_PERFORMANCE ("HIGH_PERFORMANCE")
) 
cdc_fifo_secp256k1_tx (
  .i_clk_a ( i_clk_200  ),
  .i_rst_a ( rst_200 || ENB_VERIFY_SECP256K1_SIG == 0 ),
  .i_clk_b ( i_clk_if ),
  .i_rst_b ( usr_rst || i_rst_if  ),
  .i_a ( secp256k1_in_if_s ),
  .o_full_a(),
  .o_b ( secp256k1_in_if ),
  .o_emp_b ()
);

secp256k1_top secp256k1_top (
  .i_clk      ( i_clk_200 ),
  .i_rst      ( rst_200 || ENB_VERIFY_SECP256K1_SIG == 0 ),
  .if_cmd_rx  ( secp256k1_out_if_s ),
  .if_cmd_tx  ( secp256k1_in_if_s  )
);


endmodule