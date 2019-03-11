/*
  This verifies that a Zcash equihash solution has the correct ordering.
  
  Take input stream of indices which make up a solution, and checks
  left-most leaf nodes at each level are in increasing order.
  
  Code is split up into 3 main always blocks, one for loading RAM, one for parsing
  output and loading the Blake2b block, and the final for running checks.
  
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

module equihash_verif_order
  import equihash_pkg::*;
(
  input i_clk, i_rst,

  if_axi_stream.sink i_axi,
  output logic       o_order_wrong,
  output logic       o_val
);
 

logic [$clog2(SOL_LIST_LEN)-1:0] sol_cnt;
logic [K-1:0] order_check;

logic [K-1:0]               index_val;
logic [K-1:0][SOL_BITS-1:0] index_l;
logic done;
  
// Control for writing memory with indcies as they come in
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    i_axi.rdy <= 0;
    o_order_wrong <= 0;
    o_val <= 0;
    sol_cnt <= 0;
    done <= 0;
    index_l <= 0;
    index_val <= 0;
    order_check <= 0;
  end else begin
    i_axi.rdy <= 1;
    o_val <= 0;
    
    if (i_axi.val && i_axi.rdy) begin
      sol_cnt <= sol_cnt + 1;
      
      // We check if we need to either latch the current value into some level,
      // or need to do a comparison
      for (int i = 0; i < K; i++) begin
        if (sol_cnt % (1 << i) == 0) begin
          if (index_val[i] == 0) begin
            index_l[i] <= i_axi.dat;
            index_val[i] <= 1;
          end else begin
            // If this is greater than or equal then we fail the order check
            if (i_axi.dat <= index_l[i])
              order_check[i] <= order_check[i] || 1;
            index_val[i] <= 0;
          end
        end
      end
      done <= i_axi.eop;
    end
    
    if (done) begin
      done <= 0;
      order_check <= 0;
      index_val <= 0;
      index_l <= 0;
      o_order_wrong <= |order_check;
      o_val <= 1;
      sol_cnt <= 0;
    end
  end
end

endmodule