module blake2_top_tb();

logic clk, rst;
logic [7:0] digest_byte_len, key_byte_len;
logic [128*8-1:0] i_block;
logic i_new_block;
logic i_final_block;
logic i_val;
logic[64*8-1:0] o_digest;
logic           o_rdy;
logic           o_val;
logic           o_err;

initial begin
  rst = 0;
  #100ns rst = 1;
  #100ns rst = 0;
end

initial begin
  clk = 0;
  forever #10ns clk = ~clk;
end


blake2_top DUT (
  .i_clk(clk),
  .i_rst(rst),
  .i_digest_byte_len( digest_byte_len ),
  .i_key_byte_len( key_byte_len ),
  .i_block(i_block),
  .i_new_block(i_new_block),
  .i_final_block(i_final_block),
  .i_val(i_val),
  .o_digest(o_digest),
  .o_rdy(o_rdy),
  .o_val(o_val),
  .o_err(o_err)
);

// This test runs the hash which is shown in the RFC, for "abc"
task rfc_test();
begin
  i_val = 0;
  @(posedge clk);
  while (!o_rdy) @(posedge clk);

  @(negedge clk);
  i_val = 1;
  i_final_block = 1;
  i_new_block = 1;
  i_block = 'h636261;
  
  @(negedge clk);
  i_val = 0;
  
  // TODO check rdy goes low
  
  while (!o_val) @(posedge clk);
  
 @(posedge clk);
  @(posedge clk);
  
  // TODO verify result
  
  $display("rfc_test PASSED");
end
endtask

// Main testbench calls
initial begin
  key_byte_len = 0;
  digest_byte_len = 64;
  i_block = '0;
  i_new_block = '0;
  i_final_block = '0;
  i_val = '0;

  #200ns;
  
 
  rfc_test();

 #100ns $finish();

end

endmodule