// Implemented from RFC-7693, The BLAKE2 Cryptographic Hash and Message Authentication Code (MAC)

module blake2_top
  import blake2_pkg::*;
#(
)
(
  input i_clk, i_rst,

  // Parameter block input
  input [7:0] i_digest_byte_len,
  input [7:0] i_key_byte_len,

  input [128*8-1:0] i_block,
  input i_new_block,
  input i_final_block,
  input i_val,

  output logic[64*8-1:0] o_digest,
  output logic           o_rdy,
  output logic           o_val,
  output logic           o_err,
  
  if_axi_stream o_hash
);

enum {STATE_IDLE = 0,
      STATE_ROUNDS = 1,
      STATE_NEXT_BLOCK = 2} blake2_state;

localparam ROUNDS = 12;

logic [64*8-1:0] parameters, parameters_r;
logic [7:0][63:0] h;  // The state vector
logic [15:0][63:0] v; // The local work vector
logic [31:0][63:0] g_out; // Outputs of the G mixing function - use 8 here to save on timing
logic [127:0] t;      // Counter - TODO make this smaller - related to param
logic [$clog2(ROUNDS)-1:0] round_cntr;
logic cnt;
logic g_col;
logic [15:0][63:0] block_r; // The message block registered and converted to a 2d array
logic final_block_r;

always_comb begin
  parameters = {32'd0, 8'd1, 8'd1, i_key_byte_len, blake2_pkg::NN};
end

// Logic that is for pipelining
always_ff @(posedge i_clk) begin
  if (i_val && o_rdy) begin
    block_r <= i_block;
    final_block_r <= i_final_block;
    parameters_r <= parameters;
  end
end

// State machine logic for compressing
always_ff @(posedge i_clk) begin
  if (i_rst) begin
    blake2_state <= STATE_IDLE;
    o_val <= 0;
    o_rdy <= 0;
    h <= 0;
    v <= 0;
    t <= 128;
    g_col <= 0;
    round_cntr <= 0;
    o_err <= 0;
    o_digest <= 0;
    cnt <= 0;
    
    o_hash.reset();

  end else begin
  cnt <= cnt + 1;
    case (blake2_state)
      STATE_IDLE: begin
        o_val <= 0;
        init_state_vector();
        t <= 128;
        o_err <= 0;
        o_rdy <= 1;
        v <= 0;
        o_hash.val = 0;
        g_col <= 0;
        round_cntr <= 0;
        if (o_rdy && i_val && i_new_block) begin
          init_local_work_vector(i_final_block ? i_digest_byte_len : t);
          blake2_state <= STATE_ROUNDS;
          o_rdy <= 0;
        end
      end
      // Here we do the compression over 12 rounds, each round can be done in two clock cycles
      // After we do 12 rounds we increment counter t
      STATE_ROUNDS: begin
        // Update local work vector with output of G function blocks
        for (int i = 0; i < 16; i++)
          v[i] <= g_col == 0 ? g_out[blake2_pkg::G_MAPPING[i]] : g_out[16 + blake2_pkg::G_MAPPING_DIAG[i]];

        if (g_col)
          round_cntr <= round_cntr + 1;
        g_col <= ~g_col;
        
        // Update state vector on the final round
        if (round_cntr == ROUNDS-1 && g_col) begin
 
          for (int i = 0; i < 8; i++)
            h[i] <= h[i] ^
                    g_out[16 + blake2_pkg::G_MAPPING_DIAG[i]] ^
                    g_out[16 + blake2_pkg::G_MAPPING_DIAG[i+8]];

          blake2_state <= STATE_NEXT_BLOCK;
          if (~final_block_r)
            o_rdy <= 1;
        end

      end
      STATE_NEXT_BLOCK: begin
        if (final_block_r) begin
          
          o_val <= 1;
          o_digest <= h;
          t <= 128;
          if (~o_hash.val) begin
            o_hash.dat <= h;
            o_hash.val <= 1;
            o_hash.sop <= 1;
            o_hash.eop <= 1;
          end
          if (o_hash.rdy)
            blake2_state <= STATE_IDLE;
          
        end else if (o_rdy && i_val) begin
          round_cntr <= 0;
          init_local_work_vector(t);
          t <= t + 128;
          blake2_state <= STATE_ROUNDS;
        end
      end
    endcase
  end
end

// 8x G-function blocks. 4 are col and 4 are diagonal
generate begin
  genvar gv_g;
  for (gv_g = 0; gv_g < 8; gv_g++) begin: G_FUNCTION_GEN
    blake2_g
      #(.PIPELINES(0))
    blake2_g (
      .i_clk(i_clk),
      .i_a(v[blake2_pkg::G_MAPPING[(gv_g*4 + 0)]]),
      .i_b(v[blake2_pkg::G_MAPPING[(gv_g*4 + 1)]]),
      .i_c(v[blake2_pkg::G_MAPPING[(gv_g*4 + 2)]]),
      .i_d(v[blake2_pkg::G_MAPPING[(gv_g*4 + 3)]]),
      .i_m0(block_r[blake2_pkg::SIGMA[16*(round_cntr % 10) + (gv_g*2)]]),
      .i_m1(block_r[blake2_pkg::SIGMA[16*(round_cntr % 10) + (gv_g*2 + 1)]]),
      .o_a(g_out[gv_g*4 + 0]),
      .o_b(g_out[gv_g*4 + 1]),
      .o_c(g_out[gv_g*4 + 2]),
      .o_d(g_out[gv_g*4 + 3]));
  end
end
endgenerate


// Task to initialize the state vector
task init_state_vector();
begin
  for (int i = 0; i < 8; i++)
    if (i == 0)
      h[i] <= parameters ^ blake2_pkg::IV[i];
    else
      h[i] <= blake2_pkg::IV[i];
end
endtask

// Task to initialize local work vector for the compression function
task init_local_work_vector(input [127:0] cntr);
begin
  for (int i = 0; i < 16; i++)
    case (i) inside
      0,1,2,3,4,5,6,7: v[i] <= h[i];
      8,9,10,11: v[i] <= blake2_pkg::IV[i%8];
      12: v[i] <= blake2_pkg::IV[i%8] ^ cntr[63:0];
      13: v[i] <= blake2_pkg::IV[i%8] ^ cntr[64 +: 64];
      14: v[i] <= blake2_pkg::IV[i%8] ^ {64{i_final_block}};
      15: v[i] <= blake2_pkg::IV[i%8];
    endcase
end
endtask

endmodule