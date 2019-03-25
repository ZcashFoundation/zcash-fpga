/*
  This performs point doubling.
 
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

module secp256k1_point_dbl
  import secp256k1_pkg::*;
#(
)(
  input i_clk, i_rst,
  // Input point
  input jb_point_t i_p,
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
 * 
 * 0.    A = (i_p.y)^2 mod p
 * 1.    B = (i_p.x)*A mod p [eq0]
 * 2.    B = 4*B mod p [eq1]
 * 3.    C = A^2 mod p [eq0]
 * 4.    C = C*8 mod p [eq3]
 * 5.    D = (i_p.x)^2 mod p
 * 6.    D = 3*D mod p [eq5]
 * 7.   (o_p.x) = D^2 mod p[eq6]
 * 8.    E = 2*B mod p [eq2]
 * 9.   (o_p.x) = o_p.x - E mod p [eq8, eq7]
 * 10   (o_p.y) =  B - o_p.x mod p [eq9, eq2]
 * 11.   (o_p.y) = D*(o_p.y) [eq10, eq6]
 * 12.   (o_p.y) = (o_p.y) - C mod p [eq11, eq4]
 * 13.   (o_p.z) = 2*(i_p.y) mod p
 * 14.   (o_p.z) = o_p.y * i_p.z mod p [eq14]
 */
logic [14:0] eq_val, eq_wait;

// Temporary variables
logic [255:0] A, B, C, D, E;
jb_point_t i_p_l;

always_comb begin
  o_mult_if.sop = 1;
  o_mult_if.eop = 1;
  o_mod_if.sop = 1;
  o_mod_if.eop = 1;
  o_mod_if.err = 0;
  o_mod_if.mod = 0;
  o_mult_if.err = 0;
  o_mult_if.mod = 0;
end

enum {IDLE, START, FINISHED} state;
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_val <= 0;
    o_rdy <= 0;
    o_p <= 0;
    o_mult_if.val <= 0;
    o_mult_if.ctl <= 0;
    o_mod_if.val <= 0;
    o_mod_if.ctl <= 0;
    o_mult_if.dat <= 0;
    o_mod_if.dat <= 0;
    i_mult_if.rdy <= 0;
    i_mod_if.rdy <= 0;
    eq_val <= 0;
    state <= IDLE;
    eq_wait <= 0;
    i_p_l <= 0;
    o_err <= 0;
    A <= 0;
    B <= 0;
    C <= 0;
    D <= 0;
    E <= 0;
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
        i_p_l <= i_p;
        A <= 0;
        B <= 0;
        C <= 0;
        D <= 0;
        E <= 0;
        o_val <= 0;
        if (i_val && o_rdy) begin
          state <= START;
          o_rdy <= 0;
          if (i_p.z == 0) begin
            o_p <= i_p;
            o_val <= 1;
            state <= FINISHED;
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
            2: B <= i_mod_if.dat;
            4: C <= i_mod_if.dat;
            8: E <= i_mod_if.dat;
            13: o_p.z <= i_mod_if.dat;
            default: o_err <= 1;
          endcase
        end
        
        // Check any results from multiplier
        if (i_mult_if.val && i_mult_if.rdy) begin
          eq_val[i_mult_if.ctl] <= 1;
          case(i_mult_if.ctl) inside
            0: A <= i_mult_if.dat;
            1: B <= i_mult_if.dat;
            3: C <= i_mult_if.dat;
            5: D <= i_mult_if.dat;
            6: D <= i_mult_if.dat;
            7: o_p.x <= i_mult_if.dat;
            11: o_p.y <= i_mult_if.dat;
            14: o_p.z <= i_mult_if.dat;
            default: o_err <= 1;
          endcase
        end      
         
        
        // Issue new multiplies
        if (~eq_wait[0]) begin              //0.    A = (i_p.y)^2 mod p
          multiply(0, i_p_l.y, i_p_l.y);
        end else
        if (eq_val[0] && ~eq_wait[1]) begin //1.    B = (i_p.x)*A mod p [eq0]
          multiply(1, i_p_l.x, A);
        end else
        if (eq_val[0] && ~eq_wait[3]) begin //3.    C = A^2 mod p [eq0]
          multiply(3, A, A);
        end else
        if (~eq_wait[5]) begin              //5.    D = (i_p.x)^2 mod p
          multiply(5, i_p_l.x, i_p_l.x);
        end else
        if (eq_val[5] && ~eq_wait[6]) begin //6.    D = 3*D mod p [eq5]
          multiply(6, 256'd3, D);
        end else
        if (eq_val[6] && ~eq_wait[7]) begin //7.   (o_p.x) = D^2 mod p[eq6]
          multiply(7, D, D);
        end else
        if (eq_val[10] && eq_val[6] && ~eq_wait[11]) begin //11.   (o_p.y) = D*(o_p.y) [eq10, eq6]
          multiply(11, D, o_p.y);
        end else
        if (eq_val[13] && ~eq_wait[14]) begin //14.   (o_p.z) = o_p.z * i_p.z mod p [eq13]
          multiply(14, i_p_l.z, o_p.z);
        end
                
        // Issue new modulo reductions
        if (eq_val[1] && ~eq_wait[2]) begin //2.    B = 4*B mod p [eq1]
          modulo(2, B*4);
        end else
        if (eq_val[3] && ~eq_wait[4]) begin //4.    C = C*8 mod p [eq3]
          modulo(4, C*8);
        end else
        if (eq_val[2] && ~eq_wait[8]) begin //8.    E = 2*B mod p [eq2]
          modulo(8, B*2);
        end else
        if (~eq_wait[13]) begin            //13.   (o_p.z) = 2*(i_p.y) mod p
          modulo(13, 2*i_p_l.y);
        end
        
        // Additions / subtractions we do in-module
        if (eq_val[8] && eq_val[7] && ~eq_wait[9]) begin //9.   (o_p.x) = o_p.x - E mod p [eq8, eq7]
          o_p.x <= subtract(9, o_p.x, E); 
        end
        
        if (eq_val[9] && eq_val[2] && ~eq_wait[10]) begin //10.   (o_p.y) =  B - o_p.x mod p [eq9, eq2]
          eq_wait[10] <= 1;
          eq_val[10] <= 1;
          o_p.y <= subtract(10, B, o_p.x); 
        end
        
        
        if (eq_val[4] && eq_val[11] && ~eq_wait[12]) begin //12.   (o_p.y) = (o_p.y) - C mod p [eq11, eq4]
          o_p.y <= subtract(12, o_p.y ,C);
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