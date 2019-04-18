
//  Xilinx UltraRAM True Dual Port Mode.  This code implements
//  a parameterizable UltraRAM block with write/read on both ports in
//  No change behavior on both the ports . The behavior of this RAM is
//  when data is written, the output of RAM is unchanged w.r.t each port.
//  Only when write is inactive data corresponding to the address is
//  presented on the output port.
//
//module xilinx_ultraram_true_dual_port #(
module uram #(
  parameter AWIDTH = 12,  // Address Width
  parameter DWIDTH = 72,  // Data Width
  parameter NBPIPE = 3    // Number of pipeline Registers
 ) (
    input clk,                    // Clock
    // Port A
    input rsta,                   // Reset
    input wea,                    // Write Enable
    input regcea,                 // Output Register Enable
    input mem_ena,                // Memory Enable
    input [DWIDTH-1:0] dina,      // Data Input
    input [AWIDTH-1:0] addra,     // Address Input
    output reg [DWIDTH-1:0] douta,// Data Output

    // Port B
    input rstb,                   // Reset
    input web,                    // Write Enable
    input regceb,                 // Output Register Enable
    input mem_enb,                // Memory Enable
    input [DWIDTH-1:0] dinb,      // Data Input
    input [AWIDTH-1:0] addrb,     // Address Input
    output reg [DWIDTH-1:0] doutb // Data Output
   );

(* ram_style = "ultra" *)
reg [DWIDTH-1:0] mem[(1<<AWIDTH)-1:0];        // Memory Declaration

reg [DWIDTH-1:0] memrega;
reg [DWIDTH-1:0] mem_pipe_rega[NBPIPE-1:0];    // Pipelines for memory
reg mem_en_pipe_rega[NBPIPE:0];                // Pipelines for memory enable

reg [DWIDTH-1:0] memregb;
reg [DWIDTH-1:0] mem_pipe_regb[NBPIPE-1:0];    // Pipelines for memory
reg mem_en_pipe_regb[NBPIPE:0];                // Pipelines for memory enable

integer          i;

// RAM : Read has one latency, Write has one latency as well.
always @ (posedge clk)
begin
 if(mem_ena)
  begin
   if(wea)
    mem[addra] <= dina;
   else
    memrega <= mem[addra];
  end
end
// The enable of the RAM goes through a pipeline to produce a
// series of pipelined enable signals required to control the data
// pipeline.
always @ (posedge clk)
begin
mem_en_pipe_rega[0] <= mem_ena;
 for (i=0; i<NBPIPE; i=i+1)
  mem_en_pipe_rega[i+1] <= mem_en_pipe_rega[i];
end

// RAM output data goes through a pipeline.
always @ (posedge clk)
begin
 if (mem_en_pipe_rega[0])
  mem_pipe_rega[0] <= memrega;
end

always @ (posedge clk)
begin
 for (i = 0; i < NBPIPE-1; i = i+1)
  if (mem_en_pipe_rega[i+1])
    mem_pipe_rega[i+1] <= mem_pipe_rega[i];
end

// Final output register gives user the option to add a reset and
// an additional enable signal just for the data ouptut
always @ (posedge clk)
begin
 if (rsta)
  douta <= 0;
 else if (mem_en_pipe_rega[NBPIPE] && regcea)
  douta <= mem_pipe_rega[NBPIPE-1];
end

// RAM : Read has one latency, Write has one latency as well.
always @ (posedge clk)
begin
 if(mem_enb)
  begin
   if(web)
    mem[addrb] <= dinb;
   else
    memregb <= mem[addrb];
  end
end
// The enable of the RAM goes through a pipeline to produce a
// series of pipelined enable signals required to control the data
// pipeline.
always @ (posedge clk)
begin
mem_en_pipe_regb[0] <= mem_enb;
 for (i=0; i<NBPIPE; i=i+1)
  mem_en_pipe_regb[i+1] <= mem_en_pipe_regb[i];
end

// RAM output data goes through a pipeline.
always @ (posedge clk)
begin
 if (mem_en_pipe_regb[0])
  mem_pipe_regb[0] <= memregb;
end

always @ (posedge clk)
begin
 for (i = 0; i < NBPIPE-1; i = i+1)
  if (mem_en_pipe_regb[i+1])
    mem_pipe_regb[i+1] <= mem_pipe_regb[i];
end

// Final output register gives user the option to add a reset and
// an additional enable signal just for the data ouptut
always @ (posedge clk)
begin
 if (rsta)
  doutb <= 0;
 else if (mem_en_pipe_regb[NBPIPE] && regceb)
  doutb <= mem_pipe_regb[NBPIPE-1];
end
endmodule
/*
// The following is an instantation template for
// xilinx_ultraram_true_dual_port

   xilinx_ultraram_true_dual_port # (
                                             .AWIDTH(AWIDTH),
                                             .DWIDTH(DWIDTH),
                                             .NBPIPE(NBPIPE)
                                            )
                      your_instance_name    (
                                             clk(clk),
                                             rsta(rsta),
                                             wea(wea),
                                             regcea(regcea),
                                             mem_ena(mem_ena),
                                             dina(dina),
                                             addra(addra),
                                             douta(douta),
                                             rstb(rstb),
                                             web(web),
                                             regceb(regceb),
                                             mem_enb(mem_enb),
                                             dinb(dinb),
                                             addrb(addrb),
                                             doutb(doutb)
                                            );
*/


