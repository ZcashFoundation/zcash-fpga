/*
  This performs Fp^2 point addition.
  Is a wrapper around the Fp point addition module, but with logic
  to handle the multiplications / subtractions / additions

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

module ec_fp2_point_dbl
#(
  parameter type FP2_TYPE,   // Should have FE2_TYPE elements
  parameter type FE_TYPE,
  parameter type FE2_TYPE
)(
  input i_clk, i_rst,
  // Input points
  input FP2_TYPE i_p,
  input logic    i_val,
  output logic   o_rdy,
  // Output point
  output FP2_TYPE o_p,
  input logic     i_rdy,
  output logic    o_val,
  output logic    o_err,
  // Interface to FE_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_if,
  if_axi_stream.sink   i_mul_if,
  // Interface to FE_TYPE adder (mod P)
  if_axi_stream.source o_add_if,
  if_axi_stream.sink   i_add_if,
  // Interface to FE_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_if,
  if_axi_stream.sink   i_sub_if
);

if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(8)) mul_if_fe2_i(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(8))   mul_if_fe2_o(i_clk);

localparam ADD_CTL_BIT = 8;
if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(8)) add_if_fe2_i(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(8))   add_if_fe2_o(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(16))   add_if_fe_i [2] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(16)) add_if_fe_o [2] (i_clk);

if_axi_stream #(.DAT_BITS(2*$bits(FE2_TYPE)), .CTL_BITS(8)) sub_if_fe2_i(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE2_TYPE)), .CTL_BITS(8))   sub_if_fe2_o(i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(16))   sub_if_fe_i [2] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(16)) sub_if_fe_o [2] (i_clk);




// Point addtions are simple additions on each of the Fp elements
enum {ADD0, ADD1} add_state;
always_comb begin
  add_if_fe2_i.rdy = add_state == ADD1 && (~add_if_fe_o[0].val || (add_if_fe_o[0].val && add_if_fe_o[0].rdy));
  add_if_fe_i[0].rdy = ~add_if_fe2_o.val || (add_if_fe2_o.val && add_if_fe2_o.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    add_if_fe2_o.reset_source();
    add_state <= ADD0;
    add_if_fe_o[0].reset_source();
  end else begin

    if (add_if_fe_o[0].val && add_if_fe_o[0].rdy) add_if_fe_o[0].val <= 0;
    if (add_if_fe2_o.val && add_if_fe2_o.rdy) add_if_fe2_o.val <= 0;

    // One process to parse inputs and send them to the adder
    case(add_state)
      ADD0: begin
        if (~add_if_fe_o[0].val || (add_if_fe_o[0].val && add_if_fe_o[0].rdy)) begin
          add_if_fe_o[0].copy_if({add_if_fe2_i.dat[0 +: $bits(FE_TYPE)],
                                  add_if_fe2_i.dat[$bits(FE2_TYPE) +: $bits(FE_TYPE)]},
                                  add_if_fe2_i.val, 1, 1, add_if_fe2_i.err, add_if_fe2_i.mod, add_if_fe2_i.ctl);
          add_if_fe_o[0].ctl[ADD_CTL_BIT] <= 0;
          if (add_if_fe2_i.val) add_state <= ADD1;
        end
      end
      ADD1: begin
        if (~add_if_fe_o[0].val || (add_if_fe_o[0].val && add_if_fe_o[0].rdy)) begin
          add_if_fe_o[0].copy_if({add_if_fe2_i.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)],
                                add_if_fe2_i.dat[$bits(FE2_TYPE)+$bits(FE_TYPE) +: $bits(FE_TYPE)]},
                                add_if_fe2_i.val, 1, 1, add_if_fe2_i.err, add_if_fe2_i.mod, add_if_fe2_i.ctl);
          add_if_fe_o[0].ctl[ADD_CTL_BIT] <= 1;
          if (add_if_fe2_i.val) add_state <= ADD0;
        end
      end
    endcase

    // One process to assign outputs
    if (~add_if_fe2_o.val || (add_if_fe2_o.val && add_if_fe2_o.rdy)) begin
      add_if_fe2_o.ctl <= add_if_fe_i[0].ctl;
      if (add_if_fe_i[0].ctl[ADD_CTL_BIT] == 0) begin
        if (add_if_fe_i[0].val)
          add_if_fe2_o.dat[0 +: $bits(FE_TYPE)] <= add_if_fe_i[0].dat;
      end else begin
        add_if_fe2_o.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= add_if_fe_i[0].dat;
        add_if_fe2_o.val <= add_if_fe_i[0].val;
      end
    end
  end
end

// Point subtractions are simple subtractions on each of the Fp elements
enum {SUB0, SUB1} sub_state;
always_comb begin
  sub_if_fe2_i.rdy = sub_state == ADD1 && (~sub_if_fe_o[0].val || (sub_if_fe_o[0].val && sub_if_fe_o[0].rdy));
  sub_if_fe_i[0].rdy = ~sub_if_fe2_o.val || (sub_if_fe2_o.val && sub_if_fe2_o.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    sub_if_fe2_o.reset_source();
    sub_state <= SUB0;
    sub_if_fe_o[0].reset_source();
  end else begin

    if (sub_if_fe_o[0].val && sub_if_fe_o[0].rdy) sub_if_fe_o[0].val <= 0;
    if (sub_if_fe2_o.val && sub_if_fe2_o.rdy) sub_if_fe2_o.val <= 0;

    // One process to parse inputs and send them to the subtractor
    case(sub_state)
      SUB0: begin
        if (~sub_if_fe_o[0].val || (sub_if_fe_o[0].val && sub_if_fe_o[0].rdy)) begin
          sub_if_fe_o[0].copy_if({sub_if_fe2_i.dat[0 +: $bits(FE_TYPE)],
                                  sub_if_fe2_i.dat[$bits(FE2_TYPE) +: $bits(FE_TYPE)]},
                                  sub_if_fe2_i.val, 1, 1, sub_if_fe2_i.err, sub_if_fe2_i.mod, sub_if_fe2_i.ctl);
          sub_if_fe_o[0].ctl[ADD_CTL_BIT] <= 0;
          if (sub_if_fe2_i.val) sub_state <= SUB1;
        end
      end
      SUB1: begin
        if (~sub_if_fe_o[0].val || (sub_if_fe_o[0].val && sub_if_fe_o[0].rdy)) begin
          sub_if_fe_o[0].copy_if({sub_if_fe2_i.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)],
                                sub_if_fe2_i.dat[$bits(FE_TYPE) + $bits(FE2_TYPE) +: $bits(FE_TYPE)]},
                                sub_if_fe2_i.val, 1, 1, sub_if_fe2_i.err, sub_if_fe2_i.mod, sub_if_fe2_i.ctl);
          sub_if_fe_o[0].ctl[ADD_CTL_BIT] <= 1;
          if (sub_if_fe2_i.val) sub_state <= SUB0;
        end
      end
    endcase

    // One process to assign outputs
    if (~sub_if_fe2_o.val || (sub_if_fe2_o.val && sub_if_fe2_o.rdy)) begin
      sub_if_fe2_o.ctl <= sub_if_fe_i[0].ctl;
      if (sub_if_fe_i[0].ctl[ADD_CTL_BIT] == 0) begin
        if (sub_if_fe_i[0].val)
          sub_if_fe2_o.dat[0 +: $bits(FE_TYPE)] <= sub_if_fe_i[0].dat;
      end else begin
        sub_if_fe2_o.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= sub_if_fe_i[0].dat;
        sub_if_fe2_o.val <= sub_if_fe_i[0].val;
      end
    end
  end
end

// Multiplications are calculated as (a + bi)x(a' +b'i) = (aa' - bb') + (ab' + a'b)i
// First 4 multiplications are issued, then 1 add and 1 subtraction (so we need arbitrator)
enum {MUL0, MUL1, MUL2, MUL3} mul_state;
logic [1:0] add_sub_val;
always_comb begin
  mul_if_fe2_i.rdy = mul_state == MUL3 && (~o_mul_if.val || (o_mul_if.val && o_mul_if.rdy));
  
  i_mul_if.rdy = (i_mul_if.ctl[ADD_CTL_BIT +: 2] == 0 || i_mul_if.ctl[ADD_CTL_BIT +: 2] == 1) ?
                  (~sub_if_fe_o[1].val || (sub_if_fe_o[1].val && sub_if_fe_o[1].rdy)) :
                  (~add_if_fe_o[1].val || (add_if_fe_o[1].val && add_if_fe_o[1].rdy));
  
  mul_if_fe2_o.val = &add_sub_val;
  sub_if_fe_i[1].rdy = ~add_sub_val[1] || (mul_if_fe2_o.val && mul_if_fe2_o.rdy);
  add_if_fe_i[1].rdy = ~add_sub_val[0] || (mul_if_fe2_o.val && mul_if_fe2_o.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    add_sub_val <= 0;
    mul_if_fe2_o.sop <= 0;
    mul_if_fe2_o.eop <= 0;
    mul_if_fe2_o.ctl <= 0;
    mul_if_fe2_o.dat <= 0;
    mul_if_fe2_o.mod <= 0;
    mul_state <= MUL0;
    o_mul_if.reset_source();
    sub_if_fe_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    add_if_fe_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
  end else begin

    if (mul_if_fe2_o.val && mul_if_fe2_o.rdy) begin
      add_sub_val <= 0;
    end
    if (o_mul_if.val && o_mul_if.rdy) o_mul_if.val <= 0;
    if (sub_if_fe_o[1].val && sub_if_fe_o[1].rdy) sub_if_fe_o[1].val <= 0;
    if (add_if_fe_o[1].val && add_if_fe_o[1].rdy) add_if_fe_o[1].val <= 0;

    // One process to parse inputs and send them to the multiplier
    if (~o_mul_if.val || (o_mul_if.val && o_mul_if.rdy)) begin
      case (mul_state)
        MUL0: begin
          o_mul_if.copy_if({mul_if_fe2_i.dat[0 +: $bits(FE_TYPE)],
                            mul_if_fe2_i.dat[$bits(FE2_TYPE)  +: $bits(FE_TYPE)]},
                            mul_if_fe2_i.val, 1, 1, mul_if_fe2_i.err, mul_if_fe2_i.mod, mul_if_fe2_i.ctl);
          o_mul_if.ctl[ADD_CTL_BIT +: 2] <= 0;
          if (mul_if_fe2_i.val) mul_state <= MUL1;
        end
        MUL1: begin
          o_mul_if.copy_if({mul_if_fe2_i.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)],
                            mul_if_fe2_i.dat[$bits(FE2_TYPE) + $bits(FE_TYPE) +: $bits(FE_TYPE)]},
                            mul_if_fe2_i.val, 1, 1, mul_if_fe2_i.err, mul_if_fe2_i.mod, mul_if_fe2_i.ctl);
          o_mul_if.ctl[ADD_CTL_BIT +: 2] <= 1;
          if (mul_if_fe2_i.val) mul_state <= MUL2;
        end
        MUL2: begin
          o_mul_if.copy_if({mul_if_fe2_i.dat[0 +: $bits(FE_TYPE)],
                            mul_if_fe2_i.dat[$bits(FE2_TYPE) + $bits(FE_TYPE) +: $bits(FE_TYPE)]},
                            mul_if_fe2_i.val, 1, 1, mul_if_fe2_i.err, mul_if_fe2_i.mod, mul_if_fe2_i.ctl);
          o_mul_if.ctl[ADD_CTL_BIT +: 2] <= 2;
          if (mul_if_fe2_i.val) mul_state <= MUL3;
        end
        MUL3: begin
          o_mul_if.copy_if({mul_if_fe2_i.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)],
                            mul_if_fe2_i.dat[$bits(FE2_TYPE)  +: $bits(FE_TYPE)]},
                            mul_if_fe2_i.val, 1, 1, mul_if_fe2_i.err, mul_if_fe2_i.mod, mul_if_fe2_i.ctl);
          o_mul_if.ctl[ADD_CTL_BIT +: 2] <= 3;
          if (mul_if_fe2_i.val) mul_state <= MUL0;
        end
      endcase
    end

    // Process multiplications and do subtraction
    if (~sub_if_fe_o[1].val || (sub_if_fe_o[1].val && sub_if_fe_o[1].rdy)) begin
      if (i_mul_if.ctl[ADD_CTL_BIT +: 2] == 0) begin
        if (i_mul_if.val) sub_if_fe_o[1].dat[0 +: $bits(FE_TYPE)] <= i_mul_if.dat;
      end
      if (i_mul_if.ctl[ADD_CTL_BIT +: 2] == 1) begin
        sub_if_fe_o[1].val <= i_mul_if.val;
        sub_if_fe_o[1].dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= i_mul_if.dat;
      end
      sub_if_fe_o[1].ctl <= i_mul_if.ctl;
    end

    // Process multiplications and do addition
    if (~add_if_fe_o[1].val || (add_if_fe_o[1].val && add_if_fe_o[1].rdy)) begin
      if (i_mul_if.ctl[ADD_CTL_BIT +: 2] == 2) begin
        if (i_mul_if.val) add_if_fe_o[1].dat[0 +: $bits(FE_TYPE)] <= i_mul_if.dat;
      end
      if (i_mul_if.ctl[ADD_CTL_BIT +: 2] == 3) begin
        add_if_fe_o[1].val <= i_mul_if.val;
        add_if_fe_o[1].dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= i_mul_if.dat;
      end
      add_if_fe_o[1].ctl <= i_mul_if.ctl;
    end

    // One process to assign output
    if (~add_sub_val[0] || (mul_if_fe2_o.val && mul_if_fe2_o.rdy)) begin
      mul_if_fe2_o.ctl <= add_if_fe_i[1].ctl;
      //if (~add_sub_val[0]) begin
        mul_if_fe2_o.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= add_if_fe_i[1].dat;
        add_sub_val[0] <= add_if_fe_i[1].val;
    end
    
    if (~add_sub_val[1] || (mul_if_fe2_o.val && mul_if_fe2_o.rdy)) begin
      //end
      //if (~add_sub_val[1]) begin
        mul_if_fe2_o.dat[0 +: $bits(FE_TYPE)] <= sub_if_fe_i[1].dat;
        add_sub_val[1] <= sub_if_fe_i[1].val;
      //end
    end
  end
end

ec_point_dbl #(
  .FP_TYPE ( FP2_TYPE ),
  .FE_TYPE ( FE2_TYPE )
)
ec_point_dbl (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
    // Input points
  .i_p   ( i_p  ),
  .i_val ( i_val ),
  .o_rdy ( o_rdy ),
  .o_p   ( o_p   ),
  .o_err ( o_err ),
  .i_rdy ( i_rdy ),
  .o_val ( o_val ) ,
  .o_mul_if ( mul_if_fe2_i ),
  .i_mul_if ( mul_if_fe2_o ),
  .o_add_if ( add_if_fe2_i  ),
  .i_add_if ( add_if_fe2_o  ),
  .o_sub_if ( sub_if_fe2_i  ),
  .i_sub_if ( sub_if_fe2_o  )
);

resource_share # (
  .NUM_IN ( 2 ),
  .OVR_WRT_BIT ( 10 ),
  .PIPELINE_IN ( 0  ),
  .PIPELINE_OUT ( 0 )
)
resource_share_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_if_fe_o ),
  .o_res ( o_sub_if    ),
  .i_res ( i_sub_if    ),
  .o_axi ( sub_if_fe_i )
);

resource_share # (
  .NUM_IN ( 2 ),
  .OVR_WRT_BIT ( 10 ),
  .PIPELINE_IN ( 0  ),
  .PIPELINE_OUT ( 0 )
)
resource_share_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_if_fe_o ),
  .o_res ( o_add_if    ),
  .i_res ( i_add_if    ),
  .o_axi ( add_if_fe_i )
);

endmodule