/*
  This verifies that a input list stream has no duplicates.

  Implemented using a hash table and FIFOs for flow control.
  
  Input FIFO could be implemented with clock crossing to run at higher frequency.
  
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

module dup_check # (
  parameter IN_BITS,
  parameter LIST_SIZE
) (
  input i_clk, i_rst,

  if_axi_stream.sink   i_axi, // One index per clock cycle - start on .sop and finishes on .eop
  if_axi_stream.source o_axi  // Will give a single clock cycle output with dat = 0 (no duplicates) or 1 (duplicates)
);

logic hash_map_out_rdy, hash_map_out_val, hash_map_out_fnd, hash_map_clr, hash_map_full;
logic sol_index_fifo_if_emp;
if_axi_stream #(.DAT_BITS(IN_BITS), .CTL_BITS(1), .MOD_BITS(1)) sol_index_fifo_if_in(i_clk);
if_axi_stream #(.DAT_BITS(IN_BITS), .CTL_BITS(1), .MOD_BITS(1)) sol_index_fifo_if_out(i_clk);

logic eop_l, fnd_l;

enum {IDLE = 0,
      SEARCH = 1,
      CLEAR = 2} dup_check_state;

always_comb begin
  i_axi.rdy = (dup_check_state != CLEAR) && sol_index_fifo_if_in.rdy && ~eop_l;
  sol_index_fifo_if_out.rdy = hash_map_out_rdy;
  sol_index_fifo_if_in.dat = i_axi.dat;
  sol_index_fifo_if_in.eop = 0;
  sol_index_fifo_if_in.sop = 0;
  sol_index_fifo_if_in.err = 0;
  sol_index_fifo_if_in.ctl = 0;
  sol_index_fifo_if_in.mod = 0;
  sol_index_fifo_if_in.val = i_axi.val;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    dup_check_state <= IDLE;
    hash_map_clr <= 0;
    eop_l <= 0;
    fnd_l <= 0;
    o_axi.reset_source();
  end else begin
    eop_l <= eop_l || (i_axi.val && i_axi.rdy && i_axi.eop);
    fnd_l <= fnd_l || (hash_map_out_val && hash_map_out_fnd);
    
    o_axi.val <= 0;
    o_axi.err <= 0;
    o_axi.sop <= 1;
    o_axi.eop <= 1;
    hash_map_clr <= 0;
    
    case (dup_check_state)
      IDLE: begin
        if (~sol_index_fifo_if_emp && hash_map_out_rdy) begin
          dup_check_state <= SEARCH;
        end
      end
      SEARCH: begin
        
        if (sol_index_fifo_if_emp && eop_l && o_axi.rdy) begin
          dup_check_state <= CLEAR;
          o_axi.val <= 1;
          o_axi.dat <= fnd_l;
          hash_map_clr <= 1;
        end
        
      end
      CLEAR: begin
        eop_l <= 0;
        fnd_l <= 0;
        if (hash_map_out_rdy)
          dup_check_state <= IDLE;
      end
    endcase
    
    if (hash_map_full) begin
      o_axi.err <= 1;
      o_axi.val <= 1;
      hash_map_clr <= 1;
      dup_check_state <= CLEAR;
    end
    
  end
end


axi_stream_fifo #(
  .SIZE     ( LIST_SIZE ),
  .DAT_BITS ( IN_BITS   ),
  .MOD_BITS ( 1          ),
  .CTL_BITS ( 1          ),
  .USE_BRAM ( 1          )
)
index_fifo (
  .i_clk  ( i_clk ),
  .i_rst  ( i_rst ),
  .i_axi  ( sol_index_fifo_if_in  ),
  .o_axi  ( sol_index_fifo_if_out ),
  .o_full ( sol_index_fifo_if_full ),
  .o_emp  ( sol_index_fifo_if_emp )
);
    
// Hash table used to detect duplicate index, fed from FIFO
// Could potentially be run at much higher clock
hash_map #(
  .KEY_BITS      ( IN_BITS     ),
  .DAT_BITS      ( 1           ),
  .HASH_MEM_SIZE ( 2*LIST_SIZE ),
  .LL_MEM_SIZE   ( LIST_SIZE   )
)
hash_map_i (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_key      ( sol_index_fifo_if_out.dat ),
  .i_val      ( sol_index_fifo_if_out.val ),
  .i_dat      ( 1'd1                      ),
  .i_opcode   ( 2'd1                      ),
  .o_rdy      ( hash_map_out_rdy          ),
  .o_dat      (),
  .o_val      ( hash_map_out_val          ),
  .o_fnd      ( hash_map_out_fnd          ),
  .i_cfg_clr  ( hash_map_clr              ),
  .o_cfg_full ( hash_map_full             )  
);
 
endmodule