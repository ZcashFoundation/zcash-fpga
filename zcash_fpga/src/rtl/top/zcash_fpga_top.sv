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
  import zcash_verif_pkg::*; 
#(
  parameter DAT_BYTS = 8
)(
  // Clocks and resets

  input i_clk_100, i_rst_100,
  
  // Interface inputs and outputs
  // UART
  if_axi_stream.sink   uart_if_rx,
  if_axi_stream.source uart_if_tx,
  // Ethernet
  if_axi_stream.sink   eth_if_rx,
  if_axi_stream.source eth_if_tx,
  // PCIe
  if_axi_stream.sink   pcie_if_rx,
  if_axi_stream.source pcie_if_tx  
);

// This block is used to verify a equihash solution
zcash_verif_equihash #(
  .DAT_BYTS(DAT_BYTS)
)
equihash_verif_top (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  
  .i_clk_300 ( i_clk_300 ),
  .i_rst_300 ( i_rst_300 ),  // Faster clock
  
  .i_axi      ( equihash_verif_if       ),
  .o_mask     ( equihash_verif_mask     ),
  .o_mask_val ( equihash_verif_mask_val )
);  


endmodule