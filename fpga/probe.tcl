set part xc7z010clg400-1
set root [file normalize [file join [file dirname [info script]] ..]]
set_param board.repoPaths [list [file join $root fpga board_files]]
create_project -in_memory -part $part
puts "PROBE_PART=[get_property PART [current_project]]"
puts "PROBE_BOARD_PARTS=[get_board_parts -quiet *zybo*z7*10*]"
foreach pattern {xilinx.com:ip:mipi_csi2_rx_subsystem:* xilinx.com:ip:mipi_dphy:* xilinx.com:ip:axi_vdma:* xilinx.com:ip:processing_system7:* xilinx.com:ip:axi_iic:* xilinx.com:ip:axi_ethernet:*} {
  puts "PROBE_IP_$pattern=[get_ipdefs -all -quiet $pattern]"
}
create_ip -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem:6.0 -module_name csi_rx_probe
foreach prop [list_property [get_ips csi_rx_probe]] {
  if {[string match CONFIG.* $prop]} {puts "CSI_CONFIG $prop=[get_property $prop [get_ips csi_rx_probe]]"}
}
exit
