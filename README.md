# zcash-fpga

Repo for Zcash FPGA projects code and documents.

## Overview

These have been designed targetted for Xilinx boards (US+) and therefore contain Xilinx-specific IP.

## zcash_fpga_top

This is the top level for the Zcash FPGA. It targets both Xilinx Virtex UltraScale+ FPGA VCU118 Evaluation Kit, and Amazon EC2 F1 Instances.

Architecture document is [here]()

It optionally contains the following top-level engines (you can optionally include in a build via parameters):
* Equihash verification engine
* EC secp256k1 signature verification engine
** Uses efficent endomorphism to reduce key bit size
** Signature verification calcultes multiple EC point operations in parallel, using a resource-shared single fully pipelined karabutsa multiplier and quick modulo reduction technique
* EC bls12-381 co-processor
** Point multiplication in Fp and Fp^2
** ate Pairing



## ip_cores

These contain custom IP cores used in the projects in this repo.

* blake2b - A simple implementation of blake2b and a pipline-unrolled version for high performance.
* common - Packages and interfaces that are shared.
* fifo - Fifo implementations
* parsing - Blocks for parsing/processing streams, as well as testbench files.
* Karabutsa multiplier
* Barret reduction
* Resource arbitrators
* General purpose elliptical curve point modules
** Supports point multiplication, addition, doubling
** For both Fp and Fp^2 