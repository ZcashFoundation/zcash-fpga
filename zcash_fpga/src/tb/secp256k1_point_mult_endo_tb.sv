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

module secp256k1_point_mult_endo_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(256*3/8)) in_if(clk);
if_axi_stream #(.DAT_BYTS(256*3/8)) out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mult_out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mod_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mod_out_if(clk);

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
  mod_out_if.sop = 1;
  mod_out_if.eop = 1;
  mod_out_if.mod = 0;
end

  secp256k1_point_mult_endo secp256k1_point_mult_endo (
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
    .o_mod_if ( mod_in_if ),
    .i_mod_if ( mod_out_if ),
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

secp256k1_mod #(
  .USE_MULT ( 0 ),
  .CTL_BITS ( 16 )
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
    out_if.get_stream(get_dat, get_len, 0);
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
  
  // small k        
  test(0, 
       256'd100,
       {x:256'd58873311125979645330689234758693990322142718482440736004992395581543649864914,
       y:256'd47377800525027909577048237938220344060490567826003050245752695071342182390566,
       z:256'd51761553477962655215909011819833151162194986797617471671622162861494790249339},
       {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'h1}); 
       
   // non-generator point    
   test(1, 
      256'd88597706962255542391918876972219263734377338585627945549538415112195940452672,
      {x:256'd80552615195390186547923971127606116870109658210822194698567280189432004385386,
      y:256'd55329616680323056768790645890299667681467256304685784433459139116355568202824,
      z:256'd59220439792108354484526017468353461062276312804340225301633930264091097218632},
      {x:256'd58873311125979645330689234758693990322142718482440736004992395581543649864914,
      y:256'd47377800525027909577048237938220344060490567826003050245752695071342182390566,
      z:256'd51761553477962655215909011819833151162194986797617471671622162861494790249339});
          
  // k1 is positive, k2 is negative here
  test(2, 
       256'd36644297199723006697238902796853752627288044630575801382304802161070535512204,
       {x:256'd45213033352668070164952185425578516070995776451206690854440958351598421068498,
       y:256'd85642664275538481518837161207205935282875677695988033260377207212529188560350,
       z:256'd46619474838719077565729441946941961955107434058466874326193136242340363932614},
       {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'h1});                               

// k1 and k2 is positive
  test(3, 
       256'd55241786844846723798409522554861295376012334658573106804016642051374977891741,
       {x:256'd76090149308608015449280928223196394375371085422355638787623027177573248394427,
       y:256'd52052533613727108316308539229264312767646640577338787268425139698990399010025,
       z:256'd114906227987603512981917844669318868106181860518720331222560351511921461319286},
       {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'h1});
       
       


  #1us $finish();
end
endmodule