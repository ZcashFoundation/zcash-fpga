/*
  This performs point multiplication. We use the standard double
  and add algorithm.
 
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

module secp256k1_point_mult
  import secp256k1_pkg::*;
#(
)(
  input i_clk, i_rst,
  // Input point and value to multiply
  input jb_point_t    i_p,
  input logic [255:0] i_k,
  input logic   i_val,
  output logic  o_rdy,
  // Output point
  output jb_point_t o_p,
  input logic    i_rdy,
  output logic   o_val,
  output logic   o_err
);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mult_in_if(i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mult_out_if(i_clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mod_in_if(i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mod_out_if(i_clk);

logic [255:0] k_l;
jb_point_t p_n, p_q, p_dbl;
logic p_dbl_in_val, p_dbl_in_rdy, p_dbl_out_err, p_dbl_out_val, p_dbl_out_rdy;

enum {IDLE, DOUBLE, ADD, FINISHED} state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_val <= 0;
    o_err <= 0;
    o_rdy <= 0;
    k_l <= 0;
    p_q <= 0;
    p_dbl_in_val <= 0;
    p_dbl_out_rdy <= 0;
    state <= IDLE;
    o_p <= 0;
    p_n <= 0;
  end else begin
    p_dbl_in_val <= 0;
    p_dbl_out_rdy <= 1;
    case (state)
      {IDLE}: begin
        o_rdy <= 1;
        o_err <= 0;
        p_q <= {x:0, y:0, z:1};  // p_q starts at 0
        if (o_rdy && i_val) begin
          k_l <= i_k;
          p_n <= i_p;
          // Regardless of i_k[0] we skip the first add since it would set p_q to i_p
          if (i_k[0]) begin
            p_q <= i_p;
          end
          state <= DOUBLE;
          p_dbl_in_val <= 1;
        end
      end
      {DOUBLE}: begin
        if(p_dbl_in_val && p_dbl_in_rdy) begin
          p_dbl_in_val <= 0;
        end
        if (p_dbl_out_val && p_dbl_out_rdy) begin
          p_n <= p_dbl;
          k_l <= k_l >> 1;
          if (k_l[1] == 1) begin
            state <= ADD;
          end else if (k_l[255:1] == 0) begin
            state <= FINISHED;
            o_p <= p_dbl;
            o_val <= 1;
          end else begin
            state <= DOUBLE;
            p_dbl_in_val <= 1;
          end        
        end
      end
      {ADD}: begin
        state <= DOUBLE;
        p_q <= p_n;
        p_dbl_in_val <= 1;
      end
      {FINISHED}: begin
        if (i_rdy && o_val) begin
          o_val <= 0;
          state <= IDLE;
        end
      end      
    endcase
    
    if (p_dbl_out_err) begin
      o_err <= 1;
      o_val <= 1;
      state <= FINISHED;
    end  
    
  end  
end

secp256k1_point_dbl secp256k1_point_dbl(
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  // Input point
  .i_p   ( p_n           ),
  .i_val ( p_dbl_in_val  ),
  .o_rdy ( p_dbl_in_rdy  ),
  // Output point
  .o_p   ( p_dbl         ),
  .o_err ( p_dbl_out_err ),
  .i_rdy ( p_dbl_out_rdy ),
  .o_val ( p_dbl_out_val ),
  // Interfaces to shared multipliers / modulo blocks
  .o_mult_if ( mult_in_if  ),
  .i_mult_if ( mult_out_if ),
  .o_mod_if  ( mod_in_if   ),
  .i_mod_if  ( mod_out_if  )
);


secp256k1_mult_mod #(
  .CTL_BITS ( 8 )
)
secp256k1_mult_mod (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_dat_a ( mult_in_if.dat[0 +: 256] ),
  .i_dat_b ( mult_in_if.dat[256 +: 256] ),
  .i_val ( mult_in_if.val ),
  .i_err ( mult_in_if.err ),
  .i_ctl ( mult_in_if.ctl ),
  .o_rdy ( mult_in_if.rdy ),
  .o_dat ( mult_out_if.dat ),
  .i_rdy ( mult_out_if.rdy ),
  .o_val ( mult_out_if.val ),
  .o_ctl ( mult_out_if.ctl ),
  .o_err ( mult_out_if.err ) 
);

secp256k1_mod #(
  .USE_MULT ( 0 ),
  .CTL_BITS ( 8 )
)
secp256k1_mod (
  .i_clk( i_clk     ),
  .i_rst( i_rst     ),
  .i_dat( mod_in_if.dat  ),
  .i_val( mod_in_if.val  ),
  .i_err( mod_in_if.err  ),
  .i_ctl( mod_in_if.ctl  ),
  .o_rdy( mod_in_if.rdy  ),
  .o_dat( mod_out_if.dat ),
  .o_ctl( mod_out_if.ctl ),
  .o_err( mod_out_if.err ),
  .i_rdy( mod_out_if.rdy ),
  .o_val( mod_out_if.val )
);

endmodule