/*
  Calculates a mod n, using barret reduction.

  This is the pipelined version for higher performance. Requires an arbitrator at top level
  for the two multiplier connections.

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

module barret_mod_pipe #(
  parameter                DAT_BITS,
  parameter                CTL_BITS = 8,
  parameter                IN_BITS = DAT_BITS*2,
  parameter [DAT_BITS-1:0] P                     // Input can be in range of 0 <= i_dat < P^2
)(
  input                       i_clk,
  input                       i_rst,
  input [DAT_BITS*2-1:0]      i_dat,
  input                       i_val,
  input [CTL_BITS-1:0]        i_ctl,
  output logic [CTL_BITS-1:0] o_ctl,
  output logic                o_rdy,
  output logic [DAT_BITS-1:0] o_dat,
  output logic                o_val,
  output logic                o_err,
  input                       i_rdy,
  if_axi_stream.source        o_mult_if_0,
  if_axi_stream.sink          i_mult_if_0,
  if_axi_stream.source        o_mult_if_1,
  if_axi_stream.sink          i_mult_if_1
);

localparam                 K = $clog2(P)/2 + 1;
localparam                 MAX_IN_BITS = 4*K;
localparam [MAX_IN_BITS:0] U = (1 << 4*K) / P;

logic [CTL_BITS-1:0] ctl;
logic [DAT_BITS-1:0] dat;
logic val;
logic rdy;

if_axi_stream #(.DAT_BITS(2*K + 2), .CTL_BITS(CTL_BITS)) fifo_in_if(i_clk);
if_axi_stream #(.DAT_BITS(2*K + 2), .CTL_BITS(CTL_BITS)) fifo_out_if(i_clk);
logic fifo_out_full;

// Stage 1 multiplication
always_comb begin
  o_rdy = (~o_mult_if_0.val || (o_mult_if_0.val && o_mult_if_0.rdy)) && fifo_in_if.rdy;
end


always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mult_if_0.reset_source();
    fifo_in_if.reset_source();
  end else begin
    if (fifo_in_if.rdy) fifo_in_if.val <= 0;
    if (o_mult_if_0.rdy) o_mult_if_0.val <= 0;
  
    if (o_rdy) begin
      o_mult_if_0.sop <= 1;
      o_mult_if_0.eop <= 1;
      o_mult_if_0.val <= i_val;
      o_mult_if_0.ctl <= i_ctl;
      o_mult_if_0.dat[0 +: DAT_BITS] <= i_dat >> (2*K - 2);
      o_mult_if_0.dat[DAT_BITS +: DAT_BITS] <= U;
      fifo_in_if.dat <= i_dat % (1 << (2*K + 2)); 
      fifo_in_if.ctl <= i_ctl;
      fifo_in_if.val <= i_val;
    end
  end
end

// Stage 2 shift + multiplication
always_comb begin
  i_mult_if_0.rdy = ~o_mult_if_1.val || (o_mult_if_1.val && o_mult_if_1.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mult_if_1.reset_source();
  end else begin
    if (o_mult_if_1.rdy) o_mult_if_1.val <= 0;
  
    if (i_mult_if_0.rdy) begin
      o_mult_if_1.sop <= 1;
      o_mult_if_1.eop <= 1;
      o_mult_if_1.val <= i_mult_if_0.val;
      o_mult_if_1.ctl <= i_mult_if_0.ctl;
      o_mult_if_1.dat[0 +: DAT_BITS] <= i_mult_if_0.dat >> (2*K + 2);
      o_mult_if_1.dat[DAT_BITS +: DAT_BITS] <= P;
    end
  end
end

// Stage 3 subtraction to final result
always_comb begin
  i_mult_if_1.rdy = (rdy && val) || ~val;
end
always_comb begin
  fifo_out_if.rdy = i_mult_if_1.val && i_mult_if_1.rdy;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    val <= 0;
  end else begin
    if (i_mult_if_1.rdy) val <= 0;
  
    if (i_mult_if_1.rdy) begin
      val <= i_mult_if_1.val;
      ctl <= i_mult_if_1.ctl;
      dat <= fifo_out_if.dat - (i_mult_if_1.dat % (1 << (2*K + 2)));
    end
  end
end

// Stage 4 possible subtraction of mod
always_comb begin
  rdy = (i_rdy && o_val) || ~o_val;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_val <= 0;
    o_err <= 0;
  end else begin
  
    if (i_rdy) o_val <= 0;
    
    if (~o_val || (o_val && i_rdy)) begin
      o_val <= val;
      o_ctl <= ctl;
      o_dat <= dat >= P ? dat - P : dat;
      if (dat > P*2)
        o_err <= 1;
    end
    if (fifo_out_full && fifo_in_if.val)  o_err <= 1;
  end
end

// Fifo to store inputs (as we need to do final subtraction)
axi_stream_fifo #(
  .SIZE     ( 16      ),
  .DAT_BITS ( 2*K + 2 ),
  .CTL_BITS ( CTL_BITS )
)
axi_stream_fifo (
  .i_clk ( i_clk         ),
  .i_rst ( i_rst         ),
  .i_axi ( fifo_in_if    ),
  .o_axi ( fifo_out_if   ),
  .o_full( fifo_out_full ),
  .o_emp()
);


endmodule