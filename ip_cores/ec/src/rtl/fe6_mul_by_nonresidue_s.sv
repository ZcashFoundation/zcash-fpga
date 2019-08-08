/*
  Multiplies by non-residue for Fp6 towering.
  _s in the name represents the input is a stream starting at c0.

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

module fe6_mul_by_nonresidue_s
#(
  parameter type FE_TYPE
)(
  input i_clk, i_rst,
  if_axi_stream.source o_mnr_fe6_if,
  if_axi_stream.sink   i_mnr_fe6_if ,
  if_axi_stream.source o_mnr_fe2_if,
  if_axi_stream.sink   i_mnr_fe2_if
);

logic [2:0] mnr_cnt, out_cnt;

FE_TYPE [3:0] t;
always_comb begin
  case (mnr_cnt) inside
    0,1,2,3: i_mnr_fe6_if.rdy = 1;
    4,5: i_mnr_fe6_if.rdy = ~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy);
    default: i_mnr_fe6_if.rdy = 0;
  endcase

  i_mnr_fe2_if.rdy = (~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy));
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mnr_fe2_if.reset_source();
    o_mnr_fe6_if.reset_source();
    mnr_cnt <= 0;
    out_cnt <= 0;
    t <= 0;
  end else begin

    if (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy) o_mnr_fe6_if.val <= 0;
    if (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy) o_mnr_fe2_if.val <= 0;

    case (mnr_cnt) inside
      0,1,2,3: begin
        if (i_mnr_fe6_if.val && i_mnr_fe6_if.rdy) begin
          t <= {i_mnr_fe6_if.dat, t[3:1]};
          mnr_cnt <= mnr_cnt + 1;
        end
      end
      4,5: begin
        if (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy)) begin
          o_mnr_fe2_if.val <= i_mnr_fe6_if.val;
          o_mnr_fe2_if.ctl <= i_mnr_fe6_if.ctl;
          o_mnr_fe2_if.sop <= mnr_cnt == 4;
          o_mnr_fe2_if.eop <= mnr_cnt == 5;
          o_mnr_fe2_if.dat <= i_mnr_fe6_if.dat;
          if (i_mnr_fe6_if.val) begin
            mnr_cnt <= mnr_cnt + 1;
          end
        end
      end
    endcase


    case (out_cnt) inside
      0,1: begin
        if (~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy)) begin
          o_mnr_fe6_if.val <= i_mnr_fe2_if.val;
          o_mnr_fe6_if.ctl <= i_mnr_fe2_if.ctl;
          o_mnr_fe6_if.sop <= out_cnt == 0;
          o_mnr_fe6_if.eop <= 0;
          o_mnr_fe6_if.dat <= i_mnr_fe2_if.dat;
          if (i_mnr_fe2_if.val) begin
            out_cnt <= out_cnt + 1;
          end
        end
      end
      2,3,4,5: begin
        if (~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy)) begin
          o_mnr_fe6_if.val <= 1;
          o_mnr_fe6_if.sop <= 0;
          o_mnr_fe6_if.eop <= out_cnt == 5;
          o_mnr_fe6_if.dat <= t[out_cnt-2];
          out_cnt <= out_cnt + 1;
        end
      end
      default: begin
        mnr_cnt <= 0;
        out_cnt <= 0;
      end
    endcase

  end
end
endmodule