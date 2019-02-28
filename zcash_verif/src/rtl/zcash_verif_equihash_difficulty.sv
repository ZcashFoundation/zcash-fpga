/*
  This verifies that a Zcash equihash solution has the correct difficulty.
  
  Take input stream of entire block header (including equihash solution and size) and
  calculate the SHA256d (double SHA256)
  
  We take in the stream in DAT_BYTS in a FIFO, and load the output into 512 bit words
  for the SHA256 block. Then the 256 bit output it inputted into the same SHA256 block.
  
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

module zcash_verif_equihash_difficulty
  import zcash_verif_pkg::*;
#(
  parameter DAT_BYTS = 8,
)(
  input i_clk, i_rst,

  if_axi_stream.sink i_axi,
  input logic [31:0] i_difficulty,      // Must be valid on .sop && .val
  output logic       o_difficulty_fail,
  output logic       o_val
);


logic [$clog2($bits(cblockheader_sol_t)/8)-1:0] byt_cnt;
logic o_fifo_full, o_fifo_emp;
logic [31:0] difficulty;

if_axi_stream #(.DAT_BYTS(DAT_BYTS)) o_fifo(clk);
if_axi_stream #(.DAT_BYTS(64)) i_block(clk);
if_axi_stream #(.DAT_BYTS(32)) o_hash(clk);

enum {IDLE = 0,
      SHA256_0 = 1,
      SHA256_1 = 2,
      FINISHED = 3} state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_difficulty_fail <= 0;
    o_val <= 0;
    byt_cnt <= 0;
    i_block.reset_source();
    o_hash.rdy <= 0;
    o_fifo.rdy <= 0;
    difficulty <= 0;
    state <= IDLE;
  end else begin
    o_val <= 0;
    o_hash.rdy <= 1;
    
    case(state)
      IDLE: begin
        i_block.reset_source();
        o_fifo.rdy <= 0;
        byt_cnt <= 0;
        if (i_axi.rdy && i_axi.val && i_axi.sop) begin
          difficulty <= i_difficulty;
          state <= SHA256_0;
          o_fifo.rdy <= 1;
        end
      end
      // Convert data to 512 bit wide
      SHA256_0: begin
        
        if (o_fifo.rdy && o_fifo.val) begin
          i_block.val <= 0;
          byt_cnt <= byt_cnt + DAT_BYTS;
          i_block.dat[byt_cnt +: DAT_BYTS] <= o_fifo.dat;
        end
        
        if (((byt_cnt + DAT_BYTS) % 64 == 0) ||
            (byt_cnt + DAT_BYTS) == $bits(cblockheader_sol_t)/8) begin
          i_block.val <= 1;
          i_block.sop <= (byt_cnt + DAT_BYTS)/64 == 1;
          i_block.eop <= 0;
          i_block.mod <= (byt_cnt + DAT_BYTS);
          o_fifo.rdy <= i_block.rdy;
          if ((byt_cnt + DAT_BYTS) == $bits(cblockheader_sol_t)/8) begin
            i_block.eop <= 1;
            state <= SHA256_1;
          end
        end else begin
          o_fifo.rdy <= 1;
        end
        
      end
      SHA256_1: begin
        if (i_block.val && i_block.rdy) begin
          i_block.val <= 0;
        end
        
        if (o_hash.val && o_hash.rdy) begin
          i_block.val <= 1;
          i_block.dat <= o_hash.dat;
          i_block.sop <= 1;
          i_block.eop <= 1;
          i_block.mod <= 32;
          state <= FINISHED;
        end
      end
      FINISHED: begin
        if (i_block.val && i_block.rdy) begin
          i_block.val <= 0;
        end
        
        if (o_hash.val && o_hash.rdy) begin
          o_difficulty_fail <= check_difficulty(o_hash.dat, difficulty);
          o_val <= 1;
          state <= IDLE;
        end

      end      
    endcase
    
    if ( o_fifo_full ) begin
      o_difficulty_fail <= 1;
      o_val <= 1;
      o_hash.rdy <= 1;
      o_fifo.rdy <= 1;
      i_block.reset_source();
      if ( o_fifo_emp )
        state <= IDLE;
    end

  end
end

// Function to check if difficulty passes - bits is the number of 0s we
// need
// TODO target function
function check_difficulty(input logic [255:0] hash, logic [31:0] bits);
  check_difficulty = 0;
  for (int i = 0; i < 64; i++)
    if (i > bits && hash[(64-1-i)*8 +: 8] != 0)
      check_difficulty = 1;
endfunction

// FIFO for storing input stream
axi_stream_fifo #(
  .SIZE     ( ($bits(cblockheader_sol_t)/8)/DAT_BYTS ),
  .DAT_BITS ( DAT_BYTS/8                             ),
  .USE_BRAM ( 1                                      )
)
axi_stream_fifo (
  .i_clk  ( i_clk       ),
  .i_rst  ( i_rst       ),
  .i_axi  ( i_axi       ),
  .o_axi  ( o_fifo      ),
  .o_full ( o_fifo_full ),
  .o_emp  ( o_fifo_emp  )
);

// SHA256 block
sha256_top sha256_top (
  .i_clk   ( i_clk   ),
  .i_rst   ( i_rst   ),
  .i_block ( i_block ),
  .o_hash  ( o_hash  )
);

endmodule