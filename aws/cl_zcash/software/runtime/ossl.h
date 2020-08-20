#include <openssl/ecdsa.h>
#include <openssl/sha.h>
#include <openssl/bn.h>

#include <iomanip>
#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include <string>

#include <unistd.h>
#include <stdlib.h>

#include <iostream>
//#include "ossl.hpp"

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

void char_array_display (const char* char_ptr, int size, const char* msg) {
    for(int i = 0; i < size; i++)
    std::cout  << std::setw(1) << std::setfill('0') << static_cast<char>(tolower(*(char_ptr+i)));
    //printf("%c",static_cast<char>(tolower(*(char_ptr+i)));
    std::cout  << "  //" << msg <<   std::endl;
}


Signature_t sig_ossl (bool verb)        {       //verb=true, print more info.
        Signature_t sig_ret;
        memset(&sig_ret, 0, sizeof(Signature_t));
        //std::string mesg_string = "aaa";
        std::string mesg_string = "I am a fish";
        std::vector<uint8_t> Digest (DIG_SIZE, 0);
        Digest=Hash256(mesg_string);

        //fill sig_ret.hash.
        unsigned char* p_hash = (unsigned char *)sig_ret.hash;
        int i=0;
        for     (std::vector<unsigned char>::iterator iter = Digest.begin(); iter != Digest.end(); ++iter)
        {       *(p_hash+i) =*iter; i++;        }

        //EC_KEY OBJ create
        EC_KEY *ec_key = EC_KEY_new();
        if (ec_key == NULL)  perror("Error for creating ECC key object ");
        EC_GROUP *ec_group = EC_GROUP_new_by_curve_name(NID);   //NID_secp256k1:714
        EC_KEY_set_group(ec_key, ec_group);
        if (!EC_KEY_generate_key(ec_key))       perror("Error for creating ECC key pair");

        //get private key and pub key (Qx, Qy)
        const EC_POINT *pub     = EC_KEY_get0_public_key (ec_key);
        const BIGNUM *PRIV      = EC_KEY_get0_private_key(ec_key);
        BIGNUM *QX = BN_new();
        BIGNUM *QY = BN_new();
        //Gets the affine coordinates of an EC_POINT.
        if (!(EC_POINT_get_affine_coordinates(ec_group, pub, QX, QY, NULL)))
                perror("Error for creating ECC pub key");
/*        if (verb)       {
                printf("Pub key gen OK:\n");
                std::cout << "QX      : ";
                BN_print_fp(stdout, QX);
                putc('\n', stdout);
                std::cout << "QY      : ";
                BN_print_fp(stdout, QY);
                putc('\n', stdout);
                std::cout << "Priv key: ";
                BN_print_fp(stdout, PRIV);
                printf("--------------------------------------------------\n");

	   }
*/      
       	//generate signature
        ECDSA_SIG *signature;
        unsigned char *dig_ptr=Digest.data();
        signature = ECDSA_do_sign(dig_ptr, SHA256_DIGEST_LENGTH, ec_key);
                if (signature == NULL)  perror("ECDSA_SIG generation fail");

        //verify signature
        if (!(ECDSA_do_verify(dig_ptr, SHA256_DIGEST_LENGTH, signature, ec_key)))
                perror("Openssl generated signature verify FAILED");

        //Obtain R and S
        const BIGNUM *PR = BN_new();
        const BIGNUM *PS = BN_new();
        ECDSA_SIG_get0(signature, &PR, &PS);

        //convert BN to generate TV
        char* qx        = BN_bn2hex(QX);
        char* qy        = BN_bn2hex(QY);
        char* sig_r     = BN_bn2hex(PR);
        char* sig_s     = BN_bn2hex(PS);
        char* priv_key  = BN_bn2hex(PRIV);      //private key needed for debugging

        std::string sig_r_str=sig_r;
        std::string sig_s_str=sig_s;
        std::string qx_str=qx;
        std::string qy_str=qy;

        string_to_hex(sig_r,  (unsigned char *)sig_ret.r);
        string_to_hex(sig_s,  (unsigned char *)sig_ret.s);
        string_to_hex(qx_str, (unsigned char *)sig_ret.Qx);
        string_to_hex(qy_str, (unsigned char *)sig_ret.Qy);

        if (verb)       {
        for (int i=0; i<DIG_SIZE; i++)  printf("%02x", *(dig_ptr+i));
        std::cout <<"  //digest\n";
        char_array_display (sig_r,SIG_SIZE,"sig.r");
        char_array_display (sig_s,SIG_SIZE,"sig.s");
        char_array_display (qx,   PUB_KEY_SIZE,"QX");
        char_array_display (qy,   PUB_KEY_SIZE,"QY");
        printf("--------------------------------------------------\n");
        char_array_display (priv_key,64,"PRIV");
	printf("\n");
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
        ec_group  =     nullptr;
        ec_key    = nullptr;

        BN_free(QX);
        BN_free(QY);

return sig_ret;
}

