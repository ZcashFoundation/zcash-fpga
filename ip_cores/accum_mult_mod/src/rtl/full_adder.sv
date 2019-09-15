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
  A basic 1-bit full adder
              -------
             | FA    |
    A    --> |       | --> S
    B    --> |       |
    Cin  --> |       | --> Cout
              -------
*/

module full_adder
   (
    input  logic A,
    input  logic B,
    input  logic Cin,
    output logic Cout,
    output logic S
   );

   always_comb begin
      S    =  A ^ B ^ Cin;
      Cout = (A & B) | (Cin & (A ^ B));
   end
endmodule
