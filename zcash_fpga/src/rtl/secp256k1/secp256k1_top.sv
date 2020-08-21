module secp256k1_top import secp256k1_pkg::*; #(
  parameter DO_AFFINE_CHECK = secp256k1_pkg::DO_AFFINE_CHECK,
  parameter USE_ENDOMORPH = secp256k1_pkg::USE_ENDOMORPH
)(
  input          i_clk,
  input          i_rst,
  // Command interface
  if_axi_stream.sink if_cmd_rx,
  if_axi_stream.source if_cmd_tx
);

logic rst, rst_int, timeout_l;

always_comb rst = i_rst | rst_int;

localparam DAT_BYTS = 8;
localparam DAT_BITS = DAT_BYTS*8;
import zcash_fpga_pkg::*;

// 256 bit inverse calculation
if_axi_stream #(.DAT_BYTS(256/8)) bin_inv_in_if(i_clk);
if_axi_stream #(.DAT_BYTS(256/8)) bin_inv_out_if(i_clk);

// [0] is connection from/to point_mult0 block, [1] is add point_mult1 block, 2 is this state machine, [3] is arbitrated value
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(16)) mult_in_if [3:0] (i_clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(16)) mult_out_if [3:0] (i_clk);

jb_point_t pt_mult0_in_p, pt_mult0_out_p, pt_mult1_in_p, pt_mult1_out_p, pt_X0, pt_X1, pt_X, pt_mult0_in_p2;
logic [255:0] pt_mult0_in_k, pt_mult1_in_k;
logic pt_mult0_in_val, pt_mult0_in_rdy, pt_mult0_out_rdy, pt_mult0_out_val, pt_mult0_out_err, pt_mult0_in_p2_val;
logic pt_mult1_in_val, pt_mult1_in_rdy, pt_mult1_out_rdy, pt_mult1_out_val, pt_mult1_out_err;

// Global timeout in case we get stuck somewhere, we send a failed message back to host
logic [(USE_ENDOMORPH == "YES" ? 14 : 15):0] timeout;
// Controlling state machine
typedef enum {IDLE = 0,
              GET_INDEX = 1,
              VERIFY_SECP256K1_SIG_PARSE = 2,
              CALC_S_INV = 3,
              CALC_U1_U2 = 4,
              CALC_X = 5,
              CALC_X_AFFINE = 6,
              CHECK_IN_JB = 7,
              IGNORE = 8,
              FINISHED = 9} secp256k1_state_t;

secp256k1_state_t secp256k1_state;
header_t header, header_l;
secp256k1_ver_t secp256k1_ver;
// Other temporary values
logic [255:0]  r, r_plus_n, u2;
logic r_plus_n_gt;
logic [63:0] index;
logic u2_val;

localparam MAX_BYT_MSG = 64; // Max bytes in a reply message

logic [MAX_BYT_MSG*8 -1:0] msg;
logic [$clog2(MAX_BYT_MSG)-1:0] cnt; // Counter for parsing command inputs

logic [255:0] inv_p;

always_comb begin
  header = if_cmd_rx.dat;
end

always_ff @ (posedge i_clk) begin
  r_plus_n <= r + secp256k1_pkg::n;
  r_plus_n_gt <= r_plus_n >= secp256k1_pkg::p_eq;
end

always_ff @ (posedge i_clk) begin
  if (rst) begin
    msg <= 0;
    secp256k1_state <= IDLE;
    if_cmd_tx.reset_source();
    if_cmd_rx.rdy <= 0;
    cnt <= 0;
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

    timeout <= 0;
    rst_int <= 0;
    timeout_l <= 0;

  end else begin

    timeout <= timeout + 1;

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
        timeout <= 0;
        inv_p <=  secp256k1_pkg::n;
        u2_val <= 0;
        secp256k1_ver <= 0;
        if_cmd_rx.rdy <= 1;
        header_l <= header;
        cnt <= 0;
        bin_inv_out_if.rdy <= 0;
        pt_mult1_in_p.z <= 1;
        pt_mult1_in_p.x <= secp256k1_pkg::Gx;
        pt_mult1_in_p.y <= secp256k1_pkg::Gy;

        if (if_cmd_rx.val && if_cmd_rx.rdy) begin
          case(header.cmd)
            {VERIFY_SECP256K1_SIG}: begin
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
        timeout <= 0; // Don't timeout here
        if (if_cmd_rx.val && if_cmd_rx.rdy) begin
          index <= if_cmd_rx.dat;
          secp256k1_state <= VERIFY_SECP256K1_SIG_PARSE;
        end
        if_cmd_rx.rdy <= 1;
      end
      {VERIFY_SECP256K1_SIG_PARSE}: begin
        timeout <= 0; // Don't timeout here
        if_cmd_rx.rdy <= 1;
        if (if_cmd_rx.val && if_cmd_rx.rdy) begin
          cnt <= cnt + 1;
          if (cnt == 19 && if_cmd_rx.val && if_cmd_rx.rdy) begin
            secp256k1_state <= CALC_S_INV;
            bin_inv_out_if.rdy <= 1;
          end
        end

        case(cnt) inside
          [0:3]: begin
            // Can start calculating the inverse here
            bin_inv_in_if.dat[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            if (cnt == 3 && if_cmd_rx.val && if_cmd_rx.rdy) begin
              bin_inv_in_if.val <= 1;
            end
          end
          [4:7]: begin
            r[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            mult_in_if[2].dat[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
          end
          [8:11]: begin
            pt_mult0_in_k[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
          end
          [12:19]: begin
            pt_mult0_in_p.z <= 1;
            if ((cnt-12) < 4) begin
              pt_mult0_in_p.x[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            end else begin
              pt_mult0_in_p.y[(cnt % 4)*64 +: 64] <= if_cmd_rx.dat;
            end
          end
        endcase
      end
      {CALC_S_INV}: begin
        // Wait until bin_inv_out_if.val
        if (bin_inv_in_if.dat >= secp256k1_pkg::n) secp256k1_ver.OUT_OF_RANGE_S <= 1;
        if (r >= secp256k1_pkg::n) secp256k1_ver.OUT_OF_RANGE_R <= 1;
        if (bin_inv_out_if.val && bin_inv_out_if.rdy) begin
          bin_inv_out_if.rdy <= 0;
          bin_inv_in_if.dat <= bin_inv_out_if.dat;
          // Start calculating U2
          mult_in_if[2].ctl[7:6] <= 1;  // mod n
          mult_in_if[2].dat[256 +: 256] <= bin_inv_out_if.dat;
          mult_in_if[2].val <= 1;
          secp256k1_state <= CALC_U1_U2;
          cnt <= 0;
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
          pt_X0 <= pt_mult0_out_p;
          pt_mult0_in_p <= pt_mult0_out_p;
          cnt[0] <= 1;
        end
        // Wait for u2.Q to finish
        if (pt_mult1_out_rdy && pt_mult1_out_val) begin
          pt_X1 <= pt_mult1_out_p;
          pt_mult0_in_p2 <= pt_mult1_out_p;
          cnt[1] <= 1;
        end

        // Do the final point add
        if (cnt[2:0] == 3'b011) begin
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
          if (DO_AFFINE_CHECK == "YES") begin
            secp256k1_state <= CALC_X_AFFINE;
            mult_in_if[2].val <= 1;
            mult_in_if[2].dat <= {pt_mult0_out_p.z, pt_mult0_out_p.z};
            mult_in_if[2].ctl[7:6] <= 0;  // mod p
          end else begin
            secp256k1_state <= CHECK_IN_JB;
            mult_in_if[2].val <= 1;
            mult_in_if[2].dat <= {pt_mult0_out_p.z, pt_mult0_out_p.z};
            mult_in_if[2].ctl[7:6] <= 0;  // mod p
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
              mult_in_if[2].ctl[7:6] <= 0;  // mod p
              cnt <= 1;
            end
          end
          {1}: begin
            // Do one more multiplication but mod n
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin
              mult_in_if[2].val <= 1;
              mult_in_if[2].dat <= {256'd1, mult_out_if[2].dat};
              mult_in_if[2].ctl[7:6] <= 1;  // mod n
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
            msg <= verify_secp256k1_sig_rpl(secp256k1_ver, index, timeout);
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
              mult_in_if[2].ctl[7:6] <= 0;  // mod p
              cnt <= 1;
            end
          end
          1: begin
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin
              if (mult_out_if[2].dat == pt_mult0_in_p2.x) begin
                cnt <= 3;
              end else if (r_plus_n_gt) begin
                cnt <= 3;
                secp256k1_ver.FAILED_SIG_VER <= 1;
              end else begin
                // Need to do one more check
                mult_in_if[2].dat <= {r_plus_n, pt_mult0_in_p2.z};
                mult_in_if[2].ctl[7:6] <= 0;  // mod p
                mult_in_if[2].val <= 1;
                cnt <= 2;
              end
            end
          end
          2: begin
            if (mult_out_if[2].rdy && mult_out_if[2].val) begin
              if(mult_out_if[2].dat != pt_mult0_in_p2.x) begin
                secp256k1_ver.FAILED_SIG_VER <= 1;
              end
              cnt <= 3;
            end
          end
          3: begin
            cnt <= $bits(verify_secp256k1_sig_rpl_t)/8;
            msg <= verify_secp256k1_sig_rpl(secp256k1_ver, index, timeout);
            secp256k1_state <= FINISHED;
          end
        endcase
      end
      {FINISHED}: begin
        timeout <= 0;
        send_message($bits(verify_secp256k1_sig_rpl_t)/8);
      end
      {IGNORE}: begin
        if_cmd_rx.rdy <= 1;
        if (if_cmd_rx.rdy && if_cmd_rx.val && if_cmd_rx.eop)
          secp256k1_state <= IDLE;
      end
    endcase

    // Something went wrong - send a message back to host
    if (&timeout) begin
        secp256k1_ver.TIMEOUT_FAIL <= 1;
        timeout <= timeout;
    end
    if (secp256k1_ver.TIMEOUT_FAIL) begin
      timeout <= 0;
      timeout_l <= 1;
      secp256k1_ver.TIMEOUT_FAIL <= 0;
      cnt <= $bits(verify_secp256k1_sig_rpl_t)/8;
      msg <= verify_secp256k1_sig_rpl(secp256k1_ver, index, timeout);
      secp256k1_state <= FINISHED;
    end
  end
end


// Calculate binary inverse mod n
bin_inv #(
  .BITS ( 256 )
)
bin_inv (
  .i_clk ( i_clk ),
  .i_rst ( rst) ,
  .i_dat ( bin_inv_in_if.dat ),
  .i_p   ( inv_p             ),
  .i_val ( bin_inv_in_if.val ),
  .o_rdy ( bin_inv_in_if.rdy ),
  .o_dat ( bin_inv_out_if.dat ),
  .o_val ( bin_inv_out_if.val ),
  .i_rdy ( bin_inv_out_if.rdy )
);

localparam ARB_BIT = 12;
localparam MULT_CTL_BIT = 6; // 2 bits

// Shared multiplier with cmd to control modulo p or modulo n
secp256k1_mult_mod #(
  .CTL_BITS ( 16 )
)
secp256k1_mult_mod (
  .i_clk ( i_clk ),
  .i_rst ( rst ),
  .i_dat_a ( mult_in_if[3].dat[0 +: 256] ),
  .i_dat_b ( mult_in_if[3].dat[256 +: 256] ),
  .i_val ( mult_in_if[3].val ),
  .i_err ( mult_in_if[3].err ),
  .i_ctl ( mult_in_if[3].ctl ),
  .i_cmd ( mult_in_if[3].ctl[MULT_CTL_BIT +: 2] ),
  .o_rdy ( mult_in_if[3].rdy ),
  .o_dat ( mult_out_if[3].dat ),
  .i_rdy ( mult_out_if[3].rdy ),
  .o_val ( mult_out_if[3].val ),
  .o_ctl ( mult_out_if[3].ctl ),
  .o_err ( mult_out_if[3].err )
);

resource_share # (
  .NUM_IN      ( 3       ),
  .CTL_BITS    ( 16      ),
  .DAT_BITS    ( 512     ),  
  .DAT_BYTS    ( 512/8   ),
  .OVR_WRT_BIT ( ARB_BIT ),
  .PIPELINE_IN ( 0       )
)
resource_share_mult (
  .i_clk ( i_clk ),
  .i_rst ( rst ),
  .i_axi ( mult_in_if[2:0]  ),
  .o_res ( mult_in_if[3]    ),
  .i_res ( mult_out_if[3]   ),
  .o_axi ( mult_out_if[2:0] )
);

generate if (USE_ENDOMORPH == "NO") begin
  secp256k1_point_mult #(
    .RESOURCE_SHARE ( "YES" )
  )
  secp256k1_point_mult0 (
    .i_clk ( i_clk ),
    .i_rst ( rst ),
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
    .i_p2     ( pt_mult0_in_p2  ),
    .i_p2_val ( pt_mult0_in_p2_val )
  );

  secp256k1_point_mult #(
    .RESOURCE_SHARE ( "YES" )
  )
  secp256k1_point_mult1 (
    .i_clk ( i_clk ),
    .i_rst ( rst ),
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
    .i_p2     ( '0   ),
    .i_p2_val ( 1'b0 )
  );
end else begin
  secp256k1_point_mult_endo
  secp256k1_point_mult_endo0 (
    .i_clk ( i_clk ),
    .i_rst ( rst ),
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
    .i_p2     ( pt_mult0_in_p2  ),
    .i_p2_val ( pt_mult0_in_p2_val )
  );

  secp256k1_point_mult_endo
  secp256k1_point_mult_endo1 (
    .i_clk ( i_clk ),
    .i_rst ( rst ),
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
    .i_p2     ( '0   ),
    .i_p2_val ( 1'b0 )
  );
end endgenerate
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
      if (timeout_l) 
        rst_int <= 1;
    end
  end
endtask

endmodule