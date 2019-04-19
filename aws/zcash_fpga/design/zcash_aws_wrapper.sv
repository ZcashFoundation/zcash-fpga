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

module zcash_aws_wrapper(
  input i_rst,
  input i_clk,
  if_axi_stream.sink   rx_aws_if,
  if_axi_stream.source tx_aws_if,
  if_axi_stream.sink   rx_zcash_if,
  if_axi_stream.source tx_zcash_if
);

if_axi_stream #(.DAT_BYTS(rx_aws_if.DAT_BYTS), .CTL_BITS(1)) rx_int (rx_aws_if.i_clk) ;
if_axi_stream #(.DAT_BYTS(tx_aws_if.DAT_BYTS), .CTL_BITS(1)) tx_int (tx_aws_if.i_clk) ;

axis_dwidth_converter_8_to_64 converter_8_to_64 (
  .aclk(i_clk),
  .aresetn(~i_rst),
  .s_axis_tvalid(tx_int.val),
  .s_axis_tready(tx_int.rdy),
  .s_axis_tdata(tx_int.dat),
  .s_axis_tlast(tx_int.eop),
  .m_axis_tvalid(tx_aws_if.val),
  .m_axis_tready(tx_aws_if.rdy),
  .m_axis_tdata(tx_aws_if.dat),
  .m_axis_tlast(tx_aws_if.eop)
);

axis_data_fifo_8 tx_fifo (
  .s_axis_aresetn(~i_rst),
  .s_axis_aclk(i_clk),
  .s_axis_tvalid(rx_zcash_if.val),
  .s_axis_tready(rx_zcash_if.rdy),
  .s_axis_tdata(rx_zcash_if.dat),
  .s_axis_tlast(rx_zcash_if.eop),
  .m_axis_tvalid(tx_int.val),
  .m_axis_tready(tx_int.rdy),
  .m_axis_tdata(tx_int.dat),
  .m_axis_tlast(tx_int.eop),
  .axis_data_count(),
  .axis_wr_data_count(),
  .axis_rd_data_count()
);

axis_dwidth_converter_64_to_8 converter_64_to_8 (
  .aclk(i_clk),
  .aresetn(~i_rst),
  .s_axis_tvalid(rx_aws_if.val),
  .s_axis_tready(rx_aws_if.rdy),
  .s_axis_tdata(rx_aws_if.dat),
  .s_axis_tlast(rx_aws_if.eop),
  .m_axis_tvalid(rx_int.val),
  .m_axis_tready(rx_int.rdy),
  .m_axis_tdata(rx_int.dat),
  .m_axis_tlast(rx_int.eop)
);

axis_data_fifo_8 rx_fifo (
  .s_axis_aresetn(~i_rst),
  .s_axis_aclk(i_clk),
  .s_axis_tvalid(rx_int.val),
  .s_axis_tready(rx_int.rdy),
  .s_axis_tdata(rx_int.dat),
  .s_axis_tlast(rx_int.eop),
  .m_axis_tvalid(tx_zcash_if.val),
  .m_axis_tready(tx_zcash_if.rdy),
  .m_axis_tdata(tx_zcash_if.dat),
  .m_axis_tlast(tx_zcash_if.eop),
  .axis_data_count(),
  .axis_wr_data_count(),
  .axis_rd_data_count()
);

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    tx_zcash_if.mod <= 0;
    tx_zcash_if.ctl <= 0;
    tx_zcash_if.err <= 0;
    tx_zcash_if.sop <= 1;
  end else begin
    if (tx_zcash_if.val && tx_zcash_if.rdy) begin
      tx_zcash_if.sop <= tx_zcash_if.eop;
  end
  end
end

endmodule