/*
  This verifies that a Zcash equihash solution is correct,
  input is an axi stream of the block header. This block checks:
    1. XOR of EquihashGen() is 0
    2. Ordering
    3. No duplicates
    4. Difficulty passes
  
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

module zcash_verif_equihash
  import zcash_verif_pkg::*;
#(
  parameter DAT_BYTS = 8,
  parameter CHECK_UNIQUE_INDEX = 1
)(
  input i_clk, i_rst,

  if_axi_stream.sink   i_axi,
  output equihash_bm_t o_mask,
  output logic         o_mask_val
);
 
localparam [7:0] EQUIHASH_GEN_BYTS = $bits(equihash_gen_in_t)/8;
localparam       DAT_BITS = DAT_BYTS*8;

cblockheader_t                              cblockheader;
logic                                       cblockheader_val;
logic [$clog2($bits(cblockheader_t)/8)-1:0] cblockheader_byts;

equihash_gen_in_t                equihash_gen_in;
logic [N-1:0]                    sol_hash_xor, equihash_sol_string, equihash_sol_string_flip;
logic [$clog2(SOL_LIST_LEN)-1:0] sol_cnt_out, sol_cnt_in; // This tracks how many solutions we have XORed
logic [$clog2(2*DAT_BITS)-1:0]   sol_pos;                 // This tracks the pos in our DAT_BITS RAM output
logic [64*8-1:0]                 parameters;

if_axi_stream #(.DAT_BYTS(BLAKE2B_DIGEST_BYTS), .CTL_BYTS($clog2(INDICIES_PER_HASH))) blake2b_out_hash(i_clk);
if_axi_stream #(.DAT_BYTS(EQUIHASH_GEN_BYTS),   .CTL_BYTS($clog2(INDICIES_PER_HASH))) blake2b_in_hash(i_clk);

// We write the block into a port as it comes in and then read from the b port
localparam EQUIHASH_SOL_BRAM_DEPTH = 1 + SOL_LIST_BYTS/DAT_BYTS;
localparam EQUIHASH_SOL_BRAM_WIDTH = DAT_BITS;
if_ram #(.RAM_WIDTH(EQUIHASH_SOL_BRAM_WIDTH), .RAM_DEPTH(EQUIHASH_SOL_BRAM_DEPTH)) equihash_sol_bram_if_a (i_clk, i_rst);
if_ram #(.RAM_WIDTH(EQUIHASH_SOL_BRAM_WIDTH), .RAM_DEPTH(EQUIHASH_SOL_BRAM_DEPTH)) equihash_sol_bram_if_b (i_clk, i_rst);

logic [DAT_BITS-1:0]   equihash_sol_bram_if_b_l;
logic [2*DAT_BITS-1:0] equihash_sol_bram_if_b_l_comb, equihash_sol_bram_if_b_l_comb_flip;
logic [SOL_BITS-1:0]   equihash_sol_index;
logic [1:0]            equihash_sol_bram_read;

logic dup_chk_done, order_chk_done;

if_axi_stream #(.DAT_BITS(SOL_BITS), .CTL_BITS(1), .MOD_BITS(1)) dup_check_if_in(i_clk);
if_axi_stream #(.DAT_BITS(1), .CTL_BITS(1), .MOD_BITS(1)) dup_check_if_out(i_clk);

if_axi_stream #(.DAT_BITS(SOL_BITS), .MOD_BITS(1),  .CTL_BITS(1)) equihash_order_if(i_clk);
logic equihash_order_val, equihash_order_wrong;

   

enum {STATE_WR_IDLE = 0,
      STATE_WR_DATA = 1,
      STATE_WR_WAIT = 2} ram_wr_state;
      
enum {STATE_RD_IDLE = 0,
      STATE_RD_DATA = 1,
      STATE_RD_WAIT = 2} ram_rd_state;
      
enum {STATE_CHK_IDLE = 0,
      STATE_CHK_DATA = 1,
      STATE_CHK_WAIT = 2,
      STATE_CHK_DONE = 3} chk_state;      

// State machine for controlling writing equihash solution into the RAM and registering the header
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    i_axi.rdy <= 0;
    equihash_sol_bram_if_a.reset_source();
    cblockheader <= 0;
    cblockheader_byts <= 0;
    cblockheader_val <= 0;
    ram_wr_state <= STATE_WR_IDLE;
  end else begin
    // Defaults
    equihash_sol_bram_if_a.we <= 1;
    equihash_sol_bram_if_a.en <= 1;
    equihash_sol_bram_if_a.d <= i_axi.dat;

    if (i_axi.val && i_axi.rdy && ~cblockheader_val) begin
      cblockheader[cblockheader_byts*8 +: DAT_BITS] <= i_axi.dat;
      cblockheader_val <= (cblockheader_byts + DAT_BYTS) > $bits(cblockheader_t)/8;
      cblockheader_byts <= cblockheader_byts + DAT_BYTS;
    end

    case (ram_wr_state)
      // This state we are waiting for an input block
      STATE_WR_IDLE: begin
        i_axi.rdy <= (dup_check_if_in.rdy && equihash_order_if.rdy);
        if (i_axi.val && i_axi.rdy) begin
          ram_wr_state <= STATE_WR_DATA;
          equihash_sol_bram_if_a.a <= 0;
        end
      end
      // Here we are checking header values as well as populating the RAM
      STATE_WR_DATA: begin
        if (i_axi.val && i_axi.rdy) begin
          // Only write the solution list to memory
          if (cblockheader_val)
            equihash_sol_bram_if_a.a <= equihash_sol_bram_if_a.a + 1;
          if (i_axi.eop) begin
            i_axi.rdy <= 0;
            ram_wr_state <= STATE_WR_WAIT;
          end
        end
      end
      // Here we are have finished populating RAM and waiting for all checks to finish
      STATE_WR_WAIT: begin
        equihash_sol_bram_if_a.we <= 0;
        equihash_sol_bram_if_a.a <= equihash_sol_bram_if_a.a;
        if (chk_state == STATE_CHK_DONE) begin
          ram_wr_state <= STATE_WR_IDLE;
          cblockheader_val <= 0;
          equihash_sol_bram_if_a.a <= 0;          
        end
      end
    endcase
  end
end

// State machine for loading the output of RAM into the Blake2b block
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    blake2b_in_hash.reset_source();
    equihash_sol_bram_if_b.reset_source();
    sol_cnt_in <= 0;
    sol_pos <= 0;
    equihash_sol_bram_if_b_l <= 0;
    equihash_gen_in <= 0;
    equihash_sol_bram_read <= 0;
    dup_check_if_in.reset_source();
    equihash_order_if.reset_source();
    
    ram_rd_state <= STATE_RD_IDLE;
  end else begin
    // Defaults
    equihash_sol_bram_if_b.re <= 1;
    equihash_sol_bram_if_b.en <= 1;
    blake2b_in_hash.sop <= 1;
    blake2b_in_hash.eop <= 1;
    blake2b_in_hash.val <= 0;
    
    dup_check_if_in.val <= 0;
    equihash_order_if.val <= 0;
    
    equihash_sol_bram_read <= equihash_sol_bram_read << 1;
    if (equihash_sol_bram_read[0])
      equihash_sol_bram_if_b_l <= equihash_sol_bram_if_b.q;
    
    case(ram_rd_state)
      STATE_RD_IDLE: begin
        if (~|equihash_sol_bram_read)
          equihash_sol_bram_if_b.a <= 0;
        sol_pos <= 3*8 + ($bits(cblockheader_t) % DAT_BITS); // Add on 3*8 as this encodes the size of solution

        sol_cnt_in <= 0;
        blake2b_in_hash.val <= 0;
        
        // First case has special state
        if ( equihash_sol_bram_if_a.a*DAT_BYTS >= ($bits(cblockheader_t)/8) + (DAT_BYTS*2)) begin
          if (~|equihash_sol_bram_read) begin
            equihash_sol_bram_if_b.a <= equihash_sol_bram_if_b.a + 1;
            equihash_sol_bram_read[0] <= 1;
          end
          if (equihash_sol_bram_read[1])
            ram_rd_state <= STATE_RD_DATA;          
        end
      end
      STATE_RD_DATA: begin
      
        equihash_gen_in <= 0;
        equihash_gen_in.bits <= cblockheader.bits;
        equihash_gen_in.my_time <= cblockheader.my_time;
        equihash_gen_in.hash_merkle_root <= cblockheader.hash_merkle_root;
        equihash_gen_in.hash_prev_block <= cblockheader.hash_prev_block;
        equihash_gen_in.version <= cblockheader.version;
        equihash_gen_in.nonce <= cblockheader.nonce;
        equihash_gen_in.index <= (equihash_sol_index)/INDICIES_PER_HASH;
        blake2b_in_hash.ctl <= (equihash_sol_index) % INDICIES_PER_HASH;

                
        // Stay 2 clocks behind the RAM write
        if ((equihash_sol_bram_if_a.a*DAT_BYTS + DAT_BYTS) >= (equihash_sol_bram_if_b.a + $bits(cblockheader_t)/DAT_BITS) ||
             ram_wr_state == STATE_WR_WAIT) begin
          // Check if we need to load next memory address
          if ((sol_pos + 3*SOL_BITS >= 2*DAT_BITS) && ~|equihash_sol_bram_read) begin
            equihash_sol_bram_if_b.a <= equihash_sol_bram_if_b.a + 1;  
            equihash_sol_bram_read[0] <= 1; 
          end
                           
          // Load input into Blake2b block
          blake2b_in_hash.val <= 1;
          sol_cnt_in <= sol_cnt_in + 1;
    
          dup_check_if_in.val <= 1;
          dup_check_if_in.dat <= equihash_sol_index;
          dup_check_if_in.sop <= (sol_cnt_in == 0);
          dup_check_if_in.eop <= (sol_cnt_in == SOL_LIST_LEN - 1);
          
          equihash_order_if.val <= 1;
          equihash_order_if.dat <= equihash_sol_index;
          equihash_order_if.sop <= (sol_cnt_in == 0);
          equihash_order_if.eop <= (sol_cnt_in == SOL_LIST_LEN - 1);
          
          // If our input is about to shift we need to adjust pointer by DAT_BITS
          sol_pos <= sol_pos + SOL_BITS - (equihash_sol_bram_read[0] ? DAT_BITS : 0);
          if (sol_cnt_in == SOL_LIST_LEN - 1)
            ram_rd_state <= STATE_RD_WAIT;
        end
      end
      STATE_RD_WAIT: begin
        if (chk_state == STATE_CHK_DONE) begin
          ram_rd_state <= STATE_RD_IDLE;
        end
      end
    endcase
  end
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mask_val <= 0;
    o_mask <= 0;
    sol_hash_xor <= 0;
    blake2b_out_hash.rdy <= 0;
    sol_cnt_out <= 0;
    chk_state <= STATE_CHK_IDLE;
    dup_check_if_out.rdy <= 1;
    dup_chk_done <= 0;
    order_chk_done <= 0;
  end else begin
    // Defaults
    blake2b_out_hash.rdy <= 1;
    
    // Monitor for result of duplicate check
    if (dup_check_if_out.val) begin
      if (dup_check_if_out.dat[0] || dup_check_if_out.err) begin
        o_mask.DUPLICATE_FND <= 1;
      end
      dup_chk_done <= 1;
    end
    
    // Monitor for result of order check    
    if (equihash_order_val) begin
      if (equihash_order_wrong) begin
        o_mask.BAD_IDX_ORDER <= 1;
      end
      order_chk_done <= 1;
    end
    
    case(chk_state)
      STATE_CHK_IDLE: begin
        sol_cnt_out <= 0;
        dup_chk_done <= 0;
        order_chk_done <= 0;
        o_mask_val <= 0;
        o_mask <= 0;
        sol_hash_xor <= 0;
        if (ram_rd_state == STATE_RD_DATA)
          chk_state <= STATE_CHK_DATA;
      end
      STATE_CHK_DATA: begin
        // When we start getting the hash results, start XORing them
        if (blake2b_out_hash.val) begin
          if (sol_cnt_out == 0)
            sol_hash_xor <= equihash_sol_string_flip;
          else
            sol_hash_xor <= sol_hash_xor ^ equihash_sol_string_flip;
            
          sol_cnt_out <= sol_cnt_out + 1;
   
          //TODO here we also need to check the ordering, and duplicate indixe?
          //TODO some additional order requirements on the indexies < for certain ones
          // We also check the order is correct
          o_mask.BAD_ZERO_ORDER <= bad_order_check(sol_hash_xor, sol_cnt_out) | o_mask.BAD_ZERO_ORDER;
        end
        
        if (sol_cnt_out == SOL_LIST_LEN - 1) begin
          chk_state <= STATE_CHK_WAIT;
        end

      end
      STATE_CHK_WAIT: begin
        o_mask.XOR_NON_ZERO <= |sol_hash_xor;

        if (ram_rd_state == STATE_RD_WAIT &&
            ram_wr_state == STATE_WR_WAIT &&
            dup_chk_done &&
            order_chk_done ) begin
            
          o_mask_val <= 1;
          chk_state <= STATE_CHK_DONE;
        end
      end
      STATE_CHK_DONE: begin
        chk_state <= STATE_CHK_IDLE;
      end
    endcase
  end
end

// Constants
always_comb begin
  parameters = {'0, 8'd1, 8'd1, 8'd0, BLAKE2B_DIGEST_BYTS};
  parameters[48*8 +: 16*8] = POW_TAG; 
  blake2b_in_hash.dat = equihash_gen_in;
  equihash_sol_bram_if_b_l_comb = {equihash_sol_bram_if_b.q, equihash_sol_bram_if_b_l};
  
  // We have to select what part of Blake2b output to sleect
  // and then re-order the bytes so the XOR zeros grow from the left
  equihash_sol_string = blake2b_out_hash.dat[N*blake2b_out_hash.ctl +: N];
  for (int i = 0; i < N/8; i++)
    equihash_sol_string_flip[i*8 +: 8] = equihash_sol_string[N - 8 -i*8 +: 8];
  
  // Flip the bits in each byte
  for (int i = 0; i < DAT_BYTS*2; i++)
    for (int j = 0; j < 8; j++)
      equihash_sol_bram_if_b_l_comb_flip[i*8+j] = equihash_sol_bram_if_b_l_comb[(i*8)+7-j];
  // The SOL_BITS is also bit reversed    
  for (int i = 0; i < SOL_BITS; i++)
    equihash_sol_index[i] = equihash_sol_bram_if_b_l_comb_flip[sol_pos + SOL_BITS-1-i]; 

  
end

// This function checks the ordering of the XORs, so that the number of zeros
// grow from the left with the height of the tree
function bit bad_order_check(input logic [N-1:0] in, input int cnt);
  bad_order_check = 0;
  for (int i = 0; i < N/COLLISION_BIT_LEN; i++) begin
    if (sol_cnt_out % (1 << (i+1)) == 0) begin
      if (|in[N - (i+1)*COLLISION_BIT_LEN +: COLLISION_BIT_LEN]) begin
        bad_order_check = 1;
      end
    end
  end
  return bad_order_check;
endfunction

// Instantiate the Blake2b block - use high performance pipelined version
localparam [EQUIHASH_GEN_BYTS*8-1:0] EQUIHASH_GEN_BYTS_BM = {
           {32-SOL_BITS-$clog2(INDICIES_PER_HASH){1'b0}},
           {SOL_BITS-$clog2(INDICIES_PER_HASH){1'b1}},   // Only the lower bits of index change
           {EQUIHASH_GEN_BYTS*8-32{1'b0}}
           };

blake2b_pipe_top #(
  .MSG_LEN    ( EQUIHASH_GEN_BYTS         ),
  .MSG_VAR_BM ( EQUIHASH_GEN_BYTS_BM      ),   
  .CTL_BITS   ( $clog2(INDICIES_PER_HASH) )
)
blake2b_pipe_top_i (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_parameters ( parameters        ),
  .i_byte_len   ( EQUIHASH_GEN_BYTS ),
  .i_block ( blake2b_in_hash  ),
  .o_hash  ( blake2b_out_hash )
);

// Memory to store the compressed equihash solution as it comes in. We use dual port,
// one port for writing and one port for reading
bram #(
  .RAM_WIDTH       ( EQUIHASH_SOL_BRAM_WIDTH ),
  .RAM_DEPTH       ( EQUIHASH_SOL_BRAM_DEPTH ),
  .RAM_PERFORMANCE ( "LOW_LATENCY"          )  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
) equihash_sol_bram (
  .a ( equihash_sol_bram_if_a ),
  .b ( equihash_sol_bram_if_b )
);

zcash_verif_equihash_order
equihash_order (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  
  .i_axi         ( equihash_order_if    ),
  .o_order_wrong ( equihash_order_wrong ),
  .o_val         ( equihash_order_val   )
);

generate
  if (CHECK_UNIQUE_INDEX == 1) begin: GEN_INDEX_CHECK
    dup_check #(
      .IN_BITS   ( SOL_BITS     ),
      .LIST_SIZE ( SOL_LIST_LEN )
    )
    dup_check(
      .i_clk ( i_clk ),
      .i_rst ( i_rst ),

      .i_axi ( dup_check_if_in ),
      .o_axi ( dup_check_if_out )
    );
  end else begin
    always_comb begin
      dup_check_if_in.rdy = 1;
      dup_check_if_out.val = 1;
      dup_check_if_out.eop = 1;
      dup_check_if_out.sop = 1;
      dup_check_if_out.dat = 0;
    end
  end 
endgenerate
// Some checks to make sure our data structures are correct:
initial begin
  assert ($bits(equihash_gen_in_t)/8 == 144) else $fatal(1, "%m %t ERROR: equihash_gen_in_t is not 144 bytes in size", $time);
end

endmodule