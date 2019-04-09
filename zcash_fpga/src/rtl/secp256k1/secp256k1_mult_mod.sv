/*
  This performs a 256 bit multiplication followed by optional modulus
  operation. Modulus is either n or p depending on ctl.
  
  Using Karatsuba-Ofman multiplication, where the factor of splitting 
  is parameterized.
  
  Each level in Karatsuba-Ofman multiplication adds 3 clock cycle.
  The modulus reduction takes 3 clock cycles.
  
  The barret reduction requires a 257 bit multiplication, so we multiplex
  the multiplier.
 
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

module secp256k1_mult_mod #(
  parameter CTL_BITS = 8
)(
  input i_clk, i_rst,
  // Input value
  input [255:0]        i_dat_a,
  input [255:0]        i_dat_b,
  input [CTL_BITS-1:0] i_ctl,
  input                i_val,
  input                i_cmd,  // 0 = mod p, 1 = mod n
  input                i_err,
  output logic         o_rdy,
  // output
  output logic [255:0]        o_dat,
  output logic [CTL_BITS-1:0] o_ctl,
  input                       i_rdy,
  output logic                o_val,
  output logic                o_err
);
  
import secp256k1_pkg::*;
import common_pkg::*;

localparam KARATSUBA_LEVEL = 2;

if_axi_stream #(.DAT_BITS(512+2), .CTL_BITS(CTL_BITS+1)) int_if(i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(CTL_BITS)) out_mod_p_if(i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(CTL_BITS)) out_mod_n_if(i_clk);

// If barret mod block is using an EXTERNAL multiplier this needs to be connected to a multiplier
if_axi_stream #(.DAT_BITS(512+2), .CTL_BITS(CTL_BITS)) out_brt_mult_if(i_clk);
if_axi_stream #(.DAT_BITS(512+2), .CTL_BITS(CTL_BITS)) in_brt_mult_if(i_clk);

logic [KARATSUBA_LEVEL-1:0] err;
logic [256+8-1:0] dat_a, dat_b;
logic o_rdy_int, i_val_int;

/*
always_ff @ (posedge i_clk) begin
  in_brt_mult_if.val <= out_brt_mult_if.val;
  in_brt_mult_if.dat <= out_brt_mult_if.dat[0 +: 257] * out_brt_mult_if.dat[257 +: 257];
end*/

karatsuba_ofman_mult # (
  .BITS     ( 256 + 8         ),
  .LEVEL    ( KARATSUBA_LEVEL ),
  .CTL_BITS ( CTL_BITS + 1    )
)
karatsuba_ofman_mult (
  .i_clk  ( i_clk          ),
  .i_rst  ( i_rst          ),
  .i_ctl  ( {i_cmd, i_ctl} ),
  .i_dat_a( dat_a          ),
  .i_dat_b( dat_b          ),
  .i_val  ( i_val_int      ),
  .o_rdy  ( o_rdy_int      ),
  .o_dat  ( int_if.dat     ),
  .o_val  ( int_if.val     ),
  .i_rdy  ( int_if.rdy     ),
  .o_ctl  ( int_if.ctl     )
);
  
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    err <= 0;
  end else begin
    err <= {err, i_err};
  end
end

always_comb begin
  int_if.err = err[KARATSUBA_LEVEL-1];
  int_if.mod = 0;
  int_if.sop = 0;
  int_if.eop = 0;
end

// Depending on ctl, we mux output
logic wait_barret, int_if_rdy_n, int_if_rdy_p;
logic [KARATSUBA_LEVEL*3-1:0] wait_barret_r;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    wait_barret <= 0;
    wait_barret_r <= 0;
  end else begin
    // We have to wait for pipeline to clear on output of multiplier
    wait_barret_r <= {wait_barret_r, wait_barret};
    if (i_val && o_rdy && i_cmd == 1'd1) begin
      wait_barret <= 1;
    end
    if (out_mod_n_if.val && out_mod_n_if.rdy) begin
      wait_barret <= 0;
      wait_barret_r <= 0;
    end
    
  end
end

always_comb begin

  out_mod_p_if.rdy = i_rdy;
  out_mod_n_if.rdy = i_rdy;
  out_mod_n_if.err = 0;
  
  o_rdy = o_rdy_int && ~wait_barret;
  
  in_brt_mult_if.sop = 0;
  in_brt_mult_if.eop = 0;
  in_brt_mult_if.err = 0;
  in_brt_mult_if.mod = 0;
  in_brt_mult_if.ctl = 0;
  in_brt_mult_if.val = int_if.val;
  in_brt_mult_if.dat = int_if.dat;
  
  // Prevent new input
  if (wait_barret) begin
    out_brt_mult_if.rdy = o_rdy_int;
    dat_a = {7'd0, out_brt_mult_if.dat[0 +: 257]};
    dat_b = {7'd0, out_brt_mult_if.dat[257 +: 257]};
    i_val_int = out_brt_mult_if.val;
  end else begin
    out_brt_mult_if.rdy = 0;
    dat_a = {8'd0, i_dat_a};
    dat_b = {8'd0, i_dat_b};
    i_val_int = i_val;
    in_brt_mult_if.val = 0;
  end
  
  // Take over multiplier output after pipeline is clear
  if (wait_barret_r[KARATSUBA_LEVEL*3-1]) begin
    in_brt_mult_if.val = int_if.val;
    int_if.rdy = in_brt_mult_if.rdy;
  end else begin
    in_brt_mult_if.val = 0;
    out_brt_mult_if.rdy = 0;
    int_if.rdy = int_if.ctl[CTL_BITS] == 0 ? int_if_rdy_p : int_if_rdy_n;
  end
  
  o_dat = out_mod_p_if.val ? out_mod_p_if.dat : out_mod_n_if.dat;
  o_ctl = out_mod_p_if.val ? out_mod_p_if.ctl : out_mod_n_if.ctl;
  o_err = out_mod_p_if.val ? out_mod_p_if.err : out_mod_n_if.err;
  o_val = out_mod_p_if.val ? out_mod_p_if.val : out_mod_n_if.val;
  
end

secp256k1_mod #(
  .USE_MULT ( 0        ),
  .CTL_BITS ( CTL_BITS )
)
secp256k1_mod (
  .i_clk( i_clk       ),
  .i_rst( i_rst       ),
  .i_dat( int_if.dat  ),
  .i_val( int_if.val && int_if.ctl[CTL_BITS] == 0 && ~wait_barret_r[KARATSUBA_LEVEL*3-1]),
  .i_ctl( int_if.ctl[CTL_BITS-1:0]  ),
  .i_err( int_if.err  ),
  .o_rdy( int_if_rdy_p  ),
  .o_dat( out_mod_p_if.dat ),
  .o_ctl( out_mod_p_if.ctl ),
  .o_err( out_mod_p_if.err ),
  .i_rdy( out_mod_p_if.rdy ),
  .o_val( out_mod_p_if.val )
);

barret_mod #(
  .IN_BITS   ( 512              ),
  .OUT_BITS  ( 256              ),
  .CTL_BITS  ( CTL_BITS         ),
  .P         ( secp256k1_pkg::n ),
  .MULTIPLIER( "EXTERNAL"       )
) 
barret_mod (
  .i_clk ( i_clk      ),
  .i_rst ( i_rst      ),
  .i_dat ( int_if.dat  ),
  .i_val ( int_if.val && int_if.ctl[CTL_BITS] == 1 && ~wait_barret_r[KARATSUBA_LEVEL*3-1]),
  .i_ctl ( int_if.ctl[CTL_BITS-1:0]    ),
  .o_rdy ( int_if_rdy_n  ),
  .o_ctl ( out_mod_n_if.ctl ),
  .o_dat ( out_mod_n_if.dat ),
  .o_val ( out_mod_n_if.val ),
  .i_rdy ( out_mod_n_if.rdy ),
  .o_mult_if ( out_brt_mult_if ),
  .i_mult_if ( in_brt_mult_if )
);


endmodule
