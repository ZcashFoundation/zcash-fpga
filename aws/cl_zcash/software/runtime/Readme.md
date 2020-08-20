1. ecdsa_test.cpp: hardcoded several TV and feed to FPGA for test;

- Compile the ecdsa_test.cpp

  make -f makefile_ecdsa

- Usage: (before doing below, make sure you had already load the fpga image, check master help document)

  sudo ./ecdsa_test


-----------------------------


2. openssl_verify.cpp: utilize the openssl lib to generate the test vector dynamiclly and feedback to fpga for verify test.

- Compile the openssl_verify.cpp

  make -f openssl_verify.cpp

- Usage: (before doing below, make sure you had already load the fpga image, check the master help document)

  sudo ./openssl_verify [iteration_num] [verbose: t | f]
  

  [iteration num] is used to define how much round test to be done, just give a number;
  
  [verbose] control if you want to output more information(t) or not(f) 
