The work in this repo is the result of a Zcash foundation grant to develop open-source FPGA code that can be used to accelerate various aspects of the network.
**An Architecture document is [here](zcash_fpga_design_doc_v1.3.pdf)**.

While mainly developed for Equihash verification and elliptic curve operations on the secp256k1 and bls12-381 curves, the code (ip_cores) used in this repo can also be applied to other curves by
changing parameters / minimum modification to equations.

# Getting started

The architecture document has instructions for building an AWS image or simulating the top level design. The easiest way is to add all .sv and .xci files to a new Vivado project,
and then set the top level _tb.sv file to the module you want to test. Everything has been synthesized and tested in both simulation and on FPGA (AWS and Bittware) with both Vivado 2018.3 and 2019.1.

# Repo folder structure

Each top level folder is explained below. Inside each folder is source code written in SystemVerilog, and most blocks have a stand-alone self-checking testbench.

## AWS

This contains the top / project files for building on a AWS F1 instance (Amazon FPGA VU9P w/ 64GB DDR4).

* This contains the zcash_fpga library (aws/cl_zcash/software/runtime/zcash_fpga.hpp) that can be used to interface with the FPGA over PCIe.
* Instructions on how to build are in the architecture document.

## bittware_xupvvh

This contains the top / project files for building on the Bittware VVH board (VU37P FPGA w/ 8GB HBM, 16GB DDR4).

## ip_cores

These contain shared IP cores that are used by the projects in this repo. These include many functions, such as:

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
* Karatsuba multiplier
  - Fully parameterized for number of levels
* Barret reduction for modulo reduction when the modulus does not allow fast reduction
  - Both a fully pipelined high performance version and a slower but smaller resource utilization version
* Fully parallel multiplier with carry save adder tree and RAM for modular reduction
  - Fully pipelined, 3x performance over Karatsuba + Barret, but uses FPGA RAM  
* Multiplier using carry tree to accumulate products with BRAM for modular reduction
  - 3x performance over Karatsuba + Barret approach
* Addition and subtraction modules
  - Fully parameterized so that they can be used for large bit-width arithmetic
* Extended Euclidean algorithm for calculating multiplicative inverses
* Resource arbitrators
* General purpose elliptical curve (Weierstrass) point and element modules
  - Point multiplication, doubling, adding up to Fp^12 (towered over Fp^6 and Fp^2)
  - Operations in both affine and jacobian coordinates

## zcash_fpga

This is the top level for the Zcash FPGA. It contains source code and testbenches for the blocks used in the Zcash acceleration engine.

It optionally contains the following top-level engines (you can include in a build via parameters in the top level package):
* Equihash verification engine
  - Verifies the equihash solution and difficulty filters
* Transparent Signature Verification Engine (secp256k1 ECDSA core)
  - Uses efficient endomorphism to reduce key bit size
  - Signature verification calculates multiple EC point operations in parallel, using a resource-shared single fully pipelined karatsuba multiplier and quick modulo reduction technique
* BLS12-381 coprocessor (zk-SNARK accelerator)
  - Custom instruction set with 2kB instruction memory
  - 12kB Data slot URAM at curve native bit width of 381b
  - General arithmetic up to Fp^12 (Towering Fp -> Fp^2 -> Fp^6 -> Fp^12) over bls12-381 curve
  - Dual Point multiplication in Fp and Fp^2 (G1 and G2)
  - Fp^12 Frobenius map operations
  - Fp^12 inversion
  - Fp^12 exponentiation
  - The optimal ate pairing
    - Miller loop and final exponentiation stage, with separate instructions for multi-pairing use
