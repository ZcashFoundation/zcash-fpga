/*
  This module is the top level for the BLS12-381 coprocessor.
  Runs on instruction memory and has access to slot memory.

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

module bls12_381_top
  import bls12_381_pkg::*;
#(
)(
  input i_clk, i_rst,
  // Only tx interface is used to send messages to SW on a SEND-INTERRUPT instruction
  if_axi_stream.source tx_if,
  // User access to the instruction and register RAM
  if_axi_mm.sink       inst_usr_if,
  if_axi_mm.sink       data_usr_if,
  // Configuration memory
  if_axi_mm.sink       cfg_usr_if
);

localparam DAT_BITS = bls12_381_pkg::DAT_BITS;

// Instruction RAM
localparam READ_CYCLE = 3;
logic [READ_CYCLE:0] inst_ram_read, inst_usr_ram_read;
logic [READ_CYCLE:0] data_ram_read, data_usr_ram_read;

if_ram #(.RAM_WIDTH(bls12_381_pkg::INST_RAM_WIDTH), .RAM_DEPTH(bls12_381_pkg::INST_RAM_DEPTH)) inst_ram_sys_if(.i_clk(i_clk), .i_rst(i_rst));
if_ram #(.RAM_WIDTH(bls12_381_pkg::INST_RAM_WIDTH), .RAM_DEPTH(bls12_381_pkg::INST_RAM_DEPTH)) inst_ram_usr_if(.i_clk(i_clk), .i_rst(i_rst));
inst_t curr_inst;

// Data RAM
if_ram #(.RAM_WIDTH(bls12_381_pkg::DATA_RAM_WIDTH), .RAM_DEPTH(bls12_381_pkg::DATA_RAM_DEPTH), .BYT_EN(48)) data_ram_sys_if(.i_clk(i_clk), .i_rst(i_rst));
if_ram #(.RAM_WIDTH(bls12_381_pkg::DATA_RAM_WIDTH), .RAM_DEPTH(bls12_381_pkg::DATA_RAM_DEPTH), .BYT_EN(48)) data_ram_usr_if(.i_clk(i_clk), .i_rst(i_rst));

// Fp point multiplication
if_axi_stream #(.DAT_BITS(DAT_BITS*3)) fp_pt_mult_in_if(i_clk);
if_axi_stream #(.DAT_BITS(DAT_BITS*3)) fp_pt_mult_out_if(i_clk);


logic [DAT_BITS-1:0] k_fp_in;
logic [7:0] cnt;

always_comb begin
  curr_inst = inst_ram_sys_if.q;
end

code_t inst_state;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    tx_if.reset_source();
    inst_ram_sys_if.reset_source();
    data_ram_sys_if.reset_source();
    fp_pt_mult_out_if.rdy <= 0;
    fp_pt_mult_in_if.reset_source();
    inst_ram_read <= 0;
    data_ram_read <= 0;
    k_fp_in <= 0;
    cnt <= 0;
    inst_state <= NOOP_WAIT;
  end else begin
    inst_ram_sys_if.re <= 1;
    inst_ram_sys_if.en <= 1;
    inst_ram_read <= inst_ram_read << 1;

    data_ram_sys_if.re <= 1;
    data_ram_sys_if.en <= 1;
    data_ram_sys_if.we <= 0;
    data_ram_read <= data_ram_read << 1;

    if (fp_pt_mult_in_if.val && fp_pt_mult_in_if.rdy) fp_pt_mult_in_if.val <= 0;
    fp_pt_mult_out_if.rdy <= 1;

    case(inst_state)
      {NOOP_WAIT}: begin
        // Wait in this state
        inst_state <= curr_inst.code;
        cnt <= 0;
      end
      {COPY_REG}: begin
        inst_ram_sys_if.a <= inst_ram_sys_if.a + 1;
        inst_ram_read[0] <= 1;

        data_ram_sys_if.a <= curr_inst.a;
        data_ram_read[0] <= 1;

        if (data_ram_read[READ_CYCLE]) begin
          data_ram_sys_if.a <=  curr_inst.b;
          data_ram_sys_if.d <= data_ram_sys_if.q;
          data_ram_sys_if.we <= -1;
        end

        if (inst_ram_read[READ_CYCLE]) begin
          inst_state <= curr_inst.code;
        end
      end
      {FP_FPOINT_MULT}: begin
        case(cnt) inside
          0: begin
            data_ram_sys_if.a <= curr_inst.a;
            data_ram_read[0] <= 1;
            cnt <= cnt + 1;
          end
          1: begin
            if (data_ram_read[READ_CYCLE]) begin
              data_ram_sys_if.a <= curr_inst.b;
              k_fp_in <= data_ram_sys_if.q;
              fp_pt_mult_in_if.dat <= bls12_381_pkg::g_point;
              fp_pt_mult_in_if.val <= 1;
              data_ram_read[0] <= 1;
              cnt <= cnt + 1;
            end
          end
          // Wait for result
          2: begin
            fp_pt_mult_out_if.rdy <= 0;
            if (fp_pt_mult_out_if.val) begin
               data_ram_sys_if.d <= fp_pt_mult_out_if.dat;
               data_ram_sys_if.we <= -1;
               cnt <= cnt + 1;
            end
          end
          3: begin
            fp_pt_mult_out_if.rdy <= 0;
            data_ram_sys_if.d <= fp_pt_mult_out_if.dat >> DAT_BITS;
            data_ram_sys_if.a <= data_ram_sys_if.a + 1;
            data_ram_sys_if.we <= -1;
            cnt <= cnt + 1;
          end
          4: begin
            data_ram_sys_if.d <= fp_pt_mult_out_if.dat >> (2*DAT_BITS);
            data_ram_sys_if.we <= -1;
            data_ram_sys_if.a <= data_ram_sys_if.a + 1;
            cnt <= cnt + 1;
            inst_ram_sys_if.a <= inst_ram_sys_if.a + 1;
            inst_ram_read[0] <= 1;
          end
          5: begin
            if (inst_ram_read[READ_CYCLE]) begin
              inst_state <= curr_inst.code;
              cnt <= 0;
            end
          end

        endcase
      end
    endcase
  end
end

// Configuration registers, instruction, data RAM
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    cfg_usr_if.reset_sink();
    inst_usr_if.reset_sink();
    data_usr_if.reset_sink();

    inst_ram_usr_if.reset_source();
    data_ram_usr_if.reset_source();

    inst_usr_ram_read <= 0;
    data_usr_ram_read <= 0;

  end else begin

    data_usr_ram_read <= data_usr_ram_read << 1;
    inst_usr_ram_read <= inst_usr_ram_read << 1;

    cfg_usr_if.rd_dat_val <= 0;

    data_usr_if.rd_dat <= data_ram_usr_if.q;
    inst_usr_if.rd_dat <= inst_ram_usr_if.q;

    data_usr_if.rd_dat_val <= data_usr_ram_read[READ_CYCLE];
    inst_usr_if.rd_dat_val <= inst_usr_ram_read[READ_CYCLE];

    inst_ram_usr_if.en <= 1;
    inst_ram_usr_if.re <= 1;
    inst_ram_usr_if.we <= 0;

    data_ram_usr_if.en <= 1;
    data_ram_usr_if.re <= 1;
    data_ram_usr_if.we <= 0;

    // Write access
    if (data_usr_if.wr) begin
      data_ram_usr_if.a <= data_usr_if.addr >> DATA_RAM_ALIGN_BYTE/DATA_RAM_USR_WIDTH;
      data_ram_usr_if.d <= data_usr_if.wr_dat << (data_usr_if.addr % DATA_RAM_ALIGN_BYTE)*8;
      data_ram_usr_if.we <= {8{1'd1}}  << (data_usr_if.addr % DATA_RAM_ALIGN_BYTE);
    end

    if (inst_usr_if.wr) begin
      inst_ram_usr_if.a <= inst_usr_if.addr >> INST_RAM_ALIGN_BYTE/INST_RAM_USR_WIDTH;
      inst_ram_usr_if.d <= inst_usr_if.wr_dat;
      inst_ram_usr_if.we <= 1;
    end

    if (cfg_usr_if.wr) begin
    // Currently no write supported
    end

    // Read access
    if (data_usr_if.rd) begin
      data_usr_ram_read[0] <= 1;
      data_ram_usr_if.a <= data_usr_if.addr >> DATA_RAM_ALIGN_BYTE/DATA_RAM_USR_WIDTH;
    end

    if (inst_usr_if.rd) begin
      inst_usr_ram_read[0] <= 1;
      inst_ram_usr_if.a <= inst_usr_if.addr >> INST_RAM_ALIGN_BYTE/INST_RAM_USR_WIDTH;
    end

    if (cfg_usr_if.rd) begin
      cfg_usr_if.rd_dat_val <= 1;
      case(cfg_usr_if.addr)
        0: begin
          cfg_usr_if.rd_dat <= inst_ram_sys_if.a;
        end
      endcase
    end
  end
end

uram_reset #(
  .RAM_WIDTH(bls12_381_pkg::INST_RAM_WIDTH),
  .RAM_DEPTH(bls12_381_pkg::INST_RAM_DEPTH),
  .PIPELINES( READ_CYCLE - 2 )
)
inst_uram_reset (
  .a ( inst_ram_usr_if ),
  .b ( inst_ram_sys_if )
);

uram_reset #(
  .RAM_WIDTH(bls12_381_pkg::DATA_RAM_WIDTH),
  .RAM_DEPTH(bls12_381_pkg::DATA_RAM_DEPTH),
  .PIPELINES( READ_CYCLE - 2 )
)
data_uram_reset (
  .a ( data_ram_usr_if ),
  .b ( data_ram_sys_if )
);

// These interfaces are unused
if_axi_stream #(.DAT_BITS(DAT_BITS*2), .CTL_BITS(16)) mult_in_if(i_clk);
if_axi_stream #(.DAT_BITS(DAT_BITS), .CTL_BITS(16)) mult_out_if(i_clk);
if_axi_stream #(.DAT_BITS(DAT_BITS*2), .CTL_BITS(16)) add_in_if(i_clk);
if_axi_stream #(.DAT_BITS(DAT_BITS), .CTL_BITS(16)) add_out_if(i_clk);
if_axi_stream #(.DAT_BITS(DAT_BITS*2), .CTL_BITS(16)) sub_in_if(i_clk);
if_axi_stream #(.DAT_BITS(DAT_BITS), .CTL_BITS(16)) sub_out_if(i_clk);


always_comb begin
  mult_in_if.rdy = 1;
  mult_out_if.reset_source();
  add_in_if.rdy = 1;
  add_out_if.reset_source();
  sub_in_if.rdy = 1;
  sub_out_if.reset_source();
end

ec_fp_point_mult #(
  .P          ( bls12_381_pkg::P          ),
  .POINT_TYPE ( bls12_381_pkg::jb_point_t ),
  .DAT_BITS   ( bls12_381_pkg::DAT_BITS   ),
  .RESOURCE_SHARE ("NO")
)
ec_fp_point_mult (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_p   ( fp_pt_mult_in_if.dat ),
  .i_k   ( k_fp_in              ),
  .i_val ( fp_pt_mult_in_if.val ),
  .o_rdy ( fp_pt_mult_in_if.rdy ),
  .o_p   ( fp_pt_mult_out_if.dat ),
  .i_rdy ( fp_pt_mult_out_if.rdy ),
  .o_val ( fp_pt_mult_out_if.val ),
  .o_err ( fp_pt_mult_out_if.err ),
  .o_mult_if ( mult_in_if  ),
  .i_mult_if ( mult_out_if ),
  .o_add_if  ( add_in_if   ),
  .i_add_if  ( add_out_if  ),
  .o_sub_if  ( sub_in_if   ),
  .i_sub_if  ( sub_out_if  ),
  .i_p2_val  ( 0           ),
  .i_p2      ( 0           )
);


endmodule