/*
  Just used to allow debug to be added to an interface in Vivado easily.
  
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

module debug_if #(
  parameter DAT_BYTS,
  parameter DAT_BITS = DAT_BYTS*8,
  parameter MOD_BITS = DAT_BYTS == 1 ? 1 :$clog2(DAT_BYTS),
  parameter CTL_BITS
) (
  if_axi_stream i_if
);

(* mark_debug = "true" *) logic rdy;
(* mark_debug = "true" *) logic val;
(* mark_debug = "true" *) logic err;
(* mark_debug = "true" *) logic sop;
(* mark_debug = "true" *) logic eop;
(* mark_debug = "true" *) logic [CTL_BITS-1:0] ctl;
(* mark_debug = "true" *) logic [DAT_BITS-1:0] dat;
(* mark_debug = "true" *) logic [MOD_BITS-1:0] mod;

always_ff @ (posedge i_if.i_clk) begin
  rdy <= i_if.rdy;
  val <= i_if.val;
  err <= i_if.err;
  sop <= i_if.sop;
  eop <= i_if.eop;
  ctl <= i_if.ctl;
  dat <= i_if.dat;
  mod <= i_if.mod;
end

endmodule