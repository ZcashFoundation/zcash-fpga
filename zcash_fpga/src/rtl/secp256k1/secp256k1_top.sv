module secp256k1_top (
  input          i_clk,
  input          i_rst,
  // Command interface
  if_axi_stream.sink if_cmd_rx,
  if_axi_stream.source if_cmd_tx,
  // Memory map interface for debug
  if_axi_mm.sink if_axi_mm        
);

import secp256k1_pkg::*;
import zcash_fpga_pkg::*;

// Register map is used for storing command data
logic [REGISTER_SIZE/64-1:0][63:0] register_map;

if_ram #(.RAM_WIDTH(64), .RAM_DEPTH(REGISTER_SIZE)) register_file_a (i_clk, i_rst);
if_ram #(.RAM_WIDTH(64), .RAM_DEPTH(REGISTER_SIZE)) register_file_b (i_clk, i_rst);

// 256 multiplier (karatsuba)
logic [255:0] mult_dat_a, mult_dat_b;
logic mult_dat_val;
if_axi_stream #(.DAT_BYTS(512/8)) mult_out_if(i_clk);

// 256 bit inverse calculation
if_axi_stream #(.DAT_BYTS(256/8)) bin_inv_in_if(i_clk);
if_axi_stream #(.DAT_BYTS(256/8)) bin_inv_out_if(i_clk);

// TODO just have one multiplier (unless doulbe & add is parallel)
//one multiplier that barret reduction can share?
  
// Can avoid final inverstion converting from projected coord by some check in c++ code

// Controlling state machine
typedef enum {IDLE,
              VERIFY_SECP256K1_SIG_PARSE,           // Parse inputs
              CALC_S_INV,
              POINT_DBL,
              POINT_ADD,
              IGNORE,
              FINISHED} secp256k1_state_t;

secp256k1_state_t secp256k1_state;
header_t header, header_l;
secp256k1_ver_t secp256k1_ver;
// Other temporary values
logic [255:0] r, w;

logic [5:0] cnt; // Counter for parsing command inputs
logic if_axi_mm_rd;

always_comb begin
  header = if_cmd_rx.dat;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    secp256k1_state <= IDLE;
    if_cmd_tx.reset_source();
    if_cmd_rx.reset_sink();
    cnt <= 0;
    mult_out_if.rdy <= 0;
    register_file_a.reset_source();
    mult_dat_a <= 0;
    mult_dat_b <= 0;
    mult_dat_val <= 0;
    w <= 0;
    r <= 0;
    bin_inv_in_if.reset_source();
    bin_inv_out_if.rdy <= 0;
    secp256k1_ver <= 0;
  end else begin
  
    register_file_a.en <= 1;
    register_file_a.wr <= 0;
    register_file_a.rd <= 1;
    mult_out_if.rdy <= 1;
    bin_inv_out_if.rdy <= 1;
    mult_dat_val <= 0;
    
    case(secp256k1_state)
      {IDLE}: begin
        secp256k1_ver <= 0;
        if_cmd_rx.rdy <= 1;
        header_l <= header;
        cnt <= 0;
        if (if_cmd_rx.val && if_cmd_rx.rdy) begin
          case(header.cmd)
            {VERIFY_SECP256K1_SIG}: begin
              register_map[CURR_CMD] <= header;
              secp256k1_state <= VERIFY_SECP256K1_SIG_PARSE;
            end
            default: begin
              if (~if_cmd_rx.eop) begin
                if_cmd_rx.rdy <= 1;
                secp256k1_state <= IGNORE;
              end
            end
          endcase
        end
      end
      {VERIFY_SECP256K1_SIG_PARSE}: begin
        if_cmd_rx.rdy <= 1;
        if (if_cmd_rx.val && if_cmd_rx.rdy) begin
          register_file_a.wr <= 1;
          cnt <= cnt + 1;
          if (cnt == 19) secp256k1_state <= CALC_S_INV;
        end
        
        if (bin_inv_in_if.val && bin_inv_in_if.rdy)
          bin_inv_in_if.val <= 0;
        
        case(cnt) inside
          [0:3]: begin
            register_file_a.a <= SIG_VER_S + (cnt % 4);
            register_file_a.d <= if_cmd_rx.dat;
            // Can start calculating the inverse here
            bin_inv_in_if.dat[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            if (cnt == 3) begin
              bin_inv_in_if.val <= 1;
            end
            end
          [4:7]: begin
            // We can load R into the karatsuba multiplier
            register_file_a.a <= SIG_VER_R + (cnt % 4);
            register_file_a.d <= if_cmd_rx.dat;
            mult_dat_a[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
          end
          [8:11]: begin
            register_file_a.a <= SIG_VER_HASH + (cnt % 4);
            register_file_a.d <= if_cmd_rx.dat;
          end
          [12:19]: begin
            register_file_a.a <= SIG_VER_Q + (cnt % 8);
            register_file_a.d <= if_cmd_rx.dat;
          end
        endcase
      end
      {CALC_S_INV}: begin
        // Wait until bin_inv_out_if.val
        if (bin_inv_in_if.dat >= secp256k1_pkg::n) secp256k1_ver.OUT_OF_RANGE_S <= 1;
        if (mult_dat_a >= secp256k1_pkg::n) secp256k1_ver.OUT_OF_RANGE_R <= 1;
        if (bin_inv_out.val && bin_inv_out.rdy) begin
          w <= bin_inv_out.dat;
          // TODO also write this to RAM
          // need to do 2 multiplications % n to get u1 and u2
        end
      end
      {IGNORE}: begin
        if_cmd_rx.rdy <= 1;
        if (if_cmd_rx.rdy && if_cmd_rx.val && if_cmd_rx.eop)
          secp256k1_state <= IDLE;
      end
    endcase
  end
end

// TODO could provide write access

always_comb begin

end
always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    if_axi_mm.reset_sink();
    register_file_b.reset_source();
  end else begin
    if_axi_mm.rd_dat_val <= 0;         
    register_file_b.en <= 1;
    register_file_b.rd <= 1;
    register_file_b.a <= if_axi_mm.addr/8;
    if_axi_mm_rd <= if_axi_mm.rd;
    if (if_axi_mm_rd) begin
      if_axi_mm.rd_dat_val <= 1;
      if_axi_mm.rd_dat <= register_file_b.q;    
    end
  end
end

// BRAM for storing parsed inputs
bram #(
  .RAM_WIDTH       ( 64                 ),
  .RAM_DEPTH       ( REGISTER_SIZE      ),
  .RAM_PERFORMANCE ( "HIGH_PERFORMANCE" )
) register_file (
  .a ( register_file_a ),
  .b ( register_file_b )
);

// Calculate binary inverse mod n
begin: BINARY_INVERSE_MOD_N
  bin_inv #(
    .BITS ( 256              ),
    .P    ( secp256k1_pkg::n )
  )(
    .i_clk ( i_clk ),
    .i_rst ( i_rst) ,
    .i_dat ( bin_inv_in_if.dat ),
    .i_val ( bin_inv_in_if.val ),
    .o_rdy ( bin_inv_in_if.rdy ),
    .o_dat ( bin_inv_out_if.dat ),
    .o_val ( bin_inv_out_if.val ),
    .i_rdy ( bin_inv_out_if.rdy )
  );
end

// 256 bit Karatsuba_ofman multiplier
begin: KARATSUBA_OFMAN_MULT
  localparam KARATSUBA_LEVEL = 2;
  logic [KARATSUBA_LEVEL-1:0] val;
  
  karatsuba_ofman_mult # (
    .BITS  ( 256             ),
    .LEVEL ( KARATSUBA_LEVEL )
  )
  karatsuba_ofman_mult (
    .i_clk  ( i_clk           ),
    .i_dat_a( mult_dat_a      ),
    .i_dat_b( mult_dat_b      ),  
    .o_dat  ( mult_out_if.dat )
  );
  
  always_ff @ (posedge i_clk) begin
    if (i_rst) begin
      mult_out_if.val <= 0;
    end else begin
      val <= {val, mult_dat_val};
    end
  end
end

// Modulo p reducer (shared with arbitrator)

// Modulo n reducer (output from karatsuba multiplier)

// 256 bit Karatsuba_ofman multiplier (shared with arbitrator)

// Point double module or Point multiply module

  
endmodule