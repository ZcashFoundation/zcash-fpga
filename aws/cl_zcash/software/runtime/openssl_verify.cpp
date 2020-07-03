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

#include <openssl/ecdsa.h>
#include <openssl/sha.h>
#include <openssl/bn.h>

#define NID 714   //using NID_secp256k1:714

#define SIG_SIZE 64
#define PUB_KEY_SIZE 64
#define DIG_SIZE 32
#define PRIV_KEY_SIZE 32

typedef struct __attribute__((__packed__)) {
    uint64_t s[4];
    uint64_t r[4];
    uint64_t hash[4];
    uint64_t Qx[4];
    uint64_t Qy[4];
} Signature_t;

/* use the stdout logger for printing debug information  */

const struct logger *logger = &logger_stdout;
/*
 * check if the corresponding AFI for hello_world is loaded
 */
//int check_afi_ready(int slot_id); //I think this is not necessary as it is already override..


void usage(char* program_name) {
    printf("usage: %s [--slot <slot-id>][<poke-value>]\n", program_name);
}

void char_array_display (const char* char_ptr, int size, const char* msg) {
    for(int i = 0; i < size; i++)
    std::cout  << std::setw(1) << std::setfill('0') << static_cast<char>(tolower(*(char_ptr+i)));
    std::cout  << "  //" << msg <<   std::endl;
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


std::vector<uint8_t> Hash256(const std::string &str) {
  SHA256_CTX ctx;
  SHA256_Init(&ctx);
  SHA256_Update(&ctx, str.c_str(), str.size());
  std::vector<uint8_t> md(SHA256_DIGEST_LENGTH);
  SHA256_Final(md.data(), &ctx);
  return md;
}


Signature_t sig_ossl (bool verb)	{	//verb=true, print more info.
	Signature_t sig_ret;
	memset(&sig_ret, 0, sizeof(Signature_t));
	//std::string mesg_string = "aaa";
	std::string mesg_string = "I am a fish";
	std::vector<uint8_t> Digest (DIG_SIZE, 0);
	Digest=Hash256(mesg_string);

	//fill sig_ret.hash.
	unsigned char* p_hash = (unsigned char *)sig_ret.hash;
	int i=0;
	for	(std::vector<unsigned char>::iterator iter = Digest.begin(); iter != Digest.end(); ++iter)
	{	*(p_hash+i) =*iter; i++;	}	

	//EC_KEY OBJ create
	EC_KEY *ec_key = EC_KEY_new();
	if (ec_key == NULL)  perror("Error for creating ECC key object ");
	EC_GROUP *ec_group = EC_GROUP_new_by_curve_name(NID);   //NID_secp256k1:714
	EC_KEY_set_group(ec_key, ec_group);
	if (!EC_KEY_generate_key(ec_key))	perror("Error for creating ECC key pair");
	
	//get private key and pub key (Qx, Qy)
	const EC_POINT *pub     = EC_KEY_get0_public_key (ec_key);
	const BIGNUM *PRIV  	= EC_KEY_get0_private_key(ec_key);
	BIGNUM *QX = BN_new();
	BIGNUM *QY = BN_new();
	//Gets the affine coordinates of an EC_POINT.
	if (!(EC_POINT_get_affine_coordinates(ec_group, pub, QX, QY, NULL))) 
		perror("Error for creating ECC pub key");
	if (verb)	{
		printf("Pub key gen OK:\n");
		std::cout << "QX      : ";
		BN_print_fp(stdout, QX);
		putc('\n', stdout);
		std::cout << "QY      : ";
		BN_print_fp(stdout, QY);
		putc('\n', stdout);
		std::cout << "Priv key: ";
		BN_print_fp(stdout, PRIV);
		std::cout <<"\n--------------------------------\n";
	}	
	//generate signature
	ECDSA_SIG *signature;
	unsigned char *dig_ptr=Digest.data();
	signature = ECDSA_do_sign(dig_ptr, SHA256_DIGEST_LENGTH, ec_key);
		if (signature == NULL)	perror("ECDSA_SIG generation fail");

	//verify signature
	if (!(ECDSA_do_verify(dig_ptr, SHA256_DIGEST_LENGTH, signature, ec_key)))
		perror("Openssl generated signature verify FAILED");
	
	//Obtain R and S
	const BIGNUM *PR = BN_new();
	const BIGNUM *PS = BN_new();
	ECDSA_SIG_get0(signature, &PR, &PS);

	//convert BN to generate TV
	char* qx    	= BN_bn2hex(QX);
	char* qy    	= BN_bn2hex(QY);
	char* sig_r	= BN_bn2hex(PR);
	char* sig_s 	= BN_bn2hex(PS);
	char* priv_key  = BN_bn2hex(PRIV);	//private key needed for debugging
	
	std::string sig_r_str=sig_r;
	std::string sig_s_str=sig_s;
	std::string qx_str=qx;
	std::string qy_str=qy;

	string_to_hex(sig_r,  (unsigned char *)sig_ret.r);
        string_to_hex(sig_s,  (unsigned char *)sig_ret.s);
        string_to_hex(qx_str, (unsigned char *)sig_ret.Qx);
        string_to_hex(qy_str, (unsigned char *)sig_ret.Qy);
        
	if (verb)	{
	for (int i=0; i<DIG_SIZE; i++)	printf("%02x", *(dig_ptr+i));
	std::cout <<"  //digest\n";
	char_array_display (sig_r,SIG_SIZE,"sig.r");
	char_array_display (sig_s,SIG_SIZE,"sig.s");
	char_array_display (qx,   PUB_KEY_SIZE,"QX");
	char_array_display (qy,   PUB_KEY_SIZE,"QY");
	printf("--------------------------------------------------\n");
	char_array_display (priv_key,64,"PRIV");
	}

	//free memory
	OPENSSL_free(qx);
	OPENSSL_free(qy);
	OPENSSL_free(sig_r);
	OPENSSL_free(sig_s);

	ECDSA_SIG_free(signature);
	EC_GROUP_free(ec_group);
	EC_KEY_free(ec_key);
	
	qx    = nullptr;
	qy    = nullptr;
	sig_r = nullptr;
	sig_s = nullptr;
	signature = nullptr;
	ec_group  =	nullptr;
	ec_key	  = nullptr;

	BN_free(QX);
	BN_free(QY);

return sig_ret;
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
    uint32_t iter=100;

    if ((zfpga.m_command_cap & zcash_fpga::ENB_VERIFY_SECP256K1_SIG) != 0) {
      printf("INFO: Testing secp256k1 core...\n");
      const unsigned int index_int=0xa;

      for (unsigned int tv_ind=0; tv_ind<iter; tv_ind++) {
      std::cout<<"Openssl to generate a dynamic TV #" << tv_ind <<"\n";
      zcash_fpga::verify_secp256k1_sig_t verify_secp256k1_sig;
      memset(&verify_secp256k1_sig, 0, sizeof(zcash_fpga::verify_secp256k1_sig_t));
      verify_secp256k1_sig.hdr.cmd = zcash_fpga::VERIFY_SECP256K1_SIG;
      verify_secp256k1_sig.hdr.len = sizeof(zcash_fpga::verify_secp256k1_sig_t);
      verify_secp256k1_sig.index = index_int+tv_ind;

      Signature_t sig;
      sig=sig_ossl(true);
      unsigned char *p_dig  =(unsigned char*) &(sig.hash);
      unsigned char *p_sig_r=(unsigned char*) &(sig.r);
      unsigned char *p_sig_s=(unsigned char*) &(sig.s);
      unsigned char *p_pk_qx=(unsigned char*) &(sig.Qx);
      unsigned char *p_pk_qy=(unsigned char*) &(sig.Qy);

      	//std::reverse (p_dig,   p_dig+sizeof(sig.hash));
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
      printf("INFO: verify_secp256k1_sig_rpl.hdr.cmd = 0x%x\n", verify_secp256k1_sig_rpl.hdr.cmd);
      printf("INFO: verify_secp256k1_sig_rpl.bm = 0x%x\n", verify_secp256k1_sig_rpl.bm);
      printf("INFO: verify_secp256k1_sig_rpl.index = 0x%lx, expect 0x%x\n", verify_secp256k1_sig_rpl.index,index_int+tv_ind);
      printf("INFO: verify_secp256k1_sig_rpl.cycle_cnt = 0x%x\n", verify_secp256k1_sig_rpl.cycle_cnt);

      if (verify_secp256k1_sig_rpl.hdr.cmd != zcash_fpga::VERIFY_SECP256K1_SIG_RPL) {
          printf("ERROR: Header type was wrong for test vector#%d!\n",tv_ind);
          failed++;
	  continue;
      }
      if (verify_secp256k1_sig_rpl.bm != 0) {
          printf("ERROR: Signature verification failed for test vector #%d!\n",tv_ind);
          failed++;
	  continue;
      }

      if (verify_secp256k1_sig_rpl.index != index_int+tv_ind) {
         printf("ERROR: Index was wrong for test vector #%d!\n",tv_ind);
         failed++;
	 continue;
      }
      printf("========Test vector %d done=========\n",tv_ind+1);
      }//end of tv_ind loop
    }
printf("Total %d round test, failed %d\n", iter, failed);
 out:
    return 1;
}
