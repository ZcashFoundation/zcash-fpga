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

logic [7:0][31:0]               V;  // Internal state, V[0] == A, V[7] == H
logic [31:0]                    T1, T2;
logic [15:0][31:0]              W;
logic [15:0]                    W_nxt;
logic                           eop_l, padding_only, final_block;
logic [63:0]                    bit_len;
logic [$clog2(64)-1:0]          rnd_cntr;
      
enum {SHA_IDLE = 0,
      SHA_ROUNDS = 1,
      SHA_UPDATE_HV = 2,
      SHA_FINAL = 3} sha_state;

// Used to make compression function easier to read
localparam A = 0;
localparam B = 1;
localparam C = 2;
localparam D = 3;
localparam E = 4;
localparam F = 5;
localparam G = 6;
localparam H = 7;


always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    sha_state <= SHA_IDLE;
    rnd_cntr <= 0;
    o_hash.reset_source();
    i_block.rdy <= 0;
    bit_len <= 0;
    W <= 0;
    eop_l <= 0;
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
        eop_l <= 0;
        padding_only <= 0;
        i_block.rdy <= 1;
        // As soon as we have one write on the input we can start
        if (i_block.rdy && i_block.val && i_block.sop) begin
          W <= i_block.dat;
          bit_len <= DAT_BITS;
          i_block.rdy <= 0;
          if (i_block.eop)
            msg_eop();
          sha_state <= SHA_ROUNDS;
        end
      end
      SHA_ROUNDS: begin
        for (int i = 0; i < 16; i++) W[i] <= W[i+i];
        W[15] <= W_nxt;
        compress();
        rnd_cntr <= rnd_cntr + 1;
        if (rnd_cntr == 62) begin
          rnd_cntr <= 0;
          i_block.rdy <= ~(final_block || padding_only);
          sha_state <= SHA_UPDATE_HV;
        end
      end
      SHA_UPDATE_HV: begin
        update_H(0);
        if (final_block) begin
          sha_state <= SHA_FINAL;
          i_block.rdy <= 0;
        end else if (padding_only) begin
          final_block <= 1;
          W <= 0;
          W[(64-8)*8 +: 64] <= bit_len;
          W[(bit_len/8) % 64 +: 8] <= 1;
        end else if (i_block.rdy && i_block.val) begin
          W <= i_block.dat;
          bit_len <= bit_len + DAT_BITS;
          if (i_block.eop) begin
            msg_eop();
            i_block.rdy <= 0;
          end
          sha_state <= SHA_ROUNDS;
        end
      end
      SHA_FINAL: begin
        o_hash.val <= 1;
        o_hash.dat <= H;
        if (o_hash.val && o_hash.rdy) begin
          o_hash.val <= 0;
          sha_state <= SHA_IDLE;
        end
      end
    endcase
  end
end

// On the msg .eop we need to make sure we add padding if there is space other
// wise set a flag so next time we call we only add the padding block
task msg_eop();

  eop_l <= 1;
  bit_len <= bit_len + (i_block.mod == 0 ? DAT_BITS : i_block.mod*8);
  if (i_block.mod == 0 || i_block.mod > 64-9) begin
    padding_only <= 1; // Means we need one block extra with only len (and possibly the terminating 0x1)
  end else begin
    final_block <= 1; // This is the final block and includes padding
  end
  
  for (int i = 0; i < 64; i++)
    M[i*8 +: 8] <= (i_block.mod == 0 || i < i_block.mod) ? i_block.dat[i*8 +: 8] : 0;
  
  if (i_block.mod != 0)
    M[i_block.mod*8 +: 8] <= 1;
 
  if (i_block.mod < 64-9)
    M[(64-8)*8 +: 64] <= bit_len + i_block.mod*8;
  
endtask

always_comb begin
  W_nxt = little_sig1(W[14]) + W[9] + little_sig0(W[1]) + W[0];
end
always_comb begin
  T1 = V[H] + big_sig1(V[E]) + ch(V[E], V[F], V[G]) + sha256_pkg::K[rnd_cntr] + W[0];
  T2 = big_sig0(V[A]) + maj(V[A], V[B], V[C]);
end

task compress();
  V[H] <= V[G];
  V[G] <= V[F];
  V[F] <= V[E];
  V[E] <= V[D] + T1;
  V[D] <= V[C];
  V[C] <= V[B];
  V[B] <= V[A];
  V[A] <= T1 + T2;
endtask

task update_HV(logic init);
  if (init) begin
    for (int i = 0; i < 8; i++) begin
      H[i] <= sha256_pkg::IV[i];
      V[i] <= sha256_pkg::IV[i];
    end
  end else begin
    for (int i = 0; i < 8; i++) begin
      H[i] <= H[i] + V[i];
      V[i] <= H[i] + V[i];
    end
  end  
endtask

function [31:0] litte_sig0(input logic [31:0] in);
  litte_sig0 = {rotr(in, 7)} ^ {rotr(in, 18)} ^ {shr(in, 3)};  
endfunction

function [31:0] litte_sig1(input logic [31:0] in);
  litte_sig1 = {rotr(in, 17)} ^ {rotr(in, 19)} ^ {shr(in, 10)};  
endfunction

function [31:0] big_sig0(input logic [31:0] in);
  big_sig0 = {rotr(in, 2)} ^ {rotr(in, 13)} ^ {rotr(in, 22)};  
endfunction

function [31:0] big_sig1(input logic [31:0] in);
  big_sig1 = {rotr(in, 6)} ^ {rotr(in, 11)} ^ {rotr(in, 25)};  
endfunction

function [31:0] ch(input logic [31:0] x, y, z);
  ch = (x & y) ^ (~x & z);  
endfunction

function [31:0] maj(input logic [31:0] x, y, z);
  maj = (x & y) ^ (x & z) ^ (y & z);
endfunction

function [31:0] rotr(input logic [31:0] in, input int bits);
  for (int i = 0; i < 32; i++) rotr[i] = in[(i+bits) % 32];
endfunction

function [31:0] shr(input logic [31:0] in, input int bits);
  shr = 0; 
  shr = in >> bits;
endfunction


endmodule