/*
  This implements the SHA256d hash algorithm (double SHA256).
    
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

module sha256d_top
  import sha256_pkg::*;
(
  input i_clk, i_rst,

  if_axi_stream.sink   i_block,   // Message stream to be hashed, must be 512 bits
  if_axi_stream.source o_hash     // Resulting hash digest (32 bytes)
);

localparam DAT_BYTS = 64;
localparam DAT_BITS = DAT_BYTS*8; // Must be 512

if_axi_stream #(.DAT_BYTS(64)) hash_in_if(i_clk);
if_axi_stream #(.DAT_BYTS(32)) hash_out_if(i_clk);

enum {IDLE = 0,
      SHA0 = 1,
      SHA1 = 2,
      SHA1_WAIT = 3} sha_state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    sha_state <= IDLE;
    o_hash.reset_source();
    hash_in_if.reset_source();
    hash_out_if.rdy <= 0;
  end else begin
    case (sha_state)
      IDLE: begin
        if (i_block.sop && i_block.val && i_block.rdy) begin
          sha_state <= SHA0;
          hash_in_if.copy_if(i_block.to_struct());
        end
      end
      SHA0: begin
        if (~hash_in_if.val || (hash_in_if.val && hash_in_if.rdy)) begin
          hash_in_if.copy_if(i_block.to_struct());
          if (hash_in_if.eop) begin
            sha_state <= SHA1;
          end
        end
      end
      SHA1: begin
        hash_in_if.val <= 0;
        if (hash_out_if.val && hash_out_if.rdy && hash_out_if.sop) begin
          hash_in_if.copy_if(hash_out_if.to_struct());
          sha_state <= SHA1_WAIT;
        end
      end
      SHA1_WAIT: begin
        hash_in_if.val <= 0;
        if (~o_hash.val || (o_hash.val && o_hash.rdy)) begin
          o_hash.copy_if(hash_out_if.to_struct());
          if (o_hash.val && o_hash.rdy)
            sha_state <= IDLE;
        end
      end
    endcase
  end
end

always_comb begin
  i_block.rdy = (sha_state == IDLE || sha_state == SHA0) ? hash_in_if.rdy : 0;
end

// SHA256 block
sha256_top sha256_top (
  .i_clk   ( i_clk   ),
  .i_rst   ( i_rst   ),
  .i_block ( hash_in_if ),
  .o_hash  ( hash_out_if )
);

// Check that input size is correct
initial begin
  assert ($bits(i_block.dat) == DAT_BITS) else $fatal(1, "%m %t ERROR: sha256_top DAT_BITS (%d) does not match interface .dat (%d)", $time, DAT_BITS, $bits(i_block.dat));
end


endmodule