/*
  Fifo and width change for using AWS SDE.

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

module zcash_aws_wrapper (
  input i_rst,
  input i_clk,
  if_axi_stream.sink   rx_aws_if,
  if_axi_stream.source tx_aws_if,
  if_axi_stream.sink   rx_zcash_if,
  if_axi_stream.source tx_zcash_if
);

logic [7:0] rx_zcash_if_keep, tx_zcash_if_keep;
logic [63:0] tx_aws_if_keep, rx_aws_if_keep;

always_comb begin
  rx_zcash_if_keep = rx_zcash_if.get_keep_from_mod();
  rx_aws_if_keep = rx_aws_if.get_keep_from_mod();

  tx_aws_if.set_mod_from_keep( tx_aws_if_keep );
  tx_zcash_if.set_mod_from_keep( tx_zcash_if_keep );
end

axis_dwidth_converter_8_to_64 converter_8_to_64 (
  .aclk(i_clk),
  .aresetn(~i_rst),
  .s_axis_tvalid(rx_zcash_if.val),
  .s_axis_tready(rx_zcash_if.rdy),
  .s_axis_tdata(rx_zcash_if.dat),
  .s_axis_tlast(rx_zcash_if.eop),
  .s_axis_tkeep(rx_zcash_if_keep),
  .m_axis_tvalid(tx_aws_if.val),
  .m_axis_tready(tx_aws_if.rdy),
  .m_axis_tdata(tx_aws_if.dat),
  .m_axis_tlast(tx_aws_if.eop),
  .m_axis_tkeep(tx_aws_if_keep)
);

axis_dwidth_converter_64_to_8 converter_64_to_8 (
  .aclk(i_clk),
  .aresetn(~i_rst),
  .s_axis_tvalid(rx_aws_if.val),
  .s_axis_tready(rx_aws_if.rdy),
  .s_axis_tdata(rx_aws_if.dat),
  .s_axis_tlast(rx_aws_if.eop),
  .s_axis_tkeep(rx_aws_if_keep),
  .m_axis_tvalid(tx_zcash_if.val),
  .m_axis_tready(tx_zcash_if.rdy),
  .m_axis_tdata(tx_zcash_if.dat),
  .m_axis_tlast(tx_zcash_if.eop),
  .m_axis_tkeep(tx_zcash_if_keep)
);

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    tx_zcash_if.ctl <= 0;
    tx_zcash_if.err <= 0;
    tx_zcash_if.sop <= 1;
    tx_aws_if.ctl <= 0;
    tx_aws_if.err <= 0;
    tx_aws_if.sop <= 1;
  end else begin
    if (tx_zcash_if.val && tx_zcash_if.rdy) tx_zcash_if.sop <= tx_zcash_if.eop;
    if (tx_aws_if.val && tx_aws_if.rdy) tx_aws_if.sop <= tx_aws_if.eop;
  end
end

endmodule
