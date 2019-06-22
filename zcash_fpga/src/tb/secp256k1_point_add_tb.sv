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

module secp256k1_point_add_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(256*6/8)) in_if(clk); // Two points
if_axi_stream #(.DAT_BYTS(256*3/8)) out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mult_out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) add_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) add_out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) sub_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) sub_out_if(clk);

jb_point_t in_p1, in_p2, out_p;

always_comb begin
  in_p1 = in_if.dat[0 +: 256*3];
  in_p2 = in_if.dat[256*3 +: 256*3];
  out_if.dat = out_p;
end

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
  out_if.ctl = 0;
  out_if.mod = 0;
end

// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err)
    $error(1, "%m %t ERROR: output .err asserted", $time);

ec_point_add #(
  .FP_TYPE ( jb_point_t ),
  .FE_TYPE ( fe_t )
)
ec_point_add (
  .i_clk ( clk ),
  .i_rst ( rst ),
    // Input points
  .i_p1  ( in_p1      ),
  .i_p2  ( in_p2      ),
  .i_val ( in_if.val ),
  .o_rdy ( in_if.rdy ),
  .o_p   ( out_p     ),
  .o_err ( out_if.err ),
  .i_rdy ( out_if.rdy ),
  .o_val  ( out_if.val ) ,
  .o_mul_if ( mult_in_if ),
  .i_mul_if ( mult_out_if ),
  .o_add_if ( add_in_if ),
  .i_add_if ( add_out_if ),
  .o_sub_if ( sub_in_if ),
  .i_sub_if ( sub_out_if )
);

always_comb begin
  mult_out_if.sop = 1;
  mult_out_if.eop = 1;
  mult_out_if.err = 1;
  mult_out_if.mod = 1;
end

// Attach a mod reduction unit and multiply - mod unit
// In full design these could use dedicated multipliers or be arbitrated
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
  .i_cmd ( 2'd0           ),
  .o_rdy ( mult_in_if.rdy ),
  .o_dat ( mult_out_if.dat ),
  .i_rdy ( mult_out_if.rdy ),
  .o_val ( mult_out_if.val ),
  .o_ctl ( mult_out_if.ctl ),
  .o_err ( mult_out_if.err )
);

always_comb begin
  add_in_if.rdy = add_out_if.rdy;
  sub_in_if.rdy = sub_out_if.rdy;
end

always_ff @ (posedge clk) begin

  add_out_if.val <= add_in_if.val;
  add_out_if.dat <= fe_add(add_in_if.dat[0 +: 256], add_in_if.dat[256 +: 256]);
  add_out_if.ctl <= add_in_if.ctl;

  sub_in_if.rdy <= sub_out_if.rdy;
  sub_out_if.val <= sub_in_if.val;
  sub_out_if.dat <= fe_sub(sub_in_if.dat[0 +: 256], sub_in_if.dat[256 +: 256]);
  sub_out_if.ctl <= sub_in_if.ctl;
  
end

task test(input integer index, input jb_point_t p1, p2);
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [255:0] in_a, in_b;
  jb_point_t p_exp, p_temp, p_out;
  $display("Running test %d ...", index);

  p_exp = add_jb_point(p1, p2);

  fork
    in_if.put_stream({p2, p1}, 256*6/8);
    out_if.get_stream(get_dat, get_len);
  join

  p_out = get_dat;

  $display("%d %d %d", on_curve(p1), on_curve(p2), on_curve(p_out));//, on_curve(p_temp));

  if (p_exp != p_out) begin
    $display("Expected:");
    print_jb_point(p_exp);
    $display("Was:");
    print_jb_point(p_out);
    $fatal(1, "%m %t ERROR: test_0 point was wrong", $time);
  end

  $display("test %d PASSED", index);
      $display("Expected:");
  print_jb_point(p_exp);
end
endtask;

initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);

 test(1,
       g_point,
       dbl_jb_point(g_point));
  test(2,
        {x:256'd21093662951128507222548537960537987883266099219826518477955151519492458533937,
        y:256'd11718937855299224635656538406325081070585145153119064354000306947171340794663,
        z:256'd95062982235784117998228889817699378193266444799407382177811223706903593950986},
        {x:256'd56542328592951707446199365077593875570107826996267232506335199217850131398833,
        y:256'd40054381197676821721097330834174068128555866625836435038947476656223470027610,
        z:256'd55019374069926147245812105698770268552109628033761289528651825525953166671152}
        );

  test(3,{x:256'd56542328592951707446199365077593875570107826996267232506335199217850131398833,
          y:256'd40054381197676821721097330834174068128555866625836435038947476656223470027610,
          z:256'd55019374069926147245812105698770268552109628033761289528651825525953166671152},
         {x:256'd21093662951128507222548537960537987883266099219826518477955151519492458533937,
          y:256'd11718937855299224635656538406325081070585145153119064354000306947171340794663,
          z:256'd95062982235784117998228889817699378193266444799407382177811223706903593950986}
          );

  test(4,
        {x:256'h79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798,
        y:256'h483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8,
        z:256'h1},
        {x:256'h7d152c041ea8e1dc2191843d1fa9db55b68f88fef695e2c791d40444b365afc2,
        y:256'h56915849f52cc8f76f5fd7e4bf60db4a43bf633e1b1383f85fe89164bfadcbdb,
        z:256'h9075b4ee4d4788cabb49f7f81c221151fa2f68914d0aa833388fa11ff621a970});
        
  test(5,
      {x:256'h7d152c041ea8e1dc2191843d1fa9db55b68f88fef695e2c791d40444b365afc2,
      y:256'h56915849f52cc8f76f5fd7e4bf60db4a43bf633e1b1383f85fe89164bfadcbdb,
      z:256'h9075b4ee4d4788cabb49f7f81c221151fa2f68914d0aa833388fa11ff621a970},
      {x:256'h79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798,
      y:256'h483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8,
      z:256'h1});

  #1us $finish();
end
endmodule