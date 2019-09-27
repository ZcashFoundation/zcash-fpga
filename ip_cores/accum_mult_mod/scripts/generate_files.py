#!/usr/bin/python3

import math

#  This needs to be called before simulation / synthesis to make sure the
#  reduction ram files and include files are created.
#
#  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.


####################
# Generate the multiplier output to carry-save adder tree mapping
####################

BITS = 381
MODULUS = 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
A_DSP_W = 26
B_DSP_W = 17
GRID_BIT = 64
RAM_A_W = 10

RAM_AXI_D = 32

URAM_PERCENT = 0
USE_INIT = 1

RES_W = A_DSP_W+B_DSP_W
NUM_COL = (BITS+A_DSP_W-1)//A_DSP_W;
NUM_ROW = (BITS+B_DSP_W-1)//B_DSP_W;

A_DIFF = A_DSP_W//GRID_BIT
B_DIFF = B_DSP_W//GRID_BIT


def get_accum_gen():
  MAX_COEF = ((2*BITS)+GRID_BIT-1)//GRID_BIT
  accum_s = '\n'
  ram_s = '\n'
  products = list()
  # Make a list of all offsets where products start
  for x in range(NUM_COL):
    for y in range(NUM_ROW):
      products.append((x, y, x*A_DSP_W+y*B_DSP_W))


  # Now match these to coef
  coef = list()
  max_bits_l = list()
  for i in range(MAX_COEF):
    size = list()
    # First do a pass just to check bit sizes  - also need to account for offset
    for j in products:
      start = max(j[2], i*GRID_BIT)
      end = min(j[2]+RES_W, (i+1)*GRID_BIT)
      if (end > start):
        size.append(end-i*GRID_BIT)#start)
    # Max bits 1 + clog2() of the max size in our list
    #max_bits = max(size) + math.ceil(math.log2(size.count(max(size))))
    max_bits = max(size) + math.ceil(math.log2(len(size)))
    max_bits_l.append(max_bits)

    coef_l = list()
    for j in products:
      # Check if we are in range
      offset = (j[0]*A_DSP_W)+(j[1]*B_DSP_W)
      start = max(j[2], i*GRID_BIT)
      end = min(j[2]+RES_W, (i+1)*GRID_BIT)
      if (end > start):
        bitwidth = end-start
        start_padding = max(start - i*GRID_BIT, 0)
        end_padding = max(start+max_bits-end-start_padding, 0)
        coef_l.append('{{{{{}{{1\'d0}}}},mul_grid[{}][{}][{}+:{}],{{{}{{1\'d0}}}}}}'.format(end_padding, j[0], j[1], start-offset, bitwidth, start_padding))



    coef.append(coef_l)

  # Create compressor trees and output
  for idx, i in enumerate(coef):
    if (len(i) == 1):
      accum_s +='''
// Coef {}
always_ff @ (posedge i_clk) if (o_mul.rdy) accum_grid_o[{}] <= {};
'''.format(idx, idx, i[0])
    elif (len(i) == 2):
      accum_s +='''
// Coef {}
always_ff @ (posedge i_clk) if (o_mul.rdy) accum_grid_o[{}] <= {};
'''.format(idx, idx, ' + '.join(i))
    else:
      accum_s +='''
// Coef {}
logic [{}:0] accum_i_{} [{}];
logic [{}:0] accum_o_c_{}, accum_o_s_{};
compressor_tree_3_to_2 #(
  .NUM_ELEMENTS({}),
  .BIT_LEN({})
)
ct_{} (
  .terms(accum_i_{}),
  .C(accum_o_c_{}),
  .S(accum_o_s_{})
);
always_comb accum_i_{} = {{{}}};
always_ff @ (posedge i_clk) if (o_mul.rdy) accum_grid_o[{}] <= accum_o_c_{} + accum_o_s_{};
'''.format(idx, max_bits_l[idx]-1, idx, len(i), max_bits_l[idx]-1, idx, idx, len(i), max_bits_l[idx], idx, idx, idx, idx, idx, ','.join(i), idx, idx, idx)

  # If the bits of this coef are above the modulus, we start generating lookup RAM
  # and output of RAM goes into address trees together with other partial products

  curr_bit = 0
  curr_bit_cnt = 0
  coef = 0
  ram_bit_low = 0
  ram_addr_bits = list()

  curr_bit = MODULUS.bit_length() % GRID_BIT
  coef = (MODULUS.bit_length()//GRID_BIT)
  reduc_coef = coef
  reduc_bit = curr_bit
  ram_s += 'always_ff @ (posedge i_clk) if (o_mul.rdy) begin\n'
  mem_s = ''
  #Reduce all bits after this
  while(coef < MAX_COEF):
    # Get max bits we can take from this coef
    max_bits = min(max_bits_l[coef]-curr_bit, RAM_A_W-ram_bit_low)
    ram_s += '  mod_ram_{}_a[{}+:{}] <= accum_grid_o[{}][{}+:{}];\n'.format(len(ram_addr_bits), ram_bit_low, max_bits, coef, curr_bit, max_bits)

    if ((ram_bit_low + max_bits == RAM_A_W) or (coef == MAX_COEF - 1 and curr_bit + max_bits == max_bits_l[coef])):
      if (ram_bit_low + max_bits != RAM_A_W):
        ram_s += '  mod_ram_{}_a[{}+:{}] <= 0;\n'.format(len(ram_addr_bits), ram_bit_low+max_bits, RAM_A_W-(ram_bit_low+max_bits))

      # Generate the init file lines - need to take into account earlier address bits
      max_bits_value = max_bits + ram_bit_low
      #print("max_bits {} ram_bit_low {}".format( max_bits, ram_bit_low))
      for i in range(1 << max_bits_value):
        # The value of a bit here will depend on the GRID and posisition of bit
        # Assume (?) any bits not in this GRID are from previous
        if (ram_bit_low != 0):
          bit_l = i % (1 << ram_bit_low)
          value_l = bit_l << ((max_bits_l[coef-1]-ram_bit_low)+(coef-1)*GRID_BIT)
        else:
          value_l = 0
        bit_h = (i >> ram_bit_low)
        value_h = bit_h << (coef*GRID_BIT + curr_bit)
        value = hex((value_l + value_h) % MODULUS)[2:]

        mem_s += "{}\n".format(value.zfill(math.ceil(MODULUS.bit_length()/4)))

      f = open('../data/mod_ram_{}.mem'.format(len(ram_addr_bits)), 'w')
      f.write(mem_s)
      f.close()
      mem_s = ''

      ram_addr_bits.append(ram_bit_low + max_bits)
      ram_bit_low = 0
    else:
      ram_bit_low += max_bits


    if (curr_bit + max_bits == max_bits_l[coef]):
      coef += 1
      curr_bit = 0
    else:
      curr_bit += max_bits

  ram_s += 'end\n'
  # Add the RAMs
  ram_s1 = ''
  for idx, i in enumerate(ram_addr_bits):
    uram_s = '(* ram_style="ultra" *)' if URAM_PERCENT > 100*idx/len(ram_addr_bits) else ''
    init_s = 'initial $readmemh( "mod_ram_{}.mem", mod_ram_{}_ram);'.format(idx, idx) if USE_INIT else ''
    ram_s1 += '''
logic [{}:0]    mod_ram_{}_a;
(* DONT_TOUCH = "yes" *) logic [{}:0]    mod_ram_{}_q;
logic [{}:0]    mod_ram_{}_d;
{}logic [{}:0]    mod_ram_{}_ram [{}];
always_ff @ (posedge i_clk) if (o_mul.rdy) begin
  mod_ram_{}_q <= mod_ram_{}_ram[mod_ram_{}_a];
end
{}
'''.format(RAM_A_W-1, idx, MODULUS.bit_length()-1, idx, MODULUS.bit_length()-1, idx, uram_s, MODULUS.bit_length()-1, idx, 1 << RAM_A_W, idx, idx, idx, init_s)

  # We now generate the tree adders to sum the reduction values with the accum_grid_o values
  accum2_s = '\n'
  for coef in range(math.ceil(MODULUS.bit_length()/GRID_BIT)):
    # Make sure we have the right bit widths
    if (coef == reduc_coef):
      ram_bits = min(GRID_BIT, reduc_bit)
    else:
      ram_bits = GRID_BIT
    padding = max_bits_l[coef] - ram_bits
    #if (padding == 0):
    max_bits_l[coef] += math.ceil(math.log2(len(ram_addr_bits)))
    padding = max_bits_l[coef] - ram_bits
    in_s = ['{{{{{}{{1\'d0}}}}, mod_ram_{}_q[{}+:{}]}}'.format(padding, i, coef*GRID_BIT, ram_bits) for i in range(len(ram_addr_bits))]
    # Need to check if we also had reduction in this range
    end = max_bits_l[coef]-1
    padding = 0
    if (reduc_coef == coef):
      padding = end - reduc_bit
      end = reduc_bit-1
    in_s.append('{{{{{}{{1\'d0}}}}, accum_grid_o_rr[{}][{}:0]}}'.format(padding, coef, end))
    accum2_s +='''
// Coef {} accum 2 stage
logic [{}:0] accum2_i_{} [{}];
logic [{}:0] accum2_o_c_{}, accum2_o_s_{};
compressor_tree_3_to_2 #(
  .NUM_ELEMENTS({}),
  .BIT_LEN({})
)
ct2_{} (
  .terms(accum2_i_{}),
  .C(accum2_o_c_{}),
  .S(accum2_o_s_{})
);
always_comb accum2_i_{} = {{{}}};
always_ff @ (posedge i_clk) if (o_mul.rdy) accum2_grid_o[{}] <= accum2_o_c_{} + accum2_o_s_{};
'''.format(coef, max_bits_l[coef]-1, coef, len(ram_addr_bits)+1, max_bits_l[coef]-1, coef, coef, len(ram_addr_bits)+1, max_bits_l[coef], coef, coef, coef, coef, coef, ','.join(in_s), coef, coef, coef)

  ram_s = ram_s1 + ram_s

  # We also need to do a final level reduction
  accum3_s = '''
logic [{}:0]    mod_ram2_0_a;
logic [{}:0]    mod_ram2_0_q;
always_comb begin
  mod_ram2_0_a = res0_r[{}+:{}];
end
always_ff @ (posedge i_clk) if (o_mul.rdy) begin
  mod_ram2_0_q <= mod_ram_0_ram[mod_ram2_0_a];
end

always_comb begin
  res1_c = res0_rr[{}:0] + mod_ram2_0_q;
  res1_m_c = res0_rr[{}:0] + mod_ram2_0_q - MODULUS;
  res1_m_c_ = res0_rr[{}:0] + mod_ram2_0_q - 2*MODULUS;
end
'''.format(RAM_A_W-1, MODULUS.bit_length()-1, MODULUS.bit_length(), RAM_A_W, MODULUS.bit_length()-1, MODULUS.bit_length()-1, MODULUS.bit_length()-1)

  # We also generate the arrays since we know the max sizes
  logic_s = '''

logic [{}:0]                  accum_grid_o [{}];
logic [{}:0]                  accum_grid_o_r [{}];
logic [{}:0]                  accum_grid_o_rr [{}];
logic [{}:0]                  accum2_grid_o [{}];
'''.format(max(max_bits_l)-1, MAX_COEF, max(max_bits_l)-1, MAX_COEF//2, max(max_bits_l)-1, MAX_COEF//2, max(max_bits_l)-1, MAX_COEF//2)

  # Add logic for writing to memory
  # Make long scan chain, width of RAM_D_W
  ram_write_s = '''
localparam int RAM_PIPE = 4;
logic [RAM_PIPE:0][RAM_A_W-1:0] addr;
logic [RAM_PIPE:0][RAM_D_W-1:0] ram_d;
logic [RAM_PIPE:0]              ram_we;
logic [RAM_PIPE:0]              ram_se;

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    addr <= 0;
    ram_we <= 0;
    ram_se <= 0;
    ram_d <= 0;
  end else begin
    ram_we <= {ram_we, i_ram_we};
    ram_d  <= {ram_d, i_ram_d};
    ram_se <= {ram_se, i_ram_se};
    for (int i = 1; i <= RAM_PIPE; i++)
      addr[i] <= addr[i-1];
    if (ram_we[RAM_PIPE]) begin
      addr[0] <= addr[0] + 1;'''
  for idx, i in enumerate(ram_addr_bits):
    ram_write_s+= '''
      mod_ram_{}_ram[addr[RAM_PIPE]] <= mod_ram_{}_d;'''.format(idx, idx)
  ram_write_s += '''
    end
'''
  ram_write_s += '''
    if (ram_se[RAM_PIPE]) begin'''
  for idx, i in enumerate(ram_addr_bits):
    if idx == 0:
      previous_ram = "ram_d[RAM_PIPE]"
    else:
      previous_ram = "mod_ram_{}_d[{}:{}]".format(idx-1, MODULUS.bit_length()-1, MODULUS.bit_length()-RAM_AXI_D)
    ram_write_s += '''
      mod_ram_{}_d <= {{mod_ram_{}_d, {}}};'''.format(idx, idx, previous_ram)

  ram_write_s += '''
    end
  end
end
'''
  return logic_s + accum_s + ram_s + accum2_s + accum3_s + ram_write_s



f = open('../src/rtl/accum_mult_mod_generated.inc', 'w')
f.write(get_accum_gen())
f.close()

