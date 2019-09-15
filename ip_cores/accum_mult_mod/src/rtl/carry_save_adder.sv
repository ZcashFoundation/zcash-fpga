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
  A parameterized carry save adder (CSA)
  Loops through each input bit and feeds a full adder (FA)
             --------------------------------
            | CSA                            |
            |         for each i in BIT_LEN  |
            |            -------             |
            |           | FA    |            |
  A[]   --> |  Ai   --> |       | --> Si     | --> S[]
  B[]   --> |  Bi   --> |       |            |
  Cin[] --> |  Cini --> |       | --> Couti  | --> Cout[]
            |            -------             |
             --------------------------------
*/

module carry_save_adder
   #(
     parameter int BIT_LEN = 19
    )
   (
    input  logic [BIT_LEN-1:0] A,
    input  logic [BIT_LEN-1:0] B,
    input  logic [BIT_LEN-1:0] Cin,
    output logic [BIT_LEN-1:0] Cout,
    output logic [BIT_LEN-1:0] S
   );

   genvar i;
   generate
      for (i=0; i<BIT_LEN; i++) begin : csa_fas
         full_adder full_adder(
                               .A(A[i]),
                               .B(B[i]),
                               .Cin(Cin[i]),
                               .Cout(Cout[i]),
                               .S(S[i])
                              );
      end
   endgenerate
endmodule
