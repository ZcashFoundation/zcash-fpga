
// Interface for a AXI stream
interface if_axi_stream # (
  parameter DAT_BYTS = 8,
  parameter CTL_BYTS = 8
)(
  input i_clk
);
  
  localparam DAT_BITS = DAT_BYTS*8;
  localparam CTL_BITS = CTL_BYTS*8;
  
  logic rdy;
  logic val;
  logic err;
  logic sop;
  logic eop;
  logic [CTL_BITS-1:0] ctl;
  logic [DAT_BITS-1:0] dat;
  logic [$clog2(DAT_BYTS)-1:0] mod;
  
  task reset();
    val <= 0;
    err <= 0;
    sop <= 0;
    eop <= 0;
    dat <= 0;
    ctl <= 0;
    mod <= 0;
  endtask
  
endinterface