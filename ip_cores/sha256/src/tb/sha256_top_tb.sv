/*
  The SHA256 testbench.
  
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

module sha256_top_tb();

import common_pkg::*;

logic clk, rst;
logic [255:0] expected;
if_axi_stream #(.DAT_BYTS(64)) i_block(clk);
if_axi_stream #(.DAT_BYTS(32)) out_hash(clk);

initial begin
  rst = 0;
  #100ns rst = 1;
  #100ns rst = 0;
end

initial begin
  clk = 0;
  forever #10ns clk = ~clk;
end

sha256_top DUT (
  .i_clk   ( clk      ),
  .i_rst   ( rst      ),
  .i_block ( i_block  ),
  .o_hash  ( out_hash )
);


// NIST testcase for single 512 bit block "abc"
task nist_single_block_test();
  begin
    integer signed get_len;
    logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
    $display("Running nist_single_block_test...\n");
    expected = 'had1500f261ff10b49c7a1796a36103b02322ae5dde404141eacf018fbf1678ba;  // Both in little endian
    i_block.put_stream("cba", 3); // abc in little endian
    out_hash.get_stream(get_dat, get_len);
    common_pkg::compare_and_print(get_dat, expected);
    $display("nist_single_block_test PASSED");
  end
endtask

// NIST testcase for double 512 bit block "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
task nist_double_block_test();
  begin
    integer signed get_len;
    logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
    $display("Running nist_double_block_test...\n");
    expected = 'hc106db19d4edecf66721ff6459e43ca339603e0c9326c0e5b83806d2616a8d24;  // Both in little endian
    i_block.put_stream("qponponmonmlnmlkmlkjlkjikjihjihgihgfhgfegfedfedcedcbdcba", 56);
    out_hash.get_stream(get_dat, get_len);
    common_pkg::compare_and_print(get_dat, expected);
    $display("nist_double_block_test PASSED");
  end
endtask


// Main testbench calls
initial begin
  i_block.reset_source();
  out_hash.rdy = 1;
  
  #200ns;

  nist_single_block_test();
  nist_double_block_test();

  #10us $finish();

end

endmodule