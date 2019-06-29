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

#define AXI_FIFO_OFFSET UINT64_C(0x0)
#define ZCASH_OFFSET    UINT64_C(0x1000)


// These match the structs and commands defined in zcash_fpga_pkg.sv
class zcash_fpga {
  public:

    static zcash_fpga& getInstance() {
        static zcash_fpga instance; // Guaranteed to be destroyed. Instantiated on first use.
        return instance;
    }

    int init_fpga(int slot_id = 0);

  private:
    zcash_fpga() {}           // Constructor
    S(S const&);              // Don't Implement
    void operator=(S const&); // Don't implement

  public:
    S(S const&)               = delete;
    void operator=(S const&)  = delete;



  private:
    const struct logger *logger = &logger_stdout;
    /*
     * pci_vendor_id and pci_device_id values below are Amazon's and avaliable to use for a given FPGA slot.
     * Users may replace these with their own if allocated to them by PCI SIG
     */
    static uint16_t pci_vendor_id = 0x1D0F; /* Amazon PCI Vendor ID */
    static uint16_t pci_device_id = 0xF000; /* PCI Device ID preassigned by Amazon for F1 applications */

    pci_bar_handle_t pci_bar_handle_bar0 = PCI_BAR_HANDLE_INIT;
    pci_bar_handle_t pci_bar_handle_bar4 = PCI_BAR_HANDLE_INIT;

    bool AXI4_enabled = false;
    bool initialized = false;

    enum uint64_t {
      ENB_BLS12_381             = 1 << 3,
      ENB_VERIFY_SECP256K1_SIG  = 1 << 2,
      ENB_VERIFY_EQUIHASH_144_5 = 1 << 1,
      ENB_VERIFY_EQUIHASH_200_9 = 1 << 0
    } command_cap;

    typedef enum uin32_t {
      RESET_FPGA            = 0x0000_00_00,
      FPGA_STATUS           = 0x0000_00_01,
      VERIFY_EQUIHASH       = 0x0000_01_00,
      VERIFY_SECP256K1_SIG  = 0x0000_01_01,

      // Replies from the FPGA
      RESET_FPGA_RPL            = 0x80_00_00_00,
      FPGA_STATUS_RPL           = 0x80_00_00_01,
      FPGA_IGNORE_RPL           = 0x80_00_00_02,
      VERIFY_EQUIHASH_RPL       = 0x80_00_01_00,
      VERIFY_SECP256K1_SIG_RPL  = 0x80_00_01_01,
      BLS12_381_INTERRUPT_RPL   = 0x80_00_02_00
    } command_t;


    typedef struct __attribute__((__packed__)) header_t {
      uint32_t  len;
      command_t cmd;
    };


    typedef struct __attribute__((__packed__)) fpga_reset_rpl_t {
      header_t hdr;
    };

    typedef struct __attribute__((__packed__)) fpga_ignore_rpl_t {
      header_t hdr;
      uint64_t ignore_hdr;
    };

    typedef struct __attribute__((__packed__)) fpga_state_t {
      uint8_t typ1_state;
    } fpga_state_t;

    typedef struct __attribute__((__packed__)) fpga_status_rpl_t {
      header_t     hdr;
      uint32_t	   version;
      uint64_t	   build_date;
      uint64_t	   build_host;
      uint64_t 	   cmd_cap;
      fpga_state_t fpga_state;
    };
} // zcash_fpga

#endif // ZCASH_FPGA_H_
