/*
  This performs a 256 bit multiplication followed by modulus
  operation.
  
  Using Karatsuba-Ofman multiplication, where the factor of splitting 
  is parameterized.
  
  Each level in Karatsuba-Ofman multiplication adds 1 clock cycle.
  The modulus reduction takes 3 clock cycles.
 
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

module secp256k1_mult_mod (
  input i_clk, i_rst,
  // Input value
  input [255:0] i_dat_a,
  input [255:0] i_dat_b,
  input         i_val,
  input         i_err,
  output logic  o_rdy,
  // output
  output logic [255:0] o_dat,
  input                i_rdy,
  output logic         o_val,
  output logic         o_err 
);
  
import secp256k1_pkg::*;
import common_pkg::*;

localparam KARATSUBA_LEVEL = 3;
if_axi_stream #(.DAT_BYTS(512/8)) int_if(i_clk);

always_comb o_rdy = int_if.rdy;

logic [KARATSUBA_LEVEL-1:0] val, err;

karatsuba_ofman_mult # (
  .BITS  ( 256             ),
  .LEVEL ( KARATSUBA_LEVEL )
)
karatsuba_ofman_mult (
  .i_clk  ( i_clk      ),
  .i_dat_a( i_dat_a    ),
  .i_dat_b( i_dat_b    ),  
  .o_dat  ( int_if.dat )
);

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    val <= 0;
    err <= 0;
  end else begin
    val <= {val, i_val};
    err <= {err, i_err};
  end
end

always_comb begin
  int_if.val = val[KARATSUBA_LEVEL-1];
  int_if.err = err[KARATSUBA_LEVEL-1];
  int_if.mod = 0;
  int_if.sop = 0;
  int_if.eop = 0;
  int_if.ctl = 0;
end

secp256k1_mod #(
  .USE_MULT ( 0 )
)
secp256k1_mod (
  .i_clk( i_clk       ),
  .i_rst( i_rst       ),
  .i_dat( int_if.dat  ),
  .i_val( int_if.val  ),
  .i_err( int_if.err  ),
  .o_rdy( int_if.rdy  ),
  .o_dat( o_dat ),
  .o_err( o_err ),
  .i_rdy( i_rdy ),
  .o_val( o_val )
);


endmodule
