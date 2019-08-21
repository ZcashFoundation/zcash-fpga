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

add_wave /tb/card/fpga/CL/*pcis*
add_wave /tb/card/fpga/CL/rx_axi_lite_if/*
add_wave /tb/card/fpga/CL/rx_axi4_if/*
add_wave /tb/card/fpga/CL/zcash_axi_lite_if/*
add_wave /tb/card/fpga/CL/zcash_if_tx/*
add_wave /tb/card/fpga/CL/zcash_if_rx/*
add_wave /tb/card/fpga/CL/cl_zcash_aws_wrapper/*

run all
