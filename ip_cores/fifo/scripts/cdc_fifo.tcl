#  Find all the cdc_fifos and correctly set constraints for the rd and wr pointers that cross clock domains.
#  
#  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>. 

set cdc_fifo_instance [get_cells -hierarchical -filter { ORIG_REF_NAME =~  "cdc_fifo" || REF_NAME =~  "cdc_fifo" } ]
foreach child $cdc_fifo_instance {

  set using_bram [get_property USE_BRAM [get_cells $child]]
  set name [get_property NAME $child]
  
  set wr_ptr_cells [get_cells -hierarchical -filter "NAME =~ $name/synchronizer_wr_ptr/* "]
  set clock [get_clocks -of_objects [get_pins  -filter { NAME =~  "*dat_reg[1]*C" }  -of_objects $wr_ptr_cells]]
  set clock_period [get_property PERIOD $clock]
 
  set_bus_skew -from [get_pins  -filter { NAME =~  "*dat_reg[0]*C" }  -of_objects $wr_ptr_cells] -to [get_pins  -filter { NAME =~  "*dat_reg[1]*D" }  -of_objects $wr_ptr_cells] [expr $clock_period/2]
  set_max_delay -from [get_pins  -filter { NAME =~  "*dat_reg[0]*C" }  -of_objects $wr_ptr_cells] -to [get_pins  -filter { NAME =~  "*dat_reg[1]*D" }  -of_objects $wr_ptr_cells] -datapath_only [expr $clock_period/2]
 

  set rd_ptr_cells [get_cells -hierarchical -filter "NAME =~ $name/synchronizer_rd_ptr/* "]
  set clock [get_clocks -of_objects [get_pins  -filter { NAME =~  "*dat_reg[1]*C" }  -of_objects $rd_ptr_cells]]
  set clock_period [get_property PERIOD $clock]
 
  set_bus_skew -from [get_pins  -filter { NAME =~  "*dat_reg[0]*C" }  -of_objects $rd_ptr_cells] -to [get_pins  -filter { NAME =~  "*dat_reg[1]*D" }  -of_objects $rd_ptr_cells] [expr $clock_period/2]
  set_max_delay -from [get_pins  -filter { NAME =~  "*dat_reg[0]*C" }  -of_objects $rd_ptr_cells] -to [get_pins  -filter { NAME =~  "*dat_reg[1]*D" }  -of_objects $rd_ptr_cells] -datapath_only [expr $clock_period/2]
  
  # This is only needed if the cell is using registers (not BRAM)
  set all_cells [get_cells -hierarchical -filter "NAME =~ $name/* "]
  catch {set_bus_skew -from [get_pins  -filter { NAME =~  "*ram*C" } -of_objects $all_cells] -to [get_pins  -filter { NAME =~  "*o_dat_b*D" } -of_objects $all_cells] [expr $clock_period/2]}
  catch {set_max_delay -from [get_pins  -filter { NAME =~  "*ram*C" } -of_objects $all_cells] -to [get_pins  -filter { NAME =~  "*o_dat_b*D" } -of_objects $all_cells] -datapath_only [expr $clock_period/2]}
  
} 