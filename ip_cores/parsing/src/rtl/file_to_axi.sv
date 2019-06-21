/*
  This reads a binary or ASCII file and creates an AXI stream,
  used for testbench purposes. Can optionally add in random flow control.
  
  Only binary is supported at this moment.
  
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

module file_to_axi #(
  parameter        BINARY,        // 0 for ASCII, 1 for binary
  parameter        DAT_BYTS,
  parameter        FP = 0        // Forward pressure, if this is non-zero then this is the % of cycles o_axi.val will be low
) (
  input i_clk, i_rst,
  input string i_file,            // Path to file to read from
  input        i_start,
  output logic o_done,
  if_axi_stream.source   o_axi
);
  
integer                fp, r;
logic                  sop_l;
logic [DAT_BYTS*8-1:0] dat;

always_comb begin
  o_axi.dat = flip_bytes(dat);
end

initial begin
  o_done = 0;
  o_axi.reset_source();
  sop_l = 0;
  while (!i_start) @(posedge o_axi.i_clk);
  
  fp = $fopen(i_file, BINARY ? "rb" : "r");
  if (fp==0) $fatal(1, "%m %t ERROR: file_to_axi could not open file %s", $time, i_file);
  
  if (BINARY == 0) begin
    $fatal(1, "%m %t ERROR: file_to_axi BINARY == 0 not supported", $time);
  end else begin
    while(!$feof(fp)) begin            
      r = $fread(dat, fp);
      if (r < DAT_BYTS) dat = dat << (DAT_BYTS-r)*8;
      o_axi.val = 1; // TODO
      o_axi.sop = ~sop_l;
      sop_l = 1;
      o_axi.eop = $feof(fp);
      o_axi.mod = $feof(fp) ? r : 0;
      
      @(posedge o_axi.i_clk);
      while (!(o_axi.val && o_axi.rdy)) @(posedge o_axi.i_clk);
    end
  end
  

  o_axi.reset_source();
  o_done = 1;
  $display("%m %t INFO: file_to_axi finished reading file %s", $time, i_file);
  $fclose(fp);
end

// Function to flip bytes that are read in binary mode
function [DAT_BYTS*8-1:0] flip_bytes(input [DAT_BYTS*8-1:0] in);
  for(int i = 0; i < DAT_BYTS; i = i + 1)
    flip_bytes[i*8 +: 8] = in[(DAT_BYTS-1-i)*8 +: 8];
endfunction

endmodule