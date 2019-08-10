/*
  This provides the interface to perform Fp2 inversion

  Inputs must be interleaved starting at c0 (i.e. clock 0 = {b.c0, a.c0})
  _s in the name represents the input is a stream starting at c0.

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

module ec_fe2_inv_s
#(
  parameter type FE_TYPE,                // Base field element type
  parameter      OVR_WRT_BIT = 8    // We use 2 bits
)(
  input i_clk, i_rst,
  // Interface to FE2_TYPE inverter (mod P) FE_TYPE data width
  if_axi_stream.source o_inv_fe2_if,
  if_axi_stream.sink   i_inv_fe2_if,
  // Interface to FE_TYPE inverter (mod P) FE_TYPE data width
  if_axi_stream.source o_inv_fe_if,
  if_axi_stream.sink   i_inv_fe_if,  
  // Interface to FE_TYPE mul (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_mul_fe_if,
  if_axi_stream.sink   i_mul_fe_if,
  // Interface to FE_TYPE add (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_add_fe_if,
  if_axi_stream.sink   i_add_fe_if,
  // Interface to FE_TYPE sub (mod P) 2*FE_TYPE data width
  if_axi_stream.source o_sub_fe_if,
  if_axi_stream.sink   i_sub_fe_if
);

localparam NUM_OVR_WRT = 2;

FE_TYPE [3:0] t; // Temp storage
logic [2:0] add_cnt, sub_cnt, inv_cnt, mul_cnt, out_cnt;
logic start, t_val, t1_sub_val;

// Point addtions are simple additions on each of the Fp elements
always_comb begin
  i_inv_fe2_if.rdy = ~start;

  i_inv_fe_if.rdy = start;

  i_add_fe_if.rdy = (~o_inv_fe_if.val || (o_inv_fe_if.val && o_inv_fe_if.rdy));

  i_sub_fe_if.rdy = 1;

  case (i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT]) inside
    0,1: i_mul_fe_if.rdy = 1;
    2,3: i_mul_fe_if.rdy = (~o_inv_fe2_if.val || (o_inv_fe2_if.val && o_inv_fe2_if.rdy));
    default: i_mul_fe_if.rdy = 0;
  endcase
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_inv_fe2_if.reset_source();
    o_add_fe_if.reset_source();
    o_sub_fe_if.reset_source();
    o_mul_fe_if.reset_source();
    o_inv_fe_if.reset_source();
    t <= 0;
    t_val <= 0;
    t1_sub_val <= 0;
    {add_cnt, sub_cnt, inv_cnt, mul_cnt} <= 0;
    start <= 0;
  end else begin

    if (o_inv_fe2_if.rdy) o_inv_fe2_if.val <= 0;
    if (o_add_fe_if.rdy) o_add_fe_if.val <= 0;
    if (o_sub_fe_if.rdy) o_sub_fe_if.val <= 0;
    if (o_mul_fe_if.rdy) o_mul_fe_if.val <= 0;
    if (o_inv_fe_if.rdy) o_inv_fe_if.val <= 0;


    if (i_inv_fe2_if.val && i_inv_fe2_if.rdy) begin
      if(i_inv_fe2_if.eop) start <= 1;
      if(i_inv_fe2_if.sop) begin
        o_inv_fe2_if.ctl <= i_inv_fe2_if.ctl;
      end
      t[1:0] <= {i_inv_fe2_if.dat, t[1]}; // Latch input
    end


    // Latch t0 and t1
    if (i_mul_fe_if.val && i_mul_fe_if.rdy && i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 0) begin
      t[2] <= i_mul_fe_if.dat;
    end

    if (i_mul_fe_if.val && i_mul_fe_if.rdy && i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 1) begin
      t[3] <= i_mul_fe_if.dat;
      t_val <= 1;
    end

    if (i_inv_fe_if.val && i_inv_fe_if.rdy) begin
      t[2] <= i_inv_fe_if.dat;
      t_val <= 1;
    end

    if (i_sub_fe_if.val && i_sub_fe_if.rdy) begin
      t[1] <= i_sub_fe_if.dat;
      t1_sub_val <= 1;
    end

    // Issue new operations
    case (mul_cnt) inside
      0: fe_mul(start, t[0], t[0]);
      1: fe_mul(1, t[1], t[1]);
      2: fe_mul(inv_cnt >= 1 && t_val, t[0], t[2]);
      3: fe_mul(t1_sub_val, t[1], t[2]);
    endcase

     case (add_cnt) inside
      0: begin
        fe_add(t_val, t[2], t[3]);
        if (t_val) t_val <= 0;
      end
    endcase

     case (inv_cnt) inside
      0: begin
        fe_inv(i_add_fe_if.val, i_add_fe_if.dat);
      end
    endcase

     case (sub_cnt) inside
      0: begin
        fe_sub(add_cnt >= 1, 0, t[1]);
      end
    endcase

    // Final output flow
    if (~o_inv_fe2_if.val || (o_inv_fe2_if.val && o_inv_fe2_if.rdy)) begin
      o_inv_fe2_if.sop <= out_cnt == 0;
      o_inv_fe2_if.eop <= out_cnt == 1;
      case (out_cnt) inside
        0: begin
          o_inv_fe2_if.dat <= i_mul_fe_if.dat;
          if (i_mul_fe_if.val && i_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] == 2) begin
            o_inv_fe2_if.val <= 1;
            out_cnt <= out_cnt + 1;
          end
        end
        1: begin
          o_inv_fe2_if.dat <= i_mul_fe_if.dat;
          if (i_mul_fe_if.val) begin
            o_inv_fe2_if.val <= 1;
            out_cnt <= out_cnt + 1;
          end
        end
        default: begin
          t <= 0;
          inv_cnt <= 0;
          mul_cnt <= 0;
          add_cnt <= 0;
          sub_cnt <= 0;
          out_cnt <= 0;
          start <= 0;
          t_val <= 0;
          t1_sub_val <= 0;
        end
      endcase
    end
  end
end


// Task for fe_mul
task fe_mul(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b);
  if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
    o_mul_fe_if.sop <= 1;
    o_mul_fe_if.eop <= 1;
    o_mul_fe_if.dat <= {b, a};
    o_mul_fe_if.val <= val;
    o_mul_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= mul_cnt;
    if(val) mul_cnt <= mul_cnt + 1;
  end
endtask

// Task for fe_add
task  fe_add(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b);
  if (~o_add_fe_if.val || (o_add_fe_if.val && o_add_fe_if.rdy)) begin
    o_add_fe_if.sop <= 1;
    o_add_fe_if.eop <= 1;
    o_add_fe_if.dat <= {b, a};
    o_add_fe_if.val <= val;
    o_add_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= add_cnt;
    if(val) add_cnt <= add_cnt + 1;
  end
endtask

// Task for fe_sub
task fe_sub(input logic val, input logic [$bits(FE_TYPE)-1:0] a, b);
  if (~o_sub_fe_if.val || (o_sub_fe_if.val && o_sub_fe_if.rdy)) begin
    o_sub_fe_if.sop <= 1;
    o_sub_fe_if.eop <= 1;
    o_sub_fe_if.dat <= {b, a};
    o_sub_fe_if.val <= val;
    o_sub_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= sub_cnt;
    if(val) sub_cnt <= sub_cnt + 1;
  end
endtask

// Task for fe_inv
task fe_inv(input logic val, input logic [$bits(FE_TYPE)-1:0] a);
  if (~o_inv_fe_if.val || (o_inv_fe_if.val && o_inv_fe_if.rdy)) begin
    o_inv_fe_if.sop <= 1;
    o_inv_fe_if.eop <= 1;
    o_inv_fe_if.dat <= a;
    o_inv_fe_if.val <= val;
    o_inv_fe_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT] <= inv_cnt;
    if(val) inv_cnt <= inv_cnt + 1;
  end
endtask


endmodule