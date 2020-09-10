source device_type.tcl
create_project cl_sde_ip cl_sde_ip -part [DEVICE_TYPE]

add_files -fileset sources_1 -norecurse {
axi_fifo_mm_s_0/axi_fifo_mm_s_0.xci
axi_fifo_mm_s_lite/axi_fifo_mm_s_lite.xci
axis_dwidth_converter_64_to_8/axis_dwidth_converter_64_to_8.xci
axis_dwidth_converter_8_to_64/axis_dwidth_converter_8_to_64.xci
axis_dwidth_converter_48_to_8/axis_dwidth_converter_48_to_8.xci
axis_dwidth_converter_4_to_8/axis_dwidth_converter_4_to_8.xci
axis_dwidth_converter_8_to_4/axis_dwidth_converter_8_to_4.xci
ila_2/ila_2.xci
fifo_generator_0/fifo_generator_0.xci
}

upgrade_ip [get_ips *]

generate_target all [get_files  axi_fifo_mm_s_0/axi_fifo_mm_s_0.xci]
generate_target all [get_files  axi_fifo_mm_s_lite/axi_fifo_mm_s_lite.xci]
generate_target all [get_files  axis_dwidth_converter_64_to_8/axis_dwidth_converter_64_to_8.xci]
generate_target all [get_files  axis_dwidth_converter_8_to_64/axis_dwidth_converter_8_to_64.xci]
generate_target all [get_files axis_dwidth_converter_48_to_8/axis_dwidth_converter_48_to_8.xci]
generate_target all [get_files  axis_dwidth_converter_4_to_8/axis_dwidth_converter_4_to_8.xci]
generate_target all [get_files  axis_dwidth_converter_8_to_4/axis_dwidth_converter_8_to_4.xci]
generate_target all [get_files  ila_2/ila_2.xci]
generate_target all [get_files  fifo_generator_0/fifo_generator_0.xci]