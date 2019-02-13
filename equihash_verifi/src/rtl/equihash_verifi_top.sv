/*
 * This module is the top system level for the equihash verifier system. It takes in an AXI stream which
 * represents block chain data and verifies that it is correct.
 */ 

module equihash_verifi_top(
  input i_clk, i_rst,
  
  if_axi_stream.sink i_data,
  output logic o_valid
);
  
if_axi_stream #(.DAT_BYTS(128)) blake2b_in(clk);
if_axi_stream #(.DAT_BYTS(64)) blake2b_out(clk);


always_ff @ (posedge i_clk) begin
  i_data.rdy <= blake2b_in.rdy;
  blake2b_in.val <= i_data.val;
  blake2b_in.sop <= i_data.sop;
  blake2b_in.eop <= i_data.eop;
  blake2b_in.dat <= i_data.dat;
  blake2b_in.err <= 0;
  blake2b_in.mod <= 0;
  blake2b_in.ctl <= 0;
  
  blake2b_out.rdy <= 1; 
  o_valid <= (blake2b_out.val && blake2b_out.dat == {64{1'b1}});
end
  
  
// The Blake2 core for generating hashes

logic [64*8-1:0] blake2_parameters;
always_comb begin
  blake2_parameters = {32'd0, 8'd1, 8'd1, 8'd0, 8'd64};
end

blake2_top #(
  .EQUIHASH( 1 )
)
blake2_top (
  .i_clk        ( i_clk             ), 
  .i_rst        ( i_rst             ),
  .i_byte_len   ( 8'd128            ),
  .i_parameters ( blake2_parameters ),
  .i_block      ( blake2b_in        ),
  .o_hash       ( blake2b_out       )
);
  
endmodule