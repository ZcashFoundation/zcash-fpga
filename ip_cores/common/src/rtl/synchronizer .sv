/*
  A synchronizer block that can be used for clock crossings.
  
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

module synchronizer  #(
  parameter DAT_BITS = 1,
  parameter NUM_CLKS = 2
) (
  input i_clk_a,
  input i_clk_b,
  
  input        [DAT_BITS-1:0] i_dat_a,
  output logic [DAT_BITS-1:0] o_dat_b
);

logic [NUM_CLKS:0][DAT_BITS-1:0] dat;

always_ff @ (posedge i_clk_a) begin
  dat[0] <= i_dat_a;
end

always_ff @ (posedge i_clk_b) begin
  for(int i = 1; i <= NUM_CLKS; i++)
    dat[i] <= dat[i-1];
end

always_comb begin
  o_dat_b = dat[NUM_CLKS];
end
  
endmodule