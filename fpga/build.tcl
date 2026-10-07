# Recreate the portfolio project on the exact Zybo Z7-10 silicon.
# This stage validates custom RTL and generates a 2-lane RAW10 CSI receiver IP.
# Board-level PS/DMA/DDR integration is a separate bring-up stage.
set root [file normalize [file join [file dirname [info script]] ..]]
set build [file join $root build vivado]
file mkdir $build
file mkdir [file join $root docs]
create_project zybo_ov5647 $build -part xc7z010clg400-1 -force
set_property target_language Verilog [current_project]
add_files -norecurse [list [file join $root rtl axis_frame_monitor.sv]]
add_files -norecurse [list [file join $root rtl axis_raw10_to_bayer8.sv]]
add_files -norecurse [list [file join $root rtl axis_vision_pipeline.v]]
set_property top axis_vision_pipeline [current_fileset]

create_ip -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem:6.0 -module_name csi_rx_2lane_raw10
set_property -dict [list \
  CONFIG.CMN_NUM_LANES {2} \
  CONFIG.CMN_PXL_FORMAT {RAW10} \
  CONFIG.C_HS_LINE_RATE {292} \
  CONFIG.CMN_NUM_PIXELS {1} \
  CONFIG.CMN_INC_VFB {true}] [get_ips csi_rx_2lane_raw10]
generate_target all [get_ips csi_rx_2lane_raw10]
puts "CSI_STATUS=[report_ip_status -return_string]"
puts "CSI_FILE=[get_property IP_FILE [get_ips csi_rx_2lane_raw10]]"

synth_design -top axis_vision_pipeline -part xc7z010clg400-1
create_clock -period 10.000 -name axis_clk [get_ports aclk]
puts "RTL_SYNTH_STATUS=Complete"
report_utilization -file [file join $root docs rtl_utilization.txt]
report_timing_summary -file [file join $root docs rtl_timing.txt]
close_project

