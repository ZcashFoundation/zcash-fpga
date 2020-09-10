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
  parameter DAT_BYTS = 8     // Only tested at 8 byte data width
)(
  // Clocks and resets
  input i_clk_100, i_rst_100, // 100 MHz clock
  input i_clk_200, i_rst_200, // 200 MHz clock
  input i_clk_300, i_rst_300, // 300 MHz clock
  input i_clk_if, i_rst_if,   // Command interface clock (e.g. UART / PCIe)
  // AXI lite interface
  if_axi_lite.sink     axi_lite_if,
  // Command interface input and output
  if_axi_stream.sink   rx_if,
  if_axi_stream.source tx_if

);

localparam CTL_BITS = 8;
localparam USE_XILINX_FIFO = "YES"; // If you use this make sure you generate the ip folder in aws/cl_zcash/ip

// These are the resets combined with the user reset
logic usr_rst_100, rst_100;
logic usr_rst_200, rst_200;
logic usr_rst_300, rst_300;
logic usr_rst;

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) equihash_axi(i_clk_if);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) equihash_axi_s(i_clk_100);

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) secp256k1_out_if(i_clk_if);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) secp256k1_in_if(i_clk_if);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) secp256k1_out_if_s(i_clk_200);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) secp256k1_in_if_s(i_clk_200);

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

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(1)) tx_int_if [1:0] (i_clk_if);

control_top #(
  .DAT_BYTS ( DAT_BYTS )
)
control_top (
  .i_clk ( i_clk_if ),
  .i_rst ( i_rst_if ),
  .o_usr_rst ( usr_rst ),
  .rx_if ( rx_if ),
  .tx_if ( tx_int_if[0] ),
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
  .DAT_BYTS( DAT_BYTS )
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

if (USE_XILINX_FIFO == "YES") begin
  
  logic cdc_fifo_secp256k1_rx_full, cdc_fifo_secp256k1_rx_empty, cdc_fifo_secp256k1_rx_wr_rst_busy, cdc_fifo_secp256k1_rx_rd_rst_busy;
  
  always_comb begin
    secp256k1_out_if.rdy = ~cdc_fifo_secp256k1_rx_full && ~cdc_fifo_secp256k1_rx_wr_rst_busy;
    secp256k1_out_if_s.val = ~cdc_fifo_secp256k1_rx_rd_rst_busy && ~cdc_fifo_secp256k1_rx_empty;
    secp256k1_out_if_s.ctl = 0;
    secp256k1_out_if_s.err = 0;
    secp256k1_out_if_s.mod = 0;  
  end
    
  fifo_generator_0 cdc_fifo_secp256k1_rx (
    .srst       (i_rst_if),
    .wr_clk     (i_clk_if),
    .rd_clk     (i_clk_200),
    .din        ({secp256k1_out_if.dat, secp256k1_out_if.sop, secp256k1_out_if.eop}),
    .wr_en      (secp256k1_out_if.val), 
    .rd_en      (secp256k1_out_if_s.rdy && secp256k1_out_if_s.val),
    .dout       ({secp256k1_out_if_s.dat, secp256k1_out_if_s.sop, secp256k1_out_if_s.eop}),
    .full       (cdc_fifo_secp256k1_rx_full),
    .empty      (cdc_fifo_secp256k1_rx_empty),
    .wr_rst_busy(cdc_fifo_secp256k1_rx_wr_rst_busy),
    .rd_rst_busy(cdc_fifo_secp256k1_rx_rd_rst_busy)
  );
  
  logic cdc_fifo_secp256k1_tx_full, cdc_fifo_secp256k1_tx_empty, cdc_fifo_secp256k1_tx_wr_rst_busy, cdc_fifo_secp256k1_tx_rd_rst_busy;
  
  always_comb begin
    secp256k1_in_if_s.rdy = ~cdc_fifo_secp256k1_tx_full && ~cdc_fifo_secp256k1_tx_wr_rst_busy;
    secp256k1_in_if.val = ~cdc_fifo_secp256k1_tx_rd_rst_busy && ~cdc_fifo_secp256k1_tx_empty;
    secp256k1_in_if.ctl = 0;
    secp256k1_in_if.err = 0;
    secp256k1_in_if.mod = 0;  
  end
    
  fifo_generator_0 cdc_fifo_secp256k1_tx (
      .srst       (i_rst_if),
      .wr_clk     (i_clk_200),
      .rd_clk     (i_clk_if),
      .din        ({secp256k1_in_if_s.dat, secp256k1_in_if_s.sop, secp256k1_in_if_s.eop}),
      .wr_en      (secp256k1_in_if_s.val), 
      .rd_en      (secp256k1_in_if.rdy && secp256k1_in_if.val),
      .dout       ({secp256k1_in_if.dat, secp256k1_in_if.sop, secp256k1_in_if.eop}),
      .full       (cdc_fifo_secp256k1_tx_full),
      .empty      (cdc_fifo_secp256k1_tx_empty),
      .wr_rst_busy(cdc_fifo_secp256k1_tx_wr_rst_busy),
      .rd_rst_busy(cdc_fifo_secp256k1_tx_rd_rst_busy)
    );  
    
end else begin
    
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
  
end



// We add pipelining so this block can be on a different SLR
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) secp256k1_out_if_s_r(i_clk_200);
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) secp256k1_in_if_s_r(i_clk_200);

pipeline_if  #(
  .DAT_BYTS( DAT_BYTS ),
  .CTL_BITS( CTL_BITS ),
  .NUM_STAGES (2)
)
secp256k1_pipeline_if0 (
  .i_rst ( rst_200 ),
  .i_if  ( secp256k1_out_if_s   ),
  .o_if  ( secp256k1_out_if_s_r )
);

pipeline_if  #(
  .DAT_BYTS( DAT_BYTS ),
  .CTL_BITS( CTL_BITS ),
  .NUM_STAGES (2)
)
secp256k1_pipeline_if1 (
  .i_rst ( rst_200 ),
  .i_if  ( secp256k1_in_if_s_r ),
  .o_if  ( secp256k1_in_if_s   )
);


secp256k1_top secp256k1_top (
  .i_clk      ( i_clk_200 ),
  .i_rst      ( rst_200 || ENB_VERIFY_SECP256K1_SIG == 0 ),
  .if_cmd_rx  ( secp256k1_out_if_s_r ),
  .if_cmd_tx  ( secp256k1_in_if_s_r  )
);

bls12_381_top #(
  .USE_KARATSUBA ( BLS12_381_USE_KARATSUBA )
)
bls12_381_top (
  .i_clk ( i_clk_if ),
  .i_rst ( i_rst_if || ENB_BLS12_381 == 0 ),
  .tx_if ( tx_int_if[1] ),
  .axi_lite_if ( axi_lite_if )
);

// Mux output of control block and BLS12_381 block
packet_arb # (
  .DAT_BYTS ( DAT_BYTS ),
  .CTL_BITS ( 1 ),
  .NUM_IN   ( 2 )
) packet_arb_tx (
  .i_clk ( i_clk_if ),
  .i_rst ( i_rst_if ),
  .i_axi ( tx_int_if ),
  .o_axi ( tx_if )
);

endmodule