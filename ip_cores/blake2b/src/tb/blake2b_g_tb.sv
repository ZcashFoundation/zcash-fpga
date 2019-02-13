module blake2_g_tb();

logic clk;
logic [63:0] o_a, o_b, o_c, o_d, i_a, i_b, i_c, i_d, i_m0, i_m1;
localparam PIPELINES = 1;

blake2_g #(.PIPELINES(PIPELINES)) DUT (.i_clk(clk), .o_a(o_a), .o_b(o_b), .o_c(o_c), .o_d(o_d), .i_a(i_a), .i_b(i_b), .i_c(i_c), .i_d(i_d), .i_m0(i_m0), .i_m1(i_m1));

initial begin
  clk = 0;
  forever #10ns clk = ~clk;
end

task test1();
begin
  @(posedge clk)
  i_a      = 64'h6a09e667f2bdc948;
  i_b      = 64'h510e527fade682d1;
  i_c      = 64'h6a09e667f3bcc908;
  i_d      = 64'h510e527fade68251;
  i_m0     = 64'h0000000000000000;
  i_m1     = 64'h0000000000000000;

  repeat (PIPELINES) @(posedge clk);

  #1;
  assert (o_a == 64'hf0c9aa0de38b1b89) else $fatal(0, "%m %t:ERROR, o_a did not match", $time);
  assert (o_b == 64'hbbdf863401fde49b) else $fatal(0, "%m %t:ERROR, o_b did not match", $time);
  assert (o_c == 64'he85eb23c42183d3d) else $fatal(0, "%m %t:ERROR, o_c did not match", $time);
  assert (o_d == 64'h7111fd8b6445099d) else $fatal(0, "%m %t:ERROR, o_d did not match", $time);

  $display("test1 PASSED");
end
endtask

// Main testbench calls

initial begin
  #100ns;
  test1();

  #100ns $finish();

end

endmodule