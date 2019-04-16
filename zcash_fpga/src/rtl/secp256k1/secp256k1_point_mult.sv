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
  parameter RESOURCE_SHARE = "NO"
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
  output logic   o_err,
  // Interface to 256bit multiplier (mod p) (if RESOURCE_SHARE == "YES")
  if_axi_stream.source o_mult_if,
  if_axi_stream.sink   i_mult_if,
  // Interface to only mod reduction block (if RESOURCE_SHARE == "YES")
  if_axi_stream.source o_mod_if,
  if_axi_stream.sink   i_mod_if,

  // We provide another input so that the final point addition can be done
  input jb_point_t i_p2,
  input            i_p2_val
);

// [0] is connection from/to dbl block, [1] is add block, [2] is arbitrated value
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mult_in_if [2:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mult_out_if [2:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mod_in_if [2:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mod_out_if [2:0] (i_clk);

logic [255:0] k_l;
jb_point_t p_n, p_q, p_dbl, p_add;
logic p_dbl_in_val, p_dbl_in_rdy, p_dbl_out_err, p_dbl_out_val, p_dbl_out_rdy, p_dbl_done;
logic p_add_in_val, p_add_in_rdy, p_add_out_err, p_add_out_val, p_add_out_rdy, p_add_done;
logic special_dbl, lookahead_dbl;

enum {IDLE, DOUBLE_ADD, ADD_ONLY, FINISHED} state;

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
    lookahead_dbl <= 0;
  end else begin

    case (state)
      {IDLE}: begin
        p_dbl_out_rdy <= 1;
        p_add_out_rdy <= 1;
        p_dbl_done <= 1;
        p_add_done <= 1;
        special_dbl <= 0;
        lookahead_dbl <= 0;
        o_rdy <= 1;
        o_err <= 0;
        p_q <= 0;  // p_q starts at 0
        p_n <= i_p;
        k_l <= i_k;
        if (o_rdy && i_val) begin
          o_rdy <= 0;
          state <= DOUBLE_ADD;
        end
        if (o_rdy && i_p2_val) begin
          o_rdy <= 0;
          p_n <= i_p;
          p_q <= i_p2;
          state <= ADD_ONLY;
          // Check for special cases to determine double or add
          if (i_p.x == i_p2.x && i_p.y == i_p2.y) begin
            p_dbl_in_val <= 1;
          end else begin
            p_add_in_val <= 1;
          end
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
          // We can look ahead and start the next double
          if ((k_l >> 1) != 0 && ~lookahead_dbl && ~p_add_done) begin
            p_dbl_in_val <= 1;
            lookahead_dbl <= 1;
            p_dbl_out_rdy <= 0; // Want to make sure we don't output while still waiting for add
          end 
        end
        if (p_add_out_val && p_add_out_rdy) begin
          p_add_done <= 1;
          p_q <= p_add;
        end

        // Update variables and issue new commands
        if (p_add_done && p_dbl_done) begin
          lookahead_dbl <= 0;
          p_dbl_out_rdy <= 1;
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

          // Don't need to double on the final bit
          if ((k_l >> 1) != 0)
            p_dbl_in_val <= ~lookahead_dbl; // Don't do if we already started
          else
            p_dbl_done <= 1;

          if (k_l == 0) begin
            state <= FINISHED;
            o_p <= p_add;
            o_val <= 1;
            p_dbl_in_val <= 0;
            p_add_in_val <= 0;
          end
        end

      end
      {ADD_ONLY}: begin
        p_dbl_in_val <= (p_dbl_in_val && p_dbl_in_rdy) ? 0 : p_dbl_in_val;
        p_add_in_val <= (p_add_in_val && p_add_in_rdy) ? 0 : p_add_in_val;

        if (p_dbl_out_val && p_dbl_out_rdy) begin
          state <= FINISHED;
          o_p <= p_dbl;
          o_val <= 1;
        end
        if (p_add_out_val && p_add_out_rdy) begin
          state <= FINISHED;
          o_p <= p_add;
          o_val <= 1;
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
localparam ARB_BIT = 8;
resource_share # (
  .NUM_IN ( 2 ),
  .OVR_WRT_BIT ( ARB_BIT ),
  .PIPELINE_IN ( 0 ),
  .PIPELINE_OUT ( 0 )
)
resource_share_mod (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mod_in_if[1:0]  ),
  .o_res ( mod_in_if[2]    ),
  .i_res ( mod_out_if[2]   ), 
  .o_axi ( mod_out_if[1:0] )
);

resource_share # (
  .NUM_IN ( 2 ),
  .OVR_WRT_BIT ( ARB_BIT ),
  .PIPELINE_IN ( 0 ),
  .PIPELINE_OUT ( 0 )
)
resource_share_mult (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mult_in_if[1:0]  ),
  .o_res ( mult_in_if[2]    ),
  .i_res ( mult_out_if[2]   ), 
  .o_axi ( mult_out_if[1:0] )
);
generate
  if (RESOURCE_SHARE == "YES") begin: RESOURCE_GEN
    always_comb begin
      o_mult_if.val = mult_in_if[2].val;
      o_mult_if.dat = mult_in_if[2].dat;
      o_mult_if.ctl = mult_in_if[2].ctl;
      o_mult_if.err = 0;
      o_mult_if.mod = 0;
      o_mult_if.sop = 1;
      o_mult_if.eop = 1;
      mult_in_if[2].rdy = o_mult_if.rdy;

      o_mod_if.val = mod_in_if[2].val;
      o_mod_if.dat = mod_in_if[2].dat;
      o_mod_if.ctl = mod_in_if[2].ctl;
      o_mod_if.err = 0;
      o_mod_if.mod = 0;
      o_mod_if.sop = 1;
      o_mod_if.eop = 1;
      mod_in_if[2].rdy = o_mod_if.rdy;

      i_mult_if.rdy = mult_out_if[2].rdy;
      mult_out_if[2].val = i_mult_if.val;
      mult_out_if[2].dat = i_mult_if.dat;
      mult_out_if[2].ctl = i_mult_if.ctl;

      i_mod_if.rdy = mod_out_if[2].rdy;
      mod_out_if[2].val = i_mod_if.val;
      mod_out_if[2].dat = i_mod_if.dat;
      mod_out_if[2].ctl = i_mod_if.ctl;
    end
  end else begin
    always_comb begin
      o_mult_if.reset_source();
      i_mult_if.rdy = 0;
      o_mod_if.reset_source();
      i_mod_if.rdy = 0;
    end
    secp256k1_mult_mod #(
      .CTL_BITS ( 16 )
    )
    secp256k1_mult_mod (
      .i_clk ( i_clk ),
      .i_rst ( i_rst ),
      .i_dat_a ( mult_in_if[2].dat[0 +: 256] ),
      .i_dat_b ( mult_in_if[2].dat[256 +: 256] ),
      .i_val ( mult_in_if[2].val ),
      .i_err ( mult_in_if[2].err ),
      .i_ctl ( mult_in_if[2].ctl ),
      .i_cmd ( 1'd0              ),
      .o_rdy ( mult_in_if[2].rdy ),
      .o_dat ( mult_out_if[2].dat ),
      .i_rdy ( mult_out_if[2].rdy ),
      .o_val ( mult_out_if[2].val ),
      .o_ctl ( mult_out_if[2].ctl ),
      .o_err ( mult_out_if[2].err )
    );

    secp256k1_mod #(
      .USE_MULT ( 0 ),
      .CTL_BITS ( 16 )
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
  end
endgenerate

endmodule