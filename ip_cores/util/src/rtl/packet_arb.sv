/*
  Takes in multiple streams and round robins between them.
  
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
  parameter CTL_BITS,
  parameter NUM_IN
) (
  input i_clk, i_rst,

  if_axi_stream.sink   i_axi [NUM_IN-1:0], 
  if_axi_stream.source o_axi
);

localparam DAT_BITS = DAT_BYTS*8;
localparam MOD_BITS = $clog2(DAT_BYTS);

logic [$clog2(NUM_IN)-1:0] idx;
logic locked;

logic [NUM_IN-1:0]               rdy, val, eop, sop, err;
logic [NUM_IN-1:0][DAT_BITS-1:0] dat;
logic [NUM_IN-1:0][MOD_BITS-1:0] mod;
logic [NUM_IN-1:0][CTL_BITS-1:0] ctl;

generate
  genvar g;
  for (g = 0; g < NUM_IN; g++) begin: GEN
    always_comb begin
      i_axi[g].rdy = rdy[g];
      val[g] = i_axi[g].val;
      eop[g] = i_axi[g].eop;
      sop[g] = i_axi[g].sop;
      err[g] = i_axi[g].err;
      dat[g] = i_axi[g].dat;
      mod[g] = i_axi[g].mod;
      ctl[g] = i_axi[g].ctl;
    end
  end 
endgenerate

always_comb begin
  rdy = 0;
  rdy[idx] = o_axi.rdy;
  o_axi.dat = dat[idx];
  o_axi.mod = mod[idx];
  o_axi.ctl = ctl[idx];
  o_axi.val = val[idx];
  o_axi.err = err[idx];
  o_axi.sop = sop[idx];
  o_axi.eop = eop[idx];
end

// Logic to arbitrate is registered
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    locked <= 0;
    idx <= 0;
  end else begin
    if (~locked) begin
      idx <= get_next(idx);
      if (val[get_next(idx)]) begin
        locked <= 1;
      end
    end else if (eop[idx] && val[idx] && rdy[idx]) begin
      idx <= get_next(idx);
      locked <= 0;
    end
  end
end

// Get next input with valid
function [$clog2(NUM_IN)-1:0] get_next(input [NUM_IN-1:0] idx);
  get_next = idx;
  for (int i = 0; i < NUM_IN; i++)
    if (val[(idx+i+1) % NUM_IN]) begin
      get_next = (idx+i+1) % NUM_IN;
      break;
    end
endfunction

endmodule