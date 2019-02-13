module blake2b_top_tb();

import blake2b_pkg::*;
import common_pkg::*;

logic clk, rst;
logic [7:0] i_byte_len;
logic [64*8-1:0] parameters;

logic [64*8-1:0] expected;
if_axi_stream #(.DAT_BYTS(128)) i_block(clk);
if_axi_stream #(.DAT_BYTS(64)) out_hash(clk);

initial begin
  rst = 0;
  #100ns rst = 1;
  #100ns rst = 0;
end

initial begin
  clk = 0;
  forever #10ns clk = ~clk;
end


blake2b_top DUT (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_parameters ( parameters ),
  .i_byte_len   ( i_byte_len ),
  .i_block ( i_block ),
  .o_hash  ( out_hash )
);

// This test runs the hash which is shown in the RFC, for "abc"
task rfc_test();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  expected = 'h239900d4ed8623b95a92f1dba88ad31895cc3345ded552c22d79ab2a39c5877dd1a2ffdb6fbb124bb7c45a68142f214ce9f6129fb697276a0d4d1c983fa580ba;
  i_byte_len = 3;
  i_block.put_stream("cba", i_byte_len);
  out_hash.get_stream(get_dat, get_len);
  common_pkg::compare_and_print(get_dat, expected);
  $display("rfc_test PASSED");
end
endtask

// This is a test for hashing random string of 128 bytes
task test_128_bytes();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  expected = 'hd2a56bb7bb1ff1fffcf2f151522455e32969ddfeb409b105f45299b8cbd68eb370fd6d45d63981d23cd2686dfd9a76f5b1d134be076f7d08ecc457522042e34a;
  i_byte_len = 128;
  i_block.put_stream("monek14SFMpNgHz12zMfplMfcHkx6JhKhSWTNwzGiq8UiPa4n4Ehq363oHG92GPDVpvQut4ui5e6XxieeKTn1THLWiMZ0iaOFndxcT6FGPgmHXQ5zJU96X71zfWbvUQs", i_byte_len);
  out_hash.get_stream(get_dat, get_len);
  common_pkg::compare_and_print(get_dat, expected);
  $display("test_128_bytes PASSED");
end
endtask

// This is a test for hashing random string of 140 bytes (does two passes which is required for equihash)
task test_140_bytes();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  expected = 'h2012a869a3b89a69ffc954f6855c7f61a61190553dc487171ec3fe944d04c83cd4c842fff5a8258d5e14b05b7b6f30e8ddcb754d719137ec42fb5cdb562f8c89;
  i_byte_len = 140;
  i_block.put_stream("YbEAEzgJ1tgC3t6vDaJFqlWp1PaL482f7iZZzRj3xXpY2PPupwdTKAaBzB6KuN6j0alaoaFQfNboDbkNv5KDs5d7zN9JssrtOjGJdrVLfvb7uAdnVYoIgIv2zbXUQIPpwWdzEzj1CzX5", i_byte_len);
  out_hash.get_stream(get_dat, get_len);
  common_pkg::compare_and_print(get_dat, expected);
  $display("test_140_bytes PASSED");
end
endtask

// Main testbench calls
initial begin
  i_block.reset_source();
  i_byte_len = 3;
  out_hash.rdy = 1;
  parameters = {32'd0, 8'd1, 8'd1, 8'd0, 8'd64};
  #200ns;
  
  rfc_test();
  test_128_bytes();
  test_140_bytes();

 #10us $finish();

end

endmodule