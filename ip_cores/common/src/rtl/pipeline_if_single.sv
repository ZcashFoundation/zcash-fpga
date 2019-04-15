/*
  Pipelining for an interface.
  
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

module pipeline_if_single #(
  parameter DAT_BYTS = 8,
  parameter CTL_BITS = 8
)(
  input i_rst,
  if_axi_stream.sink   i_if,
  if_axi_stream.source o_if
);





// Need pipeline stage to store temp data
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) if_r (i_if.i_clk);

always_ff @ (i_if.i_clk) begin
  if (i_rst) begin
    o_if.reset_source();
    if_r.reset_source();
    if_r.rdy <= 0;
    i_if.rdy <= 0;
  end else begin
    i_if.rdy <= ~o_if.val || (o_if.val && o_if.rdy && ~if_r.val);
    
    
    // Data transfer cases
    if (~o_if.val || (o_if.val && o_if.rdy)) begin
      // First case - second interface is valid
      if (if_r.val) begin
        o_if.copy_if(if_r.dat, if_r.val, if_r.sop, if_r.eop, if_r.err, if_r.mod, if_r.ctl);
        if_r.val <= 0;
      // Second case - second interface not valid
      end else begin
        o_if.copy_if(i_if.dat, i_if.val, i_if.sop, i_if.eop, i_if.err, i_if.mod, i_if.ctl);
      end
    end
    
    // Check for case where input is valid so we need to store in second interface
    if (i_if.rdy && (o_if.val && ~o_if.rdy)) begin
      if_r.copy_if(i_if.dat, i_if.val, i_if.sop, i_if.eop, i_if.err, i_if.mod, i_if.ctl);
    end
  end
end
  
endmodule