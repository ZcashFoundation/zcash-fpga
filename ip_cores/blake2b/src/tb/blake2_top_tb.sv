module blake2_top_tb();

import blake2_pkg::*;
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


blake2_top DUT (
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
  expected = 'h560c602c9cda1e198190f58e6341131f127367051c64f7df7d343e1b4c32a8bbc0eac1bcae463807dca442ae77d5150df700f6a640949a52cd4341dfc1e1044b;
  i_byte_len = 3;
  i_block.put_stream("hSV", i_byte_len);
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
  expected = 'h429b65332e3b6701a29664f98c247204858479f55a8c18cc9b0ffa321cda4288fd420a5d47d134949f3b858bff7a696a00d91a07c92055cdd597971cf573281c;
  i_byte_len = 140;
  i_block.put_stream("6RehRZqUdYD2SB3N35QlQhreiU2XEaSgIGUsreLqV49l8Z5r93FbP567Juqc1IUaVyJKv8qFmtQwXYvZdnrMacAs5H9hBhs5JxAfyDibIM3TjKyiVzXC8lfCqiN1j6fW8FSJY131mVpw", i_byte_len);
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
  //test_128_bytes();
  //test_140_bytes();

 #10us $finish();

end

endmodule