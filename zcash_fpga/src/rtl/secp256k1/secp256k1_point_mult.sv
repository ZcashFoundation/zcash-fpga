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

// [0] is connection from/to dbl block, [1] is add block, [2] is arbitrated value
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mult_in_if [2:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mult_out_if [2:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mod_in_if [2:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mod_out_if [2:0] (i_clk);

logic [255:0] k_l;
jb_point_t p_n, p_q, p_dbl, p_add;
logic p_dbl_in_val, p_dbl_in_rdy, p_dbl_out_err, p_dbl_out_val, p_dbl_out_rdy, p_dbl_done;
logic p_add_in_val, p_add_in_rdy, p_add_out_err, p_add_out_val, p_add_out_rdy, p_add_done;
logic special_dbl;

enum {IDLE, DOUBLE_ADD, FINISHED} state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_val <= 0;
    o_err <= 0;
    o_rdy <= 0;
    k_l <= 0;
    p_q <= 0;
    p_dbl_in_val <= 0;
    p_dbl_out_rdy <= 0;
    p_add_in_val <= 0;
    p_add_out_rdy <= 0;
    state <= IDLE;
    o_p <= 0;
    p_n <= 0;
    p_dbl_done <= 0;
    p_add_done <= 0;
    special_dbl <= 0;
  end else begin
    p_dbl_out_rdy <= 1;
    p_add_out_rdy <= 1;
    case (state)
      {IDLE}: begin
        p_dbl_done <= 1;
        p_add_done <= 1;
        special_dbl <= 0;
        o_rdy <= 1;
        o_err <= 0;
        p_q <= 0;  // p_q starts at 0
        p_n <= i_p;
        k_l <= i_k;
        if (o_rdy && i_val) begin
          state <= DOUBLE_ADD;
        end
      end
      {DOUBLE_ADD}: begin
        p_dbl_in_val <= (p_dbl_in_val && p_dbl_in_rdy) ? 0 : p_dbl_in_val;
        p_add_in_val <= (p_add_in_val && p_add_in_rdy) ? 0 : p_add_in_val;
        if (p_dbl_out_val && p_dbl_out_rdy) begin
          p_dbl_done <= 1;
          if (special_dbl) begin
            p_q <= p_dbl;
            special_dbl <= 0;
          end
          p_n <= p_dbl;
        end
        if (p_add_out_val && p_add_out_rdy) begin
          p_add_done <= 1;
          p_q <= p_add;
        end
        
        // Update variables and issue new commands
        if (p_add_done && p_dbl_done) begin
          p_add_done <= 0;
          p_dbl_done <= 0;
          k_l <= k_l >> 1;
          if (k_l[0]) begin
            p_add_in_val <= 1;
            // Need to check for special case where the x, y point is the same
            if (p_q.x == p_n.x && p_q.y == p_n.y) begin
              special_dbl <= 1;
              p_add_in_val <= 0;
              p_add_done <= 1;
            end
          end else begin
            p_add_done <= 1;
          end
          
          p_dbl_in_val <= 1;
            
          if (k_l == 0) begin
            state <= FINISHED;
            o_p <= p_add;
            o_val <= 1;
            p_dbl_in_val <= 0;
            p_add_in_val <= 0;
          end  
        end

      end
      {FINISHED}: begin
        if (i_rdy && o_val) begin
          o_val <= 0;
          state <= IDLE;
        end
      end      
    endcase
    
    if (p_dbl_out_err || p_add_out_err) begin
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
  .o_mult_if ( mult_in_if[0]  ),
  .i_mult_if ( mult_out_if[0] ),
  .o_mod_if  ( mod_in_if[0]   ),
  .i_mod_if  ( mod_out_if[0]  )
);

secp256k1_point_add secp256k1_point_add(
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  // Input points
  .i_p1  ( p_q           ),
  .i_p2  ( p_n           ),
  .i_val ( p_add_in_val  ),
  .o_rdy ( p_add_in_rdy  ),
  // Output point
  .o_p   ( p_add         ),
  .o_err ( p_add_out_err ),
  .i_rdy ( p_add_out_rdy ),
  .o_val ( p_add_out_val ),
  // Interfaces to shared multipliers / modulo blocks
  .o_mult_if ( mult_in_if[1]  ),
  .i_mult_if ( mult_out_if[1] ),
  .o_mod_if  ( mod_in_if[1]   ),
  .i_mod_if  ( mod_out_if[1]  )
);

// We add arbitrators to these to share with the point add module
packet_arb # (
  .DAT_BYTS ( 512/8 ),
  .CTL_BITS ( 8     ),
  .NUM_IN   ( 2     ),
  .PIPELINE ( 1     )
) 
packet_arb_mult (
  .i_clk ( i_clk ), 
  .i_rst ( i_rst ),
  .i_axi ( mult_in_if[1:0] ), 
  .o_axi ( mult_in_if[2]   )
);

packet_arb # (
  .DAT_BYTS ( 512/8 ),
  .CTL_BITS ( 8     ),
  .NUM_IN   ( 2     ),
  .PIPELINE ( 1     )
) 
packet_arb_mod (
  .i_clk ( i_clk ), 
  .i_rst ( i_rst ),
  .i_axi ( mod_in_if[1:0] ), 
  .o_axi ( mod_in_if[2]   )
);

always_comb begin 
  mod_out_if[0].copy_if_comb(mod_out_if[2].to_struct());
  mod_out_if[1].copy_if_comb(mod_out_if[2].to_struct());
  
  mod_out_if[0].ctl = {1'd0, mod_out_if[2].ctl[6:0]};
  mod_out_if[1].ctl = {1'd0, mod_out_if[2].ctl[6:0]};
  
  mod_out_if[1].val = mod_out_if[2].val && mod_out_if[2].ctl[7] == 1;
  mod_out_if[0].val = mod_out_if[2].val && mod_out_if[2].ctl[7] == 0;
  mod_out_if[2].rdy = mod_out_if[2].ctl[7] == 0 ? mod_out_if[0].rdy : mod_out_if[1].rdy;
  
  mod_out_if[2].sop = 1;
  mod_out_if[2].eop = 1;
  mod_out_if[2].mod = 0;
end

always_comb begin
  mult_out_if[0].copy_if_comb(mult_out_if[2].to_struct());
  mult_out_if[1].copy_if_comb(mult_out_if[2].to_struct());
  
  mult_out_if[0].ctl = {1'd0, mult_out_if[2].ctl[6:0]};
  mult_out_if[1].ctl = {1'd0, mult_out_if[2].ctl[6:0]};
  
  mult_out_if[1].val = mult_out_if[2].val && mult_out_if[2].ctl[7] == 1;
  mult_out_if[0].val = mult_out_if[2].val && mult_out_if[2].ctl[7] == 0;
  mult_out_if[2].rdy = mult_out_if[2].ctl[7] == 0 ? mult_out_if[0].rdy : mult_out_if[1].rdy;
  
  mult_out_if[2].sop = 1;
  mult_out_if[2].eop = 1;
  mult_out_if[2].mod = 0;
end

secp256k1_mult_mod #(
  .CTL_BITS ( 8 )
)
secp256k1_mult_mod (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_dat_a ( mult_in_if[2].dat[0 +: 256] ),
  .i_dat_b ( mult_in_if[2].dat[256 +: 256] ),
  .i_val ( mult_in_if[2].val ),
  .i_err ( mult_in_if[2].err ),
  .i_ctl ( mult_in_if[2].ctl ),
  .o_rdy ( mult_in_if[2].rdy ),
  .o_dat ( mult_out_if[2].dat ),
  .i_rdy ( mult_out_if[2].rdy ),
  .o_val ( mult_out_if[2].val ),
  .o_ctl ( mult_out_if[2].ctl ),
  .o_err ( mult_out_if[2].err ) 
);

secp256k1_mod #(
  .USE_MULT ( 0 ),
  .CTL_BITS ( 8 )
)
secp256k1_mod (
  .i_clk( i_clk     ),
  .i_rst( i_rst     ),
  .i_dat( mod_in_if[2].dat  ),
  .i_val( mod_in_if[2].val  ),
  .i_err( mod_in_if[2].err  ),
  .i_ctl( mod_in_if[2].ctl  ),
  .o_rdy( mod_in_if[2].rdy  ),
  .o_dat( mod_out_if[2].dat ),
  .o_ctl( mod_out_if[2].ctl ),
  .o_err( mod_out_if[2].err ),
  .i_rdy( mod_out_if[2].rdy ),
  .o_val( mod_out_if[2].val )
);

endmodule