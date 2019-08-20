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

module ec_fp6_arithmetic_tb ();
import common_pkg::*;
import bls12_381_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

parameter type FE_TYPE  = bls12_381_pkg::fe_t;
parameter type FE2_TYPE = bls12_381_pkg::fe2_t;
parameter type FE6_TYPE = bls12_381_pkg::fe6_t;
parameter P             = bls12_381_pkg::P;

`define MULT_FUNC(K, IN_POINT) fp2_point_mult(K, IN_POINT);
`define PRINT_FUNC(IN_POINT)   print_fp2_jb_point(IN_POINT);
`define G_POINT                bls12_381_pkg::g2_point
`define TO_AFFINE              bls12_381_pkg::fp2_to_affine

localparam CTL_BITS = 24;
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(24)) mul_fe_in_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(24)) mul_fe_out_if(clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(24)) add_fe_in_if[2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(24)) add_fe_out_if[2:0] (clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(24)) sub_fe_in_if[2:0] (clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(24)) sub_fe_out_if[2:0] (clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(24)) mul_fe2_o_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(24)) mul_fe2_i_if(clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(24)) add_fe2_o_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(24)) add_fe2_i_if(clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(24)) sub_fe2_o_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(24)) sub_fe2_i_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(24)) mnr_fe2_o_if(clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(24)) mnr_fe2_i_if(clk);

if_axi_stream #(.DAT_BYTS((2*$bits(FE6_TYPE)+7)/8), .CTL_BITS(24)) mul_fe6_o_if(clk);
if_axi_stream #(.DAT_BYTS(($bits(FE6_TYPE)+7)/8), .CTL_BITS(24)) mul_fe6_i_if(clk);
if_axi_stream #(.DAT_BYTS((2*$bits(FE6_TYPE)+7)/8), .CTL_BITS(24)) add_fe6_o_if(clk);
if_axi_stream #(.DAT_BYTS(($bits(FE6_TYPE)+7)/8), .CTL_BITS(24)) add_fe6_i_if(clk);
if_axi_stream #(.DAT_BYTS((2*$bits(FE6_TYPE)+7)/8), .CTL_BITS(24)) sub_fe6_o_if(clk);
if_axi_stream #(.DAT_BYTS(($bits(FE6_TYPE)+7)/8), .CTL_BITS(24)) sub_fe6_i_if(clk);

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #(CLK_PERIOD/2) clk = ~clk;
end

ec_fe2_arithmetic #(
  .FE_TYPE ( FE_TYPE  ),
  .FE2_TYPE( FE2_TYPE ),
  .OVR_WRT_BIT ( 8        ),
  .CTL_BITS    ( CTL_BITS  )
)
ec_fe2_arithmetic (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_fp_mode ( 1'd0 ),
  .o_mul_fe_if ( mul_fe_in_if  ),
  .i_mul_fe_if ( mul_fe_out_if ),
  .o_add_fe_if ( add_fe_in_if[0]  ),
  .i_add_fe_if ( add_fe_out_if[0] ),
  .o_sub_fe_if ( sub_fe_in_if[0]  ),
  .i_sub_fe_if ( sub_fe_out_if[0] ),
  .o_mul_fe2_if ( mul_fe2_i_if  ),
  .i_mul_fe2_if ( mul_fe2_o_if ),
  .o_add_fe2_if ( add_fe2_i_if  ),
  .i_add_fe2_if ( add_fe2_o_if ),
  .o_sub_fe2_if ( sub_fe2_i_if  ),
  .i_sub_fe2_if ( sub_fe2_o_if )
);

ec_fe6_arithmetic #(
  .FE_TYPE ( FE_TYPE  ),
  .FE2_TYPE( FE2_TYPE ),
  .FE6_TYPE( FE6_TYPE ),
  .OVR_WRT_BIT ( 0        ),
  .CTL_BITS    ( CTL_BITS  )
)
ec_fe6_arithmetic (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mul_fe2_if ( mul_fe2_o_if  ),
  .i_mul_fe2_if ( mul_fe2_i_if ),
  .o_add_fe2_if ( add_fe2_o_if  ),
  .i_add_fe2_if ( add_fe2_i_if ),
  .o_sub_fe2_if ( sub_fe2_o_if  ),
  .i_sub_fe2_if ( sub_fe2_i_if ),
  .o_mnr_fe2_if ( mnr_fe2_o_if  ),
  .i_mnr_fe2_if ( mnr_fe2_i_if ),  
  .o_mul_fe6_if ( mul_fe6_i_if  ),
  .i_mul_fe6_if ( mul_fe6_o_if ),
  .o_add_fe6_if ( add_fe6_i_if  ),
  .i_add_fe6_if ( add_fe6_o_if ),
  .o_sub_fe6_if ( sub_fe6_i_if  ),
  .i_sub_fe6_if ( sub_fe6_o_if )
);

fe2_mul_by_nonresidue #(
  .FE_TYPE ( FE_TYPE )
)
fe2_mul_by_nonresidue_i (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .o_mnr_fe2_if ( mnr_fe2_i_if ),
  .i_mnr_fe2_if ( mnr_fe2_o_if ),
  .o_add_fe_if ( add_fe_in_if[1] ),
  .i_add_fe_if ( add_fe_out_if[1] ),
  .o_sub_fe_if ( sub_fe_in_if[1] ),
  .i_sub_fe_if ( sub_fe_out_if[1] )
);

ec_fp_mult_mod #(
  .P             ( P   ),
  .KARATSUBA_LVL ( 3   ),
  .CTL_BITS      ( CTL_BITS  )
)
ec_fp_mult_mod (
  .i_clk( clk         ),
  .i_rst( rst         ),
  .i_mul ( mul_fe_in_if  ),
  .o_mul ( mul_fe_out_if )
);

adder_pipe # (
  .BITS     ( bls12_381_pkg::DAT_BITS ),
  .P        ( P   ),
  .CTL_BITS ( CTL_BITS  ),
  .LEVEL    ( 2   )
)
adder_pipe (
  .i_clk ( clk        ),
  .i_rst ( rst        ),
  .i_add ( add_fe_in_if[2]  ),
  .o_add ( add_fe_out_if[2] )
);

subtractor_pipe # (
  .BITS     ( bls12_381_pkg::DAT_BITS ),
  .P        ( P   ),
  .CTL_BITS ( CTL_BITS  ),
  .LEVEL    ( 2   )
)
subtractor_pipe (
  .i_clk ( clk        ),
  .i_rst ( rst        ),
  .i_sub ( sub_fe_in_if[2]  ),
  .o_sub ( sub_fe_out_if[2] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 16               ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_sub (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( sub_fe_in_if[1:0] ),
  .o_res ( sub_fe_in_if[2] ),
  .i_res ( sub_fe_out_if[2] ),
  .o_axi ( sub_fe_out_if[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 16               ),
  .PIPELINE_IN  ( 0                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_add (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_axi ( add_fe_in_if[1:0] ),
  .o_res ( add_fe_in_if[2] ),
  .i_res ( add_fe_out_if[2] ),
  .o_axi ( add_fe_out_if[1:0] )
);


task test_add();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  FE6_TYPE a, b, exp, out;
  $display("Running test_add() ...");

  for (int i = 0; i < 3; i++) begin
    for (int j = 0; j < 2; j++) begin
      a[i][j] = random_vector($bits(FE_TYPE)/8) % P;
      b[i][j] = random_vector($bits(FE_TYPE)/8) % P;
    end
  end

  exp = fe6_add(a, b);

  fork
    add_fe6_o_if.put_stream({a, b}, ((2*$bits(FE6_TYPE)+7)/8));
    add_fe6_i_if.get_stream(get_dat, get_len);
  join

  out = get_dat;

  $display("Input a:");
  print_fe6(a);
  $display("Input b:");
  print_fe6(b);
  $display("Expected:");
  print_fe6(exp);
  $display("Was:");
  print_fe6(out);

  if (exp != out) begin
    $fatal(1, "%m %t ERROR: test_add output was wrong", $time);
  end

  $display("test_add PASSED");

end
endtask;

task test_sub();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  FE6_TYPE a, b, exp, out;
  $display("Running test_sub() ...");

  for (int i = 0; i < 3; i++) begin
    for (int j = 0; j < 2; j++) begin
      a[i][j] = random_vector($bits(FE_TYPE)/8) % P;
      b[i][j] = random_vector($bits(FE_TYPE)/8) % P;
    end
  end

  exp = fe6_sub(a, b);

  fork
    sub_fe6_o_if.put_stream({b, a}, ((2*$bits(FE6_TYPE)+7)/8));
    sub_fe6_i_if.get_stream(get_dat, get_len);
  join

  out = get_dat;

  $display("Input a:");
  print_fe6(a);
  $display("Input b:");
  print_fe6(b);
  $display("Expected:");
  print_fe6(exp);
  $display("Was:");
  print_fe6(out);

  if (exp != out) begin
    $fatal(1, "%m %t ERROR: test_sub output was wrong", $time);
  end

  $display("test_sub PASSED");

end
endtask;

task test_mul();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  FE6_TYPE a, b, exp, out;
  integer start_time, finish_time;
  $display("Running test_mul() ...");
  
  for (int loop = 0; loop < 10; loop++) begin
    $display("loop %d", loop);
    for (int i = 0; i < 3; i++) begin
      for (int j = 0; j < 2; j++) begin
        a[i][j] = random_vector($bits(FE_TYPE)/8) % P;
        b[i][j] = random_vector($bits(FE_TYPE)/8) % P;
      end
    end
   
    exp = fe6_mul(a, b);
    start_time = $time;
    fork
      mul_fe6_o_if.put_stream({b, a}, ((2*$bits(FE6_TYPE)+7)/8));
      mul_fe6_i_if.get_stream(get_dat, get_len);
    join
    finish_time = $time;
  
    out = get_dat;
  
    $display("Input a:");
    print_fe6(a);
    $display("Input b:");
    print_fe6(b);
    $display("Expected:");
    print_fe6(exp);
    $display("Was:");
    print_fe6(out);
    
    $display("Test took %d clocks", (finish_time-start_time)/CLK_PERIOD);
  
    if (exp != out) begin
      $fatal(1, "%m %t ERROR: test_mul output was wrong", $time);
    end
  end

  $display("test_mul PASSED");

end
endtask;


initial begin
  #(40*CLK_PERIOD);

  mul_fe6_o_if.reset_source();
  mul_fe6_i_if.rdy <= 0;
  add_fe6_o_if.reset_source();
  add_fe6_i_if.rdy <= 0;
  sub_fe6_o_if.reset_source();
  sub_fe6_i_if.rdy <= 0;
  
  test_add();
  test_sub();
  test_mul();

  $display("all tests PASSED!!!");

  #1us $finish();
end
endmodule