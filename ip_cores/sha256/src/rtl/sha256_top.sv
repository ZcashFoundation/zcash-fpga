/*
  This is an implementation of the SHA256 hash algorithm.
  
  Takes an AXI stream 512 bit interface. We back pressure the input
  if the message size is > 512 bits while we process the 64 rounds.
    
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

module sha256_top
  import sha256_pkg::*;
(
  input i_clk, i_rst,

  if_axi_stream.sink   i_block,   // Message stream to be hashed, must be 512 bits
  if_axi_stream.source o_hash     // Resulting hash digest (32 bytes)
);

localparam DAT_BYTS = 64;
localparam DAT_BITS = DAT_BYTS*8; // Must be 512
localparam ROUNDS = 64;

logic [7:0][0:31]               V, H;  // Internal states, V[0] == A, V[7] == H (in big endian)
logic [0:31]                    T1, T2;
logic [15:0][0:31]              W;
logic [0:31]                    W_nxt;
logic                           padding_only, final_block;
logic [63:0]                    bit_len;
logic [$clog2(ROUNDS)-1:0]      rnd_cntr;
logic [1:0][0:31]               bit_len_c;
      
enum {SHA_IDLE = 0,
      SHA_ROUNDS = 1,
      SHA_UPDATE_HV = 2,
      SHA_FINAL = 3} sha_state;

// Used to make compression function easier to read
localparam VAR_A = 0;
localparam VAR_B = 1;
localparam VAR_C = 2;
localparam VAR_D = 3;
localparam VAR_E = 4;
localparam VAR_F = 5;
localparam VAR_G = 6;
localparam VAR_H = 7;


always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    sha_state <= SHA_IDLE;
    rnd_cntr <= 0;
    o_hash.reset_source();
    i_block.rdy <= 0;
    bit_len <= 0;
    W <= 0;
    padding_only <= 0;
    final_block <= 0;
  end else begin
    o_hash.sop <= 1;
    o_hash.eop <= 1;
    case(sha_state)
      SHA_IDLE: begin
        update_HV(1);
        rnd_cntr <= 0;
        final_block <= 0;
        padding_only <= 0;
        i_block.rdy <= 1;
        // As soon as we have one write on the input we can start
        if (i_block.rdy && i_block.val && i_block.sop) begin
          for (int i = 0; i < 16; i++)
            W[i] <= sha256_pkg::bs32(i_block.dat[i*32 +: 32]);
          bit_len <= DAT_BITS;
          i_block.rdy <= 0;
          if (i_block.eop)
            msg_eop();
          sha_state <= SHA_ROUNDS;
        end
      end
      SHA_ROUNDS: begin
        for (int i = 0; i < 15; i++)
          W[i] <= W[i+1];
        W[15] <= W_nxt;
        compress();
        rnd_cntr <= rnd_cntr + 1;
        if (rnd_cntr == ROUNDS - 1) begin
          rnd_cntr <= 0;
          i_block.rdy <= ~(final_block || padding_only);
          sha_state <= SHA_UPDATE_HV;
        end
      end
      SHA_UPDATE_HV: begin
        if (final_block) begin
          update_HV(0);
          sha_state <= SHA_FINAL;
          i_block.rdy <= 0;
        end else if (padding_only) begin
          update_HV(0);
          final_block <= 1;
          W <= 0;
          W[15:14] <= {bit_len_c[0], bit_len_c[1]};
          if (bit_len % 512 == 0)
            W[0] <= sha256_pkg::bs32(32'd1);
          sha_state <= SHA_ROUNDS;
        end else if (i_block.rdy && i_block.val) begin
          update_HV(0);
          for (int i = 0; i < 16; i++)
            W[i] <= sha256_pkg::bs32(i_block.dat[i*32 +: 32]);
          bit_len <= bit_len + DAT_BITS;
          if (i_block.eop) begin
            msg_eop();
          end
          i_block.rdy <= 0;
          sha_state <= SHA_ROUNDS;
        end
      end
      SHA_FINAL: begin
        o_hash.val <= 1;
        for (int i = 0; i < 8; i++)
          o_hash.dat[i*32 +: 32] <= sha256_pkg::bs32(H[i]); // Shift back to little endian
        if (o_hash.val && o_hash.rdy) begin
          o_hash.val <= 0;
          rnd_cntr <= 0;
          bit_len <= 0;
          W <= 0;
          padding_only <= 0;
          final_block <= 0;
          sha_state <= SHA_IDLE;
        end
      end
    endcase
  end
end

// On the msg .eop we need to make sure we add padding if there is space other
// wise set a flag so next time we call we only add the padding block
task msg_eop();

  bit_len <= bit_len + (i_block.mod == 0 ? DAT_BITS : i_block.mod*8);
  if (i_block.mod == 0 || i_block.mod > 64-9) begin
    padding_only <= 1; // Means we need one block extra with only len (and possibly the terminating 0x1)
  end else begin
    final_block <= 1; // This is the final block and includes padding
  end
  
  // Every 32 bit word needs to be swapped to big endian
  for (int i = 0; i < 16; i++)
    W[i] <= (i_block.mod == 0 || i < i_block.mod) ? sha256_pkg::bs32(i_block.dat[i*32 +: 32]) : 0;
  
  if (i_block.mod != 0)
    W[i_block.mod/4][8*(i_block.mod % 4) +: 8] <= 8'h80; // Since we operate in big endian
 
  if (i_block.mod < 64-9)
    W[15:14] <= {bit_len_c[0], bit_len_c[1]};
  
endtask

always_comb begin
  bit_len_c = (bit_len + i_block.mod*8);

  W_nxt = sha256_pkg::little_sig1(W[14]) + 
          W[9] + 
          sha256_pkg::little_sig0(W[1]) + 
          W[0];
          
  T1 = V[VAR_H] +
       sha256_pkg::big_sig1(V[VAR_E]) +
       sha256_pkg::ch(V[VAR_E], V[VAR_F], V[VAR_G]) +
       sha256_pkg::K[rnd_cntr] + 
       W[0];
       
  T2 = sha256_pkg::big_sig0(V[VAR_A]) +
       sha256_pkg::maj(V[VAR_A], V[VAR_B], V[VAR_C]);
end

task compress();
  V[VAR_H] <= V[VAR_G];
  V[VAR_G] <= V[VAR_F];
  V[VAR_F] <= V[VAR_E];
  V[VAR_E] <= V[VAR_D] + T1;
  V[VAR_D] <= V[VAR_C];
  V[VAR_C] <= V[VAR_B];
  V[VAR_B] <= V[VAR_A];
  V[VAR_A] <= T1 + T2;
endtask

task update_HV(input logic init);
  if (init) begin
    for (int i = 0; i < 8; i++) begin
      H[i] <= (sha256_pkg::IV[i]);
      V[i] <= (sha256_pkg::IV[i]);
    end
  end else begin
    for (int i = 0; i < 8; i++) begin
      H[i] <= H[i] + V[i];
      V[i] <= H[i] + V[i];
    end
  end  
endtask

  // Check that input size is correct
  initial begin
    assert ($bits(i_block.dat) == DAT_BITS) else $fatal(1, "%m %t ERROR: sha256_top DAT_BITS (%d) does not match interface .dat (%d)", $time, DAT_BITS, $bits(i_block.dat));
  end


endmodule