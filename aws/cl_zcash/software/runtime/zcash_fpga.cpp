#include "zcash_fpga.hpp"

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

#include <fpga_pci.h>

zcash_fpga& zcash_fpga::get_instance() {
  static zcash_fpga instance;
  return instance;
}

int zcash_fpga::init_fpga(int slot_id) {
  // Initialize the FPGA
  if (initialized) {
    printf("INFO: FPGA already initialized, skipping initialization");
    return 0;
  }

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

  // Check if we have AXI4 mode enabled or not
  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET+0x44ULL, &rdata); //RDFO
  fail_on(rc, out, "Unable to write to FPGA!");
  AXI4_enabled = (1 << 31) & rdata;
  if (AXI4_enabled)
    printf("INFO: AXI4 mode is set ENABLED\n");
  else
    printf("INFO: AXI4 mode is set DISABLED\n");

  printf("INFO: Finished initializing FPGA.\n");
  initialized = true;

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

int zcash_fpga::check_afi_ready(int slot_id) {
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

int zcash_fpga::get_status(fpga_status_rpl_t& status_rpl) {
  // Test: send status message
  int rc;
  unsigned int timeout = 0;
  unsigned int read_len = 0;
  
  header_t hdr;
  hdr.cmd = FPGA_STATUS;
  hdr.len = 8;
  rc = write_stream((uint8_t*)&hdr, sizeof(hdr));
  fail_on(rc, out, "Unable to read from FPGA!");

  // Try read reply
  uint8_t reply[256];
  while ((read_len = read_stream(reply, 256)) == 0) {
    usleep(1);
    timeout++;
    if (timeout > 1000) {
      printf("ERROR: No reply received, timeout\n");
      rc = 1;
      goto out;
    }
  }
  
  status_rpl = *(fpga_status_rpl_t*)reply;
  printf("INFO: Received FPGA reply, FPGA version: 0x%x", status_rpl.version); // TODO print more


  return rc;
out:
  return 1;
}

int zcash_fpga::write_stream(uint8_t* data, unsigned int len) {
  int rc;
  uint32_t rdata;
  unsigned int len_send = 0;

  if (~initialized) {
    printf("INFO: FPGA not initialized!");
    goto out;
  }


  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET + 0xCULL, &rdata);
  fail_on(rc, out, "Unable to read from FPGA!");
  if (len > rdata) {
    printf("ERROR: write_stream does not have enough space to write %d bytes! (%d free)\n", len, rdata);
    goto out;
  }


  while(len_send < len) {
    if (AXI4_enabled) {
      fpga_pci_poke64(pci_bar_handle_bar4, 0, *(uint64_t*)(&data[len_send]));
      len_send += 8;
    } else {
      rc = fpga_pci_poke(pci_bar_handle_bar0, AXI_FIFO_OFFSET+0x10ULL, *(uint32_t*)(&data[len_send])); // Reset ISR
      fail_on(rc, out, "Unable to write to FPGA!");
      len_send += 4;
    }
  }

  rc = fpga_pci_poke(pci_bar_handle_bar0, AXI_FIFO_OFFSET+0x14ULL, len); // Reset ISR
  fail_on(rc, out, "Unable to write to FPGA!");


  printf("INFO: write_stream::Wrote %d bytes of data\n", len);

  // Check transmit complete bit and reset it
  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET, &rdata);
  fail_on(rc, out, "Unable to read from FPGA!");
  if ((rdata & (1 << 27)) == 0) {
    printf("WARNING: write_stream transmit bit not set, register returned 0x%x\n", rdata);
  }

  rc = fpga_pci_poke(pci_bar_handle_bar0, AXI_FIFO_OFFSET, 0x08000000); // Reset ISR
  fail_on(rc, out, "Unable to write to FPGA!");

  return rc;
  out:
    return 1;
}

int zcash_fpga::read_stream(uint8_t* data, unsigned int size) {

  uint32_t rdata;
  unsigned int read_len = 0;
  int rc;

  if (~initialized) {
    printf("INFO: FPGA not initialized!");
    goto out;
  }


  rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET, &rdata);
  fail_on(rc, out, "Unable to read from FPGA!");
  if ((rdata & (1 << 26)) == 0) return 0;  // Nothing to read

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
  printf("INFO: Read FIFO shows %d waiting to be read from FPGA\n", rdata);

  if (size < rdata) {
    printf("ERROR: Size of buffer (%d bytes) not big enough to read data!\n", size);
    return 0;
  }

  while(read_len < rdata) {
    if (AXI4_enabled) {
      rc = fpga_pci_peek(pci_bar_handle_bar4, 0x1000, (uint32_t*)(&data[read_len]));
      fail_on(rc, out, "Unable to read from FPGA PCIS!");
      read_len += 8;
    } else {
      rc = fpga_pci_peek(pci_bar_handle_bar0, AXI_FIFO_OFFSET + 0x20ULL, (uint32_t*)(&data[read_len]));
      fail_on(rc, out, "Unable to read from FPGA!");
      read_len += 4;
    }
  }

  printf("INFO: Read %d bytes from read_stream()\n", read_len);

  return read_len;
  out:
    return -1;
}

int zcash_fpga::bls12_381_write_data_slot(unsigned int id, bls12_381_slot_t slot_data) {
  char data[48];
  int rc = 0;
  if (~initialized) {
    printf("INFO: FPGA not initialized!");
    goto out;
  }

  *(bls12_381_slot_t*)data = slot_data;
  // Set the top 3 bits to the point type
  data[47] &= 0x1F;
  data[47] |= (slot_data.point_type << 5);

  for(int i = 0; i < 48/4; i=i+4) {
    rc = fpga_pci_poke(pci_bar_handle_bar0, BLS12_381_OFFSET + BLS12_381_DATA_OFFSET + id*64 + i, *((uint32_t*)&data[i]));
    fail_on(rc, out, "Unable to write to FPGA!");
  }
  return 0;
  out:
    return rc;
}

int zcash_fpga::bls12_381_read_data_slot(unsigned int id, bls12_381_slot_t& slot_data) {
  int rc = 0;
  if (~initialized) {
    printf("INFO: FPGA not initialized!");
    goto out;
  }

  for(int i = 0; i < 48/4; i=i+4) {
    rc = fpga_pci_peek(pci_bar_handle_bar0, BLS12_381_OFFSET + BLS12_381_DATA_OFFSET + id*64 + i, (uint32_t*)(&slot_data));
    fail_on(rc, out, "Unable to read from FPGA!");
  }

  slot_data.point_type = (point_type_t)(*((uint8_t*)&slot_data + 47) >> 5);
  // Clear top 3 bits
  *((char*)&slot_data + 47) &= 0x1F;

  return 0;
  out:
    return rc;
}
