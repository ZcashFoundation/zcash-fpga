#include zcash_fpga.h

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
