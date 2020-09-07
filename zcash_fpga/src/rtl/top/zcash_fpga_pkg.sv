/*
  Parameter values and tasks for the FPGA system.

  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package zcash_fpga_pkg;

  import equihash_pkg::equihash_bm_t;
  import equihash_pkg::cblockheader_sol_t;
  import equihash_pkg::N;
  import equihash_pkg::K;
  import secp256k1_pkg::secp256k1_ver_t;

  import bls12_381_pkg::point_type_t;

  parameter FPGA_VERSION = 32'h01_04_03;  //v1.4.3

  // What features are enabled in this build
  parameter bit ENB_VERIFY_SECP256K1_SIG = 1;
  parameter bit ENB_VERIFY_EQUIHASH = 0;
  parameter bit ENB_BLS12_381 = 0;

  localparam [63:0] FPGA_CMD_CAP = {{60'd0},
                                     ENB_BLS12_381,
                                     ENB_VERIFY_SECP256K1_SIG,
                                    (ENB_VERIFY_EQUIHASH && equihash_pkg::N == 144 && equihash_pkg::K == 5),       // N = 144, K = 5 for VERIFY_EQUIHASH command
                                    (ENB_VERIFY_EQUIHASH && equihash_pkg::N == 200 && equihash_pkg::K == 9)};      // N = 200, K = 9 for VERIFY_EQUIHASH command

  localparam BLS12_381_USE_KARATSUBA = "NO"; // ["YES" | "NO"], defines to use Karatsuba multiplier ("YES"), otherwise accum_mod with RAM reduction

  // These are all the command types the FPGA supports
  // Reply messages from the FPGA to host all have the last
  // bit set (start at 0x80000000). Messages with bits [31:16] == 0 are processed by a different state machine
  typedef enum logic [31:0] {
    RESET_FPGA            = 'h0000_00_00,
    FPGA_STATUS           = 'h0000_00_01,
    VERIFY_EQUIHASH       = 'h0000_01_00,
    VERIFY_SECP256K1_SIG  = 'h0000_01_01,

    // Replies from the FPGA
    RESET_FPGA_RPL            = 'h80_00_00_00,
    FPGA_STATUS_RPL           = 'h80_00_00_01,
    FPGA_IGNORE_RPL           = 'h80_00_00_02,
    VERIFY_EQUIHASH_RPL       = 'h80_00_01_00,
    VERIFY_SECP256K1_SIG_RPL  = 'h80_00_01_01,
    BLS12_381_INTERRUPT_RPL   = 'h80_00_02_00
  } command_t;

  // Data sent to the FPGA must start with a header aligned to
  // a 8 byte boundary.
  typedef struct packed {
    command_t    cmd;
    logic [31:0] len;
  } header_t;

  typedef struct packed {
    header_t     hdr;
  } fpga_reset_rpl_t;

  typedef struct packed {
    logic [63:0] ignore_hdr;
    header_t     hdr;
  } fpga_ignore_rpl_t;

  // These are registers we use for debug
  typedef struct packed {
    logic [3:0] padding;
    logic [2:0] typ1_state;
    logic error; // Any error on FPGA will have this set
  } fpga_state_t;

  typedef struct packed {
    fpga_state_t fpga_state;
    logic [63:0] cmd_cap;
    logic [63:0] build_host;
    logic [63:0] build_date;
    logic [31:0] version;
    header_t     hdr;
  } fpga_status_rpl_t;

  typedef struct packed {
    cblockheader_sol_t cblockheader_sol;
    logic [63:0]       index;
    header_t           hdr;
  } verify_equihash_t;

  typedef struct packed {
    equihash_bm_t  bm;
    logic [63:0]   index;
    header_t       hdr;
  } verify_equihash_rpl_t;

  typedef struct packed {
    logic [255:0]      Qy;
    logic [255:0]      Qx;
    logic [255:0]      hash;
    logic [255:0]      r;
    logic [255:0]      s;
    logic [63:0]       index;
    header_t           hdr;
  } verify_secp256k1_sig_t;

  typedef struct packed {
    logic [15:0]       cycle_cnt;
    secp256k1_ver_t    bm;
    logic [63:0]       index;
    header_t           hdr;
  } verify_secp256k1_sig_rpl_t;

  typedef struct packed {
    logic [5+24-1:0]              padding;
    bls12_381_pkg::point_type_t data_type;
    logic [31:0]                index;
    header_t                    hdr;
  } bls12_381_interrupt_rpl_t;

  // We have a function for building each type of reply from the FPGA
  function fpga_reset_rpl_t get_fpga_reset_rpl();
    get_fpga_reset_rpl.hdr = '{cmd:RESET_FPGA_RPL, len:$bits(fpga_reset_rpl_t)/8};
  endfunction

  function fpga_ignore_rpl_t get_fpga_ignore_rpl(header_t hdr);
    get_fpga_ignore_rpl.hdr = '{cmd:FPGA_IGNORE_RPL, len:$bits(fpga_ignore_rpl_t)/8};
    get_fpga_ignore_rpl.ignore_hdr = hdr;
  endfunction

  function fpga_status_rpl_t get_fpga_status_rpl(input [63:0] build_host, build_date, fpga_state_t fpga_state);
    get_fpga_status_rpl.cmd_cap = FPGA_CMD_CAP;
    get_fpga_status_rpl.hdr = '{cmd:FPGA_STATUS_RPL, len:$bits(fpga_status_rpl_t)/8};
    get_fpga_status_rpl.version = FPGA_VERSION;
    get_fpga_status_rpl.build_host = build_host;
    get_fpga_status_rpl.build_date = build_date;
    get_fpga_status_rpl.fpga_state = fpga_state;
  endfunction

  function verify_equihash_rpl_t get_verify_equihash_rpl(input equihash_bm_t mask, logic [63:0] index);
    get_verify_equihash_rpl.hdr = '{cmd:VERIFY_EQUIHASH_RPL, len:$bits(verify_equihash_rpl_t)/8};
    get_verify_equihash_rpl.index = index;
    get_verify_equihash_rpl.bm = mask;
  endfunction

  function verify_secp256k1_sig_rpl_t verify_secp256k1_sig_rpl(input secp256k1_ver_t mask, logic [63:0] index, logic [15:0] cycle_cnt);
    verify_secp256k1_sig_rpl.hdr = '{cmd:VERIFY_SECP256K1_SIG_RPL, len:$bits(verify_secp256k1_sig_rpl_t)/8};
    verify_secp256k1_sig_rpl.index = index;
    verify_secp256k1_sig_rpl.bm = mask;
    verify_secp256k1_sig_rpl.cycle_cnt = cycle_cnt;
  endfunction

  function bls12_381_interrupt_rpl_t bls12_381_interrupt_rpl(input logic [15:0] index, point_type_t data_type);
    bls12_381_interrupt_rpl = 0;
    bls12_381_interrupt_rpl.hdr = '{cmd:BLS12_381_INTERRUPT_RPL, len:($bits(bls12_381_interrupt_rpl_t)/8)};
    bls12_381_interrupt_rpl.data_type = data_type;
    bls12_381_interrupt_rpl.index = index;
  endfunction

endpackage
