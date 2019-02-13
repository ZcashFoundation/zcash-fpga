// Common parameter values and tasks
package common_pkg;
  parameter MAX_SIM_BYTS = 1024; // In simulation tasks how big is the logic register for putting / getting data
  
  // Compare bytes and print if they do not match
  task compare_and_print(input logic [MAX_SIM_BYTS*8-1:0] data, expected);
    if (data == expected) begin
      $display("%m %t INFO: Data matched", $time);
    end else begin
      $write("exp: 0x");
      while(expected != 0) begin
        $write("%x", expected[7:0]);
        expected = expected >> 8;
      end
      $write("\nwas: 0x");
      while(data != 0) begin
        $write("%x", data[7:0]);
        data = data >> 8;
      end
      $write("\n");
      $fatal(1, "%m %t ERROR: data did not match", $time);
    end
  endtask
endpackage