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
  parameter IF_DAT_BYTS = 2,
  parameter CORE_DAT_BYTS = 8 // Only tested at 8 byte data width
)(
  // Clocks and resets
  input i_clk_200, i_rst_200,
  input i_clk_300, i_rst_300,
  input i_clk_if, i_rst_if,
  
  // Interface input and output
  // UART
  if_axi_stream.sink   rx_if,
  if_axi_stream.source tx_if
);

logic usr_rst, core_clk, core_rst;
if_axi_stream #(.DAT_BYTS(CORE_DAT_BYTS)) equihash_axi(core_clk);

equihash_bm_t equihash_mask;
logic         equihash_mask_val;
  
always_comb begin
  core_clk = i_clk_200;
  core_rst = i_rst_200;
end

// This block takes in the interface signals and interfaces with other blocks
control_top #(
  .CORE_DAT_BYTS ( CORE_DAT_BYTS ),
  .IN_DAT_BYTS   ( IF_DAT_BYTS   )
)
control_top (
  .i_clk_core ( core_clk ),
  .i_rst_core ( core_rst ),
  .i_clk_if ( i_clk_if ),
  .i_rst_if ( i_rst_if ),
  .o_usr_rst ( usr_rst ),
  .rx_if ( rx_if ),
  .tx_if ( tx_if ),
  .o_equihash_axi      ( equihash_axi      ),
  .i_equihash_mask     ( equihash_mask     ),
  .i_equihash_mask_val ( equihash_mask_val )
);


// This block is used to verify a equihash solution
equihash_verif_top #(
  .DAT_BYTS( CORE_DAT_BYTS )
)
equihash_verif_top (
  .i_clk ( core_clk ),
  .i_rst ( core_rst || usr_rst ),
  
  .i_clk_300 ( i_clk_300 ),
  .i_rst_300 ( i_rst_300 || usr_rst ),  // Faster clock
  
  .i_axi      ( equihash_axi      ),
  .o_mask     ( equihash_mask     ),
  .o_mask_val ( equihash_mask_val )
);  

endmodule