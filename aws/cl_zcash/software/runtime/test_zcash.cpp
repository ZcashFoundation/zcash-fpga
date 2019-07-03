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

    inst.code = zcash_fpga::FP2_FPOINT_MULT;
    inst.a = 0;
    inst.b = 1;
    rc = zfpga.bls12_381_set_inst_slot(0, inst);   // This will start the coprocessor
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
        rc = 1;
        goto out;
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
        rc = 1;
        goto out;
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

