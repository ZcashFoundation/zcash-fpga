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
  parameter                IN_BITS = 512,
  parameter [OUT_BITS-1:0] P = 256'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFE_BAAEDCE6_AF48A03B_BFD25E8C_D0364141,
  parameter                K = $clog2(P),
  parameter                MULTIPLIER = "ACCUM_MULT" // [ACCUM_MULT || KARATSUBA]
)(
  input                       i_clk,
  input                       i_rst,
  input [IN_BITS-1:0]         i_dat,
  input                       i_val,
  output logic                o_rdy,
  output logic [OUT_BITS-1:0] o_dat,
  output logic                o_val,
  input                       i_rdy
);

localparam                   MAX_IN_BITS = 2*K;
localparam [MAX_IN_BITS:0]   U = (1 << (2*K)) / P;
localparam [MAX_IN_BITS-1:0] P_ = P;

if_axi_stream #(.DAT_BITS(2*(OUT_BITS+2))) mult_in_if(i_clk);
if_axi_stream #(.DAT_BITS(2*(OUT_BITS+2))) mult_out_if(i_clk);

logic [MAX_IN_BITS:0] c1, c2, c3, c4, c2_;


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
          mult_in_if.dat[0 +: OUT_BITS+1] <= i_dat >> (K-1);
          mult_in_if.dat[OUT_BITS+1 +: OUT_BITS+1] <= U;
          prev_state <= S0;
          c2_ <= (i_dat >> (K - 1))*U; // Using multiplier interface
        end
      end
      {S0}: begin
        c3 <= c2 >> (K + 1);
        state <= S1;
      end
      {S1}: begin
        mult_in_if.val <= 1;
        mult_in_if.dat[0 +: OUT_BITS+1] <= c3;
        mult_in_if.dat[OUT_BITS+1 +: OUT_BITS+1] <= P;
        state <= WAIT_MULT;
        prev_state <= S2;
      end
      {S2}: begin
        if (c4 >= P_) begin
          c4 <= c4 - P_;
        end else begin
          state <= FINISHED;
          o_dat <= c4;
          o_val <= 1;
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
          endcase
        end
      end
    endcase
  end
end

//To do the multiplications
generate 
  if (MULTIPLIER == "ACCUM_MULT") begin: MULTIPLIER_GEN
    accum_mult # (
      .BITS_A  ( OUT_BITS +8 ),
      .LEVEL_A ( 4           ) // 32 bit multiply
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
    logic [LEVEL-1:0] val;
    
    karatsuba_ofman_mult # (
      .BITS  ( OUT_BITS + 8 ),
      .LEVEL ( LEVEL        )
    )
    karatsuba_ofman_mult (
      .i_clk  ( i_clk                 ),
      .i_dat_a( {7'd0, mult_in_if.dat[0 +: OUT_BITS+1]}),
      .i_dat_b( {7'd0, mult_in_if.dat[OUT_BITS+1 +: OUT_BITS+1]} ),  
      .o_dat  ( mult_out_if.dat       )
    );
    
    always_comb begin
      mult_in_if.rdy = mult_out_if.rdy;
      mult_out_if.val = val[LEVEL-1];
    end
    
    always_ff @ (posedge i_clk) begin
      if (i_rst) begin
        val <= 0;
      end else begin
        val <= {val, mult_in_if.val};
      end  
    end
  end else 
    $fatal(1, "%m ERROR: Unknown multiplier type [%s] in barret_mod.sv", MULTIPLIER);
endgenerate
initial assert (IN_BITS <= MAX_IN_BITS) else $fatal(1, "%m ERROR: IN_BITS[%d] > MAX_IN_BITS[%d] in barret_mod", IN_BITS, MAX_IN_BITS);

endmodule