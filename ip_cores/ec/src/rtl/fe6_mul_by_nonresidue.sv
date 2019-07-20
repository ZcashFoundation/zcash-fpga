/*
  Multiplies by non-residue for Fp6 towering

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

module fe6_mul_by_nonresidue
#(
  parameter type FE2_TYPE
)(
  input i_clk, i_rst,
  if_axi_stream.source o_mnr_fe6_if,
  if_axi_stream.sink   i_mnr_fe6_if,  // Input is multiplied by non residue
  if_axi_stream.source o_mnr_fe2_if,
  if_axi_stream.sink   i_mnr_fe2_if
);

logic [2:0] val;

always_comb begin
  i_mnr_fe6_if.rdy = ~val[1] && ~val[2] && (~o_mnr_fe2_if.val || (o_mnr_fe2_if.rdy && o_mnr_fe2_if.val));
  i_mnr_fe2_if.rdy = ~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy);
  o_mnr_fe6_if.val = &val;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mnr_fe6_if.dat <= 0;
    o_mnr_fe6_if.ctl <= 0;
    o_mnr_fe6_if.mod <= 0;
    o_mnr_fe6_if.sop <= 0;
    o_mnr_fe6_if.eop <= 0;
    o_mnr_fe6_if.err <= 0;
    o_mnr_fe2_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    val <= 0;
  end else begin

    if (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy) val <= 0;
    if (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy) o_mnr_fe2_if.val <= 0;

    if (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy)) begin
      o_mnr_fe2_if.copy_if(i_mnr_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                            i_mnr_fe6_if.val && i_mnr_fe6_if.rdy, 1, 1, 0, 0, i_mnr_fe6_if.ctl);
    end

    if (~val[1]) begin
      o_mnr_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= i_mnr_fe6_if.dat[0 +: $bits(FE2_TYPE)];
      val[1] <= i_mnr_fe6_if.val && i_mnr_fe6_if.rdy;
    end

    if (~val[2]) begin
      o_mnr_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= i_mnr_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)];
      val[2] <= i_mnr_fe6_if.val && i_mnr_fe6_if.rdy;
    end

    if (~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy)) begin
      o_mnr_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= i_mnr_fe2_if.dat;
      o_mnr_fe6_if.ctl <= i_mnr_fe2_if.ctl;
      val[0] <= i_mnr_fe2_if.val;
    end
  end
end
endmodule