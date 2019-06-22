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

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mult_out_if(clk);

jb_point_t in_p, out_p;
logic [255:0] k_in;


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
  .o_p   ( out_if.dat ),
  .i_rdy ( out_if.rdy ),
  .o_val ( out_if.val ),
  .o_err ( out_if.err ),
  .o_mult_if ( mult_in_if ),
  .i_mult_if ( mult_out_if ),
  .i_p2_val (0),
  .i_p2 (0 )
);

secp256k1_mult_mod #(
  .CTL_BITS ( 16 )
)
secp256k1_mult_mod (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_dat_a ( mult_in_if.dat[0 +: 256] ),
  .i_dat_b ( mult_in_if.dat[256 +: 256] ),
  .i_val ( mult_in_if.val ),
  .i_err ( mult_in_if.err ),
  .i_ctl ( mult_in_if.ctl ),
  .i_cmd ( mult_in_if.ctl[7:6] ),
  .o_rdy ( mult_in_if.rdy ),
  .o_dat ( mult_out_if.dat ),
  .i_rdy ( mult_out_if.rdy ),
  .o_val ( mult_out_if.val ),
  .o_ctl ( mult_out_if.ctl ),
  .o_err ( mult_out_if.err )
);


// Test a point
task test(input integer index, input logic [255:0] k, jb_point_t p_exp, p_in);
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  logic [255:0] in_a, in_b;
  integer start_time, finish_time;
  jb_point_t  p_out;
  $display("Running test %d ...", index);
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
    $fatal(1, "%m %t ERROR: test %d was wrong", $time, index);
  end

  $display("test %d PASSED in %d clocks", index, (finish_time-start_time)/CLK_PERIOD);
end
endtask;


initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);

  test(0,
       1, {x:256'h79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798,
       y:256'h483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8,
       z:256'h1},
       g_point);

  test(1,
       2, {x:256'h7d152c041ea8e1dc2191843d1fa9db55b68f88fef695e2c791d40444b365afc2,
       y:256'h56915849f52cc8f76f5fd7e4bf60db4a43bf633e1b1383f85fe89164bfadcbdb,
       z:256'h9075b4ee4d4788cabb49f7f81c221151fa2f68914d0aa833388fa11ff621a970},
       g_point);

  test(3,
       3, {x:256'hca90ef9b06d7eb51d650e9145e3083cbd8df8759168862036f97a358f089848,
       y:256'h435afe76017b8d55d04ff8a98dd60b2ba7eb6f87f6b28182ca4493d7165dd127,
       z:256'h9242fa9c0b9f23a3bfea6a0eb6dbcfcbc4853fe9a25ee948105dc66a2a9b5baa},
       {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'h1});

  test(4, 
       4, {x:256'h9bae2d5bac61e6ea5de635bca754b2564b7d78c45277cad67e45c4cbbea6e706,
       y:256'h34fb8147eed1c0fbe29ead4d6c472eb4ef7b2191fde09e494b2a9845fe3f605e,
       z:256'hc327b5d2636b32f27b051e4742b1bbd5324432c1000bfedca4368a29f6654152},
       {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'h1});
           
  test(5, 
       256'd55241786844846723798409522554861295376012334658573106804016642051374977891741,
       {x:256'd114452044609218547356220974436632746395277736533029276044444520652934189718100,
       y:256'd105574650075160330358790852048157558974413633249451800413065016023266456843289,
       z:256'd114502749188206279151476081115998896219274334632701318332065731739168923561257},
       {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'h1});
                    
  test(6, 
       256'd36644297199723006697238902796853752627288044630575801382304802161070535512204,
       {x:256'd19559730912111231547572828279398263948482589709742643847415187021767406006262,
       y:256'd56669196538343662577389952407416094360513459515269228018156259621856885572646,
       z:256'd93622651521811893405023705294943233553232134901881469090144140953361623198206},
       {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'h1});                               

  test(7,
       1514155, {x:256'h759267d17957f567381462db6e240b75c9f6016091a7427cfbef33c398964a9d,
       y:256'hd81ce7034647587a9b0ea5b52ac08c91f5cfae30f4eba2ade7fa68856fc0d691,
       z:256'h7c9d27fb2de7927c982792630a0c86f411f2de60e8df44c5e9caff976658009c},
       {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'h1});

  test(8,
       256'hbad45c59dcd6d81c6a96b46a678cb893c53decc8e57465bd84efa78676ccc64a,
       {x:256'he7e2b526cd2822c69ea688586501db564f28430319cdeb95cb38feb2c77fdfc3,
        y:256'h6dda26c3c991cfab33a12ed7b56a0afa17d375d8fa5cabe2d1d143bb21cab887,
        z:256'h2f8a851f9aec0f095a31472456a91cca12dd21da865e5a83e5d1b1085835c36c},
        {x:256'h808a2c66c5b90fa1477d7820fc57a8b7574cdcb8bd829bdfcf98aa9c41fde3b4,  // Not multiplying by generator
        y:256'heed249ffde6e46d784cb53b4df8c9662313c1ce8012da56cb061f12e55a32249,
        z:256'h1});

  #1us $finish();
end
endmodule