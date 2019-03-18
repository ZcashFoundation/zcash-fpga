/*
  Multiplication using Karatsuba-Ofman algorithm.
  
  Multiple of these can be instantiated, each one takes 2 clocks cycles
  per level.
  
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
  parameter LEVEL = 1
) (
  input                     i_clk,
  input [BITS-1:0]          i_dat_a,
  input [BITS-1:0]          i_dat_b,
  output logic [BITS*2-1:0] o_dat
);

localparam HBITS = BITS/2;
  
logic [BITS-1:0] m0, m1, m2;
logic [BITS*2-1:0] q;
logic [HBITS-1:0] a0, a1;
logic sign, sign_;

generate
  always_comb begin
    a0 = i_dat_a[0 +: HBITS] > i_dat_a[HBITS +: HBITS] ? i_dat_a[0 +: HBITS] - i_dat_a[HBITS +: HBITS] : i_dat_a[HBITS +: HBITS] - i_dat_a[0 +: HBITS];
    a1 = i_dat_b[HBITS +: HBITS] > i_dat_b[0 +: HBITS] ? i_dat_b[HBITS +: HBITS] - i_dat_b[0 +: HBITS] : i_dat_b[0 +: HBITS] - i_dat_b[HBITS +: HBITS];
    sign_ = ((i_dat_a[0 +: HBITS] < i_dat_a[HBITS +: HBITS]) ^ 
        (i_dat_b[HBITS +: HBITS] < i_dat_b[0 +: HBITS]));
    q = (m0 << BITS) + ((m0 + m2 + (sign == 1 ? -m1 : m1)) << HBITS) + m2;
  end
    
  if (LEVEL == 1) begin: GEN_REC
    always_comb begin
      m0 = i_dat_a[HBITS +: HBITS] * i_dat_b[HBITS +: HBITS];
      m2 = i_dat_a[0 +: HBITS] * i_dat_b[0 +: HBITS];    
      m1 = (a0 * a1);
      sign = sign_;
    end

  end else begin 
    // pipeline the other non-mult values x clock cycles and add them after multipliers
    logic [LEVEL-2:0] sign_r;
    
    always_comb begin
      sign = sign_r[LEVEL-2];
    end
    
    always_ff @ (posedge i_clk) begin
      sign_r <= {sign_r, sign_};
    end
    
    karatsuba_ofman_mult # (
      .BITS ( HBITS   ),
      .LEVEL( LEVEL-1 )
    )
    karatsuba_ofman_mult_m0 (
      .i_clk   ( i_clk                   ),
      .i_dat_a ( i_dat_a[HBITS +: HBITS] ),
      .i_dat_b ( i_dat_b[HBITS +: HBITS] ),
      .o_dat   ( m0                      )
    );
    
    karatsuba_ofman_mult # (
      .BITS ( HBITS   ),
      .LEVEL( LEVEL-1 )
    )
    karatsuba_ofman_mult_m2 (
      .i_clk   ( i_clk               ),
      .i_dat_a ( i_dat_a[0 +: HBITS] ),
      .i_dat_b ( i_dat_b[0 +: HBITS] ),
      .o_dat   ( m2                  )
    );
    
    karatsuba_ofman_mult # (
      .BITS ( HBITS   ),
      .LEVEL( LEVEL-1 )
    )
    karatsuba_ofman_mult_m1 (
      .i_clk   ( i_clk ),
      .i_dat_a ( a0    ),
      .i_dat_b ( a1    ),
      .o_dat   ( m1    )
    );
    
  
  end
endgenerate

always_ff @ (posedge i_clk) begin
  o_dat <= q;
end

endmodule