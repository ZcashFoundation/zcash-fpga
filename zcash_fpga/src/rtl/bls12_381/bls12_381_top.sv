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
  // User access to the instruction, data, and config
  if_axi_lite.sink     axi_lite_if
);

localparam DAT_BITS = bls12_381_pkg::DAT_BITS;
localparam AXI_STREAM_BYTS = 8;

parameter type FE_TYPE   = bls12_381_pkg::fe_t;
parameter type FE2_TYPE  = bls12_381_pkg::fe2_t;
parameter type FE6_TYPE  = bls12_381_pkg::fe6_t;
parameter type FE12_TYPE = bls12_381_pkg::fe12_t;
parameter P              = bls12_381_pkg::P;

// Used for sending interrupts back to SW
import zcash_fpga_pkg::bls12_381_interrupt_rpl_t;
import zcash_fpga_pkg::bls12_381_interrupt_rpl;
bls12_381_interrupt_rpl_t interrupt_rpl;
enum {WAIT_FIFO, SEND_HDR, SEND_DATA} interrupt_state;
logic [7:0] interrupt_hdr_byt;


logic [READ_CYCLE:0] inst_ram_read, data_ram_read;
logic reset_inst_ram, reset_data_ram;

// Instruction RAM
if_ram #(.RAM_WIDTH(bls12_381_pkg::INST_RAM_WIDTH), .RAM_DEPTH(bls12_381_pkg::INST_RAM_DEPTH)) inst_ram_sys_if(.i_clk(i_clk), .i_rst(i_rst || reset_inst_ram));
if_ram #(.RAM_WIDTH(bls12_381_pkg::INST_RAM_WIDTH), .RAM_DEPTH(bls12_381_pkg::INST_RAM_DEPTH)) inst_ram_usr_if(.i_clk(i_clk), .i_rst(i_rst || reset_inst_ram));
inst_t curr_inst;

// Data RAM
if_ram #(.RAM_WIDTH(bls12_381_pkg::DATA_RAM_WIDTH), .RAM_DEPTH(bls12_381_pkg::DATA_RAM_DEPTH)) data_ram_sys_if(.i_clk(i_clk), .i_rst(i_rst || reset_data_ram));
if_ram #(.RAM_WIDTH(bls12_381_pkg::DATA_RAM_WIDTH), .RAM_DEPTH(bls12_381_pkg::DATA_RAM_DEPTH)) data_ram_usr_if(.i_clk(i_clk), .i_rst(i_rst || reset_data_ram));
data_t curr_data, new_data;

// Loading the fifo with slots and outputting an interrupt
if_axi_stream #(.DAT_BYTS(48)) interrupt_in_if(i_clk);
if_axi_stream #(.DAT_BYTS(8)) interrupt_out_if(i_clk);
if_axi_stream #(.DAT_BYTS(3)) idx_in_if(i_clk);
if_axi_stream #(.DAT_BYTS(3)) idx_out_if(i_clk);

// Fp2 point multiplication
if_axi_stream #(.DAT_BITS($bits(bls12_381_pkg::fp2_jb_point_t)), .CTL_BITS(DAT_BITS)) fp2_pt_mul_in_if(i_clk);
if_axi_stream #(.DAT_BITS($bits(bls12_381_pkg::fp2_jb_point_t))) fp2_pt_mul_out_if(i_clk);
logic fp_pt_mult_mode;

if_axi_stream #(.DAT_BITS(2*$bits(bls12_381_pkg::fp2_jb_point_t))) add_i_if(i_clk);
if_axi_stream #(.DAT_BITS($bits(bls12_381_pkg::fp2_jb_point_t))) add_o_if(i_clk);
if_axi_stream #(.DAT_BITS($bits(bls12_381_pkg::fp2_jb_point_t))) dbl_i_if(i_clk);
if_axi_stream #(.DAT_BITS($bits(bls12_381_pkg::fp2_jb_point_t))) dbl_o_if(i_clk);

localparam CTL_BITS = 128;
// Access to shared 381bit multiplier / adder / subtractor
// Fp logic uses control bits 7:0
// Fp2 15:8
// Fp6 23:16
// Top level muxes 31:24
// 67:32 Pairing engine - TODO conslidate the logic used here with the point multiplication
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) mul_in_if  [2:0] (i_clk) ;
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   mul_out_if [2:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) add_in_if        (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   add_out_if       (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BITS)) sub_in_if        (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   sub_out_if       (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   inv_fe_o_if      (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   inv_fe_i_if      (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   inv_fe2_o_if     (i_clk);
if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BITS))   inv_fe2_i_if     (i_clk);

logic pair_i_val, pair_o_rdy;
if_axi_stream #(.DAT_BITS($bits(FE_TYPE))) pair_o_res_if (i_clk); ;
bls12_381_pkg::af_point_t pair_i_g1;
bls12_381_pkg::fp2_af_point_t pair_i_g2;


logic [31:0] new_inst_pt;
logic        new_inst_pt_val, new_inst_pt_val_l;
logic        reset_done_inst, reset_done_data;

logic [7:0] cnt;
integer unsigned pt_size;

always_comb begin
  curr_inst = inst_ram_sys_if.q;
  curr_data = data_ram_sys_if.q;
  data_ram_sys_if.d = new_data;
end

code_t inst_state;
point_type_t pt_l;

logic [31:0] last_inst_cnt, curr_inst_pt;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    inst_ram_sys_if.reset_source();
    data_ram_sys_if.we <= 0;
    data_ram_sys_if.a <= 0;
    data_ram_sys_if.re <= 1;
    data_ram_sys_if.en <= 1;
    fp2_pt_mul_out_if.rdy <= 0;
    fp2_pt_mul_in_if.reset_source();
    inst_ram_read <= 0;
    data_ram_read <= 0;
    cnt <= 0;
    inv_fe_o_if.reset_source();
    inv_fe_i_if.rdy <= 0;
    inv_fe2_o_if.reset_source();
    inv_fe2_i_if.rdy <= 0;
    inst_state <= NOOP_WAIT;
    pt_l <= SCALAR;
    new_data <= 0;
    fp_pt_mult_mode <= 0;
    pt_size <= 0;
    idx_in_if.reset_source();
    interrupt_in_if.reset_source();
    last_inst_cnt <= 0;
    pair_o_res_if.rdy <= 0;

    new_inst_pt_val_l <= 0;

    mul_in_if[1].reset_source();
    add_in_if.reset_source();
    sub_in_if.reset_source();

    mul_out_if[1].rdy <= 0;
    add_out_if.rdy <= 0;
    sub_out_if.rdy <= 0;

    pair_i_val <= 0;
    pair_i_g1 <= 0;
    pair_i_g2 <= 0;

  end else begin

    mul_in_if[1].sop <= 1;
    mul_in_if[1].eop <= 1;
    add_in_if.sop <= 1;
    add_in_if.eop <= 1;
    sub_in_if.sop <= 1;
    sub_in_if.eop <= 1;

    new_inst_pt_val_l <= new_inst_pt_val || new_inst_pt_val_l; // Latch this pulse if we want to update instruction pointer

    inst_ram_sys_if.re <= 1;
    inst_ram_sys_if.en <= 1;
    inst_ram_read <= inst_ram_read << 1;

    data_ram_sys_if.re <= 1;
    data_ram_sys_if.en <= 1;
    data_ram_sys_if.we <= 0;
    data_ram_read <= data_ram_read << 1;

    if (fp2_pt_mul_in_if.rdy) fp2_pt_mul_in_if.val <= 0;
    if (inv_fe_o_if.rdy) inv_fe_o_if.val <= 0;
    if (inv_fe2_o_if.rdy) inv_fe2_o_if.val <= 0;
    if (add_in_if.rdy) add_in_if.val <= 0;
    if (sub_in_if.rdy) sub_in_if.val <= 0;
    if (mul_in_if[1].rdy) mul_in_if[1].val <= 0;
    if (pair_o_rdy) pair_i_val <= 0;

    fp2_pt_mul_out_if.rdy <= 1;

    if (idx_in_if.val && idx_in_if.rdy) idx_in_if.val <= 0;
    if (interrupt_in_if.val && interrupt_in_if.rdy) interrupt_in_if.val <= 0;

    last_inst_cnt <= last_inst_cnt + 1;

    case(inst_state)
      NOOP_WAIT: begin
        last_inst_cnt <= last_inst_cnt;
        // Wait in this state
        get_next_inst();
      end
      COPY_REG: begin
        last_inst_cnt <= last_inst_cnt;
        task_copy_reg();
      end
      INV_ELEMENT: begin
        if (cnt == 0) last_inst_cnt <= 0;
        task_inv_element();
      end
      MUL_ELEMENT: begin
        if (cnt == 0) last_inst_cnt <= 0;
        task_mul_element();
      end
      SUB_ELEMENT: begin
        if (cnt == 0) last_inst_cnt <= 0;
        task_sub_element();
      end
      ADD_ELEMENT: begin
        if (cnt == 0) last_inst_cnt <= 0;
        task_add_element();
      end
      SEND_INTERRUPT: begin
        last_inst_cnt <= last_inst_cnt;
        task_send_interrupt();
      end
      POINT_MULT: begin
        if (cnt == 0) last_inst_cnt <= 0;
        task_point_mult();
      end
      // We don't use precaculation for fixed point but could be used as optimizations
      FP_FPOINT_MULT: begin
        if (cnt == 0) last_inst_cnt <= 0;
        task_fp_fpoint_mult();
      end
      FP2_FPOINT_MULT: begin
        if (cnt == 0) last_inst_cnt <= 0;
        task_fp2_fpoint_mult();
      end
      ATE_PAIRING: begin
        if (cnt == 0) last_inst_cnt <= 0;
        task_pairing();
      end
      default: get_next_inst();
    endcase

  end
end

bls12_381_axi_bridge bls12_381_axi_bridge (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .axi_lite_if        ( axi_lite_if     ),
  .data_ram_if        ( data_ram_usr_if ),
  .inst_ram_if        ( inst_ram_usr_if ),
  .i_curr_inst_pt     ( curr_inst_pt    ),
  .i_last_inst_cnt    ( last_inst_cnt   ),
  .i_reset_done       ( reset_done_data && reset_done_inst ),
  .o_new_inst_pt      ( new_inst_pt     ),
  .o_new_inst_pt_val  ( new_inst_pt_val ),
  .o_reset_inst_ram   ( reset_inst_ram  ),
  .o_reset_data_ram   ( reset_data_ram  )
);

always_comb begin
  curr_inst_pt = 0;
  curr_inst_pt = inst_ram_sys_if.a;
end

uram_reset #(
  .RAM_WIDTH(bls12_381_pkg::INST_RAM_WIDTH),
  .RAM_DEPTH(bls12_381_pkg::INST_RAM_DEPTH),
  .PIPELINES( READ_CYCLE - 2 )
)
inst_uram_reset (
  .a ( inst_ram_usr_if ),
  .b ( inst_ram_sys_if ),
  .o_reset_done ( reset_done_inst )
);

uram_reset #(
  .RAM_WIDTH(bls12_381_pkg::DATA_RAM_WIDTH),
  .RAM_DEPTH(bls12_381_pkg::DATA_RAM_DEPTH),
  .PIPELINES( READ_CYCLE - 2 )
)
data_uram_reset (
  .a ( data_ram_usr_if ),
  .b ( data_ram_sys_if ),
  .o_reset_done ( reset_done_data )
);

bls12_381_pairing_wrapper #(
  .CTL_BITS    ( CTL_BITS ),
  .OVR_WRT_BIT ( 0        )
)
bls12_381_pairing_wrapper (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_val ( pair_i_val ),
  .o_rdy ( pair_o_rdy ),
  .i_g1_af ( pair_i_g1 ),
  .i_g2_af ( pair_i_g2 ),
  .o_fe12_if    ( pair_o_res_if ),
  .o_mul_fe_if  ( mul_in_if[0]  ),
  .i_mul_fe_if  ( mul_out_if[0] ),
  .o_inv_fe2_if ( inv_fe2_i_if  ),
  .i_inv_fe2_if ( inv_fe2_o_if  ),
  .o_inv_fe_if  ( inv_fe_i_if   ),
  .i_inv_fe_if  ( inv_fe_o_if   )
);

resource_share # (
  .NUM_IN       ( 2                ),
  .DAT_BITS     ( 2*$bits(FE_TYPE) ),
  .CTL_BITS     ( CTL_BITS         ),
  .OVR_WRT_BIT  ( 120              ),
  .PIPELINE_IN  ( 1                ),
  .PIPELINE_OUT ( 0                )
)
resource_share_mul (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( mul_in_if[1:0]  ),
  .o_res ( mul_in_if[2]    ),
  .i_res ( mul_out_if[2]   ),
  .o_axi ( mul_out_if[1:0] )
);

ec_fp_mult_mod #(
  .P             ( P        ),
  .KARATSUBA_LVL ( 3        ),
  .CTL_BITS      ( CTL_BITS )
)
ec_fp_mult_mod (
  .i_clk( i_clk ),
  .i_rst( i_rst ),
  .i_mul ( mul_in_if[2]  ),
  .o_mul ( mul_out_if[2] )
);

adder_pipe # (
  .P        ( P        ),
  .CTL_BITS ( CTL_BITS ),
  .LEVEL    ( 2        )
)
adder_pipe (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_add ( add_in_if  ),
  .o_add ( add_out_if )
);

subtractor_pipe # (
  .P        ( P        ),
  .CTL_BITS ( CTL_BITS ),
  .LEVEL    ( 2        )
)
subtractor_pipe (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_sub ( sub_in_if  ),
  .o_sub ( sub_out_if )
);

// Tasks for each of the different instructions

task get_next_inst();
  if(inst_ram_read == 0) begin
    inst_ram_sys_if.a <=  new_inst_pt_val_l ? new_inst_pt : inst_state == NOOP_WAIT ? inst_ram_sys_if.a : inst_ram_sys_if.a + 1;
    inst_ram_read[0] <= 1;
    if (new_inst_pt_val_l) new_inst_pt_val_l <= 0;
  end
  if (inst_ram_read[READ_CYCLE]) begin
    inst_state <= curr_inst.code;
    cnt <= 0;
  end
endtask

task task_sub_element();
  case(cnt)
    0: begin
      sub_out_if.rdy <= 1;
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= 1;
    end
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        sub_in_if.dat[0 +: $bits(fe_t)] <= curr_data.dat;
        pt_l <= curr_data.pt;
        data_ram_sys_if.a <=  curr_inst.b;
        data_ram_read[0] <= 1;
        cnt <= 2;
      end
    end
    2: begin
      if (data_ram_read[READ_CYCLE]) begin
        sub_in_if.dat[$bits(fe_t) +: $bits(fe_t)] <= curr_data.dat;
        sub_in_if.val <= 1;
      end
      if (sub_out_if.val && sub_out_if.rdy) begin
        data_ram_sys_if.a <=  curr_inst.c;
        new_data.dat <= sub_out_if.dat;
        new_data.pt <= pt_l;
        data_ram_sys_if.we <= 1;
        cnt <= 5;
        if (pt_l == FE2) begin
          // FE2 requires extra logic
          cnt <= 3;
        end
      end
    end
    3: begin
      if (!(|data_ram_read)) begin
        data_ram_sys_if.a <= curr_inst.a + 1;
        data_ram_read[0] <= 1;
      end
      if (data_ram_read[READ_CYCLE]) begin
        sub_in_if.dat[0 +: $bits(fe_t)] <= curr_data.dat;
        pt_l <= curr_data.pt;
        data_ram_sys_if.a <=  curr_inst.b + 1;
        data_ram_read[0] <= 1;
        cnt <= 4;
      end
    end
    4: begin
      if (data_ram_read[READ_CYCLE]) begin
        sub_in_if.dat[$bits(fe_t) +: $bits(fe_t)] <= curr_data.dat;
        sub_in_if.val <= 1;
      end
      if (sub_out_if.val && sub_out_if.rdy) begin
        data_ram_sys_if.a <=  curr_inst.c + 1;
        new_data.dat <= sub_out_if.dat;
        new_data.pt <= pt_l;
        data_ram_sys_if.we <= 1;
        cnt <= 5;
      end
    end
    5: begin
      get_next_inst();
    end
  endcase
endtask;

task task_add_element();
  case(cnt)
    0: begin
      add_out_if.rdy <= 1;
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= cnt + 1;
    end
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        add_in_if.dat[0 +: $bits(fe_t)] <= curr_data.dat;
        pt_l <= curr_data.pt;
        data_ram_sys_if.a <=  curr_inst.b;
        data_ram_read[0] <= 1;
        cnt <= 2;
      end
    end
    2: begin
      if (data_ram_read[READ_CYCLE]) begin
        add_in_if.dat[$bits(fe_t) +: $bits(fe_t)] <= curr_data.dat;
        add_in_if.val <= 1;
      end
      if (add_out_if.val && add_out_if.rdy) begin
        data_ram_sys_if.a <=  curr_inst.c;
        new_data.dat <= add_out_if.dat;
        new_data.pt <= pt_l;
        data_ram_sys_if.we <= 1;
        cnt <= 5;
        if (pt_l == FE2) begin
          // FE2 requires extra logic
          cnt <= 3;
        end
      end
    end
    3: begin
      if (!(|data_ram_read)) begin
        data_ram_sys_if.a <= curr_inst.a + 1;
        data_ram_read[0] <= 1;
      end
      if (data_ram_read[READ_CYCLE]) begin
        add_in_if.dat[0 +: $bits(fe_t)] <= curr_data.dat;
        pt_l <= curr_data.pt;
        data_ram_sys_if.a <=  curr_inst.b + 1;
        data_ram_read[0] <= 1;
        cnt <= 4;
      end
    end
    4: begin
      if (data_ram_read[READ_CYCLE]) begin
        add_in_if.dat[$bits(fe_t) +: $bits(fe_t)] <= curr_data.dat;
        add_in_if.val <= 1;
      end
      if (add_out_if.val && add_out_if.rdy) begin
        data_ram_sys_if.a <=  curr_inst.c + 1;
        new_data.dat <= add_out_if.dat;
        new_data.pt <= pt_l;
        data_ram_sys_if.we <= 1;
        cnt <= 5;
      end
    end
    5: begin
      get_next_inst();
    end
  endcase
endtask;

task task_mul_element();
  case(cnt)
    0: begin
      mul_out_if[1].rdy <= 1;
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= cnt + 1;
    end
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        mul_in_if[1].dat[0 +: $bits(fe_t)] <= curr_data.dat;
        pt_l <= curr_data.pt;
        data_ram_sys_if.a <=  curr_inst.b;
        data_ram_read[0] <= 1;
        cnt <= 2;
      end
    end
    2: begin
      if (data_ram_read[READ_CYCLE]) begin
        mul_in_if[1].dat[$bits(fe_t) +: $bits(fe_t)] <= curr_data.dat;
        mul_in_if[1].val <= 1;
        mul_in_if[1].ctl <= 0;
        if (pt_l == FE2) begin
          data_ram_sys_if.a <= curr_inst.a + 1;
          data_ram_read[0] <= 1;
          mul_out_if[1].rdy <= 0;
          // FE2 requires extra logic
          cnt <= 3;
        end
      end
      if (mul_out_if[1].val && mul_out_if[1].rdy) begin
        data_ram_sys_if.a <=  curr_inst.c;
        new_data.dat <= mul_out_if[1].dat;
        new_data.pt <= pt_l;
        data_ram_sys_if.we <= 1;
        cnt <= 8;
      end
    end
    3: begin
      if (data_ram_read[READ_CYCLE]) begin
         mul_in_if[1].dat[0 +: $bits(fe_t)] <= curr_data.dat;
         mul_in_if[1].val <= 1;
         mul_in_if[1].ctl <= 3;
         data_ram_sys_if.a <= curr_inst.b + 1;
         data_ram_read[0] <= 1;
         cnt <= 4;
      end
    end
    4: begin
      if (data_ram_read[READ_CYCLE]) begin
         mul_in_if[1].dat[$bits(fe_t) +: $bits(fe_t)] <= curr_data.dat;
         mul_in_if[1].val <= 1;
         mul_in_if[1].ctl <= 1;
         data_ram_sys_if.a <= curr_inst.a;
         data_ram_read[0] <= 1;
         cnt <= 5;
      end
    end
    5: begin
      if (data_ram_read[READ_CYCLE]) begin
         mul_in_if[1].dat[0 +: $bits(fe_t)] <= curr_data.dat;
         mul_in_if[1].val <= 1;
         mul_in_if[1].ctl <= 2;
         mul_out_if[1].rdy <= 1;
         cnt <= 6;
      end
    end
    6: begin
      sub_out_if.rdy <= 1;
      if (mul_out_if[1].val && mul_out_if[1].rdy) begin
        case(mul_out_if[1].ctl)
          0: begin
            sub_in_if.dat[0 +: $bits(fe_t)] <= mul_out_if[1].dat;
          end
          1: begin
            sub_in_if.dat[$bits(fe_t) +: $bits(fe_t)] <= mul_out_if[1].dat;
            sub_in_if.val <= 1;
          end
          2: begin
            add_in_if.dat[0 +: $bits(fe_t)] <= mul_out_if[1].dat;
            add_in_if.val <= 1;
          end
          3: begin
            add_in_if.dat[$bits(fe_t) +: $bits(fe_t)] <= mul_out_if[1].dat;
          end
        endcase
      end

      if (sub_out_if.val && sub_out_if.rdy) begin
        new_data.dat <= sub_out_if.dat;
        new_data.pt <= pt_l;
        data_ram_sys_if.we <= 1;
        data_ram_sys_if.a <=  curr_inst.c;
        add_out_if.rdy <= 1;
      end
      if (add_out_if.val && add_out_if.rdy) begin
        new_data.dat <= add_out_if.dat;
        new_data.pt <= pt_l;
        data_ram_sys_if.we <= 1;
        data_ram_sys_if.a <=  curr_inst.c + 1;
        cnt <= 8;
      end
    end
    8: begin
      get_next_inst();
    end
  endcase
endtask;

task task_copy_reg();
  case(cnt)
    0: begin
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= cnt + 1;
    end
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        data_ram_sys_if.a <=  curr_inst.b;
        new_data <= curr_data;
        data_ram_sys_if.we <= 1;
        cnt <= cnt + 1;
      end
    end
    2: begin
      get_next_inst();
    end
  endcase
endtask

task task_inv_element();
  case(cnt)
    0: begin
      inv_fe_o_if.reset_source();
      inv_fe2_o_if.reset_source();
      inv_fe_i_if.rdy <= 0;
      inv_fe2_i_if.rdy <= 0;
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= cnt + 1;
    end
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        // Depending on type of data
        if (curr_data.pt == FE) begin
          inv_fe_o_if.val <= 1;
          inv_fe_o_if.dat <= curr_data.dat;
          inv_fe_o_if.sop <= 1;
          inv_fe_o_if.eop <= 1;
          pt_l <= curr_data.pt;
        end else begin
          inv_fe2_o_if.dat <= curr_data.dat;
          data_ram_sys_if.a <= data_ram_sys_if.a + 1;
          data_ram_read[0] <= 1;
          inv_fe2_o_if.ctl <= 0;
          inv_fe2_o_if.val <= 1;
          inv_fe2_o_if.sop <= 1;
          inv_fe2_o_if.eop <= 0;
        end
      end
      if (inv_fe_o_if.val && inv_fe_o_if.rdy) cnt <= 2;
      if (inv_fe2_o_if.val && inv_fe2_o_if.rdy) cnt <= 3;
    end
    2: begin
      inv_fe_i_if.rdy <= 1;
      // FE element
      if (inv_fe_i_if.val && inv_fe_i_if.rdy) begin
        data_ram_sys_if.a <= curr_inst.b;
        new_data.pt <= pt_l;
        new_data.dat <= inv_fe_i_if.dat;
        data_ram_sys_if.we <= 1;
        cnt <= 5;
      end
    end
    //FE2 element
    3: begin
      if (data_ram_read[READ_CYCLE]) begin
        inv_fe2_o_if.val <= 1;
        inv_fe2_o_if.dat <= curr_data.dat;
        inv_fe2_o_if.sop <= 0;
        inv_fe2_o_if.eop <= 1;
        pt_l <= curr_data.pt;
      end
      if (inv_fe2_o_if.eop && inv_fe2_o_if.val && inv_fe2_o_if.rdy) cnt <= 4;
    end
    4: begin
      inv_fe2_i_if.rdy <= 1;
      if (inv_fe2_i_if.val && inv_fe2_i_if.rdy) begin
        data_ram_sys_if.a <= inv_fe2_i_if.sop ? curr_inst.b : data_ram_sys_if.a + 1;
        new_data.pt <= pt_l;
        new_data.dat <= inv_fe2_i_if.dat;
        data_ram_sys_if.we <= 1;
        if (inv_fe2_i_if.eop) cnt <= 5;
      end
    end
    5: begin
      get_next_inst();
    end
  endcase
endtask

task task_point_mult();
  fp2_pt_mul_out_if.rdy <= 0;
  case(cnt) inside
    0: begin
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= cnt + 1;
    end
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        data_ram_sys_if.a <= curr_inst.b;
        data_ram_read[0] <= 1;
        pt_size <= 0;
        fp2_pt_mul_in_if.ctl <= curr_data.dat;
        fp2_pt_mul_in_if.dat <= {FE2_one, {DAT_BITS*4{1'd0}}}; // This is in case we use affine coordinates
        cnt <= cnt + 1;
      end
    end
    2: begin
      if (data_ram_read[READ_CYCLE]) begin
        fp_pt_mult_mode <= (curr_data.pt == FP_AF) || (curr_data.pt == FP_JB);

        if (curr_data.pt == FP2_JB || curr_data.pt == FP2_AF) begin
          fp2_pt_mul_in_if.dat[DAT_BITS*pt_size +: DAT_BITS] <= curr_data.dat;
        end else begin
          fp2_pt_mul_in_if.dat[2*DAT_BITS*pt_size +: 2*DAT_BITS] <= {(DAT_BITS)'(0), curr_data.dat};
        end

        if (pt_size == get_point_type_size(curr_data.pt)-1) begin
          data_ram_sys_if.a <= curr_inst.c;
          if (curr_data.pt == FP2_AF || curr_data.pt == FP2_JB)
            cnt <= 6;
          else
            cnt <= 3;
          fp2_pt_mul_in_if.val <= 1;
        end else begin
          pt_size <= pt_size + 1;
          data_ram_sys_if.a <= data_ram_sys_if.a + 1;
          data_ram_read[0] <= 1;
        end

      end
    end
    // Wait for result of FP_JB
    3,4,5: begin
      if (fp2_pt_mul_out_if.val) begin
         new_data.pt <= FP_JB;
         new_data.dat <= fp2_pt_mul_out_if.dat >> ((cnt-3)*2*DAT_BITS);
         data_ram_sys_if.we <= 1;
         if (cnt > 3) data_ram_sys_if.a <= data_ram_sys_if.a + 1;
         cnt <= cnt + 1;
         if (cnt == 5) begin
           fp2_pt_mul_out_if.rdy <= 1;
           cnt <= 12;
         end
       end
    end
    // Wait for result of FP2_JB
    6,7,8,9,10,11: begin
      if (fp2_pt_mul_out_if.val) begin
         new_data.pt <= FP2_JB;
         new_data.dat <= fp2_pt_mul_out_if.dat >> ((cnt-6)*DAT_BITS);
         data_ram_sys_if.we <= 1;
         if (cnt > 6) data_ram_sys_if.a <= data_ram_sys_if.a + 1;
         cnt <= cnt + 1;
         if (cnt == 11) begin
           fp2_pt_mul_out_if.rdy <= 1;
           cnt <= 12;
         end
      end
    end
    12: begin
      get_next_inst();
    end
  endcase
endtask

task task_fp_fpoint_mult();
  fp2_pt_mul_out_if.rdy <= 0;
  fp_pt_mult_mode <= 1;
  case(cnt) inside
    0: begin
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= cnt + 1;
    end
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        data_ram_sys_if.a <= curr_inst.b;
        fp2_pt_mul_in_if.ctl <= curr_data.dat;
        fp2_pt_mul_in_if.dat <= g_point_fp2;
        fp2_pt_mul_in_if.val <= 1;
        cnt <= cnt + 1;
      end
    end
    // Wait for result
    2,3,4: begin
      if (fp2_pt_mul_out_if.val) begin
         new_data.pt <= FP_JB;
         new_data.dat <= fp2_pt_mul_out_if.dat >> ((cnt-2)*2*DAT_BITS);
         data_ram_sys_if.we <= 1;
         if (cnt > 2) data_ram_sys_if.a <= data_ram_sys_if.a + 1;
         cnt <= cnt + 1;
         if (cnt == 4) begin
           fp2_pt_mul_out_if.rdy <= 1;
         end
      end
    end
    5: begin
      get_next_inst();
    end
  endcase
endtask

task task_fp2_fpoint_mult();
  fp2_pt_mul_out_if.rdy <= 0;
  fp_pt_mult_mode <= 0;
  case(cnt) inside
    0: begin
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= cnt + 1;
    end
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        data_ram_sys_if.a <= curr_inst.b;
        fp2_pt_mul_in_if.ctl <= curr_data.dat;
        fp2_pt_mul_in_if.dat <= bls12_381_pkg::g2_point;
        fp2_pt_mul_in_if.val <= 1;
        cnt <= cnt + 1;
      end
    end
    // Wait for result
    2,3,4,5,6,7: begin
      if (fp2_pt_mul_out_if.val) begin
         new_data.pt <= FP2_JB;
         new_data.dat <= fp2_pt_mul_out_if.dat >> ((cnt-2)*DAT_BITS);
         data_ram_sys_if.we <= 1;
         if (cnt > 2) data_ram_sys_if.a <= data_ram_sys_if.a + 1;
         cnt <= cnt + 1;
         if (cnt == 7) begin
           fp2_pt_mul_out_if.rdy <= 1;
         end
      end
    end
    8: begin
      get_next_inst();
    end
  endcase
endtask

task task_pairing();
  case(cnt) inside
    0: begin
      data_ram_sys_if.a <= curr_inst.a;
      data_ram_read[0] <= 1;
      cnt <= cnt + 1;
    end
    // Load G1 affine point
    1,2: begin
      if (data_ram_read[READ_CYCLE]) begin
        data_ram_sys_if.a <= data_ram_sys_if.a + 1;
        data_ram_read[0] <= 1;
        case(cnt)
          1: pair_i_g1.x <= curr_data.dat;
          2: pair_i_g1.y <= curr_data.dat;
        endcase
        cnt <= cnt + 1;
        if (cnt == 2) begin
          data_ram_sys_if.a <= curr_inst.b;
        end
      end
    end
    // Load G2 affine point
    3,4,5,6: begin
      if (data_ram_read[READ_CYCLE]) begin
        data_ram_sys_if.a <= data_ram_sys_if.a + 1;
        data_ram_read[0] <= 1;
        case(cnt)
          3: pair_i_g2.x[0] <= curr_data.dat;
          4: pair_i_g2.x[1] <= curr_data.dat;
          5: pair_i_g2.y[0] <= curr_data.dat;
          6: pair_i_g2.y[1] <= curr_data.dat;
        endcase
        cnt <= cnt + 1;
        if (cnt == 6) begin
          data_ram_sys_if.a <= curr_inst.c;
          pair_i_val <= 1;
          pair_o_res_if.rdy <= 1;
        end
      end
    end
    // Wait for result
    7,8,9,10,11,12,13,14,15,16,17,18: begin
      if (pair_o_res_if.val) begin
         new_data.pt <= FE12;
         new_data.dat <= pair_o_res_if.dat;
         data_ram_sys_if.we <= 1;
         if (cnt > 7) data_ram_sys_if.a <= data_ram_sys_if.a + 1;
         cnt <= cnt + 1;
         if (cnt == 18) begin
           pair_o_res_if.rdy <= 0;
         end
      end
    end
    19: begin
      get_next_inst();
    end
  endcase
endtask

task task_send_interrupt();
  case(cnt) inside
    // Load the data
    0: begin
      interrupt_in_if.eop <= 0;
      data_ram_sys_if.a <= curr_inst.a;
      if (interrupt_state != WAIT_FIFO) begin
        // Wait here
      end else begin
        data_ram_read[0] <= 1;
        cnt <= cnt + 1;
      end
    end
    // Check what type of data it is and write index fifo
    1: begin
      if (data_ram_read[READ_CYCLE]) begin
        pt_size <= get_point_type_size(curr_data.pt);
        idx_in_if.val <= 1;
        idx_in_if.dat <= {curr_data.pt, curr_inst.b};
      end
      if (idx_in_if.val && idx_in_if.rdy) begin
        cnt <= cnt + 1;
        data_ram_read[0] <= 1;
        data_ram_sys_if.a <= curr_inst.a;
      end
    end
    // Write the slot fifo
    2: begin

      if (~interrupt_in_if.val) begin
        interrupt_in_if.dat <= curr_data.dat;
        interrupt_in_if.val <= data_ram_read[READ_CYCLE];
        interrupt_in_if.eop <= pt_size == 1;
      end

      if (interrupt_in_if.val && interrupt_in_if.rdy) begin
        pt_size <= pt_size - 1;
        interrupt_in_if.val <= 0;
        data_ram_sys_if.a <= data_ram_sys_if.a + 1;
        data_ram_read[0] <= 1;
        if (pt_size == 1) cnt <= cnt + 1;
      end

    end
    3: begin
      get_next_inst();
    end
  endcase
endtask

// Use this FIFO - width converter to send out interrupt messages
axis_dwidth_converter_48_to_8 interrupt_converter_48_to_8 (
  .aclk   ( i_clk  ),                    // input wire aclk
  .aresetn( ~i_rst ),              // input wire aresetn
  .s_axis_tvalid( interrupt_in_if.val  ),  // input wire s_axis_tvalid
  .s_axis_tready( interrupt_in_if.rdy  ),  // output wire s_axis_tready
  .s_axis_tdata ( interrupt_in_if.dat  ),    // input wire [383 : 0] s_axis_tdata
  .s_axis_tlast ( interrupt_in_if.eop  ),    // input wire s_axis_tlast
  .m_axis_tvalid( interrupt_out_if.val ),  // output wire m_axis_tvalid
  .m_axis_tready( interrupt_out_if.rdy ),  // input wire m_axis_tready
  .m_axis_tdata ( interrupt_out_if.dat ),    // output wire [63 : 0] m_axis_tdata
  .m_axis_tlast ( interrupt_out_if.eop )    // output wire m_axis_tlast
);

// This just stores the index + length of interrupt packet
axi_stream_fifo #(
  .SIZE     ( 4  ),
  .DAT_BITS ( 16 + 3 )
)
interrupt_index_fifo (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( idx_in_if ),
  .o_axi ( idx_out_if ),
  .o_full(),
  .o_emp ()
);

// Process for reading from FIFO and sending interrupt
always_comb begin
  interrupt_out_if.rdy = (interrupt_state == SEND_DATA) && (~tx_if.val || (tx_if.val && tx_if.rdy));
end


always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    interrupt_rpl <= 0;
    interrupt_state <= WAIT_FIFO;
    interrupt_hdr_byt <= 0;
    idx_out_if.rdy <= 0;
    tx_if.reset_source();
  end else begin
    case (interrupt_state)
      WAIT_FIFO: begin
        idx_out_if.rdy <= 1;
        if (idx_out_if.val) begin
          idx_out_if.rdy <= 0;
          interrupt_state <= SEND_HDR;
          interrupt_rpl <= bls12_381_interrupt_rpl(idx_out_if.dat[0 +: 16], (point_type_t)'(idx_out_if.dat[16 +: 3]));
          interrupt_hdr_byt <= $bits(bls12_381_interrupt_rpl_t)/8;
        end
      end
      // Header needs to be aligned to AXI_STREAM_BYTS
      SEND_HDR: begin
        if (~tx_if.val || (tx_if.val && tx_if.rdy)) begin
          tx_if.sop <= interrupt_hdr_byt == $bits(bls12_381_interrupt_rpl_t)/8;
          tx_if.val <= 1;
          tx_if.dat <= interrupt_rpl;
          interrupt_rpl <= interrupt_rpl >> AXI_STREAM_BYTS*8;
          interrupt_hdr_byt <= interrupt_hdr_byt - 8;
          if (interrupt_hdr_byt <= 8) interrupt_state <= SEND_DATA;
        end
      end
      SEND_DATA: begin
        if (~tx_if.val || (tx_if.val && tx_if.rdy)) begin
          tx_if.sop <= 0;
          tx_if.val <= interrupt_out_if.val;
          tx_if.dat <= interrupt_out_if.dat;
          tx_if.eop <= interrupt_out_if.eop;
          if (tx_if.eop) begin
            tx_if.reset_source();
            interrupt_state <= WAIT_FIFO;
          end
        end
      end
    endcase
  end
end
endmodule