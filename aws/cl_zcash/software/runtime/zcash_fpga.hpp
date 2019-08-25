//
//  ZCash FPGA library.
//
//  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

#ifndef ZCASH_FPGA_H_   /* Include guard */
#define ZCASH_FPGA_H_

#include <stdint.h>

#include <fpga_pci.h>
#include <fpga_mgmt.h>
#include <utils/lcd.h>
#include <utils/sh_dpi_tasks.h>


#define AXI_FIFO_OFFSET       UINT64_C(0x0)
#define BLS12_381_OFFSET      UINT64_C(0x1000)

// These match the structs and commands defined in zcash_fpga_pkg.sv
class zcash_fpga {

  public:

    typedef enum : uint64_t {
      ENB_BLS12_381             = 1 << 3,
      ENB_VERIFY_SECP256K1_SIG  = 1 << 2,
      ENB_VERIFY_EQUIHASH_144_5 = 1 << 1,
      ENB_VERIFY_EQUIHASH_200_9 = 1 << 0
    } command_cap_e;

    typedef enum : uint32_t {
      RESET_FPGA            = 0x00000000,
      FPGA_STATUS           = 0x00000001,
      VERIFY_EQUIHASH       = 0x00000100,
      VERIFY_SECP256K1_SIG  = 0x00000101,

      // Replies from the FPGA
      RESET_FPGA_RPL            = 0x80000000,
      FPGA_STATUS_RPL           = 0x80000001,
      FPGA_IGNORE_RPL           = 0x80000002,
      VERIFY_EQUIHASH_RPL       = 0x80000100,
      VERIFY_SECP256K1_SIG_RPL  = 0x80000101,
      BLS12_381_INTERRUPT_RPL   = 0x80000200
    } command_t;

    typedef enum : uint8_t {
      SCALAR = 0,
      FE     = 1,
      FE2    = 2,
      FE12   = 3,
      FP_AF  = 4,
      FP_JB  = 5,
      FP2_AF = 6,
      FP2_JB = 7
    } point_type_t;

    // On the FPGA only the first 381 bits of dat are stored
    typedef struct __attribute__((__packed__)) {
      uint8_t      dat[48];
      point_type_t point_type;
    } bls12_381_data_t;

    typedef enum : uint8_t {
      NOOP_WAIT       = 0x0,
      COPY_REG        = 0x1,
      JUMP            = 0x2,
      JUMP_IF_EQ      = 0x4,
      JUMP_NONZERO_SUB= 0x5,
      SEND_INTERRUPT  = 0x6,

      SUB_ELEMENT     = 0x10,
      ADD_ELEMENT     = 0x11,
      MUL_ELEMENT     = 0x12,
      INV_ELEMENT     = 0x13,

      POINT_MULT      = 0x20,
      MILLER_LOOP     = 0x21,
      FINAL_EXP       = 0x22,
      ATE_PAIRING     = 0x23
    } bls12_381_code_t;

    // Instruction format
    typedef struct __attribute__((__packed__)) {
      bls12_381_code_t code;
      uint16_t         a;
      uint16_t         b;
      uint16_t         c;
    } bls12_381_inst_t;

    typedef struct __attribute__((__packed__)) {
      uint32_t  len;
      command_t cmd;
    } header_t;

    typedef struct __attribute__((__packed__)) {
      header_t hdr;
    } fpga_reset_rpl_t;

    typedef struct __attribute__((__packed__)) {
      header_t hdr;
      uint64_t ignore_hdr;
    } fpga_ignore_rpl_t;

    typedef struct __attribute__((__packed__)) {
      uint8_t typ1_state;
    } fpga_state_t;

    typedef struct __attribute__((__packed__)) {
      header_t     hdr;
    } fpga_status_rq_t;


    typedef struct __attribute__((__packed__)) {
      header_t     hdr;
      uint32_t	   version;
      uint64_t	   build_date;
      uint64_t	   build_host;
      uint64_t 	   cmd_cap;
      fpga_state_t fpga_state;
    } fpga_status_rpl_t;

    typedef struct __attribute__((__packed__)) {
      header_t     hdr;
      uint32_t     index;
      point_type_t data_type;
      uint8_t      padding[3];
    } bls12_381_interrupt_rpl_t;

   typedef enum : uint8_t {
      TIMEOUT_FAIL     = 0,
      FAILED_SIG_VER   = 1,
      X_INFINITY_POINT = 2,
      OUT_OF_RANGE_S   = 3,
      OUT_OF_RANGE_R   = 4
    } secp256k1_ver_t;

    typedef struct __attribute__((__packed__)) {
      header_t hdr;
      uint64_t index;
      uint64_t s[4];
      uint64_t r[4];
      uint64_t hash[4];
      uint64_t Qx[4];
      uint64_t Qy[4];
    } verify_secp256k1_sig_t;

    typedef struct __attribute__((__packed__)) {
      header_t        hdr;
      uint64_t        index;
      secp256k1_ver_t bm;
      uint16_t        cycle_cnt;
    } verify_secp256k1_sig_rpl_t;

  private:
    static const uint16_t s_pci_vendor_id = 0x1D0F; /* Amazon PCI Vendor ID */
    static const uint16_t s_pci_device_id = 0xF000; /* PCI Device ID preassigned by Amazon for F1 applications */

    pci_bar_handle_t m_pci_bar_handle_bar0 = PCI_BAR_HANDLE_INIT;
    pci_bar_handle_t m_pci_bar_handle_bar4 = PCI_BAR_HANDLE_INIT;

    unsigned int m_bls12_381_inst_axil_offset;
    unsigned int m_bls12_381_data_axil_offset;
    unsigned int m_bls12_381_inst_size;
    unsigned int m_bls12_381_data_size;

    bool m_axi4_enabled = false;
    bool m_initialized = false;

  public:
    static zcash_fpga& get_instance();
    zcash_fpga(zcash_fpga const&) = delete;
    void operator=(zcash_fpga const&) = delete;

    /*
     * This sends a status request to the FPGA and waits for the reply,
     * checking for any errors.
     */
    int get_status(fpga_status_rpl_t& status_rpl);

    /*
     * Functions for writing and reading data/instruction slots in the BLS12_381 coprocessor
     */
    int bls12_381_set_data_slot(unsigned int id, bls12_381_data_t slot_data);
    int bls12_381_get_data_slot(unsigned int id, bls12_381_data_t& slot_data);

    int bls12_381_set_inst_slot(unsigned int id, bls12_381_inst_t inst_data);
    int bls12_381_get_inst_slot(unsigned int id, bls12_381_inst_t& inst_data);

    int bls12_381_set_curr_inst_slot(unsigned int id);
    int bls12_381_get_curr_inst_slot(unsigned int& id);

    /*
     * Return the number of cycles the last cycle took (excluding INTERRUPT and NOOP)
     */
    int bls12_381_get_last_cycle_cnt(unsigned int& cnt);

    /*
     * This will clear the entire memory back to the initial state (will not change instruction pointer)
     */
    int bls12_381_reset_memory(bool inst_memory, bool data_memory);

    /*
     * These can be used to send data / read data directly from the FPGAs stream interface
     */
    int read_stream(uint8_t* data, unsigned int size);
    int write_stream(uint8_t* data, unsigned int len);

    /*
     * This can be read to check command capability register on the FPGA
     */
    command_cap_e m_command_cap;

  private:
    /*
     * This connects to the FPGA and is called by the constructor on the first call of get_instance()
     */
    int init_fpga(int slot_id = 0);

    zcash_fpga();
    ~zcash_fpga();

    int check_afi_ready(int slot_id);

}; // zcash_fpga

#endif // ZCASH_FPGA_H_
