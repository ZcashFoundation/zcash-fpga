# Amazon FPGA Hardware Development Kit
#
# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.

#Param needed to avoid clock name collisions
set_param sta.enableAutoGenClkNamePersistence 0
set_param chipscope.enablePRFlow true
set CL_MODULE $CL_MODULE
set VDEFINES $VDEFINES

create_project -in_memory -part [DEVICE_TYPE] -force

########################################
## Generate clocks based on Recipe
########################################

puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Calling aws_gen_clk_constraints.tcl to generate clock constraints from developer's specified recipe.";

source $HDK_SHELL_DIR/build/scripts/aws_gen_clk_constraints.tcl

#############################
## Read design files
#############################

#Convenience to set the root of the RTL directory
set ENC_SRC_DIR $CL_DIR/build/src_post_encryption

puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Reading developer's Custom Logic files post encryption.";

#---- User would replace this section -----

# Reading the .sv and .v files, as proper designs would not require
# reading .v, .vh, nor .inc files

read_verilog -sv [glob $ENC_SRC_DIR/*.?v]

#---- End of section replaced by User ----

puts "AWS FPGA: Reading AWS Shell design";

#Read AWS Design files
read_verilog -sv [ list \
  $HDK_SHELL_DESIGN_DIR/lib/lib_pipe.sv \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/sync.v \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/flop_ccf.sv \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/ccf_ctl.v \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/sh_ddr.sv \
  $HDK_SHELL_DESIGN_DIR/interfaces/cl_ports.vh
]

puts "AWS FPGA: Reading IP blocks";

# User IP
read_ip [ list \
  $CL_DIR/ip/axis_dwidth_converter_4_to_8/axis_dwidth_converter_4_to_8.xci \
  $CL_DIR/ip/axis_dwidth_converter_8_to_4/axis_dwidth_converter_8_to_4.xci \
  $CL_DIR/ip/axis_dwidth_converter_64_to_8/axis_dwidth_converter_64_to_8.xci \
  $CL_DIR/ip/axis_dwidth_converter_8_to_64/axis_dwidth_converter_8_to_64.xci \
  $CL_DIR/ip/axis_dwidth_converter_48_to_8/axis_dwidth_converter_48_to_8.xci \
  $CL_DIR/ip/axi_fifo_mm_s_0/axi_fifo_mm_s_0.xci \
  $CL_DIR/ip/ila_2/ila_2.xci \
  $CL_DIR/ip/axi_fifo_mm_s_lite/axi_fifo_mm_s_lite.xci \
  $CL_DIR/ip/fifo_generator_0/fifo_generator_0.xci
]

puts "AWS FPGA: Generating IP blocks";

upgrade_ip [get_ips *]

set_property generate_synth_checkpoint false [get_files axis_dwidth_converter_64_to_8.xci]
set_property generate_synth_checkpoint false [get_files axis_dwidth_converter_8_to_64.xci]
set_property generate_synth_checkpoint false [get_files axis_dwidth_converter_4_to_8.xci]
set_property generate_synth_checkpoint false [get_files axis_dwidth_converter_8_to_4.xci]
set_property generate_synth_checkpoint false [get_files axis_dwidth_converter_48_to_8.xci]
set_property generate_synth_checkpoint false [get_files axi_fifo_mm_s_0.xci]
set_property generate_synth_checkpoint false [get_files axi_fifo_mm_s_lite.xci]
set_property generate_synth_checkpoint false [get_files ila_2.xci]
set_property generate_synth_checkpoint false [get_files fifo_generator_0.xci]

generate_target all [get_ips axis_dwidth_converter_64_to_8]
generate_target all [get_ips axis_dwidth_converter_8_to_64]
generate_target all [get_ips axis_dwidth_converter_4_to_8]
generate_target all [get_ips axis_dwidth_converter_8_to_4]
generate_target all [get_ips axis_dwidth_converter_48_to_8]
generate_target all [get_ips axi_fifo_mm_s_0]
generate_target all [get_ips axi_fifo_mm_s_lite]
generate_target all [get_ips ila_2]
generate_target all [get_ips fifo_generator_0]

#Read IP for axi register slices
read_ip [ list \
  $HDK_SHELL_DESIGN_DIR/ip/src_register_slice/src_register_slice.xci \
  $HDK_SHELL_DESIGN_DIR/ip/dest_register_slice/dest_register_slice.xci \
  $HDK_SHELL_DESIGN_DIR/ip/axi_register_slice/axi_register_slice.xci \
  $HDK_SHELL_DESIGN_DIR/ip/axi_register_slice_light/axi_register_slice_light.xci
]

#Read IP for virtual jtag / ILA/VIO
read_ip [ list \
  $HDK_SHELL_DESIGN_DIR/ip/ila_0/ila_0.xci \
  $HDK_SHELL_DESIGN_DIR/ip/cl_debug_bridge/cl_debug_bridge.xci \
  $HDK_SHELL_DESIGN_DIR/ip/ila_vio_counter/ila_vio_counter.xci \
  $HDK_SHELL_DESIGN_DIR/ip/vio_0/vio_0.xci
]

upgrade_ip [get_ips ila_0]
set_property generate_synth_checkpoint false [get_files ila_0.xci]
generate_target all [get_ips ila_0]

upgrade_ip [get_ips ila_vio_counter]
set_property generate_synth_checkpoint false [get_files ila_vio_counter.xci]
generate_target all [get_ips ila_vio_counter]

upgrade_ip [get_ips cl_debug_bridge]
set_property generate_synth_checkpoint false [get_files cl_debug_bridge.xci]
generate_target all [get_ips cl_debug_bridge]

upgrade_ip [get_ips vio_0]
set_property generate_synth_checkpoint false [get_files vio_0.xci]
generate_target all [get_ips vio_0]


# Additional IP's that might be needed if using the DDR
#read_bd [ list \
# $HDK_SHELL_DESIGN_DIR/ip/ddr4_core/ddr4_core.xci \
# $HDK_SHELL_DESIGN_DIR/ip/cl_axi_interconnect/cl_axi_interconnect.bd
#]

puts "AWS FPGA: Reading AWS constraints";

#Read all the constraints
#
#  cl_clocks_aws.xdc  - AWS auto-generated clock constraint.   ***DO NOT MODIFY***
#  cl_ddr.xdc         - AWS provided DDR pin constraints.      ***DO NOT MODIFY***
#  cl_synth_user.xdc  - Developer synthesis constraints.
read_xdc [ list \
   $CL_DIR/build/constraints/cl_clocks_aws.xdc \
   $HDK_SHELL_DIR/build/constraints/cl_ddr.xdc \
   $HDK_SHELL_DIR/build/constraints/cl_synth_aws.xdc \
   $CL_DIR/build/constraints/cl_synth_user.xdc
]

#Do not propagate local clock constraints for clocks generated in the SH
set_property USED_IN {synthesis implementation OUT_OF_CONTEXT} [get_files cl_clocks_aws.xdc]
set_property PROCESSING_ORDER EARLY  [get_files cl_clocks_aws.xdc]

set buildDate [ clock format [ clock seconds ] -format %y%m%d ]
set_property generic {zcash_fpga_top.control_top.BUILD_DATE={\"$buildDate\"}} [current_fileset]

########################
# CL Synthesis
########################
puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Start design synthesis.";

update_compile_order -fileset sources_1
puts "\nRunning synth_design for $CL_MODULE $CL_DIR/build/scripts \[[clock format [clock seconds] -format {%a %b %d %H:%M:%S %Y}]\]"
eval [concat synth_design -top $CL_MODULE -verilog_define XSDB_SLV_DIS $VDEFINES -part [DEVICE_TYPE] -mode out_of_context $synth_options -directive $synth_directive]

set failval [catch {exec grep "FAIL" failfast.csv}]
if { $failval==0 } {
  puts "AWS FPGA: FATAL ERROR--Resource utilization error; check failfast.csv for details"
  exit 1
}

puts "AWS FPGA: ([clock format [clock seconds] -format %T]) writing post synth checkpoint.";
write_checkpoint -force $CL_DIR/build/checkpoints/${timestamp}.CL.post_synth.dcp

close_project
#Set param back to default value
set_param sta.enableAutoGenClkNamePersistence 1
