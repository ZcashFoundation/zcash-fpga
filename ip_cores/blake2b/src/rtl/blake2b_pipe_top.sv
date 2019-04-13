/*
  This is a pipeline unrolled implementation of Blake2b (from RFC-7693)
  In order to get maximum throughput, the entire message block is required on the first clock cycle,
  so all hashes are single clock with .sop and .eop high.
  
  You can optionally unroll the entire pipeline but this will use a large number of resources.
  If you only unroll one pass, you need to interleave the hashes to get the best performance.
  So the first part of input message comes on first clock cycle, and the next part comes 26 clocks later.
  
  Does not support using keys.
  
  Futher optimization to save area is fixing part of input message constant for
  all hashes (just have nonce as input that changes and place this in i_block.ctl), as well as the message input length.
 
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
 
module blake2b_pipe_top
  import blake2b_pkg::*;
#(
  // If we fully unfold the pipeline, the message byte length is hard-coded
  parameter                   MSG_LEN,
  parameter [(8*MSG_LEN)-1:0] MSG_VAR_BM = {MSG_LEN*8{1'b1}}, // A bit mask of what bitds in the message will change, can be used to reduce logic
  parameter                   CTL_BITS = 8
)
(
  input i_clk, i_rst,

  input [7:0]      i_byte_len,   // Length of the input message
  input [64*8-1:0] i_parameters, // Input parameters used in the inital state.
  
  if_axi_stream.sink   i_block, // Input block with valid and ready signals for flow control
  if_axi_stream.source o_hash   // Output digest with valid and ready signals for flow control
);


localparam NUM_ROUNDS = 12; 
localparam G_FUNC_PIPELINES = 1;
localparam NUM_PASSES = 1 + (MSG_LEN - 1)/128;
localparam NUM_PIPE = 2 + NUM_PASSES*(NUM_ROUNDS*G_FUNC_PIPELINES*2) + 2*NUM_PASSES - 1;

logic [NUM_PIPE-1:0][15:0][63:0] v;
logic [NUM_PIPE-1:0][7:0][63:0] h;
logic [NUM_PIPE-1:0][MSG_LEN*8-1:0] msg;
logic [MSG_LEN*8-1:0] msg_fixed;
logic [7:0]           byte_len;
logic [NUM_PIPE-1:0][CTL_BITS-1:0] ctl;
logic [NUM_PIPE-1:0] valid;

generate
  genvar g0, g1, g2, g3;
  
  // Since this is a single pipeline flow we pause if output is not ready
  // Simplier than dealing with valid bubbles in the pipeline
  always_comb i_block.rdy = ~o_hash.val || (o_hash.val && o_hash.rdy);
    
  // Assign the output from the final pipeline stage
  always_comb begin
    o_hash.val = valid[NUM_PIPE-1];  
    o_hash.ctl = ctl[NUM_PIPE-1];
    o_hash.sop = 1;
    o_hash.eop = 1;
    o_hash.err = 0;
    o_hash.dat = h[NUM_PIPE-1];
    o_hash.mod = 0;
  end

  // First stage has special logic 
  always_ff @ (posedge i_clk) begin
    if (i_rst) begin
      h[0] <= 0;
      v[0] <= 0;
      msg[0] <= 0;
      ctl[0] <= 0;
      v[0] <= 0;
      h[0] <= 0;
      valid[0] <= 0;
      valid[1] <= 0;
      msg_fixed <= 0;
      byte_len <= 0;
    end else begin
      if (~o_hash.val || (o_hash.val && o_hash.rdy)) begin
        // First stage - depends if we are fully unrolling or not as where input comes from
        h[0] <= i_parameters ^ blake2b_pkg::IV;
        v[0] <= 0;
        for (int i = 0; i < MSG_LEN*8; i++)
          msg[0][i] <= MSG_VAR_BM[i] ? i_block.dat[i] : 1'b0;
        if (i_block.val) begin
          msg_fixed <= i_block.dat;
          byte_len <= i_byte_len;
        end
        ctl[0] <= i_block.ctl;
        valid[0] <= i_block.val && i_block.rdy;

        // Second stage
        h[1] <= h[0];
        init_local_work_vector_pipe(1, NUM_PASSES == 1 ? byte_len : 128, NUM_PASSES == 1); // initializes v[1]
        msg[1] <= msg[0];
        ctl[1] <= ctl[0];
        valid[1] <= valid[0];
      end
    end
  end  
  
  
  for (g0 = 0; g0 < NUM_PASSES; g0++) begin: GEN_PASS
  
    localparam LAST_BLOCK = (g0 + 1 == NUM_PASSES - 1);
    localparam PIPE_G0 = 2 + NUM_ROUNDS*2 + g0*(NUM_ROUNDS*2 + 2);
    
    logic [128*8-1:0] msg_fixed_int;

    always_comb begin
      msg_fixed_int = msg_fixed >> (1024*g0);
    end
    
    // At the end of each round are two pipeline stages for updating
    // the local state
    always_ff @ (posedge i_clk) begin
      if (i_rst) begin
        valid[PIPE_G0] <= 0;
        valid[PIPE_G0+1] <= 0;
      end else begin
        if (~o_hash.val || (o_hash.val && o_hash.rdy)) begin
          valid[PIPE_G0] <= valid[PIPE_G0-1];
          valid[PIPE_G0+1] <= valid[PIPE_G0];
        end
      end
    end
    
    always_ff @ (posedge i_clk) begin
      // First stage
      // Some pipelines not used in this stage
      msg[PIPE_G0] <= msg[PIPE_G0-1]; 
      ctl[PIPE_G0] <= ctl[PIPE_G0-1];
      v[PIPE_G0] <= 0;  
      if (~o_hash.val || (o_hash.val && o_hash.rdy)) begin
        for (int i = 0; i < 8; i++)
          h[PIPE_G0][i] <= h[PIPE_G0-1][i] ^ v[PIPE_G0-1][i] ^ v[PIPE_G0-1][i+8];
      end
      // Second stage
      if (~o_hash.val || (o_hash.val && o_hash.rdy)) begin
        // Shift message down either from previous pipeline or from fixed portion
        if (g0 < (NUM_PASSES - 1)) begin
          h[PIPE_G0+1] <= h[PIPE_G0];      
          init_local_work_vector_pipe(PIPE_G0+1, LAST_BLOCK ? byte_len : 128 , LAST_BLOCK);
          
          ctl[PIPE_G0+1] <= ctl[PIPE_G0];
        end
        msg[PIPE_G0+1] <= msg[PIPE_G0];
      end

    end
      
    for (g1 = 0; g1 < NUM_ROUNDS; g1++) begin: GEN_ROUND
      
      for (g2 = 0; g2 < 2; g2++) begin: GEN_G_FUNC
        
        // Each pipeline stage has 4 G function blocks in parallel
        localparam PIPE_G2 = 2 + g0*(2 + NUM_ROUNDS*2) + g1*G_FUNC_PIPELINES*2 + g2;
        
        always_ff @(posedge i_clk) begin
          if (i_rst) begin
            valid[PIPE_G2] <= 0;
          end else begin
            if (~o_hash.val || (o_hash.val && o_hash.rdy))
              valid[PIPE_G2] <= valid[PIPE_G2-1];
          end
        end
        
        always_ff @(posedge i_clk) begin
          if (~o_hash.val || (o_hash.val && o_hash.rdy)) begin
            msg[PIPE_G2] <= msg[PIPE_G2-1];
              h[PIPE_G2] <= h[PIPE_G2-1];
            ctl[PIPE_G2] <= ctl[PIPE_G2-1];
          end
        end
        
        for (g3 = 0; g3 < 4; g3++) begin: GEN_G_FUNC_COL_DIAG
          
          logic [63:0] msg0, msg1;
          logic [16*64-1:0] msg_;
          always_comb begin
            msg_ = 0;
            for (int i = 0; i < 1024; i++)
              if (((i + g0*1024) < MSG_LEN*8) && MSG_VAR_BM[i + (g0*1024)])
                msg_[i] = msg[PIPE_G2-1][i + g0*1024];
              else
                msg_[i] = msg_fixed_int[i];
            for (int i = 0; i < 8; i ++) begin
              msg0 = msg_[64*blake2b_pkg::SIGMA[16*(g1%10) + g2*8 + g3*2] +: 64];
              msg1 = msg_[64*blake2b_pkg::SIGMA[16*(g1%10) + g2*8 + g3*2 + 1] +: 64];
            end
          end
          
          blake2b_g
            #( .PIPELINES(G_FUNC_PIPELINES) )
          blake2b_g (
            .i_clk(i_clk),
            .i_rdy (~o_hash.val || (o_hash.val && o_hash.rdy)),
            .i_a(g2 == 0 ? v[PIPE_G2-1][blake2b_pkg::G_MAPPING[(g3*4 + 0)]] : v[PIPE_G2-1][blake2b_pkg::G_MAPPING[16 + (g3*4 + 0)]]),
            .i_b(g2 == 0 ? v[PIPE_G2-1][blake2b_pkg::G_MAPPING[(g3*4 + 1)]] : v[PIPE_G2-1][blake2b_pkg::G_MAPPING[16 + (g3*4 + 1)]]),
            .i_c(g2 == 0 ? v[PIPE_G2-1][blake2b_pkg::G_MAPPING[(g3*4 + 2)]] : v[PIPE_G2-1][blake2b_pkg::G_MAPPING[16 + (g3*4 + 2)]]),
            .i_d(g2 == 0 ? v[PIPE_G2-1][blake2b_pkg::G_MAPPING[(g3*4 + 3)]] : v[PIPE_G2-1][blake2b_pkg::G_MAPPING[16 + (g3*4 + 3)]]),
            .i_m0(msg0),
            .i_m1(msg1),
            .o_a(v[PIPE_G2][g2 == 0 ? blake2b_pkg::G_MAPPING[g3*4 + 0] : blake2b_pkg::G_MAPPING[16 + g3*4 + 0]]),
            .o_b(v[PIPE_G2][g2 == 0 ? blake2b_pkg::G_MAPPING[g3*4 + 1] : blake2b_pkg::G_MAPPING[16 + g3*4 + 1]]),
            .o_c(v[PIPE_G2][g2 == 0 ? blake2b_pkg::G_MAPPING[g3*4 + 2] : blake2b_pkg::G_MAPPING[16 + g3*4 + 2]]),
            .o_d(v[PIPE_G2][g2 == 0 ? blake2b_pkg::G_MAPPING[g3*4 + 3] : blake2b_pkg::G_MAPPING[16 + g3*4 + 3]])
          );
        end
      end 
    end
  end
endgenerate

// Task to initialize local work vector for the compression function
// Modified to work with pipeline version
task automatic init_local_work_vector_pipe(input integer j, input integer cnt, input last_block);
begin
  for (int i = 0; i < 16; i++)
    case (i) inside
      0,1,2,3,4,5,6,7: v[j][i] <= h[j-1][i];
      8,9,10,11: v[j][i] <= blake2b_pkg::IV[i%8];
      12: v[j][i] <= blake2b_pkg::IV[i%8] ^ cnt;//(last_block ? byte_len : j*128);
      13: v[j][i] <= blake2b_pkg::IV[i%8];// ^ j*128 >> 64; 
      14: v[j][i] <= blake2b_pkg::IV[i%8] ^ {64{last_block}};
      15: v[j][i] <= blake2b_pkg::IV[i%8];
    endcase
end
endtask

endmodule