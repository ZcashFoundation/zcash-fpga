/*
  This is a pipeline unrolled implementation of Blake2b (from RFC-7693)
  In order to get maximum throughput, the entire message block is required on the first clock cycle,
  so all hashes are single clock with .sop and .eop high.
  
  You can optionally unroll the entire pipeline but this will use a large number of resources.
  If you only unroll one pass, you need to interleave the hashes to get the best performance.
  So the first part of input message comes on first clock cycle, and the next part comes 26 clocks later.
  
  Does not support using keys.
  
  Futher optimization to save area is fixing part of input message constant for
  all hashes (just have nonce as input that changes and place this in i_block.ctl).
 
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
  // Do we fully unroll the pipeline (lot of resources) or just un-roll one pass
  parameter FULLY_UNROLL = 0,
  // If we fully unfold the pipeline, the message byte length is hard-coded
  parameter MSG_LEN = 3,
  parameter CTL_BITS = 8
)
(
  input i_clk, i_rst,

  input [7:0]      i_byte_len,   // Length of the input message
  input [64*8-1:0] i_parameters, // Input parameters used in the inital state.
  
  if_axi_stream.sink   i_block, // Input block with valid and ready signals for flow control
  if_axi_stream.source o_hash   // Output digest with valid and ready signals for flow control
);


localparam NUM_ROUNDS = 12; 
localparam NUM_PASSES = 1 + MSG_LEN/128;
localparam NUM_PIPE = 2 + NUM_PASSES*(NUM_ROUNDS*2) + 2*NUM_PASSES - 1;

logic [NUM_PIPE-1:0][15:0][63:0] v;
logic [NUM_PIPE-1:0][7:0][63:0] h;
logic [NUM_PIPE-1:0][15:0][63:0] msg;
logic [NUM_PIPE-1:0][CTL_BITS-1:0] ctl;
logic [NUM_PIPE-1:0] eop_l, sop_l, valid;

generate
  genvar g0, g1, g2, g3;
  
  // Since this is a single pipeline flow we pause if output is not ready
  // Simplier than dealing with valid bubbles in the pipeline
  always_comb i_block.rdy = o_hash.rdy;
    
  // Assign the output from the final pipeline stage
  always_comb begin
    o_hash.val = valid[NUM_PIPE-1];  
    o_hash.ctl = ctl[NUM_PIPE-1];
    o_hash.sop = 1;
    o_hash.eop = 1;
    o_hash.dat = h[NUM_PIPE-1];
  end

  // First stage has special logic 
  always_ff @ (posedge i_clk) begin
    if (i_rst) begin
      h[0] <= 0;
      v[0] <= 0;
      msg[0] <= i_block.dat;
      ctl[0] <= i_block.ctl;
      v[0] <= 0;
      h[0] <= 0;
      valid[0] <= 0;
      valid[1] <= 0;
    end else begin
      if (i_block.rdy) begin
        // First stage
        h[0] <= i_parameters ^ blake2b_pkg::IV;
        v[0] <= 0;
        msg[0] <= i_block.dat;
        ctl[0] <= i_block.ctl;
        valid[0] <= i_block.val;
      end
      if (o_hash.rdy) begin
        // Second stage
        h[1] <= h[0];
        init_local_work_vector_pipe(1, NUM_PASSES == 1); // initializes v[1]
        msg[1] <= msg[0];
        ctl[1] <= ctl[0];
        valid[1] <= valid[0];
      end
    end
  end  
  
  
  for (g0 = 0; g0 < NUM_PASSES; g0++) begin: GEN_PASS
  
    localparam LAST_BLOCK = (g0 == NUM_PASSES -1);
    localparam SR_MSG_BYTS = LAST_BLOCK ? MSG_LEN % 128 : 128;
    localparam PIPE_G0 = 2 + NUM_ROUNDS*2 + g0*(NUM_ROUNDS*2 + 2);   
    
    // Each pass after 0 has a shift register for storing that part of the message
    if_axi_stream #(.DAT_BYTS(SR_MSG_BYTS)) msg_in(clk);
    if_axi_stream #(.DAT_BYTS(SR_MSG_BYTS)) msg_out(clk);
    
    // At the end of each round are two pipeline stages for updating
    // the local state
    always_ff @ (posedge i_clk) begin
      if (i_rst) begin
        valid[PIPE_G0] <= 0;
        valid[PIPE_G0+1] <= 0;
      end else begin
        if (o_hash.rdy) begin
          valid[PIPE_G0] <= valid[PIPE_G0-1];
          valid[PIPE_G0+1] <= valid[PIPE_G0];
        end
      end
    end
    
    always_ff @ (posedge i_clk) begin
      msg_out.rdy <= 0;
      // First stage
      // Some pipelines not used in this stage
      msg[PIPE_G0] <= 0; 
      ctl[PIPE_G0] <= 0;
      v[PIPE_G0] <= 1;  
      if (o_hash.rdy) begin
        for (int i = 0; i < 8; i++)
          h[PIPE_G0][i] <= h[PIPE_G0-1][i] ^ v[PIPE_G0-1][i] ^ v[PIPE_G0-1][i+8];
      end
      // Second stage
      if (o_hash.rdy) begin
        h[PIPE_G0+1] <= h[PIPE_G0];      
        init_local_work_vector_pipe(PIPE_G0+2, LAST_BLOCK);
        // Need to pull msg and ctl from the shift register if we have more than one pass
        // and we fully unrolled. Otherwise next input will be on input. Assert the control
        // matches.
        msg_out.rdy <= 1;
        if (g0 > 0) begin
          msg[PIPE_G0+1] <= msg_out.dat;
          ctl[PIPE_G0+1] <= msg_out.ctl;
        end else begin
          msg[PIPE_G0+1] <= 0;
          ctl[PIPE_G0+1] <= 0;
        end
      end

    end
      
    if (g0 > 0 && FULLY_UNROLL != 0) begin: GEN_MSG_FIFO
          
      always_ff @ (posedge i_clk) begin
        if (msg_in.val && msg_in.rdy) begin
          msg_in.dat <= i_block.dat[128*8*g0 :+ 128*8];
          msg_in.sop <= 0;
          msg_in.eop <= 0;
          msg_in.err <= 0;
          msg_in.ctl <= i_block.ctl;
          msg_in.mod <= LAST_BLOCK ? i_block.mod : 0;
        end
      end
      
      always_comb begin
        if (g0 == 0) i_block.rdy = msg_in.rdy;
        msg_in.val = i_block.val;
      end
      
      axi_stream_fifo #(
        .A_BITS   ( $clog2(NUM_ROUNDS + 2) ),
        .DAT_BITS ( 128*8                  ),
        .CTL_BITS ( CTL_BITS               )
      )
      message_fifo (
        .i_clk ( i_clk   ),
        .i_rst ( i_rst   ),
        .i_axi ( msg_in  ),
        .o_axi ( msg_out )
      );
    
    end

    for (g1 = 0; g1 < NUM_ROUNDS; g1++) begin: GEN_ROUND
      for (g2 = 0; g2 < 2; g2++) begin: GEN_G_FUNC
        
        // Each pipeline stage has 4 G function blocks in parallel
        localparam PIPE_G2 = 2 + g0*(2 + NUM_ROUNDS*2) + g1*2 + g2;
        
        always_ff @(posedge i_clk) begin
          if (i_rst) begin
            valid[PIPE_G2] <= 0;
          end else begin
            if (o_hash.rdy) valid[PIPE_G2] <= valid[PIPE_G2-1];
          end
        end
        
        always_ff @(posedge i_clk) begin
          if (o_hash.rdy) begin
            msg[PIPE_G2] <= msg[PIPE_G2-1];
            //if (PIPE_G2 != PIPE_G0)
              h[PIPE_G2] <= h[PIPE_G2-1];
            ctl[PIPE_G2] <= ctl[PIPE_G2-1]; // TODO could remove?
          end
        end
        
        for (g3 = 0; g3 < 4; g3++) begin: GEN_G_FUNC_COL_DIAG
          
          blake2b_g
            #( .PIPELINES(1) )
          blake2b_g (
            .i_clk(i_clk),
            .i_a(g2 == 0 ? v[PIPE_G2-1][blake2b_pkg::G_MAPPING[(g3*4 + 0)]] : v[PIPE_G2-1][blake2b_pkg::G_MAPPING[16 + (g3*4 + 0)]]),
            .i_b(g2 == 0 ? v[PIPE_G2-1][blake2b_pkg::G_MAPPING[(g3*4 + 1)]] : v[PIPE_G2-1][blake2b_pkg::G_MAPPING[16 + (g3*4 + 1)]]),
            .i_c(g2 == 0 ? v[PIPE_G2-1][blake2b_pkg::G_MAPPING[(g3*4 + 2)]] : v[PIPE_G2-1][blake2b_pkg::G_MAPPING[16 + (g3*4 + 2)]]),
            .i_d(g2 == 0 ? v[PIPE_G2-1][blake2b_pkg::G_MAPPING[(g3*4 + 3)]] : v[PIPE_G2-1][blake2b_pkg::G_MAPPING[16 + (g3*4 + 3)]]),
            .i_m0(msg[PIPE_G2-1][blake2b_pkg::SIGMA[16*(g1%10) + g2*8 + g3*2]]),
            .i_m1(msg[PIPE_G2-1][blake2b_pkg::SIGMA[16*(g1%10) + g2*8 + g3*2 + 1]]),
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
task init_local_work_vector_pipe(input integer j, input last_block);
begin
  for (int i = 0; i < 16; i++)
    case (i) inside
      0,1,2,3,4,5,6,7: v[j][i] <= h[j-1][i];
      8,9,10,11: v[j][i] <= blake2b_pkg::IV[i%8];
      12: v[j][i] <= blake2b_pkg::IV[i%8] ^ (last_block ? (MSG_LEN % 128) : j*128);
      13: v[j][i] <= blake2b_pkg::IV[i%8] ^ j*128 >> 64;
      14: v[j][i] <= blake2b_pkg::IV[i%8] ^ {64{last_block}};
      15: v[j][i] <= blake2b_pkg::IV[i%8];
    endcase
end
endtask

endmodule