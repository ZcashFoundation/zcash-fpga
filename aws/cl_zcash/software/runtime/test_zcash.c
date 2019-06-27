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

#define _BSD_SOURCE

#define AXI_FIFO_OFFSET UINT64_C(0x0)
#define ZCASH_OFFSET    UINT64_C(0x1000)

/* use the stdout logger for printing debug information  */

const struct logger *logger = &logger_stdout;
/*
 * pci_vendor_id and pci_device_id values below are Amazon's and avaliable to use for a given FPGA slot.
 * Users may replace these with their own if allocated to them by PCI SIG
 */
static uint16_t pci_vendor_id = 0x1D0F; /* Amazon PCI Vendor ID */
static uint16_t pci_device_id = 0xF000; /* PCI Device ID preassigned by Amazon for F1 applications */


pci_bar_handle_t pci_bar_handle_bar0 = PCI_BAR_HANDLE_INIT;
pci_bar_handle_t pci_bar_handle_bar4 = PCI_BAR_HANDLE_INIT;


/*
 * check if the corresponding AFI for hello_world is loaded
 */
int check_afi_ready(int slot_id);

/*
 * Initialize the FPGA
 */
int init(int slot_id);

/*
 * Read / Write to the FPGA stream interface
 */
int read_stream(uint8_t* data, unsigned int size);  // Size is the buffer size being passed
int write_stream(uint8_t* data, unsigned int len);

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

    // Initialize all the FPGA connections
    rc = init(slot_id);
    fail_on(rc, out, "Unable to initialize the FPGA");

    // Test: read from register in BLS core
    uint32_t rdata;
    rc = fpga_pci_peek(pci_bar_handle_bar0, ZCASH_OFFSET, &rdata);
    fail_on(rc, out, "Unable to read from FPGA!");
    printf("INFO: Read 0x%x from address 0", rdata);


    // Test: send status message
    uint8_t message[8];
    memset(message, 0, 8);
    message[0] = 8;
    message[4] = 1;
    rc = write_stream(message, sizeof(message));
    fail_on(rc, out, "Unable to read from FPGA!");

    // Try read reply
    uint8_t reply[256];
    int timeout = 0;
    unsigned int read_len = 0;
    while ((read_len = read_stream(reply, 256)) == 0) {
      usleep(10);
      timeout++;
      if (timeout > 1000) {
        printf("ERROR: No reply received, timeout\n");
        rc = 1;
        goto out;
      }
    }


    printf("Reply received of %d bytes:0x", read_len);
    int i;
    for (i = 0; i < read_len; i++)
      printf("%x", reply[i]);
    printf("\n");


    return rc;
out:
    return 1;
}

int write_stream(uint8_t* data, unsigned int len);
  int rc;
  uint32_t rdata;
  unsigned int len_send = 0;

  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET + 0xCULL, &rdata);
  fail_on(rc, out, "Unable to read from FPGA!");
  if (len > rdata) {
    printf("ERROR: write_stream does not have enough space to write %d bytes! (%d free)\n", len, rdata);
    goto out;
  }


  while(len_send < len) {
    fpga_pci_poke64(pci_bar_handle_bar4, 0, *(uint64_t*)(&data[len_send]));
    len_send += 8;
  }

  rc = fpga_pci_poke(pci_bar_handle_bar0, AXI_FIFO_OFFSET+0x14ULL, len); // Reset ISR
  fail_on(rc, out, "Unable to write to FPGA!");


  printf("INFO: write_stream::Wrote %d bytes of data", len);

  // Check transmit complete bit and reset it
  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET, &rdata);
  fail_on(rc, out, "Unable to read from FPGA!");
  if (rdata & (1 << 27) == 0) {
    printf("WARNING: write_stream transmit bit not set, register returned 0x%x\n", rdata);
  }

  rc = fpga_pci_poke(pci_bar_handle_bar0, AXI_FIFO_OFFSET, 0x08000000); // Reset ISR
  fail_on(rc, out, "Unable to write to FPGA!");

  return rc;
  out:
    return 1;
}

int read_stream(uint8_t* data, unsigned int size);

  uint32_t rdata;
  int read_len = 0;

  if (size == 0) {
    printf("WARNING: Size was 0, cannot read into empty buffer!\n");
    return 0;
  }

  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET, &rdata);
  fail_on(rc, out, "Unable to read from FPGA!");
  if (rdata & (1 << 26) == 0) return 0;  // Nothing to read

  rc = fpga_pci_poke(pci_bar_handle_bar0, AXI_FIFO_OFFSET, 0x04000000); // clear ISR
  fail_on(rc, out, "Unable to write to FPGA!");

  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET + 0x1CULL, &rdata);  //RDFO should be non-zero (slots used in FIFO)
  fail_on(rc, out, "Unable to read from FPGA!");
  if (rdata == 0) {
    printf("WARNING: Read FIFO shows data but length was 0!\n");
    return 0;
  }

  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET + 0x24ULL, &rdata);  //RLR - length of packet in bytes
  fail_on(rc, out, "Unable to read from FPGA!");

  while(rdata > 0 && size >= read_len+8) {
    rc = fpga_pci_peek64(pci_bar_handle_bar4, 0, (uint64_t*)(&data[read_len]));
    fail_on(rc, out, "Unable to read from FPGA PCIS!");
    read_len += 8;
  }

  printf("INFO: Read %d bytes from read_stream()\n", read_len);

  return read_len;
  out:
    return -1;
}

int init(int slot_id) {
  int rc;
  uint32_t rdata;

  /* initialize the fpga_pci library so we could have access to FPGA PCIe from this applications */
  rc = fpga_pci_init();
  fail_on(rc, out, "Unable to initialize the fpga_pci library");

  rc = check_afi_ready(slot_id);
  fail_on(rc, out, "AFI not ready");

  // We need to attach to the FPGA BAR0 (OCL) and BAR4 (PCIS)
  rc = fpga_pci_attach(slot_id, FPGA_APP_PF, APP_PF_BAR0, 0, &pci_bar_handle_bar0);
  fail_on(rc, out, "Unable to attach to the AFI BAR0 on slot id %d", slot_id);

  rc = fpga_pci_attach(slot_id, FPGA_APP_PF, APP_PF_BAR4, BURST_CAPABLE, &pci_bar_handle_bar4);
  fail_on(rc, out, "Unable to attach to the AFI BAR4 on slot id %d", slot_id);

  // Now setup the streaming interface

  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET, &rdata); //ISR
  fail_on(rc, out, "Unable to read from FPGA!");
  printf("INFO: Read 0x%x from ISR register.\n", rdata);
  if (rdata != 0x01D00000) {
    printf("WARNING: Expected 0x01D00000.\n");
  }

  rc = fpga_pci_poke(pci_bar_handle_bar0, AXI_FIFO_OFFSET, 0xFFFFFFFF); // Reset ISR
  fail_on(rc, out, "Unable to write to FPGA!");

  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET+0xCULL, &rdata); //TDFV
  fail_on(rc, out, "Unable to read from FPGA!");
  printf("INFO: Read 0x%x from TDFV register.\n", rdata);
  if (rdata != 0x000001FC) {
    printf("WARNING: Expected 0x000001FC.\n");
  }

  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET+0x1CULL, &rdata); //RDFO
  fail_on(rc, out, "Unable to read from FPGA!");
  printf("INFO: Read 0x%x from RDFO register.\n", rdata);
  if (rdata != 0x00000000) {
    printf("WARNING: Expected 0x00000000.\n");
  }

  rc = fpga_pci_poke(pci_bar_handle_bar0, AXI_FIFO_OFFSET+0x4ULL, 0x0C000000); // Clear IER
  fail_on(rc, out, "Unable to write to FPGA!");

  printf("INFO: Finished initializing FPGA.\n");

  return rc;
  out:
    /* clean up */
    if (pci_bar_handle_bar0 >= 0) {
      rc = fpga_pci_detach(pci_bar_handle_bar0);
      if (rc) printf("Failure while detaching bar0 from the fpga.\n");
    }
    if (pci_bar_handle_bar4 >= 0) {
      rc = fpga_pci_detach(pci_bar_handle_bar4);
      if (rc) printf("Failure while detaching bar4 from the fpga.\n");
    }
    return 1;
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


