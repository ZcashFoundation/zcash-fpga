/*
  Takes in multiple streams and round robins between them.
  
  The last $clog2(NUM_IN) bits on ctl will be overwritten with the identifier for the channel.
  
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

module packet_arb # (
  parameter DAT_BYTS,
  parameter DAT_BITS = DAT_BYTS*8,
  parameter CTL_BITS,
  parameter NUM_IN,
  parameter OVR_WRT_BIT = CTL_BITS - $clog2(NUM_IN), // What bits in ctl are overwritten with channel id
  parameter PIPELINE = 1,
  parameter PRIORITY_IN = 0,
  parameter OVERRIDE_CTL = 1 // Optional parameter to control overriding the ctl
) (
  input i_clk, i_rst,

  if_axi_stream.sink   i_axi [NUM_IN-1:0], 
  if_axi_stream.source o_axi
);

localparam MOD_BITS = $clog2(DAT_BYTS);

logic [$clog2(NUM_IN)-1:0] idx;
logic locked;

logic [NUM_IN-1:0]               rdy, val, eop, sop, err;
logic [NUM_IN-1:0][DAT_BITS-1:0] dat;
logic [NUM_IN-1:0][MOD_BITS-1:0] mod;
logic [NUM_IN-1:0][CTL_BITS-1:0] ctl;

if_axi_stream #(.DAT_BYTS(DAT_BYTS), .DAT_BITS(DAT_BITS), .CTL_BITS(CTL_BITS)) out_int_if (i_clk);

generate
  genvar g;
  for (g = 0; g < NUM_IN; g++) begin: GEN
    
    always_comb i_axi[g].rdy = rdy[g];
    always_comb begin
      val[g] = i_axi[g].val;
      eop[g] = i_axi[g].eop;
      sop[g] = i_axi[g].sop;
      err[g] = i_axi[g].err;
      dat[g] = i_axi[g].dat;
      mod[g] = i_axi[g].mod;
      ctl[g] = i_axi[g].ctl;
      if (OVERRIDE_CTL)
        ctl[g][OVR_WRT_BIT +: $clog2(NUM_IN)] = g;
    end

  end
    
  pipeline_if  #(
    .DAT_BITS   ( DAT_BITS ),
    .CTL_BITS   ( CTL_BITS ),
    .NUM_STAGES ( PIPELINE )
  )
  pipeline_if (
    .i_rst ( i_rst  ),
    .i_if  ( out_int_if ),
    .o_if  ( o_axi      )
  );
    
endgenerate

always_comb begin
  rdy = 0;
  rdy[idx] = out_int_if.rdy;
  out_int_if.dat = dat[idx];
  out_int_if.mod = mod[idx];
  out_int_if.ctl = ctl[idx];
  out_int_if.val = val[idx];
  out_int_if.err = err[idx];
  out_int_if.sop = sop[idx];
  out_int_if.eop = eop[idx];
end

// Logic to arbitrate is registered
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    locked <= 0;
    idx <= 0;
  end else begin
  
    if (~locked) idx <= get_next(idx);
    
    if (val[idx]) begin
      locked <= 1;
      idx <= idx;
    end
    
    if (eop[idx] && val[idx] && rdy[idx]) begin
      locked <= 0;
      idx <= get_next(idx);
    end
    
  end
end

// Get next input with valid
function [$clog2(NUM_IN)-1:0] get_next(input [NUM_IN-1:0] idx);
  get_next = idx;
  for (int i = 0; i < NUM_IN; i++)
    if (PRIORITY_IN == 0) begin
      if (val[(idx+i+1) % NUM_IN]) begin
        get_next = (idx+i+1) % NUM_IN;
        break;
      end
    end else begin
      // Give priority to highest number
      if (val[(NUM_IN-1-i) % NUM_IN]) begin
        get_next = (NUM_IN-1-i) % NUM_IN;
        break;
      end
    end
endfunction

endmodule