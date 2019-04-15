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
  parameter DAT_BYTS = 8,
  parameter CTL_BITS = 8,
  parameter NUM_STAGES = 1
) (
  input i_rst,
  if_axi_stream   i_if,
  if_axi_stream o_if
);
  
genvar g0;
generate
  if (NUM_STAGES == 0) begin
    
    always_comb o_if.copy_if_comb(i_if.dat, i_if.val, i_if.sop, i_if.eop, i_if.err, i_if.mod, i_if.ctl);
    
  end else begin
    
    if_axi_stream #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) if_stage [NUM_STAGES-1:0] (i_if.i_clk) ;
    
    for (g0 = 0; g0 < NUM_STAGES; g0++) begin : GEN_STAGE
      if (g0 == 0)
        pipeline_if_single #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) 
          pipeline_if_single (
            .i_rst ( i_rst ),
            .i_if(i_if ),
            .o_if(if_stage[g0])
          );
        else if (g0 == NUM_STAGES-1)
          pipeline_if_single #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) 
            pipeline_if_single (
              .i_rst ( i_rst ),
              .i_if(if_stage[g0-1]),
              .o_if( o_if )
            );
         else
           pipeline_if_single #(.DAT_BYTS(DAT_BYTS), .CTL_BITS(CTL_BITS)) 
             pipeline_if_single (
               .i_rst ( i_rst ),
               .i_if(if_stage[g0-1]),
               .o_if(if_stage[g0])
             );
    end
    
  end
endgenerate
endmodule