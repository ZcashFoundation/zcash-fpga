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
int check_afi_ready(int slot_id);


void usage(char* program_name) {
    printf("usage: %s [--slot <slot-id>][<poke-value>]\n", program_name);
}

uint32_t byte_swap(uint32_t value);


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
    uint8_t reply[512];
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

    zfpga.bls12_381_reset_memory(true, true);
    zfpga.bls12_381_set_curr_inst_slot(0);

    // Test Fp2 point multiplication
    zcash_fpga::bls12_381_data_t data;
    zcash_fpga::bls12_381_inst_t inst;

    // Store generator points in FPGA
    size_t g1_slot = 64;
    size_t g2_slot = 68; 
    
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
    string_to_hex("ce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b82801", (unsigned char *)data.dat);
    rc = zfpga.bls12_381_set_data_slot(g2_slot + 2, data);
    fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

    data.point_type = zcash_fpga::FP2_AF;
    memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
    string_to_hex("606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79be", (unsigned char *)data.dat);
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
    rc = zfpga.bls12_381_set_data_slot(g1_slot + 1, data);                                                                                                                                          fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");


    data.point_type = zcash_fpga::SCALAR;
    memset(&data, 0x0, sizeof(zcash_fpga::bls12_381_data_t));
    data.dat[0] = 10;
    rc = zfpga.bls12_381_set_data_slot(0, data);
    fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

    memset(&inst, 0x0, sizeof(zcash_fpga::bls12_381_inst_t));
    inst.code = zcash_fpga::SEND_INTERRUPT;
    inst.a = 0;
    inst.b = 123;
    rc = zfpga.bls12_381_set_inst_slot(1, inst);
    fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

    inst.code = zcash_fpga::SEND_INTERRUPT;
    inst.a = 1;
    inst.b = 456;
    rc = zfpga.bls12_381_set_inst_slot(2, inst);
    fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

    inst.code = zcash_fpga::POINT_MULT;
    inst.a = 0;
    inst.b = g1_slot;
    inst.c = 1;
    rc = zfpga.bls12_381_set_inst_slot(1, inst);
    fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

    // Multi pairing
    inst.code = zcash_fpga::MILLER_LOOP;
    inst.a = 1;
    inst.b = g2_slot;
    inst.c = 1;
    rc = zfpga.bls12_381_set_inst_slot(2, inst);                                                                                                                                                    fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");


    // Start the test
    rc = zcash.bls12_381_set_curr_inst_slot(1);
    fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

    // Wait for interrupts
    // Try read reply - should be our scalar value

    timeout = 0;
    read_len = 0;
    memset(reply, 0, 512);
    while ((read_len = zfpga.read_stream(reply, 256)) == 0) {
      usleep(1);
      timeout++;
      if (timeout > 1000) {
        printf("ERROR: No reply received, timeout\n");
        break;
      }
    }

    printf("Received data: 0x");
    for (int i = read_len-1; i>=0; i--) printf("%x", reply[i]);
    printf("\n");

    // Try read second reply - should be point value - 6 slots
    memset(reply, 0, 512);
    timeout = 0;
    read_len = 0;
    while ((read_len = zfpga.read_stream(reply, 512)) == 0) {
      usleep(1);
      timeout++;
      if (timeout > 1000) {
        printf("ERROR: No reply received, timeout\n");
        break;
      }
    }

    printf("Received data: 0x");
    for (int i = read_len-1; i>=0; i--) printf("%x", reply[i]);
    printf("\n");

    // Read current instruction
    rc = zfpga.bls12_381_get_curr_inst_slot(slot_id);
    fail_on(rc, out, "ERROR: Unable to write to FPGA!\n");

    printf("Data slot is now %d\n", slot_id);

    // Print out data slots
    for(int i = 0; i < 10; i++) {
      zfpga.bls12_381_get_data_slot(i, data);
      printf("slot %d, pt: %d, data:0x", i, data.point_type);
      for(int j = 47; j >= 0; j--) printf("%02x", data.dat[j]);
      printf("\n");
    }


    return rc;
out:
    return 1;
}

