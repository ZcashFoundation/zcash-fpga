//
//  ZCash FPGA test.
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

#define _XOPEN_SOURCE 500

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include <string>
#include <vector>
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <unistd.h>
#include <stdlib.h>

#include <fpga_pci.h>
#include <fpga_mgmt.h>
#include <utils/lcd.h>
#include <utils/sh_dpi_tasks.h>

#include <openssl/ecdsa.h>
#include <openssl/sha.h>
#include <openssl/bn.h>

#include "./zcash_fpga.hpp"
#include "./ossl.h"

/* use the stdout logger for printing debug information  */

//const struct logger *logger = &logger_stdout;
/*
 * check if the corresponding AFI for hello_world is loaded
 */
//int check_afi_ready(int slot_id); //I think this is not necessary as it is already override..

void usage(char* program_name) {
    printf("usage: %s [--slot <slot-id>][<poke-value>]\n", program_name);
}

int main(int argc, char **argv) {

    unsigned int slot_id = 0;
    int rc;
    uint32_t value = 0;
    unsigned int timeout = 0;
    unsigned int read_len = 0;
    uint8_t reply[640];
    uint32_t failed = 0;
    // Process command line args
    {
        int i;
        int value_set = 0;
        for (i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--slot")) {
                i++;
                if (i >= argc) {
                    printf("error: missing slot-id\n");
                    usage(argv[0]);
                    return 1;
                }
                sscanf(argv[i], "%d", &slot_id);
            } else if (!value_set) {
                sscanf(argv[i], "%x", &value);
                value_set = 1;
            } else {
                printf("error: Invalid arg: %s", argv[i]);
                usage(argv[0]);
                return 1;
            }
        }
    }

    zcash_fpga& zfpga = zcash_fpga::get_instance();

    // Test the secp256k1 core
    if ((zfpga.m_command_cap & zcash_fpga::ENB_VERIFY_SECP256K1_SIG) != 0) {
      printf("INFO: Testing secp256k1 core...\n");
      const unsigned int index_int=0xa;
      for (unsigned int tv_ind=0; tv_ind<5; tv_ind++) {
      printf("******************************************************\n");

      printf("INFO: TV index=%d\n", tv_ind+1);
      zcash_fpga::verify_secp256k1_sig_t verify_secp256k1_sig;
      memset(&verify_secp256k1_sig, 0, sizeof(zcash_fpga::verify_secp256k1_sig_t));
      verify_secp256k1_sig.hdr.cmd = zcash_fpga::VERIFY_SECP256K1_SIG;
      verify_secp256k1_sig.hdr.len = sizeof(zcash_fpga::verify_secp256k1_sig_t);
      verify_secp256k1_sig.index = index_int+tv_ind;
       switch (tv_ind)
        {       case 0:
                std::cout<<"Hardcoded TV1 selected\n";
                string_to_hex("4c7dbc46486ad9569442d69b558db99a2612c4f003e6631b593942f531e67fd4", (unsigned char *)verify_secp256k1_sig.hash);
                string_to_hex("01375af664ef2b74079687956fd9042e4e547d57c4438f1fc439cbfcb4c9ba8b", (unsigned char *)verify_secp256k1_sig.r);
                string_to_hex("de0f72e442f7b5e8e7d53274bf8f97f0674f4f63af582554dbecbb4aa9d5cbcb", (unsigned char *)verify_secp256k1_sig.s);
                string_to_hex("808a2c66c5b90fa1477d7820fc57a8b7574cdcb8bd829bdfcf98aa9c41fde3b4", (unsigned char *)verify_secp256k1_sig.Qx);
                string_to_hex("eed249ffde6e46d784cb53b4df8c9662313c1ce8012da56cb061f12e55a32249", (unsigned char *)verify_secp256k1_sig.Qy);
                break;
                case 1:
                std::cout<<"Hardcoded TV2 selected\n";
                string_to_hex("aca448f8093e33286c7d284569feae5f65ae7fa2ea5ce9c46acaad408da61e1f", (unsigned char *)verify_secp256k1_sig.hash);
                string_to_hex("0bce4a3be622e3f919f97b03b45e3f32ccdf3dd6bcce40657d8f9fc973ae7b29", (unsigned char *)verify_secp256k1_sig.r);
                string_to_hex("6abcd5e40fcee8bca6b506228a2dcae67daa5d743e684c4d3fb1cb77e43b48fe", (unsigned char *)verify_secp256k1_sig.s);
                string_to_hex("b661c143ffbbad5acfe16d427767cdc57fb2e4c019a4753ba68cd02c29e4a153", (unsigned char *)verify_secp256k1_sig.Qx);
                string_to_hex("6e1fb00fdb9ddd39b55596bfb559bc395f220ae51e46dbe4e4df92d1a5599726", (unsigned char *)verify_secp256k1_sig.Qy);
                break;
                case 2:
                std::cout<<"Hardcoded TV3 selected\n";
                string_to_hex("9834876dcfb05cb167a5c24953eba58c4ac89b1adf57f28f2f9d09af107ee8f0", (unsigned char *)verify_secp256k1_sig.hash);
                string_to_hex("ae235401e2112948be75194de0bad0002e8e76e6cdf9267ccb179643d908dc5e", (unsigned char *)verify_secp256k1_sig.r);
                string_to_hex("1f37bd6b617d03db5413cad3dc74fd091d071c2377fb74f488c56077823a2d56", (unsigned char *)verify_secp256k1_sig.s);
                string_to_hex("5db9b06cc4928dd46f675c7dde14de8c7c2a8fd8e6c132da77e4ffeb90ff51d0", (unsigned char *)verify_secp256k1_sig.Qx);
                string_to_hex("54d0967454193d20bc5733d0779ce3f6824666a3a9a66273c7f21e5f26ca0bbf", (unsigned char *)verify_secp256k1_sig.Qy);
                break;
                case 3:
                std::cout<<"Hardcoded TV4 selected\n";
                string_to_hex("9834876dcfb05cb167a5c24953eba58c4ac89b1adf57f28f2f9d09af107ee8f0", (unsigned char *)verify_secp256k1_sig.hash);
                string_to_hex("a0c388bad0d0de5b8cd74dde1b130ae24f727874e00b0a19c9a0ee336ea420cf", (unsigned char *)verify_secp256k1_sig.r);
                string_to_hex("4d549363cea5e7cf2e5a80de97057e6709b8014c9037d12aac86b9ae4fbb02bb", (unsigned char *)verify_secp256k1_sig.s);
                string_to_hex("87d4561f92925beb4afd97fb0f883bc1f7f573494087191af8bc67557b4ab0f9", (unsigned char *)verify_secp256k1_sig.Qx);
                string_to_hex("0d933ed3e39c30e27dfde32f276ef50db3eef6cbea8e913f7488b3dff15fb3ee", (unsigned char *)verify_secp256k1_sig.Qy);
                break;
                case 4:
                printf ("This test vector may knock off fpga, you may need do fpga-load-local-image again!!!\n");
                string_to_hex("000ab00000000000000000000000000000000000000000000000000000000000", (unsigned char *)verify_secp256k1_sig.hash);
                string_to_hex("0000000000000000000000000000000000000000000000000000000000000000", (unsigned char *)verify_secp256k1_sig.r);
                string_to_hex("0000000000000000000000000000000000000000000000000000000000000000", (unsigned char *)verify_secp256k1_sig.s);
                string_to_hex("00bcd00000000000000000000000000000000000000000000000000000000000", (unsigned char *)verify_secp256k1_sig.Qx);
                string_to_hex("0000000000000000000000000000000000000000000000000000000000000000", (unsigned char *)verify_secp256k1_sig.Qy);
		break;
		default: 
		printf ("This test vector may knock off fpga, you may need do fpga-load-local-image again!!!\n");
		
        }
      rc = zfpga.write_stream((uint8_t*)&verify_secp256k1_sig, sizeof(zcash_fpga::verify_secp256k1_sig_t));
      fail_on(rc, out, "ERROR: Unable to send verify_secp256k1_sig to FPGA!");

     timeout = 0;
      read_len = 0;
      memset(reply, 0, 512);
      while ((read_len = zfpga.read_stream(reply, 256)) == 0) {
        usleep(1);
        timeout++;
        if (timeout > 1000) {
          printf("[ERROR]: No reply received, timeout\n");
          failed = true;
          break;
        }
      }

      zcash_fpga::verify_secp256k1_sig_rpl_t verify_secp256k1_sig_rpl;
      verify_secp256k1_sig_rpl = *(zcash_fpga::verify_secp256k1_sig_rpl_t*)reply;
      
      printf("[INFO]:  hdr.cmd  = 0x%x\n", verify_secp256k1_sig_rpl.hdr.cmd);
      printf("[INFO]: .bm       = 0x%x\n", verify_secp256k1_sig_rpl.bm);
      printf("[INFO]: .index    = 0x%lx, \t expect 0x%x\n", verify_secp256k1_sig_rpl.index,index_int+tv_ind);
      printf("[INFO]: .cycle_cnt= 0x%x\n", verify_secp256k1_sig_rpl.cycle_cnt);
      
      if (verify_secp256k1_sig_rpl.hdr.cmd != zcash_fpga::VERIFY_SECP256K1_SIG_RPL) {
          printf("[ERROR]: Header type was wrong for test vector#%d!\n",tv_ind);
          failed++;
          continue;
      }
      if (verify_secp256k1_sig_rpl.bm != 0) {
          printf("[ERROR]: Signature verification failed for test vector #%d!\n",tv_ind);
          failed++;
          continue;
      }

      if (verify_secp256k1_sig_rpl.index != index_int+tv_ind) {
         printf("[ERROR]: Index was wrong for test vector #%d!\n",tv_ind);
         failed++;
         continue;
      }
      }//end of tv_ind loop
    }
    printf("\n======================================================\n");
    printf("Final result\n");
    printf("Total 5 round test, failed [%d]\n", failed);

 out:
    return 1;
}
