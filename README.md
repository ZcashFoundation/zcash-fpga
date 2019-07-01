# zcash-fpga

Repo for Zcash FPGA projects code and documents. Architecture document is [here]().

## aws

This contains the top / project files for building on AWS (Amazon FPGA)

## bittware_xupvvh

This contains the top / project files for building on the Bittware VVH board

## ip_cores

These contain custom IP cores used by the projects in this repo.

* Hashing
  - Blake2b - single pipe implementation of blake2b and a pipline-unrolled version for high performance.
  - SHA256 and SHA256d
* Packages and interfaces that are shared
* Fifo implementations
* Blocks for parsing/processing streams, as well as testbench files
* Karabutsa multiplier
* Barret reduction for modulo reduction when the modulus does not allow fast reduction
* Resource arbitrators
* General purpose elliptical curve point modules
  - Supports point multiplication, addition, doubling in Fp and Fp^2

## zcash_fpga

This is the top level for the Zcash FPGA. It targets both Xilinx Virtex UltraScale+ FPGA VCU118 Evaluation Kit, and Amazon EC2 F1 Instances.

It optionally contains the following top-level engines (you can optionally include in a build via parameters):
* Equihash verification engine
  - Verifies the equihash solution and difficulty filters
* EC secp256k1 signature verification engine
  - Uses efficient endomorphism to reduce key bit size
  - Signature verification calculates multiple EC point operations in parallel, using a resource-shared single fully pipelined karabutsa multiplier and quick modulo reduction technique
* EC bls12-381 coprocessor
  - Point multiplication in Fp and Fp^2
  - ate Pairing
