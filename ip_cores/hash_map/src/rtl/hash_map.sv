/*
  This is a parameterizable hash map implementation using the a CRC function
  as the hash.
  
  Internally we use a main memory for collisions and then a linked list
  to store items when they collide.
  
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
module hash_map #(
  parameter KEY_BITS = 32,        // How many bits is our key
  parameter DAT_BITS = 8,         // Each key maps to data
  parameter HASH_MEM_SIZE = 8,    // The size of the first level memory, this will define how many bits of the output hash function we use 
  parameter LL_MEM_SIZE = 8       // The size of the linked list memory that is used in case of collisions
)(
  input i_clk, i_rst,
  
  input [KEY_BITS-1:0]        i_key,
  input                       i_val,
  input [DAT_BITS-1:0]        i_dat,
  input [1:0]                 i_opcode, // 0 = Lookup, 1 = Add, 2 = Delete
  output logic                o_rdy,
  output logic [DAT_BITS-1:0] o_dat,    // Valid after lookup
  output logic                o_val,
  output logic                o_fnd,    // Will be high if adding a key and it already exists (old data overwritten)
                                        // or for a lookup if key was found.
  
  // To clear memory
  input                       i_cfg_clr,
  // When linked list memory is full this will be high
  output logic                o_cfg_full  
);

parameter CRC_IN_BITS = 32;

logic [CRC_IN_BITS-1:0] key;
logic [DAT_BITS-1:0]    dat;

logic [$clog2(HASH_MEM_SIZE)-1: 0] hash_out, prev_coll_addr;
logic [$clog2(LL_MEM_SIZE)-1:0] prev_ll_addr;
      
// Two memories make the hash table, a collision memory and a linked list memory
typedef struct packed {
  logic [KEY_BITS-1:0]            key;
  logic [DAT_BITS-1:0]            dat;
  logic [$clog2(LL_MEM_SIZE)-1:0] nxt_ptr;
  logic                           used;
} hash_map_node_t;

logic free_mem_fifo_emp, pre_node_coll;

if_axi_stream #(.DAT_BITS($clog2(LL_MEM_SIZE)), .CTL_BITS(1), .MOD_BITS(1)) free_mem_fifo_if_in(i_clk); 
if_axi_stream #(.DAT_BITS($clog2(LL_MEM_SIZE)), .CTL_BITS(1), .MOD_BITS(1)) free_mem_fifo_if_out(i_clk); 

if_ram #(.RAM_WIDTH($bits(hash_map_node_t)), .RAM_DEPTH(HASH_MEM_SIZE)) coll_bram_if_a (i_clk, i_rst);
if_ram #(.RAM_WIDTH($bits(hash_map_node_t)), .RAM_DEPTH(HASH_MEM_SIZE)) coll_bram_if_b (i_clk, i_rst);

logic [$clog2(HASH_MEM_SIZE)-1:0] coll_bram_if_a_cfg;

if_ram #(.RAM_WIDTH($bits(hash_map_node_t)), .RAM_DEPTH(LL_MEM_SIZE)) ll_bram_if_a (i_clk, i_rst);
if_ram #(.RAM_WIDTH($bits(hash_map_node_t)), .RAM_DEPTH(LL_MEM_SIZE)) ll_bram_if_b (i_clk, i_rst);

hash_map_node_t coll_node_rd, ll_node_rd, coll_node_wr, ll_node_wr;

logic free_mem_fifo_rst, free_mem_loaded, coll_ram_rst;

logic [1:0] ll_ram_wait, coll_ram_wait;

typedef enum 
     {STATE_IDLE = 0,
      STATE_LOOPUP_COL = 1,  // Lookup in first collision memory
      STATE_LOOPUP_LL = 2,  // Lookup in linked list
      STATE_MODIFY_LL = 3,
      STATE_RESET = 4} hash_state_t;
      
typedef enum 
     {OPCODE_LOOKUP = 0,
      OPCODE_ADD = 1,
      OPCODE_DELETE = 2} opcode_t;      
      
opcode_t opcode;

hash_state_t hash_state, hash_state_prev;

// Counters that can be used for debug
logic [7:0] hash_collisions;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    key <= 0;
    dat <= 0;
    opcode <= OPCODE_LOOKUP;
    o_rdy <= 0;
    o_val <= 0;
    o_fnd <= 0;
    o_dat <= 0;
    o_cfg_full <= 0;
    free_mem_loaded <= 0;
    coll_ram_rst <= 0;
    free_mem_fifo_if_in.reset_source();
    free_mem_fifo_if_out.rdy <= 0;
    free_mem_fifo_rst <= 0;
    hash_state <= STATE_RESET;  // We start in reset state because we need to load the free ram pointer list
    hash_state_prev <= STATE_IDLE;
    
    ll_ram_wait <= 0;
    coll_ram_wait <= 0;
    
    coll_bram_if_b.reset_source();
    ll_bram_if_b.reset_source();
    coll_bram_if_a.we <= 0;
    ll_bram_if_a.we <= 0;
    coll_bram_if_a.en <= 1;
    ll_bram_if_a.en <= 1;
    coll_node_wr <= 0;
    ll_node_wr <= 0;
    
    coll_bram_if_a_cfg <= 0;
    hash_collisions <= 0;
    prev_ll_addr <= 0;
    prev_coll_addr <= 0;
    pre_node_coll <= 0;
    
  end else begin
    hash_state_prev <= hash_state;
    free_mem_fifo_rst <= 0;
    coll_bram_if_a.we <= 0;
    ll_bram_if_a.we <= 0;
    coll_bram_if_a.re <= 1;
    ll_bram_if_a.re <= 1;
    o_cfg_full <= free_mem_fifo_emp; // If the LL FIFO is empty it means we have no more free nodes
    
    free_mem_fifo_if_out.rdy <= 0;
    free_mem_fifo_if_in.val <= 0;
    
    ll_ram_wait <= ll_ram_wait << 1;
    coll_ram_wait <= coll_ram_wait << 1;
    
    o_val <= 0;
    
    case (hash_state)
      STATE_IDLE: begin
        coll_bram_if_a_cfg <= hash_out;
        o_rdy <= 1;
        dat <= i_dat;
        key <= i_key;
        opcode <= opcode_t'(i_opcode);
        if (o_rdy && i_val) begin
          o_rdy <= 0;
          hash_state <= STATE_LOOPUP_COL;
          coll_ram_wait[0] <= 1;
        end else if (i_cfg_clr) begin
          o_rdy <= 0;
          hash_state <= STATE_RESET;
        end
      end
      STATE_LOOPUP_COL: begin
        o_dat <= coll_node_rd.dat;
        ll_bram_if_a.a <= coll_node_rd.nxt_ptr;
        if (coll_ram_wait[1]) begin
          prev_coll_addr <= coll_bram_if_a.a;
          pre_node_coll <= 1;
          case(opcode)
            // Lookup
            OPCODE_LOOKUP: begin
              if (coll_node_rd.used == 0) begin
                o_val <= 1;
                o_rdy <= 1;
                o_fnd <= 0;
                hash_state <= STATE_IDLE;
              end else if (coll_node_rd.used == 1 && coll_node_rd.key == key) begin
                o_val <= 1;
                o_fnd <= 1;
                hash_state <= STATE_IDLE;
              end else begin
                ll_ram_wait[0] <= 1;
                hash_state <= STATE_LOOPUP_LL;
              end
            end
            // Add
            OPCODE_ADD: begin
              // Not used so can directly add here
              if (coll_node_rd.used == 0) begin
                coll_node_wr.used <= 1;
                coll_node_wr.dat <= dat;
                coll_node_wr.nxt_ptr <= 0;
                coll_node_wr.key <= key;
                coll_bram_if_a.we <= 1;
                o_rdy <= 1;
                o_val <= 1;
                hash_state <= STATE_IDLE;
              end else begin
                // Need to use free memory location from FIFO - check we have space
                if (free_mem_fifo_emp) begin
                  o_val <= 1;
                  hash_state <= STATE_IDLE;
                end else begin
                  if (coll_node_rd.nxt_ptr == 0) begin
                    coll_node_wr <= coll_node_rd;
                    coll_node_wr.nxt_ptr <= free_mem_fifo_if_out.dat;
                    coll_bram_if_a.we <= 1;
                    
                    ll_node_wr.used <= 1;
                    ll_node_wr.dat <= dat;
                    ll_node_wr.nxt_ptr <= 0;
                    ll_node_wr.key <= key;
                    ll_bram_if_a.a <= free_mem_fifo_if_out.dat;
                    free_mem_fifo_if_out.rdy <= 1;
                    ll_bram_if_a.we <= 1; 
                    
                    o_rdy <= 1;
                    o_val <= 1;
                    hash_state <= STATE_IDLE;   
                  end else begin
                    ll_ram_wait[0] <= 1;
                    hash_state <= STATE_LOOPUP_LL;
                    hash_collisions <= hash_collisions + 1;
                  end
                end
              end
            end
            // Delete
            OPCODE_DELETE: begin
              if (coll_node_rd.used == 1 && coll_node_rd.key == key) begin
                if (coll_node_rd.nxt_ptr != 0) begin
                  // Want to free the nxt_ptr and move it into the collision ram
                  free_mem_fifo_if_in.dat <= coll_node_rd.nxt_ptr;
                  free_mem_fifo_if_in.val <= 1;
                  coll_bram_if_a_cfg <= coll_bram_if_a.a;
                  ll_ram_wait[0] <= 1;  
                  hash_state <= STATE_MODIFY_LL;
                end else begin
                  coll_node_wr <= 0;
                  o_fnd <= 1;
                  o_val <= 1;
                  coll_bram_if_a.we <= 1;
                  o_rdy <= 1;
                  hash_state <= STATE_IDLE;
                end
              end else if (coll_node_rd.used == 0) begin
                o_fnd <= 0;
                o_val <= 1;
                o_rdy <= 1;
                hash_state <= STATE_IDLE;
              end else begin
                ll_ram_wait[0] <= 1;
                hash_state <= STATE_LOOPUP_LL;
              end
            end
          endcase
        end
      end
      STATE_LOOPUP_LL: begin
        // In this state we keep traversing memory until key to nxt_ptr is zero
        o_dat <= ll_node_rd.dat;
        ll_bram_if_a.a <= ll_node_rd.nxt_ptr;
        if (ll_ram_wait[1]) begin
          prev_ll_addr <= ll_bram_if_a.a;
          pre_node_coll <= 0;
          case(opcode)
            // Lookup
            OPCODE_LOOKUP: begin
              if (ll_node_rd.nxt_ptr == 0 && ll_node_rd.key != key) begin
                o_val <= 1;
                o_rdy <= 1;
                o_fnd <= 0;
                hash_state <= STATE_IDLE;
              end else if (ll_node_rd.key == key) begin
                o_val <= 1;
                o_fnd <= 1;
                hash_state <= STATE_IDLE;
              end else begin
                ll_ram_wait[0] <= 1;
              end
            end
            // Add
            OPCODE_ADD: begin
              // Pop a location from the FIFO and use its memory location as the next element
              if (ll_node_rd.nxt_ptr == 0) begin
                ll_node_wr.used <= 1;
                ll_node_wr.dat <= dat;
                ll_node_wr.nxt_ptr <= 0;
                ll_node_wr.key <= key;
                ll_bram_if_a.a <= free_mem_fifo_if_out.dat;
                free_mem_fifo_if_out.rdy <= 1;
                ll_bram_if_a.we <= 1;
                o_rdy <= 1;
                o_val <= 1;
                hash_state <= STATE_IDLE;
              end else begin
                ll_ram_wait[0] <= 1;
              end
            end
            // Delete
           OPCODE_DELETE: begin
            if (ll_node_rd.key == key) begin
              // We need to travese backwards and set the nxt_ptr to this.nxt_ptr,
              // and add this address back to the free memory pool
                free_mem_fifo_if_in.dat <= ll_bram_if_a.a;
                free_mem_fifo_if_in.val <= 1;
                if (pre_node_coll) 
                  coll_bram_if_a_cfg <= prev_coll_addr;
                else
                  ll_bram_if_a.a <= prev_ll_addr; 
                ll_ram_wait[0] <= 1;  
                pre_node_coll <= pre_node_coll;
                hash_state <= STATE_MODIFY_LL;
              // Count not find the element
              end else if (coll_node_rd.nxt_ptr == 0) begin
                o_fnd <= 0;
                o_val <= 1;
                o_rdy <= 1;
                hash_state <= STATE_IDLE;
              end else begin
                hash_state <= STATE_LOOPUP_LL;
              end
            end
          endcase
        end
      end
      // This state is used when we make a delete in the middle of the LL
      STATE_MODIFY_LL: begin
        hash_state_prev <= hash_state_prev;
        if (ll_ram_wait[1]) begin
          if (hash_state_prev == STATE_LOOPUP_COL) begin
            coll_node_wr <= ll_node_rd;
            coll_bram_if_a.we <= 1;
          end else if (pre_node_coll) begin
            coll_node_wr <= coll_node_rd;
            coll_node_wr.nxt_ptr <= prev_ll_addr;
            coll_bram_if_a.we <= 1;
          end else begin
            ll_node_wr <= ll_node_rd;
            ll_node_wr.nxt_ptr <= prev_ll_addr;
            ll_bram_if_a.we <= 1;
          end
        
          o_fnd <= 1;
          o_val <= 1;
          o_rdy <= 1;
          hash_state <= STATE_IDLE;
        end
      end
      // In this state we clear the free memory FIFO and re-load it
      STATE_RESET: begin
        o_rdy <= 0;
        hash_collisions <= 0;
        o_cfg_full <= 0;
        // First clock we reset the fifo
        if (hash_state_prev != STATE_RESET) begin
          free_mem_fifo_rst <= 1;
          free_mem_fifo_if_in.dat <= 1; // Need to reserve nxt_ptr = 0 as terminator
          free_mem_fifo_if_out.rdy <= 0;
          free_mem_loaded <= 0;
          coll_ram_rst <= 0;
          coll_node_wr.used <= 0;
          coll_bram_if_a.we <= 1;
          coll_bram_if_a_cfg <= 0;
        end else begin
          free_mem_fifo_if_in.val <= 0;
          
          // Next we load the fifo with pointers
          if (free_mem_fifo_if_in.rdy && ~free_mem_loaded) begin
            free_mem_fifo_if_in.val <= 1;
            if (free_mem_fifo_if_in.val) begin
              free_mem_fifo_if_in.dat <= free_mem_fifo_if_in.dat + 1;
              if (free_mem_fifo_if_in.dat == LL_MEM_SIZE-1) begin
                free_mem_loaded <= 1;
                free_mem_fifo_if_in.val <= 0;
              end
            end
          end  
          
          // And clear collision memory
          if (~coll_ram_rst) begin
            coll_bram_if_a.we <= 1;
            coll_bram_if_a_cfg <= coll_bram_if_a_cfg + 1;
            coll_bram_if_a.we <= 1;
            if (coll_bram_if_a_cfg == HASH_MEM_SIZE-1) begin
              coll_ram_rst <= 1;
              coll_bram_if_a.we <= 0;
            end
          end
            
          if (free_mem_loaded && coll_ram_rst)
            hash_state <= STATE_IDLE;
        end
      end
    endcase

  end
end

always_comb begin
  coll_bram_if_a.a = (hash_state == STATE_IDLE) ? hash_out : coll_bram_if_a_cfg; 
  coll_node_rd = coll_bram_if_a.q;
  ll_node_rd = ll_bram_if_a.q;
  coll_bram_if_a.d = coll_node_wr;
  ll_bram_if_a.d = ll_node_wr;
end

// Use CRC-32 as the hash function
crc #(
  .IN_BITS    ( CRC_IN_BITS           ),
  .OUT_BITS   ( $clog2(HASH_MEM_SIZE) ),
  .POLYNOMIAL ( 32'h04C11DB7          ),
  .PIPELINE   ( 0                     )
)
crc_i (
  .i_clk ( i_clk                                ),
  .i_rst ( i_rst                                ),
  .in    ( (hash_state != STATE_IDLE 
           || coll_bram_if_a.we ) ? key : i_key ),
  .out   ( hash_out                             )
);

// We store the free pointers in a FIFO
axi_stream_fifo #(
  .SIZE     ( LL_MEM_SIZE         ),
  .DAT_BITS ( $clog2(LL_MEM_SIZE) ),
  .MOD_BITS ( 1                   ),
  .CTL_BITS ( 1                   )
)
free_mem_fifo (
  .i_clk  ( i_clk ),
  .i_rst  ( free_mem_fifo_rst || i_rst ),
  .i_axi  ( free_mem_fifo_if_in  ),
  .o_axi  ( free_mem_fifo_if_out ),
  .o_full (),
  .o_emp  ( free_mem_fifo_emp    )
);

// RAM to store first level collision
bram #(
  .RAM_WIDTH       ( $bits(hash_map_node_t) ),
  .RAM_DEPTH       ( HASH_MEM_SIZE          ),
  .RAM_PERFORMANCE ( "LOW_LATENCY"          )
) coll_bram (
  .a ( coll_bram_if_a ),
  .b ( coll_bram_if_b )
);

// Spill over linked list memory
bram #(
  .RAM_WIDTH       ( $bits(hash_map_node_t) ),
  .RAM_DEPTH       ( LL_MEM_SIZE            ),
  .RAM_PERFORMANCE ( "LOW_LATENCY"          )
) ll_bram (
  .a ( ll_bram_if_a ),
  .b ( ll_bram_if_b )
);

endmodule