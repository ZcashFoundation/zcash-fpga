/* Implemented from RFC-7693, The BLAKE2 Cryptographic Hash and Message Authentication Code (MAC)
 * Parameters are passed in as an input. Inputs and outputs are AXI stream and respect flow control.
 * Only only hash is computed at a time, and takes 26 clocks * number of 128 Byte message blocks.
 */ 

module blake2_top
  import blake2_pkg::*;
(
  input i_clk, i_rst,

  input [7:0]      i_byte_len,   // Length of the input message
  input [64*8-1:0] i_parameters, // Input parameters used in the inital state.
  
  if_axi_stream.sink   i_block, // Input block with valid and ready signals for flow control
  if_axi_stream.source o_hash   // Output digest with valid and ready signals for flow control
);

enum {STATE_IDLE = 0,
      STATE_ROUNDS = 1,
      STATE_NEXT_BLOCK = 2,
      STATE_FINAL_BLOCK = 3} blake2_state;

localparam ROUNDS = 12;

logic [7:0][63:0] h, h_tmp;  // The state vector
logic [15:0][63:0] v, v_tmp; // The local work vector and its intermediate value
logic [31:0][63:0] g_out; // Outputs of the G mixing function - use 8 here to save on timing
logic [127:0] t;      // Counter
logic [$clog2(ROUNDS)-1:0] round_cntr, round_cntr_msg, round_cntr_fin;
logic g_col;
logic [15:0][63:0] block, block_r; // The message block registered and converted to a 2d array
logic block_eop_l; // Use to latch if this is the final block
logic h_xor_done;
logic [7:0] byte_len_l;

// Pipelining logic that has no reset
always_ff @(posedge i_clk) begin

  if (blake2_state == STATE_IDLE && ~i_block.rdy)
    block_r <= 0;
  
  if (i_block.val && i_block.rdy) begin
    block_r <= i_block.dat;
  end
 
  
  for (int i = 0; i < 16; i++)
    if (g_col == 0)
      v_tmp[i] <= g_out[blake2_pkg::G_MAPPING[i]];
      
  for (int i = 0; i < 8; i++)
    if (blake2_state == STATE_ROUNDS)
      h_tmp[i] <= g_out[16 + blake2_pkg::G_MAPPING_DIAG[i]] ^ g_out[16 + blake2_pkg::G_MAPPING_DIAG[i+8]];
  
end

always_comb begin
  block = i_block.dat;
end

// State machine logic for compressing
always_ff @(posedge i_clk) begin
  if (i_rst) begin
    blake2_state <= STATE_IDLE;
    i_block.rdy <= 0;
    h <= 0;
    v <= 0;
    t <= 128;
    g_col <= 0;
    round_cntr <= 0;
    round_cntr_msg <= 0;
    o_hash.reset_source();
    round_cntr_fin <= 0;
    block_eop_l <= 0;
    h_xor_done <= 0;
    byte_len_l <= 0;
  end else begin
  
    g_col <= ~g_col;
    
    case (blake2_state)
      STATE_IDLE: begin
        h <= i_parameters ^ blake2_pkg::IV;
        t <= 2;
        i_block.rdy <= 1;
        v <= 0;
        o_hash.val <= 0;
        g_col <= 0;
        round_cntr <= 0;
        round_cntr_msg <= 0;
        round_cntr_fin <= 0;
        if (i_block.rdy && i_block.val && i_block.sop) begin
          init_local_work_vector(i_block.eop ? i_byte_len : 128, i_block.eop);
          blake2_state <= STATE_ROUNDS;
          g_col <= 0;
          i_block.rdy <= 0;
          block_eop_l <= i_block.eop;
          byte_len_l <= i_byte_len;
        end
      end
      // Here we do the compression over 12 rounds, each round can be done in two clock cycles
      // After we do 12 rounds we increment counter t
      STATE_ROUNDS: begin
        
        // Update local work vector with output of G function blocks depending on column or diagonal operation
        for (int i = 0; i < 16; i++) begin
          v[i] <= g_out[16 + blake2_pkg::G_MAPPING_DIAG[i]];
        end

        if (g_col) begin
          round_cntr <= round_cntr + 1;
        end else begin
          round_cntr_msg <= (round_cntr_msg + 1) % 10;
        end
        if (round_cntr == ROUNDS-1)
          round_cntr_fin <= 1;
          
        if (round_cntr_fin) begin
          if (block_eop_l)
            blake2_state <= STATE_FINAL_BLOCK;
          else begin
            blake2_state <= STATE_NEXT_BLOCK;
          end
        end
      end
      STATE_NEXT_BLOCK: begin
        round_cntr <= 0;
        round_cntr_msg <= 0;
        round_cntr_fin <= 0;
        h_xor_done <= 1;
        i_block.rdy <= 1;
        if (~h_xor_done)
          for (int i = 0; i < 8; i++)
            h[i] <= h[i] ^ h_tmp[i];
        if (i_block.rdy && i_block.val) begin
          init_local_work_vector(i_block.eop ? byte_len_l : t*128, i_block.eop);
          block_eop_l <= i_block.eop;
          t <= t + 1;
          blake2_state <= STATE_ROUNDS;
          h_xor_done <= 0;
          i_block.rdy <= 0;
          g_col <= 0;
        end
      end
      STATE_FINAL_BLOCK: begin
        round_cntr <= 0;
        round_cntr_fin <= 0;
        round_cntr_msg <= 0;
        if (~o_hash.val || (o_hash.val && o_hash.rdy)) begin
            if (~o_hash.val) begin
              o_hash.dat <= h ^ h_tmp;
              o_hash.val <= 1;
              o_hash.sop <= 1;
              o_hash.eop <= 1;
            end
            if (o_hash.rdy) begin
              blake2_state <= STATE_IDLE;
              i_block.rdy <= 1;
            end
        end  
      end
    endcase
  end
end

// 8x G-function blocks. 4 are col and 4 are diagonal
generate begin
  genvar gv_g;
  for (gv_g = 0; gv_g < 8; gv_g++) begin: G_FUNCTION_GEN
  
    // For each G function we want to pipeline the input message to help timing
    logic [63:0] m0, m1;
    always_ff @ (posedge i_clk) begin
      if(blake2_state == STATE_IDLE || blake2_state == STATE_NEXT_BLOCK) begin
        m0 <= block[blake2_pkg::SIGMA[gv_g*2]];
        m1 <= block[blake2_pkg::SIGMA[gv_g*2 + 1]];
      end else begin
        m0 <= block_r[blake2_pkg::SIGMA[16*round_cntr_msg + gv_g*2]];
        m1 <= block_r[blake2_pkg::SIGMA[16*round_cntr_msg + gv_g*2 + 1]];
      end
    end 
    
    blake2_g
      #(.PIPELINES(0))
    blake2_g (
      .i_clk(i_clk),
      .i_a(gv_g < 4 ? v[blake2_pkg::G_MAPPING[(gv_g*4 + 0)]] : v_tmp[blake2_pkg::G_MAPPING[(gv_g*4 + 0)]]),
      .i_b(gv_g < 4 ? v[blake2_pkg::G_MAPPING[(gv_g*4 + 1)]] : v_tmp[blake2_pkg::G_MAPPING[(gv_g*4 + 1)]]),
      .i_c(gv_g < 4 ? v[blake2_pkg::G_MAPPING[(gv_g*4 + 2)]] : v_tmp[blake2_pkg::G_MAPPING[(gv_g*4 + 2)]]),
      .i_d(gv_g < 4 ? v[blake2_pkg::G_MAPPING[(gv_g*4 + 3)]] : v_tmp[blake2_pkg::G_MAPPING[(gv_g*4 + 3)]]),
      .i_m0(m0),
      .i_m1(m1),
      .o_a(g_out[gv_g*4 + 0]),
      .o_b(g_out[gv_g*4 + 1]),
      .o_c(g_out[gv_g*4 + 2]),
      .o_d(g_out[gv_g*4 + 3]));
      
  end
end
endgenerate

// Task to initialize local work vector for the compression function
task init_local_work_vector(input [127:0] cntr, input last_block);
begin
  for (int i = 0; i < 16; i++)
    case (i) inside
      0,1,2,3,4,5,6,7: v[i] <= h[i];
      8,9,10,11: v[i] <= blake2_pkg::IV[i%8];
      12: v[i] <= blake2_pkg::IV[i%8] ^ cntr[63:0];
      13: v[i] <= blake2_pkg::IV[i%8] ^ cntr[64 +: 64];
      14: v[i] <= blake2_pkg::IV[i%8] ^ {64{last_block}};
      15: v[i] <= blake2_pkg::IV[i%8];
    endcase
end
endtask

endmodule