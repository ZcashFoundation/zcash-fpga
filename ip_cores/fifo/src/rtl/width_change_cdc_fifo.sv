/*
  Changes the width between two streams (must be powers of 2).
  Goes through a clock crossing FIFO so can run on different
  clock domains.

  Input and output widths need to be a multiple of each other

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

module width_change_cdc_fifo # (
  parameter IN_DAT_BYTS,
  parameter OUT_DAT_BYTS,
  parameter CTL_BITS,
  parameter FIFO_ABITS,
  parameter USE_BRAM,
  parameter CDC_ASYNC = "YES"  // Do we require the clock crossing
) (
  input i_clk_a, i_rst_a,
  input i_clk_b, i_rst_b,

  if_axi_stream.sink   i_axi_a,
  if_axi_stream.source o_axi_b
);

localparam SHIFT_DOWN = IN_DAT_BYTS > OUT_DAT_BYTS;
localparam SHIFT_RATIO = SHIFT_DOWN ? IN_DAT_BYTS/OUT_DAT_BYTS : OUT_DAT_BYTS/IN_DAT_BYTS;
localparam MAX_BYTS = SHIFT_DOWN ? IN_DAT_BYTS : OUT_DAT_BYTS;
localparam MIN_BYTS = SHIFT_DOWN ? OUT_DAT_BYTS : IN_DAT_BYTS;

localparam IN_DAT_BITS = IN_DAT_BYTS*8;
localparam IN_MOD_BITS = IN_DAT_BYTS == 1 ? 1 : $clog2(IN_DAT_BYTS);

localparam OUT_DAT_BITS = OUT_DAT_BYTS*8;
localparam OUT_MOD_BITS = OUT_DAT_BYTS == 1 ? 1 : $clog2(OUT_DAT_BYTS);


if_axi_stream #(.DAT_BYTS(IN_DAT_BYTS), .CTL_BITS(CTL_BITS)) o_axi_int (i_clk_b);

logic [$clog2(MAX_BYTS)-1:0] byt_cnt;
logic sop_l;

generate if (SHIFT_DOWN) begin

  always_ff @ (posedge i_clk_b) begin
    if (i_rst_b) begin
      o_axi_b.reset_source();
      byt_cnt <= 0;
      sop_l <= 0;
      o_axi_int.rdy <= 0;
    end else begin

      o_axi_int.rdy <= 0;
      
      if (o_axi_b.val && o_axi_b.rdy) o_axi_b.val <= 0;

      if (~o_axi_b.val || (o_axi_b.val && o_axi_b.rdy)) begin

        if (o_axi_int.val && ~o_axi_int.rdy) begin
        

          if (~sop_l) begin
            o_axi_b.ctl <= o_axi_int.ctl;
            o_axi_b.err <= o_axi_int.err;
            sop_l <= 1;
          end
          o_axi_b.dat <= o_axi_int.dat[byt_cnt*8 +: OUT_DAT_BITS];
          o_axi_b.sop <= ~sop_l;
          o_axi_b.val <= 1;
          o_axi_b.eop <= 0;
   

          byt_cnt <= byt_cnt + OUT_DAT_BYTS;

          // Detect the last data
          if ((byt_cnt + OUT_DAT_BYTS == IN_DAT_BYTS) || (o_axi_int.eop && o_axi_int.mod != 0 && (byt_cnt + OUT_DAT_BYTS >= o_axi_int.mod))) begin
            byt_cnt <= 0;
            o_axi_int.rdy <= 1;
            if (o_axi_int.eop) begin
              o_axi_b.eop <= 1;
              o_axi_b.mod <= o_axi_int.mod == 0 ? 0 : (o_axi_int.mod % OUT_DAT_BYTS);
              sop_l <= 0;
            end
          end
        end

      end
    end
  end

end else begin

  always_ff @ (posedge i_clk_b) begin
    if (i_rst_b) begin
      o_axi_b.reset_source();
      byt_cnt <= 0;
      sop_l <= 0;
      o_axi_int.rdy <= 0;
    end else begin
      
      if (o_axi_b.val && o_axi_b.rdy) begin
        o_axi_b.reset_source();
      end

      if (~o_axi_b.val || (o_axi_b.val && o_axi_b.rdy)) begin

          o_axi_int.rdy <= 1;
          
        if (o_axi_int.val && o_axi_int.rdy) begin
          
          if (~sop_l) begin
            o_axi_b.ctl <= o_axi_int.ctl;
            o_axi_b.err <= o_axi_int.err;
            sop_l <= 1;
          end
          o_axi_b.dat[byt_cnt*8 +: IN_DAT_BITS] <= o_axi_int.dat;
          o_axi_b.sop <= o_axi_b.sop || ~sop_l;

          byt_cnt <= byt_cnt + IN_DAT_BYTS;

          // Detect the last data
          if ((byt_cnt + IN_DAT_BYTS == OUT_DAT_BYTS) || o_axi_int.eop) begin
            byt_cnt <= 0;
            o_axi_b.val <= 1;
            o_axi_int.rdy <= 0;
            if (o_axi_int.eop) begin
              o_axi_b.eop <= 1;
              o_axi_b.mod <= byt_cnt + IN_DAT_BYTS;
              sop_l <= 0;
            end
          end
        end

      end
    end
  end

end
endgenerate

generate if (CDC_ASYNC == "YES") begin
  cdc_fifo #(
    .SIZE     ( 1<<FIFO_ABITS                              ),
    .DAT_BITS ( IN_DAT_BYTS*8 + IN_MOD_BITS + CTL_BITS + 3 ),
    .USE_BRAM ( USE_BRAM                                   )
  )
  cdc_fifo (
    .i_clk_a ( i_clk_a ),
    .i_rst_a ( i_rst_a ),
    .i_clk_b ( i_clk_b ),
    .i_rst_b ( i_rst_b ),
  
    .i_val_a( i_axi_a.val ),
    .i_dat_a({i_axi_a.dat,
              i_axi_a.mod,
              i_axi_a.sop,
              i_axi_a.eop,
              i_axi_a.err,
              i_axi_a.ctl}),
    .o_rdy_a( i_axi_a.rdy ),
    .o_full_a(),
  
    .o_val_b( o_axi_int.val ),
    .o_dat_b({o_axi_int.dat,
              o_axi_int.mod,
              o_axi_int.sop,
              o_axi_int.eop,
              o_axi_int.err,
              o_axi_int.ctl}),
    .i_rdy_b( o_axi_int.rdy ),
    .o_emp_b(),
    .o_rd_wrds_b()
  );
end else begin
  axi_stream_fifo #(
    .SIZE     ( 1<<FIFO_ABITS    ),
    .DAT_BITS ( i_axi_a.DAT_BITS ),
    .MOD_BITS ( i_axi_a.MOD_BITS ),
    .CTL_BITS ( i_axi_a.CTL_BITS ),
    .USE_BRAM ( USE_BRAM         )
  ) 
  axi_stream_fifo (
    .i_clk ( i_clk_a ),
    .i_rst ( i_rst_a ),
    .i_axi ( i_axi_a),
    .o_axi ( o_axi_int ),
    .o_full(),
    .o_emp()
  );
end endgenerate

endmodule