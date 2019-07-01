The work in this repo is the result of a Zcash foundation grant to develop open-source FPGA code that can be used to accelerate various aspects of the network.
**An Architecture document is [here](https://docs.google.com/document/d/1zKZP0SlvL1LxzCStOaIWPoddgXfRXx6f_vveiZj8w0E/edit?usp=sharing)** (comments are enabled so if you have questions / comments please feel free to add them).

# Repo folder structure

Each top level folder is explained below. Inside each folder is source code written in systemverilog, and most blocks have a standalone self-checking testbench.

## aws

This contains the top / project files for building on a AWS (Amazon FPGA VU9P w/ 64GB DDR4).

* This contains the zcash_fpga library (aws/cl_zcash/software/runtime/zcash_fpga.hpp) that can be used to interface with the FPGA over PCIe.
* Instructions on how to build are in the architecture document.

## bittware_xupvvh

This contains the top / project files for building on the Bittware VVH board (VU37P FPGA w/ 8GB HBM, 16GB DDR4).

## ip_cores

These contain shared IP cores used by the projects in this repo. These include many functions, such as:

* Hashing
  - Blake2b - single pipe implementation of blake2b and a pipline-unrolled version for high performance (single clock hash @ 200MHz after initial 52 clock delay).
  - SHA256 and SHA256d
* Packages and interfaces for common use, along with many tasks to simplify simulation
  - AXI4
  - AXI4-lite
  - Block RAM
* Fifo implementations
* Hash map implementation
  - Fully parameterized for bit widths and uses CRC as the hashing function
* Blocks for parsing/processing streams
* Karabutsa multiplier
  - Fully parameterized for number of levels
* Barret reduction for modulo reduction when the modulus does not allow fast reduction
  - Both a fully pipelined high performance version and a slower but smaller resource utilization version
* Addition and subtraction modules
  - Fully parameterized so that they can be used for large bit-width arithmetic
* Resource arbitrators
* General purpose elliptical curve point modules
  - Supports point multiplication, addition, doubling in Fp and Fp^2

## zcash_fpga

This is the top level for the Zcash FPGA. It contains source code and testbenches for the blocks used in the Zcash acceleration engine.

It optionally contains the following top-level engines (you can include in a build via parameters in the top level package):
* Equihash verification engine
  - Verifies the equihash solution and difficulty filters
* EC secp256k1 signature verification engine
  - Uses efficient endomorphism to reduce key bit size
  - Signature verification calculates multiple EC point operations in parallel, using a resource-shared single fully pipelined karabutsa multiplier and quick modulo reduction technique
* EC bls12-381 coprocessor
  - General arithmetic over bls12-381 curve
  - Dual Point multiplication in Fp and Fp^2
  - ate Pairing (miller loop and final exponentiation)
