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
  parameter NUM_IN
) (
  input i_clk, i_rst,

  if_axi_stream.sink   i_axi [NUM_IN-1:0], 
  if_axi_stream.source o_axi
);

logic [$clog2(NUM_IN)-1:0] idx;
logic locked;

logic [NUM_IN-1:0] rdy, val, eop;

generate
  genvar g;
  for (g = 0; g < NUM_IN; g++) begin: GEN
    always_comb begin
      i_axi[g].rdy = rdy[g];
      val[g] = i_axi[g].val;
      eop[g] = i_axi[g].eop;
    end
    
    always_ff @ (posedge i_clk) begin
      if(g == idx)
        o_axi.copy_if(i_axi[g].to_struct());
    end
    
  end
endgenerate

always_comb begin
  rdy = 0;
  rdy[idx] = o_axi.rdy;
end

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