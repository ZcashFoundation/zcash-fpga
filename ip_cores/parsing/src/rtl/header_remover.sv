/*
  This takes in a AXI stream, removes N bytes, and outputs the resulting stream.
  
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

module header_remover #(
  parameter MAX_HDR_BYTS,
  parameter DAT_BYTS
) (
  input i_clk, i_rst,
  
  input [$clog2(MAX_HDR_BYTS)-1:0] i_hdr_byts,  // Can change during packet
  input                  i_hdr_val,
  if_axi_stream.sink     i_axi,
  if_axi_stream.source   o_axi
);
  
localparam DAT_BITS = DAT_BYTS*8;
  
logic [(DAT_BITS*2)-1:0]       dat_buff;
logic [$clog2(MAX_HDR_BYTS):0] hdr_byts, hdr_byts_l, byt_cnt;
logic o_sop_l;

always_comb begin
  hdr_byts = i_hdr_val ? i_hdr_byts : hdr_byts_l;
  i_axi.rdy = ~i_rst && ((hdr_byts >= byt_cnt) || o_axi.rdy);
  o_axi.dat = dat_buff[(hdr_byts % DAT_BYTS)*8 +: DAT_BITS];
  o_axi.sop = ~o_sop_l;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_axi.val <= 0;
    o_axi.eop <= 0;
    o_axi.mod <= 0;
    o_axi.err <= 0;
    o_axi.ctl <= 0;
    byt_cnt <= 0;
    hdr_byts_l <= MAX_HDR_BYTS;
    o_sop_l <= 0;
  end else begin
       
    if (~o_axi.val || (o_axi.val && o_axi.rdy)) begin
    
      if (i_axi.val && i_axi.rdy)
        byt_cnt <= (byt_cnt >= hdr_byts) ? byt_cnt : byt_cnt + DAT_BYTS;
      
      if (i_axi.sop && i_axi.val && i_axi.rdy) begin
        hdr_byts_l <= MAX_HDR_BYTS;
        o_axi.ctl <= i_axi.ctl;
      end
      
      dat_buff <= {i_axi.dat, dat_buff[DAT_BITS +: DAT_BITS]};
      o_axi.val <= i_axi.val && (byt_cnt >= hdr_byts);
      
      o_sop_l <= o_sop_l | (o_axi.sop && o_axi.val && o_axi.rdy);
      
      if (o_axi.eop && o_axi.val && o_axi.rdy) begin
        o_sop_l <= 0;
        o_axi.eop <= 0;
        o_axi.val <= 0;
        byt_cnt <= 0;
      end
      if (i_axi.eop && i_axi.val && i_axi.rdy) begin
        hdr_byts_l <= MAX_HDR_BYTS;
        o_axi.eop <= i_axi.eop;
        o_axi.mod <= -(hdr_byts % DAT_BYTS) + i_axi.mod;
      end
      
    end
    
    if (i_hdr_val) 
      hdr_byts_l <= i_hdr_byts;
    
  end
end
  
endmodule