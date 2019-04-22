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

set curr_wave [current_wave_config]
if { [string length $curr_wave] == 0 } {
  if { [llength [get_objects]] > 0} {
    add_wave /
    set_property needs_save false [current_wave_config]
  } else {
     send_msg_id Add_Wave-1 WARNING "No top level signals found. Simulator will start without a wave window. If you want to open a wav#e window go to 'File->New Waveform Configuration' or type 'create_wave_config' in the TCL console."
  }
}

add_wave /tb/card/fpga/CL/*
add_wave /tb/card/fpga/CL/CL_SDE_SRM/*
add_wave /tb/card/fpga/CL/zcash_if_rx/*
add_wave /tb/card/fpga/CL/zcash_if_tx/*
add_wave /tb/card/fpga/CL/aws_if_rx/*
add_wave /tb/card/fpga/CL/aws_if_tx/*


run 200 us
