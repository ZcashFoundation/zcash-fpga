/*
  This provides the interface to perform
  Fp^12 point logic (adding, subtracting, multiplication), over a Fp6 tower.
  Fq12 is constructed as Fq6(w) / (w2 - γ) where γ = v

  TODO: Input control should be added to allow for sparse multiplication.

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

module ec_fe12_arithmetic
#(
  parameter type FE6_TYPE,
  parameter type FE12_TYPE,
  parameter CTL_BITS    = 12, 
  parameter OVR_WRT_BIT = 8       // From this bit 4 bits are used for internal control, 
                                  // 2 bits for resource sharing, 1 bit for square control, 1 bit for sparse mult by c0, c1, c4
)(
  input i_clk, i_rst,
  // Interface to FE6_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe6_if,
  if_axi_stream.sink   i_mul_fe6_if,
  // Interface to FE6_TYPE adder (mod P)
  if_axi_stream.source o_add_fe6_if,
  if_axi_stream.sink   i_add_fe6_if,
  // Interface to FE6_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe6_if,
  if_axi_stream.sink   i_sub_fe6_if,
  // Interface to FE6_TYPE multiply by non-residue
  if_axi_stream.source o_mnr_fe6_if,
  if_axi_stream.sink   i_mnr_fe6_if,
  // Interface to FE12_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe12_if,
  if_axi_stream.sink   i_mul_fe12_if,
  // Interface to FE12_TYPE adder (mod P)
  if_axi_stream.source o_add_fe12_if,
  if_axi_stream.sink   i_add_fe12_if,
  // Interface to FE12_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe12_if,
  if_axi_stream.sink   i_sub_fe12_if
);

localparam NUM_OVR_WRT_BIT = 4;
localparam SQR_BIT = OVR_WRT_BIT + 6;

if_axi_stream #(.DAT_BITS($bits(FE6_TYPE)), .CTL_BITS(CTL_BITS))   add_if_fe6_i [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE6_TYPE)), .CTL_BITS(CTL_BITS)) add_if_fe6_o [1:0] (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE6_TYPE)), .CTL_BITS(CTL_BITS))   sub_if_fe6_i [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE6_TYPE)), .CTL_BITS(CTL_BITS)) sub_if_fe6_o [1:0] (i_clk);

// Point addtions are simple additions on each of the Fp6 elements
logic add_cnt;
always_comb begin
  i_add_fe12_if.rdy = (add_cnt == 1) && (~add_if_fe6_o[0].val || (add_if_fe6_o[0].val && add_if_fe6_o[0].rdy));
  add_if_fe6_i[0].rdy = ~o_add_fe12_if.val || (o_add_fe12_if.val && o_add_fe12_if.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_add_fe12_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    add_cnt <= 0;
    add_if_fe6_o[0].copy_if(0, 0, 1, 1, 0, 0, 0);
  end else begin

    if (add_if_fe6_o[0].val && add_if_fe6_o[0].rdy) add_if_fe6_o[0].val <= 0;
    if (o_add_fe12_if.val && o_add_fe12_if.rdy) o_add_fe12_if.val <= 0;

    // One process to parse inputs and send them to the adder
    case(add_cnt)
      0: begin
        if (~add_if_fe6_o[0].val || (add_if_fe6_o[0].val && add_if_fe6_o[0].rdy)) begin
          add_if_fe6_o[0].copy_if({i_add_fe12_if.dat[0 +: $bits(FE6_TYPE)],
                                   i_add_fe12_if.dat[$bits(FE12_TYPE) +: $bits(FE6_TYPE)]},
                                   i_add_fe12_if.val, 1, 1, i_add_fe12_if.err, 0, i_add_fe12_if.ctl);
          add_if_fe6_o[0].ctl[OVR_WRT_BIT +: 2] <= add_cnt;
          if (i_add_fe12_if.val) add_cnt <= 1;
        end
      end
      1: begin
        if (~add_if_fe6_o[0].val || (add_if_fe6_o[0].val && add_if_fe6_o[0].rdy)) begin
          add_if_fe6_o[0].copy_if({i_add_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)],
                                i_add_fe12_if.dat[$bits(FE12_TYPE)+$bits(FE6_TYPE) +: $bits(FE6_TYPE)]},
                                i_add_fe12_if.val, 1, 1, i_add_fe12_if.err, 0, i_add_fe12_if.ctl);
          add_if_fe6_o[0].ctl[OVR_WRT_BIT +: 2] <= add_cnt;
          if (i_add_fe12_if.val) add_cnt <= 0;
        end
      end
    endcase

    // One process to assign outputs
    if (~o_add_fe12_if.val || (o_add_fe12_if.val && o_add_fe12_if.rdy)) begin
      o_add_fe12_if.ctl <= add_if_fe6_i[0].ctl;
      o_add_fe12_if.ctl[OVR_WRT_BIT +: 2] <= 0;
      if (add_if_fe6_i[0].ctl[OVR_WRT_BIT +: 2] == 0) begin
        if (add_if_fe6_i[0].val)
          o_add_fe12_if.dat[0 +: $bits(FE6_TYPE)] <= add_if_fe6_i[0].dat;
      end else begin
        o_add_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= add_if_fe6_i[0].dat;
        o_add_fe12_if.val <= add_if_fe6_i[0].val;
      end
    end
  end
end

// Point subtractions are simple subtractions on each of the Fp6 elements
logic sub_cnt;
always_comb begin
  i_sub_fe12_if.rdy = (sub_cnt == 1) && (~sub_if_fe6_o[0].val || (sub_if_fe6_o[0].val && sub_if_fe6_o[0].rdy));
  sub_if_fe6_i[0].rdy = ~o_sub_fe12_if.val || (o_sub_fe12_if.val && o_sub_fe12_if.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_sub_fe12_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    sub_cnt <= 0;
    sub_if_fe6_o[0].copy_if(0, 0, 1, 1, 0, 0, 0);
  end else begin

    if (sub_if_fe6_o[0].val && sub_if_fe6_o[0].rdy) sub_if_fe6_o[0].val <= 0;
    if (o_sub_fe12_if.val && o_sub_fe12_if.rdy) o_sub_fe12_if.val <= 0;

    // One process to parse inputs and send them to the suber
    case(sub_cnt)
      0: begin
        if (~sub_if_fe6_o[0].val || (sub_if_fe6_o[0].val && sub_if_fe6_o[0].rdy)) begin
          sub_if_fe6_o[0].copy_if({i_sub_fe12_if.dat[$bits(FE12_TYPE) +: $bits(FE6_TYPE)],
                                   i_sub_fe12_if.dat[0 +: $bits(FE6_TYPE)]},
                                   i_sub_fe12_if.val, 1, 1, i_sub_fe12_if.err, 0, i_sub_fe12_if.ctl);
          sub_if_fe6_o[0].ctl[OVR_WRT_BIT +: 2] <= sub_cnt;
          if (i_sub_fe12_if.val) sub_cnt <= 1;
        end
      end
      1: begin
        if (~sub_if_fe6_o[0].val || (sub_if_fe6_o[0].val && sub_if_fe6_o[0].rdy)) begin
          sub_if_fe6_o[0].copy_if({i_sub_fe12_if.dat[$bits(FE12_TYPE)+$bits(FE6_TYPE) +: $bits(FE6_TYPE)],
                                   i_sub_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)]},
                                   i_sub_fe12_if.val, 1, 1, i_sub_fe12_if.err, 0, i_sub_fe12_if.ctl);
          sub_if_fe6_o[0].ctl[OVR_WRT_BIT +: 2] <= sub_cnt;
          if (i_sub_fe12_if.val) sub_cnt <= 0;
        end
      end
    endcase

    // One process to assign outputs
    if (~o_sub_fe12_if.val || (o_sub_fe12_if.val && o_sub_fe12_if.rdy)) begin
      o_sub_fe12_if.ctl <= sub_if_fe6_i[0].ctl;
      o_sub_fe12_if.ctl[OVR_WRT_BIT +: 2] <= 0;
      if (sub_if_fe6_i[0].ctl[OVR_WRT_BIT +: 2] == 0) begin
        if (sub_if_fe6_i[0].val)
          o_sub_fe12_if.dat[0 +: $bits(FE6_TYPE)] <= sub_if_fe6_i[0].dat;
      end else begin
        o_sub_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= sub_if_fe6_i[0].dat;
        o_sub_fe12_if.val <= sub_if_fe6_i[0].val;
      end
    end
  end
end

// Multiplications are calculated using the formula in bls12_381.pkg::fe12_mul()

logic [8:0] eq_val, eq_wait;
logic rdy_l;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_mul_fe12_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_mnr_fe6_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    o_mul_fe6_if.copy_if(0, 0, 1, 1, 0, 0, 0);
    sub_if_fe6_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    add_if_fe6_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    i_mul_fe12_if.rdy <= 0;
    i_mul_fe6_if.rdy <= 0;
    sub_if_fe6_i[1].rdy <= 0;
    add_if_fe6_i[1].rdy <= 0;
    i_mnr_fe6_if.rdy <= 0;
    eq_val <= 0;
    eq_wait <= 0;
    rdy_l <= 0;
    
  end else begin

    i_mul_fe6_if.rdy <= 1;
    sub_if_fe6_i[1].rdy <= 1;
    add_if_fe6_i[1].rdy <= 1;
    i_mnr_fe6_if.rdy <= 1;
    i_mul_fe12_if.rdy <= 0;

    if (o_mul_fe12_if.rdy) o_mul_fe12_if.val <= 0;
    if (o_mul_fe6_if.rdy) o_mul_fe6_if.val <= 0;
    if (sub_if_fe6_o[1].rdy) sub_if_fe6_o[1].val <= 0;
    if (add_if_fe6_o[1].rdy) add_if_fe6_o[1].val <= 0;
    if (o_mnr_fe6_if.rdy) o_mnr_fe6_if.val <= 0;

    if (o_mul_fe12_if.val && o_mul_fe12_if.rdy) begin
      eq_val <= 0;
      eq_wait <= 0;
      rdy_l <= 0;
    end
    
    if (eq_val[0] && eq_val[1] && eq_val[2] && eq_val[3] && ~rdy_l) begin
       i_mul_fe12_if.rdy <= 1;
       o_mul_fe12_if.ctl <= i_mul_fe12_if.ctl;
       rdy_l <= 1;
    end
        
    // Check any results from multiplier
    if (i_mul_fe6_if.val && i_mul_fe6_if.rdy) begin
      eq_val[i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
      case(i_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
        0: add_if_fe6_o[1].dat[0 +: $bits(FE6_TYPE)] <= i_mul_fe6_if.dat;
        1: o_mnr_fe6_if.dat <= i_mul_fe6_if.dat;
        4: o_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= i_mul_fe6_if.dat;
        default: o_mul_fe12_if.err <= 1;
      endcase
    end

      // Check any results from mnr
      if (i_mnr_fe6_if.val && i_mnr_fe6_if.rdy) begin
        eq_val[i_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
        case(i_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
          7: o_mnr_fe6_if.dat <= i_mnr_fe6_if.dat;
          default: o_mul_fe12_if.err <= 1;
        endcase
      end

      // Check any results from sub
      if (sub_if_fe6_i[1].val && sub_if_fe6_i[1].rdy) begin
        eq_val[sub_if_fe6_i[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
        case(sub_if_fe6_i[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
          5: o_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= sub_if_fe6_i[1].dat;
          6: o_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= sub_if_fe6_i[1].dat;
          default: o_mul_fe12_if.err <= 1;
        endcase
      end

      // Check any results from add
      if (add_if_fe6_i[1].val && add_if_fe6_i[1].rdy) begin
        eq_val[add_if_fe6_i[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]] <= 1;
        case(add_if_fe6_i[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT]) inside
          2: o_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= add_if_fe6_i[1].dat;
          3: o_mul_fe12_if.dat[0 +: $bits(FE6_TYPE)] <= add_if_fe6_i[1].dat;
          8: begin
            o_mul_fe12_if.dat[0 +: $bits(FE6_TYPE)] <= add_if_fe6_i[1].dat;
            o_mul_fe12_if.val <= 1;
          end
          default: o_mul_fe12_if.err <= 1;
        endcase
      end

      // Issue new multiplies
      if (~eq_wait[0] && i_mul_fe12_if.val && eq_val[2] && eq_val[3]) begin                 // 0. aa = mul(a[0], b[0])
        fe6_multiply(0, i_mul_fe12_if.dat[0 +: $bits(FE6_TYPE)],
                        i_mul_fe12_if.dat[$bits(FE12_TYPE) +: $bits(FE6_TYPE)]);              
      end else
      if (~eq_wait[1] && i_mul_fe12_if.val) begin                // 1. bb = mul(a[1], b[1])
        fe6_multiply(1, i_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)],
                        i_mul_fe12_if.dat[$bits(FE12_TYPE) + $bits(FE6_TYPE) +: $bits(FE6_TYPE)]);
      end else
      if (~eq_wait[4] && eq_val[2] && eq_val[3]) begin  // 4. out[1] = mul(fe6_mul[1], fe6_mul[0])  [2, 3]
        fe6_multiply(4, o_mul_fe12_if.dat[0 +: $bits(FE6_TYPE)], o_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)]);
      end

      // Issue new adds
      if (~eq_wait[2] && i_mul_fe12_if.val) begin                // 2. out[1] = add(a[1], a[0])
        fe6_addition(2, i_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)],
                        i_mul_fe12_if.dat[0 +: $bits(FE6_TYPE)]);
      end else
      if (~eq_wait[3] && i_mul_fe12_if.val) begin                // 3. fe6_mul[0] = add(b[0], b[1])
        fe6_addition(3, i_mul_fe12_if.dat[$bits(FE12_TYPE) +: $bits(FE6_TYPE)],
                        i_mul_fe12_if.dat[$bits(FE12_TYPE) + $bits(FE6_TYPE) +: $bits(FE6_TYPE)]);
      end else                             // 8. out[0] = add(aa, bb) [0, 1, 7]
      if (~eq_wait[8] && eq_val[0] && eq_val[1] && eq_val[7]) begin
        fe6_addition(8, add_if_fe6_o[1].dat[0 +: $bits(FE6_TYPE)], o_mnr_fe6_if.dat);
      end

      // Issue new sub
      if (~eq_wait[5] && eq_val[4] && eq_val[0]) begin        // 5. out[1] = sub(out[1], aa) [4, 0]
        fe6_subtraction(5, o_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)], add_if_fe6_o[1].dat[0 +: $bits(FE6_TYPE)]);
      end else
      if (~eq_wait[6] && eq_val[5] && eq_val[1]) begin        // 6. out[1] = sub(out[1], bb) [5, 1]
        fe6_subtraction(6, o_mul_fe12_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)], o_mnr_fe6_if.dat);
      end

      // Issue new mnr
      if (~eq_wait[7] && eq_wait[6]) begin        // 7. bb = mnr(bb) [6]
        fe6_mnr(7, o_mnr_fe6_if.dat, 1'b0);
      end
      
  end
end

resource_share # (
  .NUM_IN       ( 2                 ),
  .DAT_BITS     ( 2*$bits(FE6_TYPE) ),
  .CTL_BITS     ( CTL_BITS          ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + NUM_OVR_WRT_BIT ),
  .PIPELINE_IN  ( 0                 ),
  .PIPELINE_OUT ( 0                 )
)
resource_share_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_if_fe6_o[1:0] ),
  .o_res ( o_sub_fe6_if ),
  .i_res ( i_sub_fe6_if ),
  .o_axi ( sub_if_fe6_i[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                 ),
  .DAT_BITS     ( 2*$bits(FE6_TYPE) ),
  .CTL_BITS     ( CTL_BITS          ),
  .OVR_WRT_BIT  ( OVR_WRT_BIT + NUM_OVR_WRT_BIT ),
  .PIPELINE_IN  ( 0                 ),
  .PIPELINE_OUT ( 0                 )
)
resource_share_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_if_fe6_o[1:0] ),
  .o_res ( o_add_fe6_if      ),
  .i_res ( i_add_fe6_if      ),
  .o_axi ( add_if_fe6_i[1:0] )
);

// Task for subtractions
task fe6_subtraction(input int unsigned ctl, input FE6_TYPE a, b);
  if (~sub_if_fe6_o[1].val || (sub_if_fe6_o[1].val && sub_if_fe6_o[1].rdy)) begin
    sub_if_fe6_o[1].val <= 1;
    sub_if_fe6_o[1].dat[0 +: $bits(FE6_TYPE)] <= a;
    sub_if_fe6_o[1].dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= b;
    sub_if_fe6_o[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for addition
task fe6_addition(input int unsigned ctl, input FE6_TYPE a, b); 
  if (~add_if_fe6_o[1].val || (add_if_fe6_o[1].val && add_if_fe6_o[1].rdy)) begin
    add_if_fe6_o[1].val <= 1;
    add_if_fe6_o[1].dat[0 +: $bits(FE6_TYPE)] <= a;
    add_if_fe6_o[1].dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= b;
    add_if_fe6_o[1].ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for using mult
task fe6_multiply(input int unsigned ctl, input FE6_TYPE a, b);
  if (~o_mul_fe6_if.val || (o_mul_fe6_if.val && o_mul_fe6_if.rdy)) begin
    o_mul_fe6_if.val <= 1;
    o_mul_fe6_if.dat[0 +: $bits(FE6_TYPE)] <= a;
    o_mul_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE6_TYPE)] <= b;
    o_mul_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask

// Task for using mnr
task fe6_mnr(input int unsigned ctl, input FE6_TYPE a, input logic en = 1'b1);
  if (~o_mnr_fe6_if.val || (o_mnr_fe6_if.val && o_mnr_fe6_if.rdy)) begin
    o_mnr_fe6_if.val <= 1;
    if (en)
      o_mnr_fe6_if.dat <= a;
    o_mnr_fe6_if.ctl[OVR_WRT_BIT +: NUM_OVR_WRT_BIT] <= ctl;
    eq_wait[ctl] <= 1;
  end
endtask


endmodule