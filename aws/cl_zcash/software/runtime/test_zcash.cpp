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

#include <unistd.h>
#include <stdlib.h>

#include <fpga_pci.h>
#include <fpga_mgmt.h>
#include <utils/lcd.h>
#include <utils/sh_dpi_tasks.h>

#include "zcash_fpga.hpp"

/* use the stdout logger for printing debug information  */

const struct logger *logger = &logger_stdout;
/*
 * check if the corresponding AFI for hello_world is loaded
 */
//int check_afi_ready(int slot_id); //I think this is not necessary as it is already override..


void usage(char* program_name) {
    printf("usage: %s [--slot <slot-id>][<poke-value>]\n", program_name);
}

// uint32_t byte_swap(uint32_t value);

uint32_t byte_swap(uint32_t value) {
    uint32_t swapped_value = 0;
    int b;
    for (b = 0; b < 4; b++) {
        swapped_value |= ((value >> (b * 8)) & 0xff) << (8 * (3-b));
    }
    return swapped_value;
}

bool string_to_hex(const std::string &inStr, unsigned char *outStr) {
    size_t len = inStr.length();
    for (ssize_t i = len-2; i >= 0; i -= 2) {
        sscanf(inStr.c_str() + i, "%2hhx", outStr);
        ++outStr;
    }
    return true;
}

int main(int argc, char **argv) {

    unsigned int slot_id = 0;
    int rc;
    uint32_t value = 0;
    unsigned int timeout = 0;
    unsigned int read_len = 0;
    uint8_t reply[640];
    bool failed = 0;
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

      zcash_fpga::verify_secp256k1_sig_t verify_secp256k1_sig;
      memset(&verify_secp256k1_sig, 0, sizeof(zcash_fpga::verify_secp256k1_sig_t));
      verify_secp256k1_sig.hdr.cmd = zcash_fpga::VERIFY_SECP256K1_SIG;
      verify_secp256k1_sig.hdr.len = sizeof(zcash_fpga::verify_secp256k1_sig_t);
      verify_secp256k1_sig.index = 0xa;
      string_to_hex("4c7dbc46486ad9569442d69b558db99a2612c4f003e6631b593942f531e67fd4", (unsigned char *)verify_secp256k1_sig.hash);
      string_to_hex("01375af664ef2b74079687956fd9042e4e547d57c4438f1fc439cbfcb4c9ba8b", (unsigned char *)verify_secp256k1_sig.r);
      string_to_hex("de0f72e442f7b5e8e7d53274bf8f97f0674f4f63af582554dbecbb4aa9d5cbcb", (unsigned char *)verify_secp256k1_sig.s);
      string_to_hex("808a2c66c5b90fa1477d7820fc57a8b7574cdcb8bd829bdfcf98aa9c41fde3b4", (unsigned char *)verify_secp256k1_sig.Qx);
      string_to_hex("eed249ffde6e46d784cb53b4df8c9662313c1ce8012da56cb061f12e55a32249", (unsigned char *)verify_secp256k1_sig.Qy);

      rc = zfpga.write_stream((uint8_t*)&verify_secp256k1_sig, sizeof(zcash_fpga::verify_secp256k1_sig_t));
      fail_on(rc, out, "ERROR: Unable to send verify_secp256k1_sig to FPGA!");

      timeout = 0;
      read_len = 0;
      memset(reply, 0, 512);
      while ((read_len = zfpga.read_stream(reply, 256)) == 0) {
        usleep(1);
        timeout++;
        if (timeout > 1000) {
          printf("ERROR: No reply received, timeout\n");
          failed = true;
          break;
        }
      }

      zcash_fpga::verify_secp256k1_sig_rpl_t verify_secp256k1_sig_rpl;
      verify_secp256k1_sig_rpl = *(zcash_fpga::verify_secp256k1_sig_rpl_t*)reply;
      printf("INFO: verify_secp256k1_sig_rpl.hdr.cmd = 0x%x\n", verify_secp256k1_sig_rpl.hdr.cmd);
      printf("INFO: verify_secp256k1_sig_rpl.bm = 0x%x\n", verify_secp256k1_sig_rpl.bm);
      printf("INFO: verify_secp256k1_sig_rpl.index = 0x%lx\n", verify_secp256k1_sig_rpl.index);
      printf("INFO: verify_secp256k1_sig_rpl.cycle_cnt = 0x%x\n", verify_secp256k1_sig_rpl.cycle_cnt);

      if (verify_secp256k1_sig_rpl.hdr.cmd != zcash_fpga::VERIFY_SECP256K1_SIG_RPL) {
          printf("ERROR: Header type was wrong!\n");
          failed = true;
      }
      if (verify_secp256k1_sig_rpl.bm != 0) {
          printf("ERROR: Signature verification failed!\n");
          failed = true;
      }

      if (verify_secp256k1_sig_rpl.index != 0xa) {
        printf("ERROR: Index was wrong!\n");
        failed = true;
      }
    }

    if ((zfpga.m_command_cap & zcash_fpga::ENB_BLS12_381) != 0) {
      printf("INFO: Testing bls12_381 coprocessor...\n");

      zfpga.bls12_381_reset_memory(true, true);
      zfpga.bls12_381_set_curr_inst_slot(0);

      // Test Fp2 point multiplication
      zcash_fpga::bls12_381_data_t data;
      zcash_fpga::bls12_381_inst_t inst;

      // Store generator points in FPGA
      size_t g1_slot = 64;
      size_t g2_slot = 66;

      data.point_type = zcash_fpga::FP2_AF;
      memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
      string_to_hex("024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8", (unsigned char *)data.dat);
      rc = zfpga.bls12_381_set_data_slot(g2_slot, data);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      data.point_type = zcash_fpga::FP2_AF;
      memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
      string_to_hex("13e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e", (unsigned char *)data.dat);
      rc = zfpga.bls12_381_set_data_slot(g2_slot + 1, data);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      data.point_type = zcash_fpga::FP2_AF;
      memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
      string_to_hex("0ce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b82801", (unsigned char *)data.dat);
      rc = zfpga.bls12_381_set_data_slot(g2_slot + 2, data);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      data.point_type = zcash_fpga::FP2_AF;
      memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
      string_to_hex("0606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79be", (unsigned char *)data.dat);
      rc = zfpga.bls12_381_set_data_slot(g2_slot + 3, data);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      data.point_type = zcash_fpga::FP_AF;
      memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
      string_to_hex("17F1D3A73197D7942695638C4FA9AC0FC3688C4F9774B905A14E3A3F171BAC586C55E83FF97A1AEFFB3AF00ADB22C6BB", (unsigned char *)data.dat);
      rc = zfpga.bls12_381_set_data_slot(g1_slot, data);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      data.point_type = zcash_fpga::FP_AF;
      memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
      string_to_hex("08B3F481E3AAA0F1A09E30ED741D8AE4FCF5E095D5D00AF600DB18CB2C04B3EDD03CC744A2888AE40CAA232946C5E7E1", (unsigned char *)data.dat);
      rc = zfpga.bls12_381_set_data_slot(g1_slot + 1, data);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");


      data.point_type = zcash_fpga::SCALAR;
      memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
      data.dat[0] = 10;
      rc = zfpga.bls12_381_set_data_slot(0, data);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      memset(&inst, 0x0, sizeof(zcash_fpga::bls12_381_inst_t));
      inst.code = zcash_fpga::SEND_INTERRUPT;
      inst.a = 0;
      inst.b = 123;
      rc = zfpga.bls12_381_set_inst_slot(5, inst);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      inst.code = zcash_fpga::SEND_INTERRUPT;
      inst.a = 1;
      inst.b = 456;
      rc = zfpga.bls12_381_set_inst_slot(6, inst);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");
      // Multi pairing of e(G1, G2) . e(G1, G2)
      inst.code = zcash_fpga::MILLER_LOOP;
      inst.a = g1_slot;
      inst.b = g2_slot;
      inst.c = 1;
      rc = zfpga.bls12_381_set_inst_slot(1, inst);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      inst.code = zcash_fpga::MILLER_LOOP;
      inst.a = g1_slot;
      inst.b = g2_slot;
      inst.c = 13;
      rc = zfpga.bls12_381_set_inst_slot(2, inst);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      inst.code = zcash_fpga::MUL_ELEMENT;
      inst.a = 1;
      inst.b = 13;
      inst.c = 1;
      rc = zfpga.bls12_381_set_inst_slot(3, inst);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      inst.code = zcash_fpga::FINAL_EXP;
      inst.a = 1;
      inst.b = 1;
      inst.c = 0;
      rc = zfpga.bls12_381_set_inst_slot(4, inst);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      // Start the test
      rc = zfpga.bls12_381_set_curr_inst_slot(1);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      // Wait for interrupts
      // Try read reply - should be our scalar value - not using right now, could be used for point multiplication

      timeout = 0;
      read_len = 0;
      memset(reply, 0, 512);
      while ((read_len = zfpga.read_stream(reply, 256)) == 0) {
        usleep(1);
        timeout++;
        if (timeout > 1000) {
          printf("ERROR: No reply received, timeout\n");
          failed = true;
          break;
        }
      }


      zcash_fpga::bls12_381_interrupt_rpl_t bls12_381_interrupt_rpl;
      // Check it matches the expected values
      bls12_381_interrupt_rpl = *(zcash_fpga::bls12_381_interrupt_rpl_t*)reply;
      if (bls12_381_interrupt_rpl.data_type != zcash_fpga::SCALAR) {
        printf("ERROR: Interrupt data type was wrong, expected SCALAR, was [%d]\n", bls12_381_interrupt_rpl.data_type);
        failed = true;
      }
      if (bls12_381_interrupt_rpl.index != 123) {
        printf("ERROR: Interrupt index was wrong, expected 123, was [%d]\n", bls12_381_interrupt_rpl.index);
        failed = true;
      }
      if (reply[sizeof(zcash_fpga::bls12_381_interrupt_rpl_t)] != 10) {
        printf("ERROR: Interrupt data was wrong, expected 10, was [%d]\n", reply[sizeof(zcash_fpga::bls12_381_interrupt_rpl_t)]);
        failed = true;
      }

      // Try read second reply - should be point value - 12 slots = 576 bytes
      memset(reply, 0, 640);
      timeout = 0;
      read_len = 0;
      while ((read_len = zfpga.read_stream(reply, 640)) == 0) {
        usleep(1);
        timeout++;
        if (timeout > 1000) {
          printf("ERROR: No reply received, timeout\n");
          failed = true;
          break;
        }
      }
     // Check it matches the expected values
      bls12_381_interrupt_rpl = *(zcash_fpga::bls12_381_interrupt_rpl_t*)reply;
      if (bls12_381_interrupt_rpl.data_type != zcash_fpga::FE12) {
        printf("ERROR: Interrupt data type was wrong, expected FE12, was [%d]\n", bls12_381_interrupt_rpl.data_type);
        failed = true;
      }
      if (bls12_381_interrupt_rpl.index != 456) {
        printf("ERROR: Interrupt index was wrong, expected 456, was [%d]\n", bls12_381_interrupt_rpl.index);
        failed = true;
      }

      // Check it matches the value expected from our software model
      uint8_t exp_res[640];
      memset(exp_res, 0, 640);
      string_to_hex("04fb0f149dd925d2c590a960936763e519c2b62e14c7759f96672cd852194325904197b0b19c6b528ab33566946af39b", (unsigned char *)&exp_res[0]);
      string_to_hex("185ef728cf41a1b7b700b7e445f0b372bc29e370bc227d443c70ae9dbcf73fee8acedbd317a286a53266562d817269c0", (unsigned char *)&exp_res[48]);
      string_to_hex("03a3734dbeb064bf4bc4a03f945a4921e49d04ab8d45fd753a28b8fa082616b4b17bbcb685e455ff3bf8f60c3bd32a0c", (unsigned char *)&exp_res[2*48]);
      string_to_hex("1409cebef9ef393aa00f2ac64673675521e8fc8fddaf90976e607e62a740ac59c3dddf95a6de4fba15beb30c43d4e3f8", (unsigned char *)&exp_res[3*48]);
      string_to_hex("1692a61ce5f4d7a093b2c46aa4bca6c4a66cf873d405ebc9c35d8aa639763720177b23beffaf522d5e41d3c5310ea333", (unsigned char *)&exp_res[4*48]);
      string_to_hex("081abd33a78d31eb8d4c1bb3baab0529bb7baf1103d848b4cead1a8e0aa7a7b260fbe79c67dbe41ca4d65ba8a54a72b6", (unsigned char *)&exp_res[5*48]);
      string_to_hex("0900410bb2751d0a6af0fe175dcf9d864ecaac463c6218745b543f9e06289922434ee446030923a3e4c4473b4e3b1914", (unsigned char *)&exp_res[6*48]);
      string_to_hex("113286dee21c9c63a458898beb35914dc8daaac453441e7114b21af7b5f47d559879d477cf2a9cbd5b40c86becd07128", (unsigned char *)&exp_res[7*48]);
      string_to_hex("06d8046c6b3424c4cd2d72ce98d279f2290a28a87e8664cb0040580d0c485f34df45267f8c215dcbcd862787ab555c7e", (unsigned char *)&exp_res[8*48]);
      string_to_hex("0f6b8b52b2b5d0661cbf232820a257b8c5594309c01c2a45e64c6a7142301e4fb36e6e16b5a85bd2e437599d103c3ace", (unsigned char *)&exp_res[9*48]);
      string_to_hex("017f1c95cf79b22b459599ea57e613e00cb75e35de1f837814a93b443c54241015ac9761f8fb20a44512ff5cfc04ac7f", (unsigned char *)&exp_res[10*48]);
      string_to_hex("079ab7b345eb23c944c957a36a6b74c37537163d4cbf73bad9751de1dd9c68ef72cb21447e259880f72a871c3eda1b0c", (unsigned char *)&exp_res[11*48]);

      if (memcmp((void*)&(reply[sizeof(zcash_fpga::bls12_381_interrupt_rpl_t)]), (void*)exp_res, 12*48) != 0) {
        printf("ERROR: Interrupt data was wrong (check data slot 1-13)!\n");
        failed = true;
      }


      // Read current instruction
      rc = zfpga.bls12_381_get_curr_inst_slot(slot_id);
      fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

      printf("INFO: Data slot is now %d\n", slot_id);

      // Print out data slots
      for(int i = 0; i < 13; i++) {
        zfpga.bls12_381_get_data_slot(i, data);
        printf("slot %d, pt: %d, data:0x", i, data.point_type);
        for(int j = 47; j >= 0; j--) printf("%02x", data.dat[j]);
        printf("\n");
      }
    }
    if (!failed) {
      printf("INFO: All tests passed!\n");
    } else {
      printf("ERROR: Tests did not pass!\n");
    }

    return rc;
out:
    return 1;
}
