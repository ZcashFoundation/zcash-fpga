/*
  Calculates a mod n, using barret reduction.
  Can use either karatsuba multiplier or accumlate - multiply 
  for the multiplications. 
  
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

module barret_mod #(
  parameter                OUT_BITS = 256,
  parameter                CTL_BITS = 8,
  parameter                IN_BITS = 512,
  parameter [OUT_BITS-1:0] P = 256'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFE_BAAEDCE6_AF48A03B_BFD25E8C_D0364141,
  parameter                K = OUT_BITS,
  parameter                MULTIPLIER = "EXTERNAL" // [ACCUM_MULT || KARATSUBA || EXTERNAL]
)(
  input                       i_clk,
  input                       i_rst,
  input [IN_BITS-1:0]         i_dat,
  input                       i_val,
  input [CTL_BITS-1:0]        i_ctl,
  output logic [CTL_BITS-1:0] o_ctl,
  output logic                o_rdy,
  output logic [OUT_BITS-1:0] o_dat,
  output logic                o_val,
  input                       i_rdy,
  if_axi_stream.source        o_mult_if,
  if_axi_stream.sink          i_mult_if
);

localparam                   MAX_IN_BITS = 2*K;
localparam [MAX_IN_BITS:0]   U = (1 << (2*K)) / P;
logic [2:0][CTL_BITS-1:0] ctl_r;

if_axi_stream #(.DAT_BITS(2*(OUT_BITS+2))) mult_in_if(i_clk);
if_axi_stream #(.DAT_BITS(2*(OUT_BITS+2))) mult_out_if(i_clk);

logic [MAX_IN_BITS:0] c1, c2, c3, c4, P_;
logic c4_grt;

always_comb begin
  P_ = {{(MAX_IN_BITS-OUT_BITS-1){1'b0}}, P}; 
  c4_grt  = c4 >= P_;
end

typedef enum {IDLE, S0, S1, S2, FINISHED, WAIT_MULT} state_t;
state_t state, prev_state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_rdy <= 0;
    o_dat <= 0;
    o_val <= 0;
    state <= IDLE;
    prev_state <= IDLE;
    c1 <= 0;
    c2 <= 0;
    c3 <= 0;
    c4 <= 0;
    mult_in_if.reset_source();
    mult_out_if.rdy <= 1;
    o_ctl <= 0;
    ctl_r <= 0;
  end else begin
    mult_out_if.rdy <= 1;
    case (state)
      {IDLE}: begin
        o_rdy <= 1;
        o_val <= 0;
        c4 <= i_dat;
        if (i_val && o_rdy) begin
          o_rdy <= 0;
          state <= WAIT_MULT;
          mult_in_if.val <= 1;
          ctl_r[0] <= i_ctl;
          mult_in_if.dat[0 +: OUT_BITS+1] <= i_dat >> (K-1);
          mult_in_if.dat[OUT_BITS+1 +: OUT_BITS+1] <= U;
          prev_state <= S0;
        end
      end
      {S0}: begin
        c3 <= c2 >> (K + 1);
        state <= S1;
        ctl_r[1] <= ctl_r[0];
      end
      {S1}: begin
        mult_in_if.val <= 1;
        mult_in_if.dat[0 +: OUT_BITS+1] <= c3;
        mult_in_if.dat[OUT_BITS+1 +: OUT_BITS+1] <= P;
        state <= WAIT_MULT;
        prev_state <= S2;
        ctl_r[2] <= ctl_r[1];
      end
      {S2}: begin
        if (c4_grt) begin
          c4 <= c4 - P_;
          state <= S2;
        end else begin
          state <= FINISHED;
          o_dat <= c4;
          o_val <= 1;
          o_ctl <= ctl_r[2];
        end
      end
      {FINISHED}: begin
        if (o_val && i_rdy) begin
          o_val <= 0;
          state <= IDLE;
        end
      end
      // In this state we are waiting for a multiply to be finished
      {WAIT_MULT}: begin
        if (mult_in_if.val && mult_in_if.rdy) mult_in_if.val <= 0;
        if (mult_out_if.rdy && mult_out_if.val) begin
          state <= prev_state;
          case(prev_state)
            S0: c2 <= mult_out_if.dat;
            S2: c4 <= c4 - mult_out_if.dat;
            default: begin end     
          endcase
        end
      end
      default: begin
        o_val <= 0;
        state <= IDLE;
      end
    endcase
  end
end

// Do the multiplications
generate 
  if (MULTIPLIER == "ACCUM_MULT") begin: MULTIPLIER_GEN
    accum_mult # (
      .BITS_A  ( OUT_BITS +8 ),
      .LEVEL_A ( 6          ),
      .LEVEL_B ( 4          )
    ) 
    accum_mult (
      .i_clk ( i_clk ),
      .i_rst ( i_rst ),
      .i_dat_a ({7'd0, mult_in_if.dat[0 +: OUT_BITS+1]}) ,
      .i_dat_b ({7'd0, mult_in_if.dat[OUT_BITS+1 +: OUT_BITS+1]}),
      .i_val ( mult_in_if.val ),
      .o_rdy ( mult_in_if.rdy ),
      .o_dat ( mult_out_if.dat ),
      .o_val ( mult_out_if.val ),
      .i_rdy ( mult_out_if.rdy )
    );
  end else if (MULTIPLIER == "KARATSUBA") begin
    localparam LEVEL = 2;
    
    karatsuba_ofman_mult # (
      .BITS  ( OUT_BITS + 8 ),
      .LEVEL ( LEVEL        )
    )
    karatsuba_ofman_mult (
      .i_clk  ( i_clk                 ),
      .i_rst ( i_rst),
      .i_val ( mult_in_if.val ),
      .i_ctl (),
      .i_rdy( mult_out_if.rdy ),
      .o_rdy (mult_in_if.rdy),
      .o_val(mult_out_if.val),
      .i_dat_a( {7'd0, mult_in_if.dat[0 +: OUT_BITS+1]}),
      .i_dat_b( {7'd0, mult_in_if.dat[OUT_BITS+1 +: OUT_BITS+1]} ),  
      .o_dat  ( mult_out_if.dat       )
    );
    
  always_comb begin
    o_mult_if.val = 0;
    i_mult_if.rdy = 0;
    end

  
  end else if (MULTIPLIER == "EXTERNAL") begin
    always_comb begin
      o_mult_if.val = mult_in_if.val;
      o_mult_if.dat = mult_in_if.dat;
      o_mult_if.sop = mult_in_if.sop;
      o_mult_if.eop = mult_in_if.eop;
      o_mult_if.err = mult_in_if.err;
      o_mult_if.mod = mult_in_if.mod;
      o_mult_if.ctl = mult_in_if.ctl;
      mult_in_if.rdy = o_mult_if.rdy;
      
      mult_out_if.val = i_mult_if.val;
      mult_out_if.dat = i_mult_if.dat;
      mult_out_if.sop = i_mult_if.sop;
      mult_out_if.eop = i_mult_if.eop;
      mult_out_if.err = i_mult_if.err;
      mult_out_if.mod = i_mult_if.mod;
      mult_out_if.ctl = i_mult_if.ctl;
      i_mult_if.rdy = mult_out_if.rdy;
    end
  end else
    $fatal(1, "%m ERROR: Unknown multiplier type [%s] in barret_mod.sv", MULTIPLIER);
endgenerate
initial assert (IN_BITS <= MAX_IN_BITS) else $fatal(1, "%m ERROR: IN_BITS[%d] > MAX_IN_BITS[%d] in barret_mod", IN_BITS, MAX_IN_BITS);

endmodule
