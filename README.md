# zcash-fpga

Repo for Zcash FPGA projects code and documents.

## Overview

These have been designed targetted for Xilinx boards (US+) and therefore contain Xilinx-specific IP.

## zcash_verif

This is the top level for the Zcash verification FPGA board. It targets both Xilinx Virtex UltraScale+ FPGA VCU118 Evaluation Kit, and Amazon EC2 F1 Instances.

Architecture document is [here]()

Contains the following top-level engine:
### Equihash verification engine
### EC secp256k1 signature verification engine
### EC bls12-381 co-processor


## ip_cores

These contain custom IP cores used in the projects in this repo.

* blake2b - A simple implementation of blake2b and a pipline-unrolled version for high performance.
* common - Packages and interfaces that are shared.
* fifo - Fifo implementations
* parsing - Blocks for parsing/processing streams, as well as testbench files.