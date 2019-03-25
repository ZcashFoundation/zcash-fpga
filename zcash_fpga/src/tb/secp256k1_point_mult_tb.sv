/*
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
`timescale 1ps/1ps

module secp256k1_point_mult_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(256*3/8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(256*3/8)) out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mult_out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mod_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mod_out_if(clk);

jb_point_t in_p, out_p;
logic [255:0] k_in;

always_comb begin
  in_p = in_if.dat; 
  out_if.dat = out_p;
end

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #(CLK_PERIOD/2) clk = ~clk;
end

always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
  out_if.ctl = 0;
  out_if.mod = 0;
end

// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err) begin
    out_if.rdy = 1;
    $error(1, "%m %t ERROR: output .err asserted", $time);
  end

always_comb begin
  mult_out_if.sop = 1;
  mult_out_if.eop = 1;
  mult_out_if.mod = 0;
  mod_out_if.sop = 1;
  mod_out_if.eop = 1;
  mod_out_if.mod = 0;  
end

secp256k1_point_mult #(
  .RESOURCE_SHARE ("YES")
  )
secp256k1_point_mult (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_p   ( in_if.dat  ),
  .i_k   ( k_in       ),
  .i_val ( in_if.val  ),
  .o_rdy ( in_if.rdy  ),
  .o_p   ( out_p      ),
  .i_rdy ( out_if.rdy ),
  .o_val ( out_if.val ),
  .o_err ( out_if.err ),
  .o_mult_if ( mult_in_if ),
  .i_mult_if ( mult_out_if ),
  .o_mod_if ( mod_in_if ),
  .i_mod_if ( mod_out_if )
);

secp256k1_mult_mod #(
  .CTL_BITS ( 8 )
)
secp256k1_mult_mod (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_dat_a ( mult_in_if.dat[0 +: 256] ),
  .i_dat_b ( mult_in_if.dat[256 +: 256] ),
  .i_val ( mult_in_if.val ),
  .i_err ( mult_in_if.err ),
  .i_ctl ( mult_in_if.ctl ),
  .i_cmd (1'd0            ),
  .o_rdy ( mult_in_if.rdy ),
  .o_dat ( mult_out_if.dat ),
  .i_rdy ( mult_out_if.rdy ),
  .o_val ( mult_out_if.val ),
  .o_ctl ( mult_out_if.ctl ),
  .o_err ( mult_out_if.err ) 
);

secp256k1_mod #(
  .USE_MULT ( 0 ),
  .CTL_BITS ( 8 )
)
secp256k1_mod (
  .i_clk( clk       ),
  .i_rst( rst       ),
  .i_dat( mod_in_if.dat  ),
  .i_val( mod_in_if.val  ),
  .i_err( mod_in_if.err  ),
  .i_ctl( mod_in_if.ctl  ),
  .o_rdy( mod_in_if.rdy  ),
  .o_dat( mod_out_if.dat ),
  .o_ctl( mod_out_if.ctl ),
  .o_err( mod_out_if.err ),
  .i_rdy( mod_out_if.rdy ),
  .o_val( mod_out_if.val )
);

// Test a point
task test(input logic [255:0] k, jb_point_t p_exp);
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [255:0] in_a, in_b;
  integer start_time, finish_time;
  jb_point_t p_in, p_out;
  $display("Running test_0...");
  p_in = secp256k1_pkg::G_p;
  k_in = k;
  start_time = $time;
  fork
    in_if.put_stream(p_in, 256*3/8);
    out_if.get_stream(get_dat, get_len);
  join
  finish_time = $time;
  
  p_out = get_dat;
  
  if (p_exp != p_out) begin
    $display("Expected:");
    print_jb_point(p_exp);
    $display("Was:");
    print_jb_point(p_out);
    $fatal(1, "%m %t ERROR: test with k=%d was wrong", $time, integer'(k));
  end 

  $display("test with k=%d PASSED in %d clocks", integer'(k), (finish_time-start_time)/CLK_PERIOD);
end
endtask;


initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);

  test(1, {x:256'h79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798,
           y:256'h483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8,
           z:256'h1});

  test(2, {x:256'h7d152c041ea8e1dc2191843d1fa9db55b68f88fef695e2c791d40444b365afc2,
           y:256'h56915849f52cc8f76f5fd7e4bf60db4a43bf633e1b1383f85fe89164bfadcbdb,
           z:256'h9075b4ee4d4788cabb49f7f81c221151fa2f68914d0aa833388fa11ff621a970});
             
  test(3, {x:256'hca90ef9b06d7eb51d650e9145e3083cbd8df8759168862036f97a358f089848,
           y:256'h435afe76017b8d55d04ff8a98dd60b2ba7eb6f87f6b28182ca4493d7165dd127,
           z:256'h9242fa9c0b9f23a3bfea6a0eb6dbcfcbc4853fe9a25ee948105dc66a2a9b5baa});  
                      
  test(4, {x:256'h9bae2d5bac61e6ea5de635bca754b2564b7d78c45277cad67e45c4cbbea6e706,
           y:256'h34fb8147eed1c0fbe29ead4d6c472eb4ef7b2191fde09e494b2a9845fe3f605e,
           z:256'hc327b5d2636b32f27b051e4742b1bbd5324432c1000bfedca4368a29f6654152});
           
  test(1514155, {x:256'h759267d17957f567381462db6e240b75c9f6016091a7427cfbef33c398964a9d,
                 y:256'hd81ce7034647587a9b0ea5b52ac08c91f5cfae30f4eba2ade7fa68856fc0d691,
                 z:256'h7c9d27fb2de7927c982792630a0c86f411f2de60e8df44c5e9caff976658009c});

  #1us $finish();
end
endmodule