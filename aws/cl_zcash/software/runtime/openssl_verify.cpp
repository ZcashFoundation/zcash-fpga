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

#include "./zcash_fpga.hpp"
#include "./ossl.h"

#include <openssl/ecdsa.h>
#include <openssl/sha.h>
#include <openssl/bn.h>

#define MAX_TEST_ITER 10000


int main(int argc, char *argv[]) {

    //unsigned int slot_id = 0;
    int rc;
    //uint32_t value = 0;
    unsigned int timeout = 0;
    unsigned int read_len = 0;
    uint8_t reply[640];
    uint32_t failed = 0;
    bool verb=false;
    //uint32_t iter=100;
    // Process command line args 
  if (argc != 3) {
    std::cout << "Usage: " << argv[0] << " <TV number> <Verbose:t|f> \n";
    printf ("TV number: any number between 1 and %d\n",MAX_TEST_ITER);
    printf ("Verbose: t=ture f=false, control debug infor output (signature etc..) \n");

    return 1;
  }
  char* argv1_ptr;
  uint32_t iter = strtoul(argv[1], &argv1_ptr, 10);
  if (*argv1_ptr != '\0') {
      return 1;
      }
  if (iter < 1 || iter > MAX_TEST_ITER) {
	  printf ("[ERROR]: Incorrect num of TV input, should be between [%d-%d]\n",1,MAX_TEST_ITER);
      return 1;
      }
 
  if ((strcmp(argv[2], "t")!= 0) && (strcmp(argv[2], "f")!= 0) ) {
	  std::cout <<argv[2] <<"\n";
	printf("[Error]: Wrong mode switch, shall be either t or f\n");
  	return 1;
  }
   verb= ( (strcmp(argv[2], "t")== 0)? true:false);

    zcash_fpga& zfpga = zcash_fpga::get_instance();

    // Test the secp256k1 core

    if ((zfpga.m_command_cap & zcash_fpga::ENB_VERIFY_SECP256K1_SIG) != 0) {
      printf("INFO: Testing secp256k1 core...\n");
      const unsigned int index_int=0xa;

      for (unsigned int tv_ind=0; tv_ind<iter; tv_ind++) {
      std::cout<<"Openssl to generate a dynamic TV #" << tv_ind <<"\n";
      printf("\n******************************************************************\n");
      printf("******                Iteration #%3d of %3d                 ******\n",tv_ind+1,iter);
      printf("******************************************************************\n");

      zcash_fpga::verify_secp256k1_sig_t verify_secp256k1_sig;
      memset(&verify_secp256k1_sig, 0, sizeof(zcash_fpga::verify_secp256k1_sig_t));
      verify_secp256k1_sig.hdr.cmd = zcash_fpga::VERIFY_SECP256K1_SIG;
      verify_secp256k1_sig.hdr.len = sizeof(zcash_fpga::verify_secp256k1_sig_t);
      verify_secp256k1_sig.index = index_int+tv_ind;

      Signature_t sig;
      sig=sig_ossl(verb);
      
      //in case the Big_little Endian convert are needed.
      
      unsigned char *p_dig  =(unsigned char*) &(sig.hash);
      //unsigned char *p_sig_r=(unsigned char*) &(sig.r);
      //unsigned char *p_sig_s=(unsigned char*) &(sig.s);
      //unsigned char *p_pk_qx=(unsigned char*) &(sig.Qx);
      //unsigned char *p_pk_qy=(unsigned char*) &(sig.Qy);
      std::reverse (p_dig,   p_dig+sizeof(sig.hash));
      //std::reverse (p_sig_r, p_sig_r+sizeof(sig.r));
      //std::reverse (p_sig_s, p_sig_s+sizeof(sig.s));
      //std::reverse (p_pk_qx, p_pk_qx+sizeof(sig.Qx));
      //std::reverse (p_pk_qy, p_pk_qy+sizeof(sig.Qy));

      for (int i=0; i<4 ;i++) {
		verify_secp256k1_sig.hash[i]=sig.hash[i];
                verify_secp256k1_sig.r[i]=sig.r[i];
                verify_secp256k1_sig.s[i]=sig.s[i];
                verify_secp256k1_sig.Qx[i]=sig.Qx[i];
                verify_secp256k1_sig.Qy[i]=sig.Qy[i];
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
          printf("ERROR: No reply received, timeout\n");
          failed = true;
          break;
        }
      }

      zcash_fpga::verify_secp256k1_sig_rpl_t verify_secp256k1_sig_rpl;
      verify_secp256k1_sig_rpl = *(zcash_fpga::verify_secp256k1_sig_rpl_t*)reply;
      /*
      printf("[INFO]:  hdr.cmd  = 0x%x\n", verify_secp256k1_sig_rpl.hdr.cmd);
      printf("[INFO]: .bm       = 0x%x\n", verify_secp256k1_sig_rpl.bm);
      printf("[INFO]: .index    = 0x%lx, \t expect 0x%x\n", verify_secp256k1_sig_rpl.index,index_int+tv_ind);
      printf("[INFO]: .cycle_cnt= 0x%x\n", verify_secp256k1_sig_rpl.cycle_cnt);
      */
      if (verify_secp256k1_sig_rpl.hdr.cmd != zcash_fpga::VERIFY_SECP256K1_SIG_RPL) {
          printf("[ERROR]: Header type was wrong for test vector#%d!\n",tv_ind);
          failed++;
	  continue;
      }
      if (verify_secp256k1_sig_rpl.bm != 0) {
          printf("[ERROR]: Signature verification failed for test vector #%d!\n",tv_ind);
	  printf("[INFO]:  hdr.cmd  = 0x%x\n", verify_secp256k1_sig_rpl.hdr.cmd);
      	  printf("[INFO]: .bm       = 0x%x\n", verify_secp256k1_sig_rpl.bm);
      	  printf("[INFO]: .index    = 0x%lx, \t expect 0x%x\n", verify_secp256k1_sig_rpl.index,index_int+tv_ind);
      	  printf("[INFO]: .cycle_cnt= 0x%x\n", verify_secp256k1_sig_rpl.cycle_cnt);
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
printf("Total [%d] round test, failed [%d]\n", iter, failed);
 out:
    return 1;
}
