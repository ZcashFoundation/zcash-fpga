/*
  This is a simple FIFO implementation using AXI stream source and sink interfaces.
  It has a single clock delay from i_axi to o_axi in the case of an empty FIFO.
  Only works with power of 2 A_BITS
 
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

module axi_stream_fifo #(
  parameter SIZE,
  parameter DAT_BITS,
  parameter MOD_BITS = $clog2(DAT_BITS/8),
  parameter CTL_BITS
) (
  input i_clk, i_rst,
  if_axi_stream.sink   i_axi,
  if_axi_stream.source o_axi,
  output logic         o_full,
  output logic         o_emp
);
  
logic [$clog2(SIZE)-1:0] rd_ptr, wr_ptr;

logic [SIZE-1:0][DAT_BITS + CTL_BITS + MOD_BITS + 3 -1:0] ram;  

// Control for full and empty, and assigning outputs from the ram
always_comb begin
  i_axi.rdy = ~o_full;
  o_axi.dat = ram[rd_ptr][0 +: DAT_BITS];
  o_axi.ctl = ram[rd_ptr][DAT_BITS +: CTL_BITS];
  o_axi.mod = ram[rd_ptr][CTL_BITS+DAT_BITS +: MOD_BITS];
  o_axi.sop = ram[rd_ptr][CTL_BITS+DAT_BITS+MOD_BITS +: 1];
  o_axi.eop = ram[rd_ptr][CTL_BITS+DAT_BITS+MOD_BITS+1 +: 1];
  o_axi.err = ram[rd_ptr][CTL_BITS+DAT_BITS+MOD_BITS+2 +: 1];
  o_axi.val = ~o_emp;
end

// Logic for writing and reading from ram without reset
always_ff @ (posedge i_clk) begin
  if (i_axi.val && i_axi.rdy) begin
    ram [wr_ptr] <= {i_axi.err, i_axi.eop, i_axi.sop, i_axi.mod, i_axi.ctl, i_axi.dat};
  end
end

// Control logic which requires a reset
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    rd_ptr <= 0;
    wr_ptr <= 0;
    o_emp <= 1;
    o_full <= 0;
  end else begin
  
    // Write and read
    if (i_axi.val && i_axi.rdy && o_axi.val && o_axi.rdy) begin
      wr_ptr <= (wr_ptr + 1) % SIZE;
      rd_ptr <= (rd_ptr + 1) % SIZE;
    // Write
    end else if(~o_full && i_axi.val && i_axi.rdy) begin
      o_emp <= 0;
      wr_ptr <= (wr_ptr + 1) % SIZE;
      if ((wr_ptr + 1) % SIZE == rd_ptr) o_full <= 1;
    // Read
    end else if (~o_emp && o_axi.val && o_axi.rdy) begin
      o_full <= 0;
      rd_ptr <= (rd_ptr + 1) % SIZE;
      if ((rd_ptr + 1) % SIZE == wr_ptr) o_emp <= 1;
    end
    
  end
end
  
endmodule