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


// This test runs the hash which is shown in the RFC, for "abc"
task rfc_test();
  begin
    integer signed get_len;
    logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
    $display("Running rfc_test...\n");
    expected = 'h239900d4ed8623b95a92f1dba88ad31895cc3345ded552c22d79ab2a39c5877dd1a2ffdb6fbb124bb7c45a68142f214ce9f6129fb697276a0d4d1c983fa580ba;
    i_block.put_stream("cba", 3);
    out_hash.get_stream(get_dat, get_len);
    common_pkg::compare_and_print(get_dat, expected);
    $display("rfc_test PASSED");
  end
endtask


// Main testbench calls
initial begin
  i_block.reset_source();
  out_hash.rdy = 1;
  
  #200ns;

  rfc_test();

  #10us $finish();

end

endmodule