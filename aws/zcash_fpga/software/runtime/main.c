// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.

// Test program for the zcash FPGA on AWS

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>

#include <fpga_pci.h>
#include <fpga_mgmt.h>
#include <utils/lcd.h>


#include <utils/sh_dpi_tasks.h>

/* Constants determined by the CL */
/* a set of register offsets; this CL has only one */
/* these register addresses should match the addresses in */
/* /aws-fpga/hdk/cl/examples/common/cl_common_defines.vh */
/* SV_TEST macro should be set if SW/HW co-simulation should be enabled */

#define HELLO_WORLD_REG_ADDR UINT64_C(0x500)
#define VLED_REG_ADDR	UINT64_C(0x504)
#define CL_SDE_CONFIG UINT64_C(0x2000)

/* use the stdout logger for printing debug information  */

const struct logger *logger = &logger_stdout;
/*
 * pci_vendor_id and pci_device_id values below are Amazon's and avaliable to use for a given FPGA slot.
 * Users may replace these with their own if allocated to them by PCI SIG
 */
static uint16_t pci_vendor_id = 0x1D0F; /* Amazon PCI Vendor ID */
static uint16_t pci_device_id = 0xF002; /* PCI Device ID preassigned by Amazon for F1 applications */

/*
 * check if the corresponding AFI for hello_world is loaded
 */
int check_afi_ready(int slot_id);
/*
 * An example to attach to an arbitrary slot, pf, and bar with register access.
 */
int peek_poke_example(uint32_t value, int slot_id, int pf_id, int bar_id);

int peek_register(uint64_t addr, &value, uint32_t int slot_id);

void usage(char* program_name) {
    printf("usage: %s [--slot <slot-id>][<poke-value>]\n", program_name);
}

uint32_t byte_swap(uint32_t value);

int test_dma();

uint32_t byte_swap(uint32_t value) {
    uint32_t swapped_value = 0;
    int b;
    for (b = 0; b < 4; b++) {
        swapped_value |= ((value >> (b * 8)) & 0xff) << (8 * (3-b));
    }
    return swapped_value;
}


int main(int argc, char **argv) {

    uint32_t value = 0xefbeadde;
    int slot_id = 0;
    int rc;

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

    /* initialize the fpga_pci library so we could have access to FPGA PCIe from this applications */
    rc = fpga_pci_init();
    fail_on(rc, out, "Unable to initialize the fpga_pci library");

    rc = check_afi_ready(slot_id);
    fail_on(rc, out, "AFI not ready");

    /* Accessing the CL registers via AppPF BAR0, which maps to sh_cl_ocl_ AXI-Lite bus between AWS FPGA Shell and the CL*/

    printf("===== Starting with peek_poke_example =====\n");
    //rc = peek_poke_example(value, slot_id, FPGA_APP_PF, APP_PF_BAR0);
    rc = peek_register(CL_SDE_CONFIG, &value, slot_id);
    fail_on(rc, out, "peek-poke example failed");


    return rc;
}

 int check_afi_ready(int slot_id) {
   struct fpga_mgmt_image_info info = {0};
   int rc;

   /* get local image description, contains status, vendor id, and device id. */
   rc = fpga_mgmt_describe_local_image(slot_id, &info,0);
   fail_on(rc, out, "Unable to get AFI information from slot %d. Are you running as root?",slot_id);

   /* check to see if the slot is ready */
   if (info.status != FPGA_STATUS_LOADED) {
     rc = 1;
     fail_on(rc, out, "AFI in Slot %d is not in READY state !", slot_id);
   }

   printf("AFI PCI  Vendor ID: 0x%x, Device ID 0x%x\n",
          info.spec.map[FPGA_APP_PF].vendor_id,
          info.spec.map[FPGA_APP_PF].device_id);

   /* confirm that the AFI that we expect is in fact loaded */
   if (info.spec.map[FPGA_APP_PF].vendor_id != pci_vendor_id ||
       info.spec.map[FPGA_APP_PF].device_id != pci_device_id) {
     printf("AFI does not show expected PCI vendor id and device ID. If the AFI "
            "was just loaded, it might need a rescan. Rescanning now.\n");

     rc = fpga_pci_rescan_slot_app_pfs(slot_id);
     fail_on(rc, out, "Unable to update PF for slot %d",slot_id);
     /* get local image description, contains status, vendor id, and device id. */
     rc = fpga_mgmt_describe_local_image(slot_id, &info,0);
     fail_on(rc, out, "Unable to get AFI information from slot %d",slot_id);

     printf("AFI PCI  Vendor ID: 0x%x, Device ID 0x%x\n",
            info.spec.map[FPGA_APP_PF].vendor_id,
            info.spec.map[FPGA_APP_PF].device_id);

     /* confirm that the AFI that we expect is in fact loaded after rescan */
     if (info.spec.map[FPGA_APP_PF].vendor_id != pci_vendor_id ||
         info.spec.map[FPGA_APP_PF].device_id != pci_device_id) {
       rc = 1;
       fail_on(rc, out, "The PCI vendor id and device of the loaded AFI are not "
               "the expected values.");
     }
   }

   return rc;
 out:
   return 1;
 }

int peek_register(uint64_t addr, &value, uint32_t int slot_id) {
  int rc;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
  rc = fpga_pci_attach(slot_id, FPGA_APP_PF, APP_PF_BAR0, 0, &pci_bar_handle);
  fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);

  rc = fpga_pci_peek(pci_bar_handle, addr, value);
  fail_on(rc, out, "Unable to read read from the fpga !");

  printf("register: 0x%x\n", *value);

  /* if there is an error code, exit with status 1 */
  return (rc != 0 ? 1 : 0);
}

/*
 * An example to attach to an arbitrary slot, pf, and bar with register access.
 */
int peek_poke_example(uint32_t value, int slot_id, int pf_id, int bar_id) {
    int rc;
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */

    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */

    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);


    /* write a value into the mapped address space */

    printf("Writing 0x%08x to HELLO_WORLD register (0x%016lx)\n", value, HELLO_WORLD_REG_ADDR);
    rc = fpga_pci_poke(pci_bar_handle, HELLO_WORLD_REG_ADDR, value);

    fail_on(rc, out, "Unable to write to the fpga !");

    /* read it back and print it out; you should expect the byte order to be
     * reversed (That's what this CL does) */
    rc = fpga_pci_peek(pci_bar_handle, HELLO_WORLD_REG_ADDR, &value);
    fail_on(rc, out, "Unable to read read from the fpga !");

    printf("register: 0x%x\n", value);

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

//////////////////////////////////////
// Test xdma
//////////////////////////////////////

#define BUF_SIZE              256
#define OFFSET_IN_FPGA_DRAM   0x10000000

static char *rand_str(char *str, size_t size)  // randomize a string of size <size>
{
    const char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRTSUVWXYZ1234567890";
    int i;

    for(i = 0; i < size; i++) {
        int key = rand() % (int) (sizeof charset - 1);
        str[i] = charset[key];
    }

    str[size-1] = '\0';
    return str;
}


int test_dma()
{
    char* srcBuf;
    char* dstBuf;
    int read_fd;
    int write_fd;
    int i;
    int ret;

    srcBuf = (char*)malloc(BUF_SIZE * sizeof(char));
    dstBuf = (char*)malloc(BUF_SIZE * sizeof(char));

    /* Initialize srcBuf */
    rand_str(srcBuf, BUF_SIZE);

    /* Open a XDMA write channel (Host to Core) */
    if ((write_fd = open("/dev/xdma0_h2c_0",O_WRONLY)) == -1) {
        perror("open failed with errno");
    }

    /* Open a XDMA read channel (Core to Host) */
    if ((read_fd = open("/dev/xdma0_c2h_0",O_RDONLY)) == -1) {
        perror("open failed with errno");
    }

    /* Write the entire source buffer to offset OFFSET_IN_FPGA_DRAM */
    ret = pwrite(write_fd , srcBuf, BUF_SIZE, OFFSET_IN_FPGA_DRAM);
    if (ret < 0) {
        perror("write failed with errno");
    }

    printf("Tried to write %u bytes, succeeded in writing %u bytes\n", BUF_SIZE, ret);

    ret = pread(read_fd, dstBuf, BUF_SIZE, OFFSET_IN_FPGA_DRAM);
    if (ret < 0) {
        perror("read failed with errno");
    }

    printf("Tried reading %u byte, succeeded in read %u bytes\n", BUF_SIZE, ret);

    if (close(write_fd) < 0) {
        perror("write_fd close failed with errno");
    }
    if (close(read_fd) < 0) {
        perror("read_fd close failed with errno");
    }

    printf("Data read is %s\n", dstBuf);

    return 0;
}
