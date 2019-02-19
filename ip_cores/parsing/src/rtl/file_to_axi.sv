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
    parameter        HDR_BYTS,
    parameter        DAT_BYTS,
    parameter        BINARY,      // 0 for ASCII, 1 for binary
    parameter string FILE = "",   // Path to file
    parameter        FP = 0       // Forward pressure, if this is non-zero then this is the % of cycles o_axi.val will be low
) (
  input i_clk, i_rst,
  if_axi_stream.source   o_axi
);
  
  
logic [DAT_BYTS*8-1:0] data_temp;
integer                fp, r;
logic                  sop_l;

initial begin
  o_axi.reset_source();
  sop_l = 0;
  fp = $fopen(FILE, BINARY ? "rb" : "r");
  if (fp==0) $fatal(1, "%m %t ERROR: file_to_axi could not open file %s", $time, FILE);
  
  if (BINARY == 0) begin
    $fatal(1, "%m %t ERROR: file_to_axi BINARY == 0 not supported", $time);
  end else begin
    while(!$feof(fp)) begin            
      r = $fread(o_axi.dat, fp);
      o_axi.val = 1; // TODO
      o_axi.sop = ~sop_l;
      sop_l = 1;
      o_axi.eop = $feof(fp);
      o_axi.mod = $feof(fp) ? r : 0;
      
      @(posedge o_axi.clk);
      while (!(o_axi.val && o_axi.rdy)) @(posedge o_axi.clk);
    end
  end
  

  o_axi.reset_source();
  $display("%m %t INFO: file_to_axi finished reading file %s", $time, FILE);
  $fclose(fp);
end

endmodule