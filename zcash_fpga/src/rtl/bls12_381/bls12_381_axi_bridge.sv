/*
  Handles all the AXI lite to RAM memory access for bls12-381 coprocessor

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

module bls12_381_axi_bridge (
  input i_clk, i_rst,
  if_axi_lite.sink axi_lite_if,
  if_ram.source    data_ram_if,
  if_ram.source    inst_ram_if,

  // Configuration signals
  input [31:0] i_curr_inst_pt,
  input [31:0] i_last_inst_cnt,
  input        i_reset_done,

  output logic [31:0] o_new_inst_pt,
  output logic        o_new_inst_pt_val,
  output logic        o_reset_inst_ram,
  output logic        o_reset_data_ram,

  // Interface to memory used in multiplier
  output logic [31:0] o_ram_d,
  output logic        o_ram_we,
  output logic        o_ram_se
);

import bls12_381_pkg::*;


logic [READ_CYCLE:0] data_ram_read, inst_ram_read;
logic wr_active;
logic [31:0] wr_addr;

logic [31:0] curr_inst_pt;
logic [31:0] last_inst_cnt;

always_ff @ (posedge i_clk) begin
  curr_inst_pt <= i_curr_inst_pt;
  last_inst_cnt <= i_last_inst_cnt;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    axi_lite_if.reset_sink();
    data_ram_if.reset_source();
    inst_ram_if.reset_source();
    data_ram_read <= 0;
    inst_ram_read <= 0;
    wr_active <= 0;
    wr_addr <= 0;
    o_new_inst_pt_val <= 0;
    o_new_inst_pt <= 0;
    o_reset_inst_ram <= 0;
    o_reset_data_ram <= 0;

    o_ram_d <= 0;
    o_ram_we <= 0;
    o_ram_se <= 0;
  end else begin

    o_reset_inst_ram <= 0;
    o_reset_data_ram <= 0;
    o_new_inst_pt_val <= 0;

    data_ram_read <= data_ram_read << 1;
    inst_ram_read <= inst_ram_read << 1;

    inst_ram_if.en <= 1;
    inst_ram_if.re <= 1;
    inst_ram_if.we <= 0;

    data_ram_if.en <= 1;
    data_ram_if.re <= 1;
    data_ram_if.we <= 0;

    o_ram_we <= 0;
    o_ram_se <= 0;

    axi_lite_if.arready <= data_ram_read == 0 && inst_ram_read == 0 &&
                           wr_active == 0 && i_reset_done == 1;

    axi_lite_if.awready <= data_ram_read == 0 && inst_ram_read == 0 &&
                           wr_active == 0 && i_reset_done == 1;

    if (axi_lite_if.bready && axi_lite_if.bvalid) axi_lite_if.bvalid <= 0;
    if (axi_lite_if.rvalid && axi_lite_if.rready) axi_lite_if.rvalid <= 0;
    if (axi_lite_if.wready && axi_lite_if.wvalid) axi_lite_if.wready <= 0;
    if (axi_lite_if.bvalid && axi_lite_if.bready) begin
      axi_lite_if.awready <= 1;
      axi_lite_if.bvalid <= 0;
      wr_active <= 0;
    end

    // Read requests
    if (inst_ram_read[READ_CYCLE]) begin
      axi_lite_if.rdata <= inst_ram_if.q >> ((axi_lite_if.araddr - INST_AXIL_START) % INST_RAM_ALIGN_BYTE)*8;
      axi_lite_if.rvalid <= 1;
    end
    if (data_ram_read[READ_CYCLE]) begin
      axi_lite_if.rdata <= data_ram_if.q >> ((axi_lite_if.araddr - DATA_AXIL_START) % DATA_RAM_ALIGN_BYTE)*8;
      axi_lite_if.rvalid <= 1;
    end

    if (axi_lite_if.arvalid && axi_lite_if.arready) begin
      if (axi_lite_if.araddr < INST_AXIL_START) begin
        axi_lite_if.rvalid <= 1;
        // Config area
        case(axi_lite_if.araddr)
          32'h0: axi_lite_if.rdata <= INST_AXIL_START;
          32'h4: axi_lite_if.rdata <= DATA_AXIL_START;
          32'h8: axi_lite_if.rdata <= DATA_RAM_DEPTH;
          32'hc: axi_lite_if.rdata <= INST_RAM_DEPTH;
          32'h10: axi_lite_if.rdata <= curr_inst_pt;
          32'h14: axi_lite_if.rdata <= last_inst_cnt;
          default: axi_lite_if.rdata <= 32'hbeef;
        endcase
      end else
      if (axi_lite_if.araddr < DATA_AXIL_START) begin
        // Instruction memory
        inst_ram_read[0] <= 1;
        inst_ram_if.a <= (axi_lite_if.araddr - INST_AXIL_START) / INST_RAM_ALIGN_BYTE;
      end else begin
        // Data memory
        data_ram_read[0] <= 1;
        data_ram_if.a <= (axi_lite_if.araddr - DATA_AXIL_START) / DATA_RAM_ALIGN_BYTE;
      end
    end else
    // Write requests (read gets priority)
    if (axi_lite_if.awvalid && axi_lite_if.awready) begin
      wr_active <= 1;
      axi_lite_if.awready <= 0;
      axi_lite_if.wready <= 1;
      wr_addr <= axi_lite_if.awaddr;
    end

    if (axi_lite_if.wready && axi_lite_if.wvalid) begin
      axi_lite_if.bvalid <= 1;
      if (wr_addr < INST_AXIL_START) begin
        // Config area
        case(wr_addr)
          32'h10: begin // This updates the current instruction pointer
            o_new_inst_pt_val <= 1;
            o_new_inst_pt <= axi_lite_if.wdata;
          end
          32'h0: begin
            o_reset_inst_ram <= axi_lite_if.wdata[0]; // This will reset the instruction ram
            o_reset_data_ram <= axi_lite_if.wdata[1]; // This will reset the data ram
          end
          32'h18: begin
            o_ram_d <= axi_lite_if.wdata;
          end
          32'h1c: begin
            o_ram_we <= axi_lite_if.wdata[0];
            o_ram_se <= axi_lite_if.wdata[1];
          end
        endcase
      end else
      if (wr_addr < DATA_AXIL_START) begin
        // Instruction memory
        inst_ram_if.d[(((wr_addr - INST_AXIL_START) % INST_RAM_ALIGN_BYTE)/INST_RAM_USR_WIDTH)*32 +: 32] <= axi_lite_if.wdata;
        inst_ram_if.a <= (wr_addr - INST_AXIL_START) / INST_RAM_ALIGN_BYTE;
        // Only write on the last work to make this atomic
        if ((wr_addr - INST_AXIL_START) % 8 == 4) inst_ram_if.we <= 1;
      end else begin
        // Data memory
        data_ram_if.d[(((wr_addr - DATA_AXIL_START) % DATA_RAM_ALIGN_BYTE)/DATA_RAM_USR_WIDTH)*32 +: 32] <= axi_lite_if.wdata;
        data_ram_if.a <= (wr_addr - DATA_AXIL_START) / DATA_RAM_ALIGN_BYTE;
        // Only write on the last work to make this atomic
        if ((wr_addr - DATA_AXIL_START) % 64 == 44) data_ram_if.we <= 1;
      end
    end
  end
end

endmodule