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

module secp256k1_point_mult_endo_decom_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(256*3/8)) in_if(clk);
if_axi_stream #(.DAT_BYTS((256*2+256*3)/8)) out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mult_out_if(clk);


jb_point_t in_p, out_p;
logic [255:0] k_in;
logic signed [255:0] k1_out, k2_out;

always_comb begin
  in_p = in_if.dat;
  out_if.dat = {k2_out, k1_out, out_p};
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
end


secp256k1_point_mult_endo_decom secp256k1_point_mult_endo_decom (
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
  .o_k1 ( k1_out ),
  .o_k2 ( k2_out ),
  .o_mult_if ( mult_in_if ),
  .i_mult_if ( mult_out_if )
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
task test(input integer index, input logic [255:0] k, jb_point_t p_exp, p_in, logic signed [255:0] k1_exp, k2_exp);
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  integer start_time, finish_time;
  jb_point_t  p_out;
  logic signed [255:0] k1, k2;
  $display("Running test %d...", index);
  k_in = k;
  start_time = $time;
  fork
    in_if.put_stream(p_in, 256*3/8);
    out_if.get_stream(get_dat, get_len, 0);
  join
  finish_time = $time;

  p_out = get_dat[3*256-1:0];
  k1 = get_dat[3*256 +: 256];
  k2 = get_dat[4*256 +: 256];
  
  if (p_exp != p_out || k1 != k1_exp || k2 != k2_exp) begin
    $display("Expected:");
    print_jb_point(p_exp);
    $display("k1 %h k2 %h", k1_exp, k2_exp);
    $display("Was:");
    print_jb_point(p_out);
    $display("k1 %h k2 %h", k1, k2);
    $fatal(1, "%m %t ERROR: test %d was wrong", $time, index);
  end

  $display("test %d PASSED in %d clocks", index, (finish_time-start_time)/CLK_PERIOD);
end
endtask;


initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);
  
test (0,
      256'd55241786844846723798409522554861295376012334658573106804016642051374977891741,
      {x:256'd85340279321737800624759429340272274763154997815782306132637707972559913914315,
       y:256'd32670510020758816978083085130507043184471273380659243275938904335757337482424, z:256'd1},
      {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'd1},
      256'd384458048086738728616354309893792094261,
      256'd5290804493113523428570938576690193618);
      
test (1,
        256'd529517403483370943333515471837290126144817603611185636669178179344924684232,
        {x:256'd85340279321737800624759429340272274763154997815782306132637707972559913914315,
         y:256'd32670510020758816978083085130507043184471273380659243275938904335757337482424, z:256'd1},
        {x:secp256k1_pkg::Gx, y:secp256k1_pkg::Gy, z:256'd1},
        256'd220390740267097681469989715867489183793,
        -256'd233066591111900161328361760514744826974);

  #1us $finish();
end
endmodule