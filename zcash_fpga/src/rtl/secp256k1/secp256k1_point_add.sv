/*
  This performs point addition.
 
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

module secp256k1_point_add
  import secp256k1_pkg::*;
#(
)(
  input i_clk, i_rst,
  // Input points
  input jb_point_t i_p1,
  input jb_point_t i_p2,
  input logic   i_val,
  output logic  o_rdy,
  // Output point
  output jb_point_t o_p,
  input logic    i_rdy,
  output logic   o_val,
  output logic   o_err,
  // Interface to 256bit multiplier (mod p)
  if_axi_stream.source o_mult_if,
  if_axi_stream.sink   i_mult_if,
  // Interface to only mod reduction block
  if_axi_stream.source o_mod_if,
  if_axi_stream.sink   i_mod_if
);

/*
   These are the equations that need to be computed, they are issued as variables
   become valid. We have a bitmask to track what equation results are valid which
   will trigger other equations. [] show what equations must be valid before this starts.
   We reuse input points (as they are latched) when possible to reduce register usage.
   Taken from https://en.wikibooks.org/wiki/Cryptography/Prime_Curve/Jacobian_Coordinates
 
   U1 = X1*Z2^2
   U2 = X2*Z1^2
   S1 = Y1*Z2^3
   S2 = Y2*Z1^3
   H = U2 - U1
   R = S2 - S1
   X3 = R^2 - H^3 - 2*U1*H^2
   Y3 = R*(U1*H^2 - X3) - S1*H^3
   Z3 = H*Z1*Z2


   0. A = i_p2.z*i_p2.z mod p
   1. i_p1.x = A * i_p1.x mod p [eq0]           ..U1
   2. C = i_p1.z*i_p1.z mod p
   3. i_p2.x = C * i_p2.x mod p [eq2]        ... U2
   4. A = A * i_p2.z mod p [eq1]
   5. A = A * i_p1.y [eq4]         ... S1
   6. C = C * i_p1.z mod p [eq3]
   7. C = C * i_p2.y mod p [eq6]       .. S2
   8. i_p1.y = i_p2.x - i_p1.x mod p [eq3, eq1, eq5]    .. H
   9. i_p2.y = C - A mod p [eq5,eq7]    ... R
   10. o_p.x = i_p2.y * i_p2.y mod p [eq9]   ... R^2
   11. C = i_p1.y * i_p1.y mod p [eq9]         .. H^2
   12. i_p2.x = C * i_p1.y mod p [eq8, eq11]    ..H^3
   13. o_p.x = o_p.x - i_p2.x mod p [eq12, eq10]
   14. i_p1.x = i_p1.x*C  [eq11, eq8]      ..U1*H^2
   15. o_p.y =  i_p1.x  [eq14]
   16. i_p1.x = 2* i_p1.x mod p [eq15, eq14]
   17. o_p.x = o_p.x - i_p1.x [eq16, eq13]
   18. o_p.y = o_p.y - o_p.x mod p [eq17, eq15]
   19. o_p.y = o_p.y * i_p2.y mod p [eq18, eq9]
   20. i_p2.x = i_p2.x * A [eq5, eq12]
   21. o_p.y = o_p.y - i_p2.x [eq20, eq19]
   22. o_p.z = i_p1.z * i_p2.z mod p
   23. o_p.z = o_p.z * i_p1.y mod p [eq22, eq8]
 */ 
 
 // We also check in the inital state if one of the inputs is "None" (.z == 0), and set the output to the other point
logic [23:0] eq_val, eq_wait;

// Temporary variables
logic [255:0] A, C;
jb_point_t i_p1_l, i_p2_l;

always_comb begin
  o_mult_if.sop = 1;
  o_mult_if.eop = 1;
  o_mod_if.sop = 1;
  o_mod_if.eop = 1;
  o_mod_if.err = 1;
  o_mod_if.mod = 0;
  o_mult_if.err = 1;
  o_mult_if.mod = 0;
end

enum {IDLE, START, FINISHED} state;
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_val <= 0;
    o_rdy <= 0;
    o_p <= 0;
    o_mult_if.val <= 0;
    o_mod_if.val <= 0;
    o_mult_if.dat <= 0;
    o_mod_if.dat <= 0;
    i_mult_if.rdy <= 0;
    i_mod_if.rdy <= 0;
    o_mod_if.ctl <= 0;
    o_mult_if.ctl <= 0;
    eq_val <= 0;
    state <= IDLE;
    eq_wait <= 0;
    i_p1_l <= 0;
    i_p2_l <= 0;
    o_err <= 0;
    A <= 0;
    C <= 0;
  end else begin

    if (o_mult_if.rdy) o_mult_if.val <= 0;
    if (o_mod_if.rdy) o_mod_if.val <= 0;
    
    case(state)
      {IDLE}: begin
        o_rdy <= 1;
        eq_val <= 0;
        eq_wait <= 0;
        o_err <= 0;
        i_mult_if.rdy <= 1;
        i_p1_l <= i_p1;
        i_p2_l <= i_p2;
        A <= 0;
        C <= 0;
        if (i_val && o_rdy) begin
          state <= START;
          o_rdy <= 0;
          // If one point is at infinity
          if (i_p1.z == 0 || i_p2.z == 0) begin
            state <= FINISHED;
            o_val <= 1;
            o_p <= (i_p1.z == 0 ? i_p2 : i_p1);
          end else
          // If the points are opposite each other
          if ((i_p1.x == i_p2.x) && (i_p1.y != i_p2.y)) begin
            state <= FINISHED;
            o_val <= 1;
            o_p <= 0; // Return infinity
          end else
          // If the points are the same this module cannot be used
          if ((i_p1.x == i_p2.x) && (i_p1.y == i_p2.y)) begin
            state <= FINISHED;
            o_err <= 1;
            o_val <= 1;
          end
        end
      end
      // Just a big if tree where we issue equations if the required inputs
      // are valid
      {START}: begin
        i_mod_if.rdy <= 1;
        i_mult_if.rdy <= 1;

        // Check any results from modulo
        if (i_mod_if.val && i_mod_if.rdy) begin
          eq_val[i_mod_if.ctl] <= 1;
          case(i_mod_if.ctl)
            16: i_p1_l.x <= i_mod_if.dat;
            default: o_err <= 1;
          endcase
        end
        
        // Check any results from multiplier
        if (i_mult_if.val && i_mult_if.rdy) begin
          eq_val[i_mult_if.ctl] <= 1;
          case(i_mult_if.ctl) inside
            0: A <= i_mult_if.dat;
            1: i_p1_l.x <= i_mult_if.dat;
            2: C <= i_mult_if.dat;
            3: i_p2_l.x <= i_mult_if.dat;
            4: A <= i_mult_if.dat;
            5: A <= i_mult_if.dat;
            6: C <= i_mult_if.dat;
            7: C <= i_mult_if.dat;
            10: o_p.x <= i_mult_if.dat;
            11: C <= i_mult_if.dat;
            12: i_p2_l.x <= i_mult_if.dat;
            14: i_p1_l.x <= i_mult_if.dat;
            19: o_p.y <= i_mult_if.dat;
            20: i_p2_l.x <= i_mult_if.dat;
            22: o_p.z <= i_mult_if.dat;
            23: o_p.z <= i_mult_if.dat;
            default: o_err <= 1;
          endcase
        end      
        
        // Issue new multiplies
        if (~eq_wait[0]) begin                            // 0. A = i_p2.z*i_p2.z mod p
          multiply(0, i_p2_l.z, i_p2_l.z);
        end else
        if (eq_val[0] && ~eq_wait[1]) begin               // 1. i_p1.x = A * i_p1.x mod p [eq0]           ..U1
          multiply(1, A, i_p1_l.x);
        end else
        if (~eq_wait[2]) begin                          // 2. C = i_p1.z*i_p1.z mod p
          multiply(2, i_p1_l.z, i_p1_l.z);
        end else
        if (eq_val[2] && ~eq_wait[3]) begin               // 3. i_p2.x = C * i_p2.x mod p [eq2]        ... U2
          multiply(3, C, i_p2_l.x);
        end else
        if (eq_val[1] && ~eq_wait[4]) begin               //  4. A = A * i_p2.z mod p [eq1]
          multiply(4, A, i_p2_l.z);
        end else
        if (eq_val[4] && ~eq_wait[5]) begin               //  5. A = A * i_p1.y [eq4]         ... S1
          multiply(5, A, i_p1_l.y);
        end else
        if (eq_val[3] && ~eq_wait[6]) begin               //  6. C = C * i_p1.z mod p [eq3]
          multiply(6, C, i_p1_l.z);
        end else
        if (eq_val[6] && ~eq_wait[7]) begin               //  7. C = C * i_p2.y mod p [eq6]       .. S2
          multiply(7, C, i_p2_l.y);
        end else
        if (eq_val[9] && ~eq_wait[10]) begin               //  10. o_p.x = i_p2.y * i_p2.y mod p [eq9]
          multiply(10, i_p2_l.y, i_p2_l.y);
        end else
        if (eq_val[9] && ~eq_wait[11]) begin               //  11. C = i_p1.y * i_p1.y mod p [eq9]         .. H^2
          multiply(11, i_p1_l.y, i_p1_l.y);
        end else
        if (eq_val[11] && eq_val[8] && ~eq_wait[12]) begin      //  12. i_p2.x = C * i_p1.y mod p [eq8, eq11]    ..H^3 
          multiply(12, C, i_p1_l.y);
        end else
        if (eq_val[11] && eq_val[8] && ~eq_wait[14]) begin      //  14. i_p1.x = i_p1.x*C  [eq11, eq8]      ..U1*H^2
          multiply(14, C, i_p1_l.x);
        end else
        if (eq_val[18] && eq_val[9] && ~eq_wait[19]) begin      //  19. o_p.y = o_p.y * i_p2.y mod p [eq18, eq9]
          multiply(19, o_p.y, i_p2_l.y);
        end else
        if (eq_val[5] && eq_val[12] && ~eq_wait[20]) begin      //  20. i_p2.x = i_p2.x * A [eq5, eq12]
          multiply(20, i_p2_l.x, A);
        end else
        if (~eq_wait[22]) begin                               //  22. o_p.z = i_p1.z * i_p2.z mod p
          multiply(22, i_p1_l.z, i_p2_l.z);
        end else
        if (eq_val[8] && eq_val[22] && ~eq_wait[23]) begin       //  23. o_p.z = o_p.z * i_p1.y mod p [eq22, eq8]
          multiply(23, o_p.z, i_p1_l.y);
        end
            
        // Issue new modulo reductions
       if (eq_val[15] && eq_val[14] && ~eq_wait[16]) begin           // 16. i_p1.x = 2* i_p1.x mod p [eq15, eq14]
          modulo(16, 2 * i_p1_l.x);
        end
        
        // Subtractions we do in-module
        if (eq_val[1] && eq_val[3] && eq_val[5] && ~eq_wait[8]) begin                //8. i_p1.y = i_p2.x - i_p1.x mod p [eq3, eq1, eq5]    .. H
          i_p1_l.y <= subtract(8, i_p2_l.x, i_p1_l.x);
        end
        if (eq_val[5] && eq_val[7] && ~eq_wait[9]) begin                              //9. i_p2.y = C - A mod p [eq5,eq7]    ... R
          i_p2_l.y <= subtract(9, C, A);
        end       
        if (eq_val[12] && eq_val[10] && ~eq_wait[13]) begin                          //13. o_p.x = o_p.x - i_p2.x mod p [eq12, eq10]
          o_p.x <= subtract(13, o_p.x, i_p2_l.x);
        end           
        if (eq_val[16] && eq_val[13] && ~eq_wait[17]) begin                          //17. o_p.x = o_p.x - i_p1.x [eq16, eq13]
          o_p.x <= subtract(17, o_p.x, i_p1_l.x);
        end         
        if (eq_val[17] && eq_val[15] && ~eq_wait[18]) begin                          //18. o_p.y = o_p.y - o_p.x mod p [eq17, eq15]
          o_p.y <= subtract(18, o_p.y, o_p.x);
        end      
        if (eq_val[20] && eq_val[19] && ~eq_wait[21]) begin                          //21. o_p.y = o_p.y - i_p2.x [eq20, eq19]
          o_p.y <= subtract(21, o_p.y, i_p2_l.x);
        end     

        // Assignments
        if (eq_val[14] && ~eq_wait[15]) begin                          //15. o_p.y =  i_p1.x  [eq14]
          eq_wait[15] <= 1;
          eq_val[15] <= 1;
          o_p.y <= i_p1_l.x;
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

// Task for subtractions
function logic [255:0] subtract(input int unsigned ctl, input logic [255:0] a, b);
  eq_wait[ctl] <= 1;
  eq_val[ctl] <= 1;
  return (a + (b > a ? secp256k1_pkg::p : 0) - b);
endfunction


// Task for using multiplies
task multiply(input int unsigned ctl, input logic [255:0] a, b);
  if (~o_mult_if.val || (o_mult_if.val && o_mult_if.rdy)) begin
    o_mult_if.val <= 1;
    o_mult_if.dat[0 +: 256] <= a;
    o_mult_if.dat[256 +: 256] <= b;
    o_mult_if.ctl <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for using modulo
task modulo(input int unsigned ctl, input logic [512:0] a);
  if (~o_mod_if.val || (o_mod_if.val && o_mod_if.rdy)) begin
    o_mod_if.val <= 1;
    o_mod_if.dat <= a;
    o_mod_if.ctl <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask


endmodule