#  Find all the cdc_fifos and synchronizers set constraints for the cross clock domains.
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

set synchronizer_instance [get_cells -hierarchical -filter { ORIG_REF_NAME =~  "synchronizer" || REF_NAME =~  "synchronizer" } ]
foreach child $synchronizer_instance {

  set name [get_property NAME $child]
  
  set cells [get_cells -hierarchical -filter "NAME =~ $name/* "]
  set clock [get_clocks -of_objects [get_pins  -filter { NAME =~  "*dat_reg[1]*C" }  -of_objects $cells]]
  set clock_period [get_property PERIOD $clock]
 
  set_bus_skew -from [get_pins  -filter { NAME =~  "*dat_reg[0]*C" }  -of_objects $cells] -to [get_pins  -filter { NAME =~  "*dat_reg[1]*D" }  -of_objects $cells] [expr $clock_period/2]
  set_max_delay -from [get_pins  -filter { NAME =~  "*dat_reg[0]*C" }  -of_objects $cells] -to [get_pins  -filter { NAME =~  "*dat_reg[1]*D" }  -of_objects $cells] -datapath_only [expr $clock_period/2]
 
} 