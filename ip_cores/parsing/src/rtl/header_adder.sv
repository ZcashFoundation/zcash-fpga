/*
  This takes in a AXI stream, appends a header, and outputs the resulting stream.
  
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

module header_adder #(
    parameter HDR_BYTS,
    parameter DAT_BYTS
) (
  input i_clk, i_rst,
  
  input [HDR_BYTS*8-1:0] i_header,  // Must be valid during i_axi.val
  if_axi_stream.sink     i_axi,
  if_axi_stream.source   o_axi
);
  
logic [(DAT_BYTS+(HDR_BYTS % DAT_BYTS))*8-1:0] dat_buff;
logic sop_l;
logic [$clog2(HDR_BYTS)-1:0] hdr_cnt;

always_comb begin
  i_axi.dat = dat_buff[HDR_BYTS*8 +: DAT_BYTS*8];
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    dat_buff <= 0;
    hdr_cnt <= 0;
    i_axi.rdy <= 0;
    sop_l <= 0;
    o_axi.reset_source();
  end else begin
    i_axi.rdy <= o_axi.rdy && (hdr_cnt + DAT_BYTS >= HDR_BYTS);
    if (~o_axi.val || (~o_axi.val && o_axi.rdy)) begin
      o_axi.sop <= ~sop_l;
      o_axi.val <= i_axi.val;
      o_axi.err <= i_axi.err;
      o_axi.ctl <= i_axi.ctl;
      o_axi.mod <= (i_axi.mod + HDR_BYTS) % DAT_BYTS;
      o_axi.eop <= i_axi.eop;
      hdr_cnt <= (hdr_cnt + DAT_BYTS >= HDR_BYTS) ? hdr_cnt : hdr_cnt + DAT_BYTS;
      sop_l <= i_axi.sop;
      //TODO
      dat_buff <= {dat_buff[0 +: (HDR_BYTS % DAT_BYTS)*8], i_axi.dat};
      
      
      if (i_axi.eop) hdr_cnt <= 0;
      
    end
  end
end
  
endmodule