/*
  This decomposes the scalar value required for endomorphsis.
  Requires external multiplier.

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

module secp256k1_point_mult_endo_decom
  import secp256k1_pkg::*;
#(
  parameter MULT_CTL_BIT = 6    // Bit used to control multiplier shift
)(
  input i_clk, i_rst,
  // Input point and value to decompose
  input jb_point_t    i_p,
  input logic [255:0] i_k,
  input logic         i_val,
  output logic        o_rdy,
  // Output point (beta multiplied)
  output jb_point_t    o_p,
  input logic          i_rdy,
  output logic         o_val,
  output logic         o_err,
  // Output values of k decomposed (can be negative)
  output logic signed [255:0] o_k1,
  output logic signed [255:0] o_k2,
  // Interface to 256bit multiplier
  if_axi_stream.source o_mult_if,
  if_axi_stream.sink   i_mult_if
);

/* Equations we calculate for the decomposisiton:
   0. o_p = {(beta*i_p.x) mod p, i_p.y, i_p.z}
   1. c1 = (c1_pre*k)  (scale mod p)
   2. c2 = (c2_pre*k)  (scale mod p)
   3. c1_a1 = (c1*a1) mod p           [eq1]
   4. c2_a2 = (c2*a2) mod p           [eq2]
   5. c1_b1 = (c1*b1_neg) mod p       [eq1]
   6. c2_b2 = (c2*b2) mod p           [eq2]
   7. k1 = k - (c1_a1)                [eq3, eq4]
   8. k1 = k1 - (c2_a2)               [eq7]
   9. k2 = c1_b1 - c2_b2              [eq5, eq6]
 */

logic [9:0] eq_val, eq_wait;
logic [255:0] c1, c2, c1_a1, c2_a2, c2_b2;
enum {IDLE, START, FINISHED} state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_val <= 0;
    o_err <= 0;
    o_rdy <= 0;
    o_k1 <= 0;
    o_k2 <= 0;
    state <= IDLE;
    o_p <= 0;
    o_mult_if.reset_source();
    i_mult_if.rdy <= 0;
    c1 <= 0;
    c2 <= 0;
    c1_a1 <= 0;
    c2_a2 <= 0;
    c2_b2 <= 0;
    eq_val <= 0;
    eq_wait <= 0;
  end else begin

    if (o_mult_if.rdy) o_mult_if.val <= 0;
    o_mult_if.sop <= 1;
    o_mult_if.eop <= 1;
    
    case(state)
      {IDLE}: begin
        o_val <= 0;
        o_err <= 0;
        o_rdy <= 1;
        o_k1 <= i_k;
        o_k2 <= 0;
        o_p <= i_p;
        c1 <= 0;
        c2 <= 0;
        c1_a1 <= 0;
        c2_a2 <= 0;
        c2_b2 <= 0;
        eq_val <= 0;
        eq_wait <= 0;
        if (i_val && o_rdy) begin
          state <= START;
          o_rdy <= 0;
        end
      end
      // Just a big if tree where we issue equations if the required inputs
      // are valid
      {START}: begin

        i_mult_if.rdy <= 1;
        

        
        // Check any results from multiplier
        if (i_mult_if.val && i_mult_if.rdy) begin
          eq_val[i_mult_if.ctl[5:0]] <= 1;
          case(i_mult_if.ctl[5:0]) inside
            0: o_p.x <= i_mult_if.dat;
            1: c1 <= i_mult_if.dat;
            2: c2 <= i_mult_if.dat;
            3: c1_a1 <= i_mult_if.dat;
            4: c2_a2 <= i_mult_if.dat;
            5: o_k2 <= i_mult_if.dat;
            6: c2_b2 <= i_mult_if.dat;
            default: o_err <= 1;
          endcase
        end      
        
        // Issue new multiplies
        if (~eq_wait[0]) begin                            // 0. o_p = {(beta*i_p.x) mod p, i_p.y, i_p.z}
          multiply(0, secp256k1_pkg::beta, o_p.x, 2'd0);
        end else
        if (~eq_wait[1]) begin                            // 1. c1 = (c1_pre*k)  (scale mod p)
          multiply(1, o_k1, secp256k1_pkg::c1_pre, 2'd2);
        end else
        if (~eq_wait[2]) begin                            // 2. c2 = (c2_pre*k)  (scale mod p)
          multiply(2, o_k1, secp256k1_pkg::c2_pre, 2'd2);
        end else    
        if (~eq_wait[3] && eq_val[1]) begin                  // 3. c1_a1 = (c1*a1) mod p           [eq1]
          multiply(3, c1, secp256k1_pkg::a1, 2'd0);
        end else        
        if (~eq_wait[4] && eq_val[2]) begin                  // 4. c2_a2 = (c2*a2) mod p           [eq2]
          multiply(4, c2, secp256k1_pkg::a2, 2'd0);
        end else                
        if (~eq_wait[5] && eq_val[1]) begin                  // 5. c1_b1 = (c1*b1_neg) mod p       [eq1]
          multiply(5, c1, secp256k1_pkg::b1_neg, 2'd0);
        end else               
        if (~eq_wait[6] && eq_val[2]) begin                  // 6. c2_b2 = (c2*b2) mod p           [eq2]
          multiply(6, c2, secp256k1_pkg::b2, 2'd0);
        end     
        
        // Subtractions we do in-module
        if (eq_val[3] && eq_val[4] && ~eq_wait[7]) begin      // 7. k1 = k - (c1_a1)                [eq3, eq4]
          o_k1 <= o_k1 - $signed(c1_a1);
          eq_val[7] <= 1;
          eq_wait[7] <= 1;
        end
        if (eq_val[7] && ~eq_wait[8]) begin                      // 8. k1 = k1 - (c2_a2)               [eq7]
          o_k1 <= o_k1 - $signed(c2_a2);
          eq_val[8] <= 1;
          eq_wait[8] <= 1;
        end 
        if (eq_val[5] && eq_val[6] && ~eq_wait[9]) begin      // 9. k2 = c1_b1 - c2_b2              [eq5, eq6]
          o_k2 <= o_k2 - $signed(c2_b2);
          eq_val[9] <= 1;
          eq_wait[9] <= 1;
        end              
           
        if (&eq_val) begin
          state <= FINISHED;
          o_val <= 1;
        end
      end
      {FINISHED}: begin
        if (o_val && i_rdy) begin
          state <= IDLE;
          o_val <= 0;
          o_rdy <= 1;
        end
      end
    endcase
    
    if (o_err) begin
      o_val <= 1;
      if (o_val && i_rdy) begin
        o_err <= 0;
        state <= IDLE;
      end
    end
    
  end
end

// Task for using multiplies
task multiply(input int unsigned ctl, input logic [255:0] a, b, input logic [1:0] cmd);
  if (~o_mult_if.val || (o_mult_if.val && o_mult_if.rdy)) begin
    o_mult_if.val <= 1;
    o_mult_if.dat[0 +: 256] <= a;
    o_mult_if.dat[256 +: 256] <= b;
    o_mult_if.ctl[5:0] <= ctl;
    o_mult_if.ctl[7:6] <= cmd;
    eq_wait[ctl] <= 1;
  end
endtask

endmodule