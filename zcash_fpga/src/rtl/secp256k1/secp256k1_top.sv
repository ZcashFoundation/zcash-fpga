module secp256k1_top #(
  parameter DAT_BYTS = 8,
  parameter DAT_BITS = DAT_BYTS*8,
  parameter DO_AFFINE_CHECK = 0
)(
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
if_ram #(.RAM_WIDTH(64), .RAM_DEPTH(REGISTER_SIZE)) register_file_a (i_clk, i_rst);
if_ram #(.RAM_WIDTH(64), .RAM_DEPTH(REGISTER_SIZE)) register_file_b (i_clk, i_rst);

// 256 bit inverse calculation
if_axi_stream #(.DAT_BYTS(256/8)) bin_inv_in_if(i_clk);
if_axi_stream #(.DAT_BYTS(256/8)) bin_inv_out_if(i_clk);

// [0] is connection from/to point_mult0 block, [1] is add point_mult1 block, 2 is this state machine, [3] is arbitrated value
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mult_in_if [3:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mult_out_if [3:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mod_in_if [2:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mod_out_if [2:0] (i_clk);

jb_point_t pt_mult0_in_p, pt_mult0_out_p, pt_mult1_in_p, pt_mult1_out_p, pt_X0, pt_X1, pt_X, pt_mult0_in_p2;
logic [255:0] pt_mult0_in_k, pt_mult1_in_k;
logic pt_mult0_in_val, pt_mult0_in_rdy, pt_mult0_out_rdy, pt_mult0_out_val, pt_mult0_out_err, pt_mult0_in_p2_val;
logic pt_mult1_in_val, pt_mult1_in_rdy, pt_mult1_out_rdy, pt_mult1_out_val, pt_mult1_out_err;
 
// Can avoid final inverstion converting from projected coord by some check in c++ code

// Controlling state machine
typedef enum {IDLE,
              GET_INDEX,
              VERIFY_SECP256K1_SIG_PARSE,
              CALC_S_INV,
              CALC_U1_U2,
              CALC_X,
              CALC_X_AFFINE,
              CHECK_IN_JB,
              UPDATE_RAM_VARIABLES,
              IGNORE,
              FINISHED} secp256k1_state_t;

secp256k1_state_t secp256k1_state;
header_t header, header_l;
secp256k1_ver_t secp256k1_ver;
// Other temporary values - could use RAM insead?
logic [255:0]  r, u2;
logic [63:0] index;
logic u2_val;

localparam MAX_BYT_MSG = 64; // Max bytes in a reply message

logic [MAX_BYT_MSG*8 -1:0] msg;
logic [$clog2(MAX_BYT_MSG)-1:0] cnt; // Counter for parsing command inputs
logic if_axi_mm_rd;

logic [255:0] inv_p;

always_comb begin
  header = if_cmd_rx.dat;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    msg <= 0;
    secp256k1_state <= IDLE;
    if_cmd_tx.reset_source();
    if_cmd_rx.rdy <= 0;
    cnt <= 0;
    register_file_a.reset_source();
    r <= 0;
    u2 <= 0;
    u2_val <= 0;
    bin_inv_in_if.reset_source();
    bin_inv_out_if.rdy <= 0;
    secp256k1_ver <= 0;
    inv_p <=  secp256k1_pkg::n;
    
    pt_X <= 0;
    pt_X0 <= 0;
    pt_X1 <= 0;
    
    pt_mult0_in_p <= 0;
    pt_mult1_in_p <= 0;
    pt_mult0_in_k <= 0;
    pt_mult1_in_k <= 0;
    pt_mult0_in_val <= 0;
    pt_mult0_out_rdy <= 0;
    pt_mult1_in_val <= 0;
    pt_mult1_out_rdy <= 0;
    pt_mult0_in_p2_val <= 0;
    
    mult_out_if[2].rdy <= 0;
    mult_in_if[2].reset_source();
    
    index <= 0;
    
  end else begin
  
    register_file_a.en <= 1;
    register_file_a.we <= 0;
    register_file_a.re <= 1;
    mult_out_if[2].rdy <= 1;
    mult_in_if[2].sop <= 1;
    mult_in_if[2].eop <= 1;
    
    
    pt_mult0_out_rdy <= 1;
    pt_mult1_out_rdy <= 1;
    
    if (pt_mult0_in_val && pt_mult0_in_rdy)
      pt_mult0_in_val <= 0;
      
    if (pt_mult1_in_val && pt_mult1_in_rdy)
      pt_mult1_in_val <= 0;
      
    if (bin_inv_in_if.val && bin_inv_in_if.rdy)
      bin_inv_in_if.val <= 0;
      
    if (pt_mult0_in_p2_val && pt_mult0_in_rdy)
      pt_mult0_in_p2_val <= 0;
      
    if (mult_in_if[2].val && mult_in_if[2].rdy)
      mult_in_if[2].val <= 0;
          
    case(secp256k1_state)
      {IDLE}: begin
        inv_p <=  secp256k1_pkg::n;
        u2_val <= 0;
        secp256k1_ver <= 0;
        if_cmd_rx.rdy <= 1;
        header_l <= header;
        cnt <= 0;
        
        pt_mult1_in_p.z <= 1;
        pt_mult1_in_p.x <= secp256k1_pkg::Gx;
        pt_mult1_in_p.y <= secp256k1_pkg::Gy;
              
        if (if_cmd_rx.val && if_cmd_rx.rdy) begin
          case(header.cmd)
            {VERIFY_SECP256K1_SIG}: begin
              register_file_a.we <= 1;
              register_file_a.a <= CURR_CMD;
              register_file_a.d <= header;
              secp256k1_state <= GET_INDEX;
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
      {GET_INDEX}: begin
        if (if_cmd_rx.val && if_cmd_rx.rdy) begin
          index <= if_cmd_rx.dat;
          secp256k1_state <= VERIFY_SECP256K1_SIG_PARSE;
        end
        if_cmd_rx.rdy <= 1;
      end
      {VERIFY_SECP256K1_SIG_PARSE}: begin
        if_cmd_rx.rdy <= 1;
        if (if_cmd_rx.val && if_cmd_rx.rdy) begin
          register_file_a.we <= 1;
          cnt <= cnt + 1;
          if (cnt == 19) begin
            secp256k1_state <= CALC_S_INV;
            bin_inv_out_if.rdy <= 1;
          end
        end  
        
        case(cnt) inside
          [0:3]: begin
            register_file_a.a <= SIG_VER_S/8 + (cnt);
            register_file_a.d <= if_cmd_rx.dat;
            // Can start calculating the inverse here
            bin_inv_in_if.dat[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            if (cnt == 3) begin
              bin_inv_in_if.val <= 1;
            end
          end
          [4:7]: begin
            register_file_a.a <= SIG_VER_R/8 + (cnt - 4);
            r[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat; // TODO remove
            register_file_a.d <= if_cmd_rx.dat;
            mult_in_if[2].dat[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
          end
          [8:11]: begin
            pt_mult0_in_k[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            register_file_a.a <= SIG_VER_HASH/8 + (cnt - 8);
            register_file_a.d <= if_cmd_rx.dat;
          end
          [12:19]: begin
            register_file_a.a <= SIG_VER_Q/8 + (cnt - 12);
            pt_mult0_in_p.z <= 1;
            if ((cnt-12) < 4) begin
              pt_mult0_in_p.x[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            end else begin
              pt_mult0_in_p.y[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            end
            register_file_a.d <= if_cmd_rx.dat;
          end
        endcase
      end
      {CALC_S_INV}: begin
        // Wait until bin_inv_out_if.val
        if (bin_inv_in_if.dat >= secp256k1_pkg::n) secp256k1_ver.OUT_OF_RANGE_S <= 1;
        if (mult_in_if[2].dat >= secp256k1_pkg::n) secp256k1_ver.OUT_OF_RANGE_R <= 1;
        if (bin_inv_out_if.val && bin_inv_out_if.rdy) begin
          bin_inv_out_if.rdy <= 0;
          bin_inv_in_if.dat <= bin_inv_out_if.dat;
          // Start calculating U2
          mult_in_if[2].ctl <= 1;  // mod n
          mult_in_if[2].dat[256 +: 256] <= bin_inv_out_if.dat;
          mult_in_if[2].val <= 1;
          secp256k1_state <= CALC_U1_U2;
          cnt <= 0;
          // TODO also write this to RAM
          // need to do 2 multiplications % n to get u1 and u2
        end
      end
      {CALC_U1_U2}: begin
        if (mult_in_if[2].val && mult_in_if[2].rdy) begin
          cnt[1:0] <= 2'b01;
          mult_in_if[2].val <= 0;
          // Calculate U1
          mult_in_if[2].dat[0 +: 256] <= pt_mult0_in_k;
          mult_in_if[2].val <= 1;
          if (cnt[1:0] == 2'b01) begin
            mult_in_if[2].val <= 0;
          end
        end
        // Check for result
        // TODO load into RAM
        
        if (mult_out_if[2].val && mult_out_if[2].rdy) begin
          case(cnt[2])
            {1'd0}: begin
              pt_mult0_in_k <= mult_out_if[2].dat;
              // TODO write this to RAM
              pt_mult0_in_k <= mult_out_if[2].dat;
              pt_mult0_in_val <= 1;
              cnt[2] <= 1;
            end
            {1'd1}: begin
              pt_mult1_in_k <= mult_out_if[2].dat;
              pt_mult1_in_val <= 1;
              u2 <= mult_out_if[2].dat;
              u2_val <= 1;
              cnt <= 0;
              secp256k1_state <= CALC_X;
            end
          endcase
        end
      end
      {CALC_X}: begin
        // Wait for u1.P to finish
        if (pt_mult0_out_rdy && pt_mult0_out_val) begin
          // TODO load equation into point ADD
          pt_X0 <= pt_mult0_out_p;
          pt_mult0_in_p <= pt_mult0_out_p;
          cnt[0] <= 1;
        end
        // Wait for u2.Q to finish
        if (pt_mult1_out_rdy && pt_mult1_out_val) begin
          // TODO load equation into point ADD
          pt_X1 <= pt_mult1_out_p; // TODO remove these
          pt_mult0_in_p2 <= pt_mult1_out_p;
          cnt[1] <= 1;
        end
        
        // Do the final point add
        if (cnt[2:0] == 3'b011) begin
            // TODO the final add  /checks
            pt_mult0_in_p2_val <= 1;
            cnt[2:0] <= 3'b100;
        end
        
        // Do the final inversion back to jacobian coords of the X, so need inverse of Z^2
        if (cnt[2:0] == 3'b100 && pt_mult0_out_rdy && pt_mult0_out_val) begin
          // Check for infinity
          if (pt_mult0_out_p.z == 0)
            secp256k1_ver.X_INFINITY_POINT <= 1;
          cnt <= 0;
          // Just store our value temp
          pt_mult0_in_p2 <= pt_mult0_out_p;
          if (DO_AFFINE_CHECK) begin
            secp256k1_state <= CALC_X_AFFINE;
            mult_in_if[2].val <= 1;
            mult_in_if[2].dat <= {pt_mult0_out_p.z, pt_mult0_out_p.z};
            mult_in_if[2].ctl <= 0;  // mod p
          end else begin
            secp256k1_state <= CHECK_IN_JB;
            mult_in_if[2].val <= 1;
            mult_in_if[2].dat <= {pt_mult0_out_p.z, pt_mult0_out_p.z};
            mult_in_if[2].ctl <= 0;  // mod p
          end
          // Here we either do a final inverstion to get the original .x value or we can do special checks
        end
      end
      {CALC_X_AFFINE}: begin
        case(cnt)
          0: begin
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin 
              bin_inv_in_if.dat <= mult_out_if[2].dat;
              inv_p <=  secp256k1_pkg::p_eq;
              bin_inv_in_if.val <= 1;
              bin_inv_out_if.rdy <= 1;
            end
            
            // Need to do final multiplication
            if (bin_inv_out_if.val && bin_inv_out_if.rdy) begin
              mult_in_if[2].val <= 1;
              mult_in_if[2].dat <= {bin_inv_out_if.dat, pt_mult0_in_p2.x};
              mult_in_if[2].ctl <= 0;  // mod p
              cnt <= 1;
            end
          end
          {1}: begin
            // Do one more multiplication but mod n
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin 
              mult_in_if[2].val <= 1;
              mult_in_if[2].dat <= {256'd1, mult_out_if[2].dat};
              mult_in_if[2].ctl <= 1;  // mod n
              cnt <= 2;
            end
          end
          {2}: begin
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin 
              if (mult_out_if[2].dat != r) begin
                secp256k1_ver.FAILED_SIG_VER <= 1;
              end
              cnt <= 3;
            end
          end
          {3}: begin
            cnt <= $bits(verify_secp256k1_sig_rpl_t)/8;
            msg <= verify_secp256k1_sig_rpl(secp256k1_ver, index);
            secp256k1_state <= FINISHED;
          end
        endcase
      end
        // This state does the verification checks avoiding the final inversion
      {CHECK_IN_JB}: begin
        case(cnt)
          0: begin
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin
              pt_mult0_in_p2.z <= mult_out_if[2].dat;
              mult_in_if[2].val <= 1;
              mult_in_if[2].dat <= {r, mult_out_if[2].dat};
              mult_in_if[2].ctl <= 0;  // mod p
              cnt <= 1;
            end
          end
          1: begin
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin
              r <= r + secp256k1_pkg::n;
              if (mult_out_if[2].dat == pt_mult0_in_p2.x) begin
                cnt <= 3;
              end else if (r + secp256k1_pkg::n >= secp256k1_pkg::p_eq) begin
                cnt <= 3;
                secp256k1_ver.FAILED_SIG_VER <= 1;
              end else begin
                // Need to do one more check
                mult_in_if[2].dat <= {r, pt_mult0_in_p2.z};
                mult_in_if[2].ctl <= 0;  // mod p
                mult_in_if[2].val <= 1;
                cnt <= 2;
              end
            end
          end
          2: begin
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin
              if(mult_out_if[2].dat != pt_mult0_in_p2.x)
                secp256k1_ver.FAILED_SIG_VER <= 1;
              cnt <= 3;
            end
          end
          3: begin
            cnt <= $bits(verify_secp256k1_sig_rpl_t)/8;
            msg <= verify_secp256k1_sig_rpl(secp256k1_ver, index);
            secp256k1_state <= FINISHED;
          end
        endcase
      end
      {UPDATE_RAM_VARIABLES}: begin
        // Here we write all our calculated variables to RAM
      end
      
      {FINISHED}: begin
        // TODO send message back
        send_message($bits(verify_secp256k1_sig_rpl_t)/8);
        // TODO also write result into RAM
      end
      {IGNORE}: begin
        if_cmd_rx.rdy <= 1;
        if (if_cmd_rx.rdy && if_cmd_rx.val && if_cmd_rx.eop)
          secp256k1_state <= IDLE;
      end
    endcase
    
    // We use this to write to the RAM as results are valid
    
  end
end

logic if_axi_mm_rd_;

always_comb begin
  register_file_b.a = if_axi_mm.addr/8;
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    if_axi_mm.reset_sink();
    register_file_b.en <= 1;
    register_file_b.re <= 1;
    register_file_b.we <= 0;
    register_file_b.d <= 0;
    if_axi_mm_rd_ <= 0;
  end else begin
    if_axi_mm_rd_ <= if_axi_mm_rd;
    if_axi_mm.rd_dat_val <= 0;         
    register_file_b.en <= 1;
    register_file_b.re <= 1;
    if_axi_mm_rd <= if_axi_mm.rd;
    if (if_axi_mm_rd_) begin
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
bin_inv #(
  .BITS ( 256 )
)
bin_inv (
  .i_clk ( i_clk ),
  .i_rst ( i_rst) ,
  .i_dat ( bin_inv_in_if.dat ),
  .i_p   ( inv_p             ),
  .i_val ( bin_inv_in_if.val ),
  .o_rdy ( bin_inv_in_if.rdy ),
  .o_dat ( bin_inv_out_if.dat ),
  .o_val ( bin_inv_out_if.val ),
  .i_rdy ( bin_inv_out_if.rdy )
);


localparam RESOURCE_SHARE = "YES";
localparam ARB_BIT = 6;

// Shared multiplier with cmd to control modulo p or modulo n
secp256k1_mult_mod #(
  .CTL_BITS ( 8 )
)
secp256k1_mult_mod (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_dat_a ( mult_in_if[3].dat[0 +: 256] ),
  .i_dat_b ( mult_in_if[3].dat[256 +: 256] ),
  .i_val ( mult_in_if[3].val ),
  .i_err ( mult_in_if[3].err ),
  .i_ctl ( mult_in_if[3].ctl ),
  .i_cmd ( mult_in_if[3].ctl[ARB_BIT +: 2] == 2 ? mult_in_if[3].ctl[0] : 1'd0 ),
  .o_rdy ( mult_in_if[3].rdy ),
  .o_dat ( mult_out_if[3].dat ),
  .i_rdy ( mult_out_if[3].rdy ),
  .o_val ( mult_out_if[3].val ),
  .o_ctl ( mult_out_if[3].ctl ),
  .o_err ( mult_out_if[3].err )
);

secp256k1_mod #(
  .USE_MULT ( 0 ),
  .CTL_BITS ( 8 )
)
secp256k1_mod (
  .i_clk( i_clk ),
  .i_rst( i_rst ),
  .i_dat( mod_in_if[2].dat  ),
  .i_val( mod_in_if[2].val  ),
  .i_err( mod_in_if[2].err  ),
  .i_ctl( mod_in_if[2].ctl  ),
  .o_rdy( mod_in_if[2].rdy  ),
  .o_dat( mod_out_if[2].dat ),
  .o_ctl( mod_out_if[2].ctl ),
  .o_err( mod_out_if[2].err ),
  .i_rdy( mod_out_if[2].rdy ),
  .o_val( mod_out_if[2].val )
);

packet_arb # (
  .DAT_BYTS    ( 512/8   ),
  .CTL_BITS    ( 8       ),
  .NUM_IN      ( 3       ),
  .OVR_WRT_BIT ( ARB_BIT ),
  .PIPELINE    ( 0       )
) 
packet_arb_mult (
  .i_clk ( i_clk ), 
  .i_rst ( i_rst ),
  .i_axi ( mult_in_if[2:0] ), 
  .o_axi ( mult_in_if[3]   )
);

packet_arb # (
  .DAT_BYTS    ( 512/8   ),
  .CTL_BITS    ( 8       ),
  .NUM_IN      ( 2       ),
  .OVR_WRT_BIT ( ARB_BIT ),
  .PIPELINE    ( 0       )
) 
packet_arb_mod (
  .i_clk ( i_clk ), 
  .i_rst ( i_rst ),
  .i_axi ( mod_in_if[1:0] ), 
  .o_axi ( mod_in_if[2]   )
);

always_comb begin 
  mod_out_if[0].copy_if_comb(mod_out_if[2].to_struct());
  mod_out_if[1].copy_if_comb(mod_out_if[2].to_struct());
  
  mod_out_if[0].ctl = mod_out_if[2].ctl;
  mod_out_if[1].ctl = mod_out_if[2].ctl;
  mod_out_if[0].ctl[ARB_BIT] = 0;
  mod_out_if[1].ctl[ARB_BIT] = 0;
  
  mod_out_if[1].val = mod_out_if[2].val && mod_out_if[2].ctl[ARB_BIT] == 1;
  mod_out_if[0].val = mod_out_if[2].val && mod_out_if[2].ctl[ARB_BIT] == 0;
  mod_out_if[2].rdy = mod_out_if[2].ctl[ARB_BIT] == 0 ? mod_out_if[0].rdy : mod_out_if[1].rdy;
  
  mod_out_if[2].sop = 1;
  mod_out_if[2].eop = 1;
  mod_out_if[2].mod = 0;
end

always_comb begin
  mult_out_if[0].copy_if_comb(mult_out_if[3].to_struct());
  mult_out_if[1].copy_if_comb(mult_out_if[3].to_struct());
  mult_out_if[2].copy_if_comb(mult_out_if[3].to_struct());
  
  mult_out_if[0].ctl = mult_out_if[3].ctl;
  mult_out_if[1].ctl = mult_out_if[3].ctl;
  mult_out_if[2].ctl = mult_out_if[3].ctl;
  mult_out_if[0].ctl[ARB_BIT +: 2] = 0;
  mult_out_if[1].ctl[ARB_BIT +: 2] = 0;
  mult_out_if[2].ctl[ARB_BIT +: 2] = 0;
  
  mult_out_if[1].val = mult_out_if[3].val && mult_out_if[3].ctl[ARB_BIT +: 2] == 1;
  mult_out_if[0].val = mult_out_if[3].val && mult_out_if[3].ctl[ARB_BIT +: 2] == 0;
  mult_out_if[2].val = mult_out_if[3].val && mult_out_if[3].ctl[ARB_BIT +: 2] == 2;
  
  if (mult_out_if[3].ctl[ARB_BIT +: 2] == 0)
    mult_out_if[3].rdy = mult_out_if[0].rdy;
  else if (mult_out_if[3].ctl[ARB_BIT +: 2] == 1)
    mult_out_if[3].rdy = mult_out_if[1].rdy;
  else
    mult_out_if[3].rdy = mult_out_if[2].rdy;
  
  mult_out_if[3].sop = 1;
  mult_out_if[3].eop = 1;
  mult_out_if[3].mod = 0;
end

secp256k1_point_mult #(
  .RESOURCE_SHARE ( RESOURCE_SHARE )
)
secp256k1_point_mult0 (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_p   ( pt_mult0_in_p    ),
  .i_k   ( pt_mult0_in_k    ),
  .i_val ( pt_mult0_in_val  ),
  .o_rdy ( pt_mult0_in_rdy  ),
  .o_p   ( pt_mult0_out_p   ),
  .i_rdy ( pt_mult0_out_rdy ),
  .o_val ( pt_mult0_out_val ),
  .o_err ( pt_mult0_out_err ),
  .o_mult_if ( mult_in_if[0]  ),
  .i_mult_if ( mult_out_if[0] ),
  .o_mod_if ( mod_in_if[0]    ),
  .i_mod_if ( mod_out_if[0]   ),
  .i_p2     ( pt_mult0_in_p2  ),
  .i_p2_val ( pt_mult0_in_p2_val )
);

secp256k1_point_mult #(
  .RESOURCE_SHARE ( RESOURCE_SHARE )
)
secp256k1_point_mult1 (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_p   ( pt_mult1_in_p    ),
  .i_k   ( pt_mult1_in_k    ),
  .i_val ( pt_mult1_in_val  ),
  .o_rdy ( pt_mult1_in_rdy  ),
  .o_p   ( pt_mult1_out_p   ),
  .i_rdy ( pt_mult1_out_rdy ),
  .o_val ( pt_mult1_out_val ),
  .o_err ( pt_mult1_out_err ),
  .o_mult_if ( mult_in_if[1]  ),
  .i_mult_if ( mult_out_if[1] ),
  .o_mod_if ( mod_in_if[1]    ),
  .i_mod_if ( mod_out_if[1]   ),
  .i_p2     ( '0   ),
  .i_p2_val ( 1'b0 )
);

// Task to help build reply messages. Assume no message will be more than MAX_BYT_MSG bytes
task send_message(input logic [$clog2(MAX_BYT_MSG)-1:0] msg_size);
  if (~if_cmd_tx.val || (if_cmd_tx.rdy && if_cmd_tx.val)) begin
    if_cmd_tx.dat <= msg;
    if_cmd_tx.val <= 1;
    if_cmd_tx.sop <= cnt == msg_size;
    if_cmd_tx.eop <= (cnt <= DAT_BYTS);
    if_cmd_tx.mod <= cnt < DAT_BYTS ? cnt : 0;
    cnt <= (cnt > DAT_BYTS) ? (cnt - DAT_BYTS) : 0;
    msg <= msg >> DAT_BITS;
    if (cnt == 0) begin
      if_cmd_tx.val <= 0;
      secp256k1_state <= IDLE;
    end
  end
endtask
  
endmodule