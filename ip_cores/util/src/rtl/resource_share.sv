/*
  Takes in multiple streams and muxes them onto one output,
  and then takes another stream and de-muxes depending on control.
  Useful for sharing a single resource (i.e. multiplier) with multiple end points.
  
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

module resource_share # (
  parameter NUM_IN = 4,
  parameter CTL_BITS = 16,
  parameter DAT_BYTS = 8,
  parameter DAT_BITS = DAT_BYTS*8,
  parameter OVR_WRT_BIT = 0,
  parameter PIPELINE_IN = 0,
  parameter PIPELINE_OUT = 0,
  parameter PRIORITY_IN = 0
) (
  input i_clk, i_rst,

  if_axi_stream.sink   i_axi [NUM_IN-1:0], 
  if_axi_stream.source o_res,
  
  if_axi_stream.sink   i_res, 
  if_axi_stream.source o_axi [NUM_IN-1:0]
);

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .DAT_BITS(DAT_BITS), .CTL_BITS(CTL_BITS)) out_int (i_clk);

// Arbitratation to the resource
packet_arb # (
  .DAT_BITS    ( DAT_BITS ),
  .DAT_BYTS    ( DAT_BYTS ),
  .CTL_BITS    ( CTL_BITS ),
  .NUM_IN      ( NUM_IN      ),
  .OVR_WRT_BIT ( OVR_WRT_BIT ),
  .PIPELINE    ( 0           ),
  .PRIORITY_IN ( PRIORITY_IN )
)
packet_arb_mult (
  .i_clk ( i_clk   ),
  .i_rst ( i_rst   ),
  .i_axi ( i_axi   ),
  .o_axi ( out_int )
);

pipeline_if  #(
  .DAT_BITS   ( DAT_BITS ),
  .DAT_BYTS   ( DAT_BYTS ),
  .CTL_BITS   ( CTL_BITS ),
  .NUM_STAGES ( PIPELINE_OUT )
)
pipeline_if_out (
  .i_rst ( i_rst   ),
  .i_if  ( out_int ),
  .o_if  ( o_res   )
);

// Demuxing
if_axi_stream #(.DAT_BYTS(DAT_BYTS), .DAT_BITS(DAT_BITS), .CTL_BITS(CTL_BITS)) in_int (i_clk);

genvar gen0;
logic [NUM_IN-1:0] rdy;

pipeline_if  #(
  .DAT_BITS   ( DAT_BITS ),
  .DAT_BYTS   ( DAT_BYTS ),
  .CTL_BITS   ( CTL_BITS ),
  .NUM_STAGES ( PIPELINE_IN )
)
pipeline_if_in (
  .i_rst ( i_rst  ),
  .i_if  ( i_res  ),
  .o_if  ( in_int )
);

generate 
  for (gen0 = 0; gen0 < NUM_IN; gen0++) begin: GEN_DEMUX
  
    always_comb begin
      rdy[gen0] = o_axi[gen0].rdy;
      o_axi[gen0].copy_if_comb(in_int.dat, in_int.val && in_int.ctl[OVR_WRT_BIT +: $clog2(NUM_IN)] == gen0,
          in_int.sop, in_int.eop, in_int.err, in_int.mod, in_int.ctl);
      o_axi[gen0].ctl[OVR_WRT_BIT +: $clog2(NUM_IN)] = 0;
    end 
    
  end
endgenerate

always_comb begin
  in_int.rdy = rdy[in_int.ctl[OVR_WRT_BIT +: $clog2(NUM_IN)]];
end

endmodule