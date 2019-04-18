/*
  Fifo used for CDC crossing.
  
  Uses either BRAM or registers for the memory, and grey coding for the rd/wr pointers.
 
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

module cdc_fifo #(
  parameter SIZE = 4,         // Needs to be a power of 2
  parameter DAT_BITS = 8,
  parameter USE_BRAM = 0,  // If using BRAM there is an extra cycle delay between reads
  parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE"
) (
  input i_clk_a, i_rst_a,
  input i_clk_b, i_rst_b,
  
  input                       i_val_a,
  input        [DAT_BITS-1:0] i_dat_a,
  output logic                o_rdy_a,
  output logic                o_full_a,
  
  output logic                o_val_b,
  output logic [DAT_BITS-1:0] o_dat_b,
  input                       i_rdy_b,
  output logic                o_emp_b,
  
  output logic [ABITS:0]      o_rd_wrds_b
);
  
localparam ABITS = $clog2(SIZE);
logic [ABITS:0] rd_ptr_b, wr_ptr_a, rd_ptrg_a, rd_ptr_a, wr_ptrg_b, wr_ptr_b;

generate
  if (USE_BRAM == 0) begin: BRAM_GEN
  
    logic [SIZE-1:0][DAT_BITS-1:0] ram;  
  
    always_ff @ (posedge i_clk_a) begin
      if (i_val_a && o_rdy_a) begin
        ram [wr_ptr_a[ABITS-1:0]] <= i_dat_a;
      end
    end
    
    always_ff @ (posedge i_clk_b) begin
      if (i_rst_b) begin
        o_val_b <= 0;
        o_dat_b <= 0;
      end else begin
        if (~o_val_b || (o_val_b && i_rdy_b)) begin
          if (o_val_b && i_rdy_b) begin
            o_val_b <= ~(wr_ptr_b == (rd_ptr_b + 1) % (1 << (ABITS+1)));
            o_dat_b <= ram [(rd_ptr_b[ABITS-1:0]+1) % SIZE];
          end else begin
            o_val_b <= ~(wr_ptr_b == rd_ptr_b);
            o_dat_b <= ram [rd_ptr_b[ABITS-1:0]];
          end
        end
      end
    end
    
  end else begin
    
    logic [DAT_BITS-1:0] dat_b;
    logic [1:0] read_cyc;
    if_ram #(.RAM_WIDTH(DAT_BITS), .RAM_DEPTH(SIZE)) bram_if_rd (i_clk_b, i_rst_b);
    if_ram #(.RAM_WIDTH(DAT_BITS), .RAM_DEPTH(SIZE)) bram_if_wr (i_clk_a, i_rst_a);
    
    bram #(
      .RAM_WIDTH       ( DAT_BITS        ),
      .RAM_DEPTH       ( SIZE            ),
      .RAM_PERFORMANCE ( RAM_PERFORMANCE )
    ) bram_i (
      .a ( bram_if_rd ),
      .b ( bram_if_wr )
    );

    
    always_ff @ (posedge i_clk_b) begin
      if (i_rst_b) begin
        read_cyc <= 0;
        o_val_b <= 0;
      end else begin
        read_cyc <= read_cyc << 1;
        o_val_b <= 0;
        if (~o_emp_b) o_val_b <= 1;
        
        if (o_val_b && i_rdy_b) begin 
          o_val_b <= 0;
          read_cyc[0] <= 1;
        end
        if (RAM_PERFORMANCE == "HIGH_PERFORMANCE" && read_cyc[0])
          o_val_b <= 0;
        
      end
    end
    
    always_comb begin
      
      bram_if_rd.re = 1;
      bram_if_rd.a = rd_ptr_b[ABITS-1:0];
      bram_if_rd.d = 0;
      bram_if_rd.we = 0;
      bram_if_rd.en = 1;
      
      bram_if_wr.re = 0;
      bram_if_wr.a = wr_ptr_a[ABITS-1:0];
      bram_if_wr.d = i_dat_a;
      bram_if_wr.we  = i_val_a && o_rdy_a;
      bram_if_wr.en = 1;
      
      o_dat_b = bram_if_rd.q;
    end
  end
endgenerate

// i_clk_a
always_ff @ (posedge i_clk_a) begin
  if (i_rst_a) begin
    wr_ptr_a <= 0;
  end else begin
    if (i_val_a && o_rdy_a) begin
      wr_ptr_a <= wr_ptr_a + 1;
    end
  end
end

// i_clk_b
always_ff @ (posedge i_clk_b) begin
  if (i_rst_b) begin
    rd_ptr_b <= 0;
  end else begin
    if (o_val_b && i_rdy_b) begin
      rd_ptr_b <= rd_ptr_b + 1;
    end    
  end
end

always_comb begin
  rd_ptr_a = grey_to_bin(rd_ptrg_a);
  wr_ptr_b = grey_to_bin(wr_ptrg_b);
end

always_comb begin
  o_emp_b = wr_ptr_b == rd_ptr_b;
  o_full_a = wr_ptr_a == {~rd_ptr_a[ABITS], rd_ptr_a[ABITS-1:0]};
end

always_comb begin
  o_rdy_a = ~o_full_a && ~i_rst_a;
  o_rd_wrds_b = o_emp_b ? (1 << ABITS) : wr_ptr_b[ABITS-1:0] - rd_ptr_b[ABITS-1:0];
end

// Synchronizers
synchronizer  #(
  .DAT_BITS ( ABITS + 1 ),
  .NUM_CLKS ( 2         )
)
synchronizer_wr_ptr (
  .i_clk_a ( i_clk_a ),
  .i_clk_b ( i_clk_b ),
  .i_dat_a ( bin_to_grey(wr_ptr_a) ),
  .o_dat_b ( wr_ptrg_b             )
);

synchronizer  #(
  .DAT_BITS ( ABITS + 1 ),
  .NUM_CLKS ( 2         )
)
synchronizer_rd_ptr (
  .i_clk_a ( i_clk_b ),
  .i_clk_b ( i_clk_a ),  
  .i_dat_a ( bin_to_grey(rd_ptr_b) ),
  .o_dat_b ( rd_ptrg_a             )
);

// Functions to convert to grey counter and back
function [ABITS:0] grey_to_bin(input logic [ABITS:0] in);
  grey_to_bin[ABITS] = in[ABITS];
  for(int i = ABITS-1; i >= 0; i--) begin
    grey_to_bin[i] = in[i] ^ grey_to_bin[i+1];
  end
endfunction

function [ABITS:0] bin_to_grey(input logic [ABITS:0] in);
  bin_to_grey[ABITS] = in[ABITS];
  for (int i = ABITS; i > 0; i--)
    bin_to_grey[i-1] = in[i] ^ in[i-1];
endfunction

initial if (SIZE != 2**($clog2(SIZE))) $fatal(1, "ERROR: cdc_fifo.sv SIZE needs to be a power of 2 - was %d", SIZE);
endmodule