/*
  Fifo used for CDC crossing but with interfaces.
  
  Uses either BRAM or registers for the memory, and grey coding for the rd/wr pointers.
 
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

module cdc_fifo_if #(
  parameter SIZE = 4,         // Needs to be a power of 2
  parameter USE_BRAM = 0,  // If using BRAM there is an extra cycle delay between reads
  parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE"
) (
  input i_clk_a, i_rst_a,
  input i_clk_b, i_rst_b,
  if_axi_stream.sink          i_a,
  output logic                o_full_a,
  if_axi_stream.source        o_b,
  output logic                o_emp_b
);

cdc_fifo #(
  .SIZE     ( SIZE             ),
  .DAT_BITS ( i_a.DAT_BITS + i_a.MOD_BITS + i_a.CTL_BITS + 3 ),
  .USE_BRAM ( USE_BRAM            ),
  .RAM_PERFORMANCE (RAM_PERFORMANCE )
) 
cdc_fifo (
  .i_clk_a ( i_clk_a ),
  .i_rst_a ( i_rst_a ),
  .i_clk_b ( i_clk_b ),
  .i_rst_b ( i_rst_b ),

  .i_val_a ( i_a.val ),
  .i_dat_a ( {i_a.ctl,
              i_a.dat,
              i_a.mod,
              i_a.sop,
              i_a.eop,
              i_a.err} ),
  .o_rdy_a ( i_a.rdy ),
  .o_full_a(o_full_a),
  .o_val_b ( o_b.val ),
  .o_dat_b ( {o_b.ctl,
              o_b.dat,
              o_b.mod,
              o_b.sop,
              o_b.eop,
              o_b.err} ),
  .i_rdy_b ( o_b.rdy ),
  .o_emp_b (o_emp_b),
  .o_rd_wrds_b()
);
  
endmodule