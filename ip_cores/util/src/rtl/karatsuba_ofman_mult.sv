/*
  Multiplication using Karatsuba-Ofman algorithm.
  
  Multiple of these can be instantiated, each one takes 3 clocks cycles
  per level. Fully pipelined so can accept a new input every clock.
  
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

module karatsuba_ofman_mult # (
  parameter BITS = 256,
  parameter CTL_BITS = 8,
  parameter LEVEL = 1
) (
  input                       i_clk,
  input                       i_rst,
  input [BITS-1:0]            i_dat_a,
  input [BITS-1:0]            i_dat_b,
  input                       i_val,
  input [CTL_BITS-1:0]        i_ctl,
  input                       i_rdy,
  output logic                o_rdy,
  output logic                o_val,
  output logic [CTL_BITS-1:0] o_ctl,
  output logic [BITS*2-1:0]   o_dat
);

localparam HBITS = BITS/2;
  
logic [BITS-1:0] m0, m1, m2, dat_a, dat_b;
logic [BITS*2-1:0] q;
logic [HBITS-1:0] a0, a1;
logic sign_;
logic [HBITS-1:0] a0_, a1_;
logic [BITS-1:0] m0_, m1_, m2_;

logic [LEVEL*3-1:0] val, sign;
logic [LEVEL*3-1:0][CTL_BITS-1:0] ctl;

always_comb begin
  o_val = val[LEVEL*3-1];
  o_ctl = ctl[LEVEL*3-1]; 
  if (LEVEL == 1)
    o_rdy = ~o_val || (o_val && i_rdy);
  else
    o_rdy = i_rdy;
end
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    val <= 0;
  end else begin
    if(o_rdy) begin
      val <= {val, i_val};
    end
  end
end

always_ff @ (posedge i_clk) begin
  if(o_rdy) begin
    o_dat <= q;
    ctl <= {ctl, i_ctl};
    a0_ <= a0;
    a1_ <= a1;
    m0_ <= m0;
    m1_ <= m1;
    m2_ <= m2;
    dat_a <= i_dat_a;
    dat_b <= i_dat_b;
    sign <= {sign, sign_};
  end
end

generate
  always_comb begin
    a0 = i_dat_a[0 +: HBITS] > i_dat_a[HBITS +: HBITS] ? i_dat_a[0 +: HBITS] - i_dat_a[HBITS +: HBITS] : i_dat_a[HBITS +: HBITS] - i_dat_a[0 +: HBITS];
    a1 = i_dat_b[HBITS +: HBITS] > i_dat_b[0 +: HBITS] ? i_dat_b[HBITS +: HBITS] - i_dat_b[0 +: HBITS] : i_dat_b[0 +: HBITS] - i_dat_b[HBITS +: HBITS];
    sign_ = ((dat_a[0 +: HBITS] < dat_a[HBITS +: HBITS]) ^ 
        (dat_b[HBITS +: HBITS] < dat_b[0 +: HBITS]));
    q = (m0_ << BITS) + ((m0_ + m2_ + (sign[3*(LEVEL-1)] == 1 ? -m1_ : m1_)) << HBITS) + m2_;
  end
    
  if (LEVEL == 1) begin: GEN_REC
  
    always_comb begin
      m0 = dat_a[HBITS +: HBITS] * dat_b[HBITS +: HBITS];
      m2 = dat_a[0 +: HBITS] * dat_b[0 +: HBITS];    
      m1 = (a0_ * a1_);
    end
    
  end else begin 
    
    karatsuba_ofman_mult # (
      .BITS     ( HBITS    ),
      .CTL_BITS ( CTL_BITS ),
      .LEVEL    ( LEVEL-1  )
    )
    karatsuba_ofman_mult_m0 (
      .i_clk   ( i_clk                 ),
      .i_rst   ( i_rst                 ),
      .i_dat_a ( dat_a[HBITS +: HBITS] ),
      .i_dat_b ( dat_b[HBITS +: HBITS] ),
      .i_val   ( val[0]                ),
      .o_val   (                       ),
      .i_ctl   ( ctl[0]                ),
      .o_ctl   (                       ),
      .i_rdy   ( o_rdy                 ),
      .o_rdy   (                       ),
      .o_dat   ( m0                    )
    );
    
    karatsuba_ofman_mult # (
      .BITS     ( HBITS   ),
      .CTL_BITS ( CTL_BITS       ),
      .LEVEL    ( LEVEL-1 )
    )
    karatsuba_ofman_mult_m2 (
      .i_clk   ( i_clk             ),
      .i_rst   ( i_rst             ),
      .i_dat_a ( dat_a[0 +: HBITS] ),
      .i_dat_b ( dat_b[0 +: HBITS] ),
      .i_val   ( val[0]            ),
      .o_val   (),
      .i_ctl   ( ctl[0]            ),
      .o_ctl   (),
      .i_rdy   ( o_rdy             ),
      .o_rdy   (),      
      .o_dat   ( m2                )
    );
    
    karatsuba_ofman_mult # (
      .BITS     ( HBITS   ),
      .CTL_BITS ( CTL_BITS       ),
      .LEVEL    ( LEVEL-1 )
    )
    karatsuba_ofman_mult_m1 (
      .i_clk   ( i_clk  ),
      .i_rst   ( i_rst  ),
      .i_dat_a ( a0_    ),
      .i_dat_b ( a1_    ),
      .i_val   ( val[0] ),
      .o_val   (),
      .i_ctl   ( ctl[0] ),
      .o_ctl   (),
      .i_rdy   ( o_rdy  ),
      .o_rdy   (),            
      .o_dat   ( m1     )
    );
    
  
  end
endgenerate

endmodule