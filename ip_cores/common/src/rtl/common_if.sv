/*
  Commonly used interfaces:
    - AXI stream
    - RAM
 
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

interface if_axi_stream # (
  parameter DAT_BYTS = 64,
  parameter DAT_BITS = DAT_BYTS*8,
  parameter CTL_BYTS = 1,
  parameter CTL_BITS = CTL_BYTS*8,
  parameter MOD_BITS = DAT_BYTS == 1 ? 1 : $clog2(DAT_BYTS)
)(
  input i_clk
);
  
  logic rdy;
  logic val;
  logic err;
  logic sop;
  logic eop;
  logic [CTL_BITS-1:0] ctl;
  logic [DAT_BITS-1:0] dat;
  logic [MOD_BITS-1:0] mod;
  
  modport sink (input val, err, sop, eop, ctl, dat, mod, i_clk, output rdy,
                import function to_struct() );
  modport source (output val, err, sop, eop, ctl, dat, mod, input rdy, i_clk,
                  import task reset_source(), import task copy_if(in), import function to_struct());
 
  // Task to reset a source interface signals to all 0
  task reset_source();
    val <= 0;
    err <= 0;
    sop <= 0;
    eop <= 0;
    dat <= 0;
    ctl <= 0;
    mod <= 0;
  endtask
 
  typedef struct packed {
    logic val;
    logic err;
    logic sop;
    logic eop;
    logic [CTL_BITS-1:0] ctl;
    logic [DAT_BITS-1:0] dat;
    logic [MOD_BITS-1:0] mod;
  } if_t;
  
  function if_t to_struct();
    to_struct.val = val;
    to_struct.err = err;
    to_struct.sop = sop;
    to_struct.eop = eop;
    to_struct.ctl = ctl;
    to_struct.dat = dat;
    to_struct.mod = mod;
  endfunction
  
    // Task to apply signals from one task to another in a clocked process
  task copy_if(if_t in);
    dat <= in.dat;
    val <= in.val;
    sop <= in.sop;
    eop <= in.eop;
    mod <= in.mod;
    ctl <= in.ctl;
    err <= in.err;
  endtask
  
  // Task used in simulation to drive data on a source interface
  task automatic put_stream(input logic [common_pkg::MAX_SIM_BYTS*8-1:0] data, input integer signed len);
    logic sop_l=0;
    
    reset_source();
    @(posedge i_clk);
    
    while (len > 0) begin
      sop = ~sop_l;
      eop = len - DAT_BYTS <= 0;
      val = 1;
      dat = data;
      if (eop) mod = len;
      data = data >> DAT_BITS;
      sop_l = 1;
      len = len - DAT_BYTS;
      @(posedge i_clk); // Go to next clock edge
      while (!rdy) @(posedge i_clk); // If not rdy then wait here
    end
    reset_source();
  endtask
  
  task print();
    $display("@ %t Interface values .val %h .sop %h .eop %h .err %h .mod 0x%h\n.dat 0x%h", $time, val, sop, eop, err, mod, dat);
  endtask;
  
  // Task used in simulation to get data from a sink interface
  task automatic get_stream(ref logic [common_pkg::MAX_SIM_BYTS*8-1:0] data, ref integer signed len);
    logic sop_l = 0;
    rdy = 1;
    len = 0;
    data = 0;
    @(posedge i_clk);
    
    while (1) begin
      if (val && rdy) begin
        sop_l = sop_l || sop;
        if (!sop_l) begin
          print();
          $fatal(1, "%m %t:ERROR, get_stream() .val without seeing .sop", $time);
        end
        data[len*8 +: DAT_BITS] = dat;
        len = len + (eop ? (mod == 0 ? DAT_BYTS : mod) : DAT_BYTS);
        if (eop) break;
      end
      @(posedge i_clk);
    end
  endtask
  
endinterface

interface if_ram # (
  parameter RAM_WIDTH = 32,
  parameter RAM_DEPTH = 128
)(
  input i_clk, i_rst
);
  
  logic [$clog2(RAM_DEPTH)-1:0] a;
  logic en;
  logic we;
  logic re;
  logic [RAM_WIDTH-1:0 ] d, q;
  
  modport sink (input a, en, re, we, d, i_clk, i_rst, output q);
  modport source (output a, en, re, we, d, input q, i_clk, i_rst, import task reset_source());
  
  // Task to reset a source interface signals to all 0
  task reset_source();
    a <= 0;
    en <= 0;
    we <= 0;
    re <= 0;
    d <= 0;
  endtask
  
endinterface