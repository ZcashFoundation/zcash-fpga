
//  Xilinx True Dual Port RAM, No Change, Dual Clock.
//  Added wrapper to use intefaces.
//  This code implements a parameterizable true dual port memory (both ports can read and write).
//  This is a no change RAM which retains the last read value on the output during writes
//  which is the most power efficient mode.
//  If a reset or enable is not necessary, it may be tied off or removed from the code.

module bram_reset #(
  parameter RAM_WIDTH = 18,
  parameter RAM_DEPTH = 1024,
  parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE",
  parameter INIT_FILE = ""
) (
  if_ram.sink a,
  if_ram.sink b
);

if_ram #(.RAM_WIDTH(a.RAM_WIDTH), .RAM_DEPTH(a.RAM_DEPTH)) if_ram_a(.i_clk(a.i_clk), .i_rst(a.i_rst));

logic reset_done;
logic [$clog2(RAM_WIDTH)-1:0] addr;

always_ff @ (posedge a.i_clk) begin
  if (a.i_rst) begin
    reset_done <= 0;
    addr <= 0;
  end else begin
    addr <= addr + 1;
    if (&addr)
      reset_done <= 1;
  end
end

always_comb begin
  if_ram_a.a =  reset_done ? a.a : addr;
  if_ram_a.en = reset_done ? a.en : 1'd1;
  if_ram_a.we = reset_done ? a.we : 1'd1;
  if_ram_a.re = a.re;
  if_ram_a.d =  reset_done ? a.d : {RAM_WIDTH{1'd0}};
  a.q = if_ram_a.q;
end

bram #(
  .RAM_WIDTH ( RAM_WIDTH ),
  .RAM_DEPTH ( RAM_DEPTH ),
  .RAM_PERFORMANCE ( RAM_PERFORMANCE ),
  .INIT_FILE ( INIT_FILE )
)
bram_instance (
  .a( if_ram_a ),
  .b( b )
);

endmodule

module bram #(
  parameter RAM_WIDTH = 18,
  parameter RAM_DEPTH = 1024,
  parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE",
  parameter INIT_FILE = ""
) (
  if_ram.sink a,
  if_ram.sink b
);

  // Check RAM sizes match the interface
  initial begin
    assert ($bits(a.d) == RAM_WIDTH) else $fatal(1, "%m %t ERROR: bram RAM_WIDTH (%d) does not match interface a (%d)", $time, RAM_WIDTH, $bits(a.d));
    assert ($bits(a.a) == $clog2(RAM_DEPTH)) else $fatal(1, "%m %t ERROR: bram $clog2(RAM_DEPTH) (%d) does not match interface a (%d)", $time, $clog2(RAM_DEPTH), $bits(a.a));
    assert ($bits(b.d) == RAM_WIDTH) else $fatal(1, "%m %t ERROR: bram RAM_WIDTH (%d) does not match interface b (%d)", $time, RAM_WIDTH, $bits(b.d));
    assert ($bits(b.a) == $clog2(RAM_DEPTH)) else $fatal(1, "%m %t ERROR: bram $clog2(RAM_DEPTH) (%d) does not match interface b (%d)", $time, $clog2(RAM_DEPTH), $bits(b.a));
  end

  xilinx_true_dual_port_no_change_2_clock_ram #(
    .RAM_WIDTH(RAM_WIDTH),                       // Specify RAM data width
    .RAM_DEPTH($clog2(RAM_DEPTH)),                       // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE(RAM_PERFORMANCE),           // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
    .INIT_FILE(INIT_FILE)                        // Specify name/location of RAM initialization file if using one (leave blank if not)
  )
  bram_instance (
    .addra(a.a),   // Port A address bus, width determined from RAM_DEPTH
    .addrb(b.a),   // Port B address bus, width determined from RAM_DEPTH
    .dina(a.d),     // Port A RAM input data, width determined from RAM_WIDTH
    .dinb(b.d),     // Port B RAM input data, width determined from RAM_WIDTH
    .clka(a.i_clk),     // Port A clock
    .clkb(b.i_clk),     // Port B clock
    .wea(a.we),       // Port A write enable
    .web(b.we),       // Port B write enable
    .ena(a.en),       // Port A RAM Enable, for additional power savings, disable port when not in use
    .enb(b.en),       // Port B RAM Enable, for additional power savings, disable port when not in use
    .rsta(a.i_rst),     // Port A output reset (does not affect memory contents)
    .rstb(b.i_rst),     // Port B output reset (does not affect memory contents)
    .regcea(a.re), // Port A output register enable
    .regceb(b.re), // Port B output register enable
    .douta(a.q),   // Port A RAM output data, width determined from RAM_WIDTH
    .doutb(b.q)    // Port B RAM output data, width determined from RAM_WIDTH
  );

endmodule


module xilinx_true_dual_port_no_change_2_clock_ram #(
  parameter RAM_WIDTH = 18,                       // Specify RAM data width
  parameter RAM_DEPTH = 1024,                     // Specify RAM depth (number of entries)
  parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE", // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
  parameter INIT_FILE = ""                        // Specify name/location of RAM initialization file if using one (leave blank if not)
) (
  input [clogb2(RAM_DEPTH-1)-1:0] addra,  // Port A address bus, width determined from RAM_DEPTH
  input [clogb2(RAM_DEPTH-1)-1:0] addrb,  // Port B address bus, width determined from RAM_DEPTH
  input [RAM_WIDTH-1:0] dina,           // Port A RAM input data
  input [RAM_WIDTH-1:0] dinb,           // Port B RAM input data
  input clka,                           // Port A clock
  input clkb,                           // Port B clock
  input wea,                            // Port A write enable
  input web,                            // Port B write enable
  input ena,                            // Port A RAM Enable, for additional power savings, disable port when not in use
  input enb,                            // Port B RAM Enable, for additional power savings, disable port when not in use
  input rsta,                           // Port A output reset (does not affect memory contents)
  input rstb,                           // Port B output reset (does not affect memory contents)
  input regcea,                         // Port A output register enable
  input regceb,                         // Port B output register enable
  output [RAM_WIDTH-1:0] douta,         // Port A RAM output data
  output [RAM_WIDTH-1:0] doutb          // Port B RAM output data
);

  reg [RAM_WIDTH-1:0] BRAM [RAM_DEPTH-1:0];
  reg [RAM_WIDTH-1:0] ram_data_a = {RAM_WIDTH{1'b0}};
  reg [RAM_WIDTH-1:0] ram_data_b = {RAM_WIDTH{1'b0}};

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate
    if (INIT_FILE != "") begin: use_init_file
      initial
        $readmemh(INIT_FILE, BRAM, 0, RAM_DEPTH-1);
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          BRAM[ram_index] = {RAM_WIDTH{1'b0}};
    end
  endgenerate

  always @(posedge clka)
    if (ena)
      if (wea)
        BRAM[addra] <= dina;
      else
        ram_data_a <= BRAM[addra];

  always @(posedge clkb)
    if (enb)
      if (web)
        BRAM[addrb] <= dinb;
      else
        ram_data_b <= BRAM[addrb];

  //  The following code generates HIGH_PERFORMANCE (use output register) or LOW_LATENCY (no output register)
  generate
    if (RAM_PERFORMANCE == "LOW_LATENCY") begin: no_output_register

      // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
       assign douta = ram_data_a;
       assign doutb = ram_data_b;

    end else begin: output_register

      // The following is a 2 clock cycle read latency with improve clock-to-out timing

      reg [RAM_WIDTH-1:0] douta_reg = {RAM_WIDTH{1'b0}};
      reg [RAM_WIDTH-1:0] doutb_reg = {RAM_WIDTH{1'b0}};

      always @(posedge clka)
        if (rsta)
          douta_reg <= {RAM_WIDTH{1'b0}};
        else if (regcea)
          douta_reg <= ram_data_a;

      always @(posedge clkb)
        if (rstb)
          doutb_reg <= {RAM_WIDTH{1'b0}};
        else if (regceb)
          doutb_reg <= ram_data_b;

      assign douta = douta_reg;
      assign doutb = doutb_reg;

    end
  endgenerate

  //  The following function calculates the address width based on specified RAM depth
  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule

