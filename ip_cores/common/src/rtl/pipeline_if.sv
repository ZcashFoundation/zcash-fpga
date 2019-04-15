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

module pipeline_if  #(
  parameter NUM_STAGES = 1
) (
  input rst,
  if_axi_stream.sink   i_if,
  if_axi_stream.source o_if
);
  
genvar g0;
generate
  if (NUM_STAGES == 0) begin
    
    always_comb o_if.copy_if_comb(i_if.dat, i_if.val, i_if.sop, i_if.eop, i_if.err, i_if.mod, i_if.ctl);
    
  end else begin
    
    if_axi_stream #(.DAT_BYTS(i_if.DAT_BYTS), .CTL_BITS(i_if.CTL_BITS)) if_stage [NUM_STAGES-1] (i_if.clk);
    
    for (g0 = 0; g0 < NUM_STAGES; g0++) begin : GEN_STAGE
      pipeline_if_single pipeline_if_single (.i_if(g0 == 0 ? i_if : if_stage[g0-1]), .o_of(g0 == NUM_STAGES-1 ? o_if : if_stage[g0]));
    end
    
  end
endgenerate
endmodule