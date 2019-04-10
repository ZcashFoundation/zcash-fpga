/*
  This performs point multiplication, but first decomposes the scalar
  value using endomorphsis. Then we use the standard double
  and add algorithm in parallel on the two products.

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

module secp256k1_point_mult_endo
  import secp256k1_pkg::*;
(
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
  output logic   o_err,
  // Interface to 256bit multiplier
  if_axi_stream.source o_mult_if,
  if_axi_stream.sink   i_mult_if,
  // Interface to only mod reduction block
  if_axi_stream.source o_mod_if,
  if_axi_stream.sink   i_mod_if,

  // We provide another input so that the final point addition can be done
  // This is connected to k2 block's addition input
  input jb_point_t i_p2,
  input            i_p2_val
);

// [0] is connection from/to k1 block, [1] is k2 block, [2] is multiplier used by decomposing block, [3] is arbitrated value
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mult_in_if [3:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mult_out_if [3:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mod_in_if [2:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mod_out_if [2:0] (i_clk);

logic [255:0] k_l, k1, k2;
logic signed [255:0] k1_decom, k2_decom;
jb_point_t p2_k1, p2_k2, p_k1, p_k2, p_o1, p_o2, p_o_decom;
logic i_val1, o_rdy1, i_rdy1, o_val1, o_err1, i_val2, o_rdy2, i_rdy2, o_val2, o_err2;
logic p2_k1_val, p2_k2_val;
enum {IDLE, ADD_ONLY, DECOMPOSE_K, POINT_MULT, COMBINE_K_PROD, FINISHED} state;
logic i_val_decom, o_rdy_decom, i_rdy_decom, o_val_decom, o_err_decom;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_val <= 0;
    o_err <= 0;
    o_rdy <= 0;
    k_l <= 0;
    k1 <= 0;
    k2 <= 0;
    state <= IDLE;
    o_p <= 0;
    i_val1 <= 0;
    i_rdy1 <= 0;
    i_val2 <= 0;
    i_rdy2 <= 0;
    p2_k1 <= 0;
    p2_k2 <= 0;
    p_k1 <= 0;
    p_k2 <= 0;
    i_val_decom <= 0;
    i_rdy_decom <= 0;
    p2_k1_val <= 0;
    p2_k2_val <= 0;
  end else begin
  
    if (i_val_decom && o_rdy_decom) i_val_decom <= 0;
    if (i_val1 && o_rdy1) i_val1 <= 0;
    if (i_val2 && o_rdy2) i_val2 <= 0;
    if (p2_k1_val && o_rdy1) p2_k1_val <= 0;
    
    i_rdy_decom <= 0;
    i_rdy1 <= 0;
    i_rdy2 <= 0;
    
    case (state)
      {IDLE}: begin
        i_rdy_decom <= 1;
        i_rdy1 <= 1;
        i_rdy2 <= 1;
        
        o_val <= 0;
        o_err <= 0;
        o_rdy <= 1;
        k_l <= i_k;
        k1 <= 0;
        k2 <= 0;
        o_p <= 0;

        p2_k1 <= 0;
        p2_k2 <= 0;
        p_k1 <= i_p;
        p_k2 <= 0;
        p2_k1_val <= 0;
        p2_k2_val <= 0;
        
        if (o_rdy && i_val) begin
          o_rdy <= 0;
          i_val_decom <= 1;
          state <= DECOMPOSE_K;
        end
        if (o_rdy && i_p2_val) begin
          i_val_decom <= 0;
          o_rdy <= 0;
          p_k2 <= i_p;
          p2_k2 <= i_p2;
          p2_k2_val <= 1;
          state <= ADD_ONLY;
        end

      end
      {ADD_ONLY}: begin
        if (o_val && i_rdy) begin
          state <= IDLE;
          i_rdy2 <= 1;
        end
        i_rdy2 <= 0;
        o_p <= p_o2;
        o_val <= o_val2;
      end
      {DECOMPOSE_K}: begin
        if (o_val_decom) begin
          p_k2 <= p_o_decom;
          i_val2 <= 1;
          i_val1 <= 1;
          // Only want absolute values here
          // We don't assert ready on the decom block as we need to check the sign later
          k1 <= k1_decom[255] ? -k1_decom : k1_decom;
          k2 <= k2_decom[255] ? -k2_decom : k2_decom; 
          state <= POINT_MULT;
        end
      end
      {POINT_MULT}: begin
      // Combine the final products
      // If k1 or k2 were negative we need to invert the point here before we add
        if (o_val1 && o_val2) begin
          i_rdy1 <= 1;
          i_rdy2 <= 1;
          p2_k1 <= p_o1;
          p_k1 <= p_o2;
          p2_k1_val <= 1;
          state <= COMBINE_K_PROD;
          i_rdy_decom <= 1;
          if (k2_decom[255]) begin
            p_k1.y <= secp256k1_pkg::p_eq - p_o2.y;
          end
          if (k1_decom[255]) begin
            p2_k1.y <= secp256k1_pkg::p_eq - p_o1.y;
          end
        end

      end
      {COMBINE_K_PROD}: begin
        if (o_val1 && ~p2_k1_val) begin
          o_val <= 1;
          o_p <= p_o1;
          state <= FINISHED;
        end
      end
      {FINISHED}: begin
        if (i_rdy && o_val) begin
          o_val <= 0;
          i_rdy_decom <= 1;
          i_rdy1 <= 1;
          i_rdy2 <= 1;
          state <= IDLE;
        end
      end
    endcase

    if (o_err_decom || o_err1 || o_err2) begin
      o_err <= 1;
      o_val <= 1;
      state <= FINISHED;
    end

  end
end

secp256k1_point_mult_endo_decom secp256k1_point_mult_endo_decom (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_p   ( p_k1  ),
  .i_k   ( k_l   ),
  .i_val ( i_val_decom  ),
  .o_rdy ( o_rdy_decom  ),
  .o_p   ( p_o_decom   ),
  .i_rdy ( i_rdy_decom ),
  .o_val ( o_val_decom ),
  .o_err ( o_err_decom ),
  .o_k1 ( k1_decom ),
  .o_k2 ( k2_decom ),
  .o_mult_if ( mult_in_if[2] ),
  .i_mult_if ( mult_out_if[2] )
);


secp256k1_point_mult #(
  .RESOURCE_SHARE ( "YES" )
)
secp256k1_point_mult_k1 (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_p   ( p_k1   ),
  .i_k   ( k1     ),
  .i_val ( i_val1 ),
  .o_rdy ( o_rdy1 ),
  .o_p   ( p_o1   ),
  .i_rdy ( i_rdy1 ),
  .o_val ( o_val1 ),
  .o_err ( o_err1 ),
  .o_mult_if ( mult_in_if[0]  ),
  .i_mult_if ( mult_out_if[0] ),
  .o_mod_if  ( mod_in_if[0]   ),
  .i_mod_if  ( mod_out_if[0]  ),
  .i_p2     ( p2_k1     ),
  .i_p2_val ( p2_k1_val )
);

secp256k1_point_mult #(
  .RESOURCE_SHARE ( "YES" )
)
secp256k1_point_mult_k2 (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_p   ( p_k2   ),
  .i_k   ( k2     ),
  .i_val ( i_val2 ),
  .o_rdy ( o_rdy2 ),
  .o_p   ( p_o2   ),
  .i_rdy ( i_rdy2 ),
  .o_val ( o_val2 ),
  .o_err ( o_err2 ),
  .o_mult_if ( mult_in_if[1]  ),
  .i_mult_if ( mult_out_if[1] ),
  .o_mod_if  ( mod_in_if[1]   ),
  .i_mod_if  ( mod_out_if[1]  ),
  .i_p2     ( p2_k2    ),
  .i_p2_val ( p2_k2_val )
);

// We add arbitrators to these to share with the point add module
localparam ARB_BIT = 10;
packet_arb # (
  .DAT_BYTS    ( 512/8   ),
  .CTL_BITS    ( 16      ),
  .NUM_IN      ( 3       ),
  .OVR_WRT_BIT ( ARB_BIT ),
  .PIPELINE    ( 0       )
)
packet_arb_mult (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mult_in_if[2:0] ),
  .o_axi ( mult_in_if[3]   )
);

packet_arb # (
  .DAT_BYTS    ( 512/8   ),
  .CTL_BITS    ( 16      ),
  .NUM_IN      ( 2       ),
  .OVR_WRT_BIT ( ARB_BIT ),
  .PIPELINE    ( 0       )
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

  mod_out_if[0].ctl = mod_out_if[2].ctl;
  mod_out_if[1].ctl = mod_out_if[2].ctl;
  mod_out_if[0].ctl[ARB_BIT] = 0;
  mod_out_if[1].ctl[ARB_BIT] = 0;

  mod_out_if[1].val = mod_out_if[2].val && mod_out_if[2].ctl[ARB_BIT] == 1;
  mod_out_if[0].val = mod_out_if[2].val && mod_out_if[2].ctl[ARB_BIT] == 0;
  mod_out_if[2].rdy = mod_out_if[2].ctl[ARB_BIT] == 0 ? mod_out_if[0].rdy : mod_out_if[1].rdy;

  mod_out_if[2].sop = 1;
  mod_out_if[2].eop = 1;
  mod_out_if[2].mod = 0;
end

always_comb begin
  mult_out_if[0].copy_if_comb(mult_out_if[3].to_struct());
  mult_out_if[1].copy_if_comb(mult_out_if[3].to_struct());
  mult_out_if[2].copy_if_comb(mult_out_if[3].to_struct());

  mult_out_if[0].ctl = mult_out_if[3].ctl;
  mult_out_if[1].ctl = mult_out_if[3].ctl;
  mult_out_if[2].ctl = mult_out_if[3].ctl;
  mult_out_if[0].ctl[ARB_BIT +: 2] = 0;
  mult_out_if[1].ctl[ARB_BIT +: 2] = 0;
  mult_out_if[2].ctl[ARB_BIT +: 2] = 0;

  mult_out_if[0].val = mult_out_if[3].val && mult_out_if[3].ctl[ARB_BIT +: 2] == 0;
  mult_out_if[1].val = mult_out_if[3].val && mult_out_if[3].ctl[ARB_BIT +: 2] == 1;
  mult_out_if[2].val = mult_out_if[3].val && mult_out_if[3].ctl[ARB_BIT +: 2] == 2;

  if (mult_out_if[3].ctl[ARB_BIT +: 2] == 0)
    mult_out_if[3].rdy = mult_out_if[0].rdy;
  else if (mult_out_if[3].ctl[ARB_BIT +: 2] == 1)
    mult_out_if[3].rdy = mult_out_if[1].rdy;
  else
    mult_out_if[3].rdy = mult_out_if[2].rdy;

  mult_out_if[3].sop = 1;
  mult_out_if[3].eop = 1;
  mult_out_if[3].mod = 0;
  mult_out_if[3].err = 0;
end

// We always use the external multiplier
always_comb begin
  o_mult_if.val = mult_in_if[3].val;
  o_mult_if.dat = mult_in_if[3].dat;
  o_mult_if.ctl = mult_in_if[3].ctl;
  o_mult_if.err = 0;
  o_mult_if.mod = 0;
  o_mult_if.sop = 1;
  o_mult_if.eop = 1;
  mult_in_if[3].rdy = o_mult_if.rdy;

  o_mod_if.val = mod_in_if[2].val;
  o_mod_if.dat = mod_in_if[2].dat;
  o_mod_if.ctl = mod_in_if[2].ctl;
  o_mod_if.err = 0;
  o_mod_if.mod = 0;
  o_mod_if.sop = 1;
  o_mod_if.eop = 1;
  mod_in_if[2].rdy = o_mod_if.rdy;

  i_mult_if.rdy = mult_out_if[3].rdy;
  mult_out_if[3].val = i_mult_if.val;
  mult_out_if[3].dat = i_mult_if.dat;
  mult_out_if[3].ctl = i_mult_if.ctl;

  i_mod_if.rdy = mod_out_if[2].rdy;
  mod_out_if[2].val = i_mod_if.val;
  mod_out_if[2].dat = i_mod_if.dat;
  mod_out_if[2].ctl = i_mod_if.ctl;
end


endmodule