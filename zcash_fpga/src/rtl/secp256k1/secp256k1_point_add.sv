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
  if_axi_stream.source i_mult_if,
  // Interface to only mod reduction block
  if_axi_stream.source o_mod_if,
  if_axi_stream.source i_mod_if
);

/*
 * These are the equations that need to be computed, they are issued as variables
 * become valid. We have a bitmask to track what equation results are valid which
 * will trigger other equations. [] show what equations must be valid before this starts.
 * We reuse input points (as they are latched) when possible to reduce register usage.
 * 
 * 0. A = i_p1.y - i_p2.y mod p
 * 1. B = i_p1.x - i_p2.x mod p 
 * 2. o_p.z = B * i_p1.z mod p [eq1]
 * 3. i_p1.z = B * B mod p [eq2]
 * 4. i_p2.x = A * A mod p [eq0, eq5]
 * 5. o_p.x = i_p1.x + i_p2.x mod p
 * 6. o_p.x = o_p.x * i_p1.z mod p [eq5, eq3]
 * 7. o_p.x = i_p2.x - o_p.x mod p[eq6, eq4]
 * 8. o_p.y = i_p1.x*i_p1.z mod p [eq3]
 * 9. o_p.y = o_p.y - o_p.x mod p [eq3, eq7, eq8]
 * 10. o_p.y = o_p.y * A mod p [eq0, eq9]
 * 11. i_p2.y = B * i_p1.z mod p [eq1, eq3, eq0]
 * 12. i_p2.y = i_p2.y * i_p1.y [eq11]
 * 13. o_p.y = o_p.y - i_p2.y mod p [eq12, eq10]
 */
 
 // We also check in the inital state if one of the inputs is "None" (.z == 0), and set the output to the other point
logic [13:0] eq_val, eq_wait;

// Temporary variables
logic [255:0] A, B;
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
    eq_val <= 0;
    state <= IDLE;
    eq_wait <= 0;
    i_p1_l <= 0;
    i_p2_l <= 0;
    o_err <= 0;
    A <= 0;
    B <= 0;
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
        B <= 0;
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

        // Check any results from multiplier
        if (i_mod_if.val && i_mod_if.rdy) begin
          eq_val[i_mod_if.ctl] <= 1;
          case(i_mod_if.ctl)
            5: o_p.x <= i_mod_if.dat;
            default: o_err <= 1;
          endcase
        end
        
        // Check any results from multiplier
        if (i_mult_if.val && i_mult_if.rdy) begin
          eq_val[i_mult_if.ctl] <= 1;
          case(i_mult_if.ctl) inside
            2: o_p.z <= i_mult_if.dat;
            3: i_p1_l.z <= i_mult_if.dat;
            4: i_p2_l.x  <= i_mult_if.dat;
            6: o_p.x <= i_mult_if.dat;
            8: o_p.y <= i_mult_if.dat;
            10: o_p.y <= i_mult_if.dat;
            11: i_p1_l.y <= i_mult_if.dat;
            12: i_p2_l.y <= i_mult_if.dat;
            default: o_err <= 1;
          endcase
        end      
        
        // Issue new multiplies
        if (eq_val[1] && ~eq_wait[2]) begin               // 2. o_p.z = B * i_p1.z mod p [eq1]
          multiply(2, B, i_p1_l.z);
        end else
        if (eq_val[2] && ~eq_wait[3]) begin               // 3. i_p1.z = B * B mod p [eq2]
          multiply(3, B, B);
        end else
        if (eq_val[0] && eq_val[5] && ~eq_wait[4]) begin  // 4. i_p2.x = A * A mod p [eq0, eq5]
          multiply(4, A, A);
        end else
        if (eq_val[3] && eq_val[5] && ~eq_wait[6]) begin  // 6. o_p.x = o_p.x * i_p1.z mod p [eq5, eq3]
          multiply(6, o_p.x, i_p1_l.z);
        end else
        if (eq_val[3] && ~eq_wait[8]) begin               // 8. o_p.y = i_p1.x*i_p1.z mod p [eq3]
          multiply(8, i_p1_l.x, i_p1_l.z);
        end else
        if (eq_val[0] && eq_val[9] && ~eq_wait[10]) begin               // 10. o_p.y = o_p.y * A mod p [eq0, eq9]
          multiply(10, o_p.y, A);
        end else
        if (eq_val[0] && eq_val[1] && eq_val[3] && ~eq_wait[11]) begin   // 11. i_p2.y = B * i_p1.z mod p [eq1, eq3, eq0]
          multiply(11, B, i_p1_l.z);
        end else
        if (eq_val[11] && ~eq_wait[12]) begin   // 12. i_p2.y = i_p2.y * i_p1.y [eq11]
          multiply(12, i_p1_l.y, i_p2_l.y);
        end
                
        // Issue new modulo reductions
        if (~eq_wait[5]) begin           // 5. o_p.x = i_p1.x + i_p2.x mod p
          modulo(5, i_p1.x + i_p2.x);
        end
        
        // Subtractions we do in-module
        if (~eq_wait[0]) begin                              //0. A = i_p1.y - i_p2.y mod p
          A <= subtract(0, i_p1_l.y, i_p2_l.y);
        end
        if (~eq_wait[1]) begin                              //1. B = i_p1.x - i_p2.x mod p 
          B <= subtract(1, i_p1_l.x, i_p2_l.x);
        end
        if (~eq_wait[7] && eq_val[6] && eq_val[4]) begin    //7. o_p.x = i_p2.x - o_p.x mod p[eq6, eq4]
          o_p.x <= subtract(7, i_p2_l.x, o_p.x);
        end
        if (~eq_wait[9] && eq_val[3] && eq_val[7] && eq_val[8]) begin    //9. o_p.y = o_p.y - o_p.x mod p [eq3, eq7, eq8]
          o_p.y <= subtract(9, o_p.y, o_p.x);
        end        
        if (~eq_wait[13] && eq_val[12] && eq_val[10]) begin    //13. o_p.y = o_p.y - i_p2.y mod p [eq12, eq10]
          o_p.y <= subtract(13, o_p.y, i_p2_l.y);
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