/*
  Multiplies by non-residue for Fp2 towering

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

module fe2_mul_by_nonresidue
#(
  parameter type FE_TYPE
)(
  input i_clk, i_rst,
  if_axi_stream.source o_mnr_fe2_if,
  if_axi_stream.sink   i_mnr_fe2_if,  // Input is multiplied by non residue
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if
);

logic [1:0] add_sub_val;
always_comb begin
  i_mnr_fe2_if.rdy = (~o_add_fe_if.val || (o_add_fe_if.rdy && o_add_fe_if.val)) && (~o_sub_fe_if.val || (o_sub_fe_if.rdy && o_sub_fe_if.val));
  o_mnr_fe2_if.val = &add_sub_val;
  i_add_fe_if.rdy = ~add_sub_val[0];
  i_sub_fe_if.rdy = ~add_sub_val[1];
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mnr_fe2_if.sop <= 1;
    o_mnr_fe2_if.eop <= 1;
    o_mnr_fe2_if.mod <= 0;
    o_mnr_fe2_if.err <= 0;
    o_mnr_fe2_if.ctl <= 0;
    o_add_fe_if.reset_source();
    o_sub_fe_if.reset_source();
    add_sub_val <= 0;
  end else begin

    if (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy) add_sub_val <= 0;

    if (i_mnr_fe2_if.rdy) begin
      o_add_fe_if.copy_if({i_mnr_fe2_if.dat[0 +: $bits(FE_TYPE)],
                            i_mnr_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)]},
                            i_mnr_fe2_if.val && i_mnr_fe2_if.rdy, 1, 1, i_mnr_fe2_if.err, i_mnr_fe2_if.mod, i_mnr_fe2_if.ctl);
      o_sub_fe_if.copy_if({i_mnr_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)],
                           i_mnr_fe2_if.dat[0 +: $bits(FE_TYPE)]},
                           i_mnr_fe2_if.val && i_mnr_fe2_if.rdy, 1, 1, i_mnr_fe2_if.err, i_mnr_fe2_if.mod, i_mnr_fe2_if.ctl);
    end

    if (~o_mnr_fe2_if.val || (o_mnr_fe2_if.val && o_mnr_fe2_if.rdy)) begin
      if (~add_sub_val[0]) begin
        o_mnr_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= i_add_fe_if.dat;
        o_mnr_fe2_if.ctl <= i_add_fe_if.ctl;
        add_sub_val[0] <= i_add_fe_if.val;
      end
      if (~add_sub_val[1]) begin
        o_mnr_fe2_if.dat[0 +: $bits(FE_TYPE)] <= i_sub_fe_if.dat;
        o_mnr_fe2_if.ctl <= i_sub_fe_if.ctl;
        add_sub_val[1] <= i_sub_fe_if.val;
      end
    end
  end
end
endmodule