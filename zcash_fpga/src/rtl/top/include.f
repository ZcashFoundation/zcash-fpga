${ZCASH_DIR}/zcash_fpga/src/rtl/secp256k1/secp256k1_pkg.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/equihash/equihash_pkg.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_pkg.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/top/zcash_fpga_pkg.sv
${ZCASH_DIR}/ip_cores/common/src/rtl/common_pkg.sv

${ZCASH_DIR}/ip_cores/common/src/rtl/common_if.sv
${ZCASH_DIR}/ip_cores/common/src/rtl/synchronizer.sv
${ZCASH_DIR}/ip_cores/common/src/rtl/pipeline_if_single.sv
${ZCASH_DIR}/ip_cores/common/src/rtl/pipeline_if.sv

${ZCASH_DIR}/zcash_fpga/src/rtl/control/control_top.sv

${ZCASH_DIR}/zcash_fpga/src/rtl/equihash/equihash_verif_difficulty.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/equihash/equihash_verif_order.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/equihash/equihash_verif_top.sv

${ZCASH_DIR}/zcash_fpga/src/rtl/secp256k1/secp256k1_mod.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/secp256k1/secp256k1_mult_mod.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/secp256k1/secp256k1_point_mult_endo_decom.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/secp256k1/secp256k1_point_mult_endo.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/secp256k1/secp256k1_point_mult.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/secp256k1/secp256k1_top.sv

${ZCASH_DIR}/ip_cores/blake2b/src/rtl/blake2b_pkg.sv
${ZCASH_DIR}/ip_cores/blake2b/src/rtl/blake2b_g.sv
${ZCASH_DIR}/ip_cores/blake2b/src/rtl/blake2b_pipe_top.sv
${ZCASH_DIR}/ip_cores/blake2b/src/rtl/blake2b_top.sv

${ZCASH_DIR}/ip_cores/fifo/src/rtl/axi_stream_fifo.sv
${ZCASH_DIR}/ip_cores/fifo/src/rtl/cdc_fifo_if.sv
${ZCASH_DIR}/ip_cores/fifo/src/rtl/cdc_fifo.sv
${ZCASH_DIR}/ip_cores/fifo/src/rtl/width_change_cdc_fifo.sv

${ZCASH_DIR}/ip_cores/hash_map/src/rtl/crc.sv
${ZCASH_DIR}/ip_cores/hash_map/src/rtl/hash_map.sv

${ZCASH_DIR}/ip_cores/memory/src/rtl/bram.sv
${ZCASH_DIR}/ip_cores/memory/src/rtl/uram.sv

${ZCASH_DIR}/ip_cores/sha256/src/rtl/sha256_pkg.sv
${ZCASH_DIR}/ip_cores/sha256/src/rtl/sha256_top.sv
${ZCASH_DIR}/ip_cores/sha256/src/rtl/sha256d_top.sv

${ZCASH_DIR}/ip_cores/util/src/rtl/accum_mult.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/barret_mod.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/bin_inv.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/bin_inv_s.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/dup_check.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/karatsuba_ofman_mult.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/packet_arb.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/resource_share.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/barret_mod_pipe.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/adder_pipe.sv
${ZCASH_DIR}/ip_cores/util/src/rtl/subtracter_pipe.sv

${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fp_mult_mod.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fp2_arithmetic.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fp2_point_add.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fp2_point_dbl.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_point_add.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_point_dbl.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_point_mult.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fe12_inv_s.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fe12_mul_s.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fe12_pow_s.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fe2_inv_s.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fe2_mul_s.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fe6_inv_s.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/ec_fe6_mul_s.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/fe2_mul_by_nonresidue_s.sv
${ZCASH_DIR}/ip_cores/ec/src/rtl/fe6_mul_by_nonresidue_s.sv


${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_axi_bridge.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_top.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_pairing.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_pairing_wrapper.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_pairing_miller_dbl.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_pairing_miller_add.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_final_exponent.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_fe6_fmap.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_fe2_fmap.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_fe12_inv_wrapper.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_fe12_fmap.sv
${ZCASH_DIR}/zcash_fpga/src/rtl/bls12_381/bls12_381_fe12_fmap_wrapper.sv



${ZCASH_DIR}/zcash_fpga/src/rtl/top/zcash_fpga_top.sv
