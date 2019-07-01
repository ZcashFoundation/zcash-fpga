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

    int slot_id = 0;
    int rc;
    uint32_t value = 0;

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

    // Get FPGA status
    zcash_fpga::fpga_status_rpl_t status_rpl;
    rc = zfpga.get_status(status_rpl);
    fail_on(rc, out, "Unable toget FPGA status!");

    // Read and write a data slot in BLS12_381
    zcash_fpga::bls12_381_slot_t data_slot;
    rc = zfpga.bls12_381_read_data_slot(0, data_slot);
    printf("Data slot type was: %i, data is 0x", data_slot.point_type);
    for (int i = 47; i >= 0; i--)
      printf("%x", data_slot.dat[i]);
    printf("\n");

    printf("Writing to data slot...\n");
    data_slot.point_type = zcash_fpga::FE;
    memset(&data_slot.dat, 0x0a, 48);
    rc = zfpga.bls12_381_read_data_slot(0, data_slot);

    rc = zfpga.bls12_381_read_data_slot(0, data_slot);
    printf("Data slot type was: %i, data is 0x", data_slot.point_type);
    for (int i = 47; i >= 0; i--)
      printf("%x", data_slot.dat[i]);
    printf("\n");

    return rc;
out:
    return 1;
}
