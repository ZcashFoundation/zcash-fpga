/*******************************************************************************
  Copyright 2019 Supranational LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*******************************************************************************/

/*
  Tree built out of 3:2 compressors.  
  Parameterized to take any number of inputs, each of a common size
*/

module compressor_tree_3_to_2
   #(
     parameter int NUM_ELEMENTS      = 9,
     parameter int BIT_LEN           = 16
    )
   (
    input  logic [BIT_LEN-1:0] terms[NUM_ELEMENTS],
    output logic [BIT_LEN-1:0] C,
    output logic [BIT_LEN-1:0] S
   );

`ifdef FASTSIM
   // This is intended for simulation only to improve compile and run time
   always_comb begin
      C = 0;
      S = 0;
      for(int k = 0; k < NUM_ELEMENTS; k++) begin
         S += terms[k];
      end
   end
   
`else

   // If there is only one or two elements, then return the input (no tree)
   // If there are three elements, this is the last level in the tree
   // For greater than three elements:
   //   Instantiate a set of carry save adders to process this level's terms
   //   Recursive instantiate this module to complete the rest of the tree
   generate
      if (NUM_ELEMENTS == 1) begin // Return value
         always_comb begin
            C[BIT_LEN-1:0] = '0;
            S[BIT_LEN-1:0] = terms[0];
         end
      end
      else if (NUM_ELEMENTS == 2) begin // Return value
         always_comb begin
            C[BIT_LEN-1:0] = terms[1];
            S[BIT_LEN-1:0] = terms[0];
         end
      end
      else if (NUM_ELEMENTS == 3) begin // last level
         /* verilator lint_off UNUSED */
        logic [BIT_LEN-1:0] Cout;
         /* verilator lint_on UNUSED */
         
         carry_save_adder #(.BIT_LEN(BIT_LEN))
            carry_save_adder (
                              .A(terms[0]),
                              .B(terms[1]),
                              .Cin(terms[2]),
                              .Cout(Cout),
                             .S(S[BIT_LEN-1:0])
                             );
         always_comb begin
            C[BIT_LEN-1:0] = {Cout[BIT_LEN-2:0], 1'b0};
         end
      end
      else begin
         //localparam integer NUM_RESULTS = ($rtoi($floor(NUM_ELEMENTS/3)) * 2) + 
         //                                 (NUM_ELEMENTS%3);
         localparam integer NUM_RESULTS = (integer'(NUM_ELEMENTS/3) * 2) + 
                                          (NUM_ELEMENTS%3);

         logic [BIT_LEN-1:0] next_level_terms[NUM_RESULTS];

         carry_save_adder_tree_level #(.NUM_ELEMENTS(NUM_ELEMENTS),
                                       .BIT_LEN(BIT_LEN)
                                      )
            carry_save_adder_tree_level (
                                         .terms(terms),
                                         .results(next_level_terms)
                                        );

         compressor_tree_3_to_2 #(.NUM_ELEMENTS(NUM_RESULTS),
                                  .BIT_LEN(BIT_LEN)
                                 )
            compressor_tree_3_to_2 (
                                    .terms(next_level_terms),
                                    .C(C),
                                    .S(S)
                                   );
      end
   endgenerate
`endif
endmodule
