/*
  This performs point multiplication. We use the standard double
  and add algorithm, with some look ahead so we can perform
  adds or doubles as early as possible.

  Optimizations would be to use NAF.

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

module ec_point_mult
#(
  parameter      P,
  parameter type FP_TYPE,
  parameter      DAT_BITS = $clog2(P)
)(
  input i_clk, i_rst,
  // Input point and value to multiply in control
  if_axi_stream.source o_pt_mult,
  if_axi_stream.sink   i_pt_mult,
  // Interface to point adder / doubler
  if_axi_stream.source o_dbl,
  if_axi_stream.sink   i_dbl,
  if_axi_stream.source o_add,
  if_axi_stream.sink   i_add
);

localparam CHK_POINT = 0;

logic [DAT_BITS-1:0] k_l;
logic p_dbl_done, p_add_done, special_dbl, lookahead_dbl;

enum {IDLE, DOUBLE_ADD, FINISHED} state;

always_comb begin
  o_add.dat[$bits(FP_TYPE) +: $bits(FP_TYPE)] = o_dbl.dat;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_dbl.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_add.val <= 0;
    o_add.sop <= 1;
    o_add.eop <= 1;
    o_add.err <= 0;
    o_add.ctl <= 0;
    o_add.mod <= 0;
    o_pt_mult.copy_if(0, 0, 1, 1, 0, 0, 0);
    i_add.rdy <= 0;
    i_dbl.rdy <= 0;
    i_pt_mult.rdy <= 0;
    k_l <= 0;
    state <= IDLE;
    p_dbl_done <= 0;
    p_add_done <= 0;
    special_dbl <= 0;
    lookahead_dbl <= 0;
  end else begin

    case (state)
      {IDLE}: begin
        i_add.rdy <= 1;
        i_dbl.rdy <= 1;
        p_dbl_done <= 1;
        p_add_done <= 1;
        special_dbl <= 0;
        lookahead_dbl <= 0;
        i_pt_mult.rdy <= 1;
        o_pt_mult.err <= 0;
        o_add.dat[0 +: $bits(FP_TYPE)] <= 0;
        o_dbl.dat <= i_pt_mult.dat;
        k_l <= i_pt_mult.ctl;
        if (i_pt_mult.rdy && i_pt_mult.val) begin
          i_pt_mult.rdy <= 0;
          state <= DOUBLE_ADD;
        end
      end
      {DOUBLE_ADD}: begin
        if (o_dbl.val && o_dbl.rdy) o_dbl.val <= 0;
        if (o_add.val && o_add.rdy) o_add.val <= 0;

        if (i_dbl.val && i_dbl.rdy) begin
          p_dbl_done <= 1;
          if (special_dbl) begin
            o_add.dat[0 +: $bits(FP_TYPE)] <= i_dbl.dat;
            special_dbl <= 0;
          end

          o_dbl.dat <= i_dbl.dat;
          // We can look ahead and start the next double
          if ((k_l >> 1) != 0 && ~lookahead_dbl && ~p_add_done) begin
            o_dbl.val <= 1;
            lookahead_dbl <= 1;
            i_dbl.rdy <= 0; // Want to make sure we don't output while still waiting for add
          end
        end
        if (i_add.val && i_add.rdy) begin
          p_add_done <= 1;
          o_add.dat[0 +: $bits(FP_TYPE)] <= i_add.dat;
        end

        // Update variables and issue new commands
        if (p_add_done && p_dbl_done) begin
          lookahead_dbl <= 0;
          i_dbl.rdy <= 1;
          p_add_done <= 0;
          p_dbl_done <= 0;
          k_l <= k_l >> 1;
          if (k_l[0]) begin
            o_add.val <= 1;
            // Need to check for special case where the point coords are the same (if enabled)
            if (CHK_POINT == 1) begin
              if (o_add.dat[0 +: $bits(FP_TYPE)] == o_dbl.dat) begin
                special_dbl <= 1;
                o_add.val <= 0;
                p_add_done <= 1;
              end
            end
          end else begin
            p_add_done <= 1;
          end

          // Don't need to double on the final bit
          if ((k_l >> 1) != 0)
            o_dbl.val <= ~lookahead_dbl; // Don't do if we already started
          else
            p_dbl_done <= 1;

          if (k_l == 0) begin
            state <= FINISHED;
            o_pt_mult.dat <= i_add.dat;
            o_pt_mult.val <= 1;
            o_dbl.val <= 0;
            o_add.val <= 0;
          end
        end

      end
      {FINISHED}: begin
        if (o_pt_mult.rdy && o_pt_mult.val) begin
          o_pt_mult.val <= 0;
          state <= IDLE;
        end
      end
    endcase

    if (i_dbl.err || i_add.err) begin
      o_pt_mult.err <= 1;
      o_pt_mult.val <= 1;
      state <= FINISHED;
    end

  end
end
endmodule