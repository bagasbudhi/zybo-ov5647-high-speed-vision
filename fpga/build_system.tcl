# Zybo Z7-10 CSI-2 capture, custom RTL, DDR frame buffering and HDMI output.
# Processor firmware is still required to configure the sensor and VDMA.
set root [file normalize [file join [file dirname [info script]] ..]]
set_param board.repoPaths [list [file join $root fpga board_files]]
set build [file join $root build system]
file mkdir $build
create_project zybo_camera_system $build -part xc7z010clg400-1 -force
set_property board_part digilentinc.com:zybo-z7-10:part0:1.2 [current_project]
set_property ip_repo_paths [list [file join $root fpga ip_repo]] [current_fileset]
update_ip_catalog -rebuild
add_files -norecurse [list [file join $root rtl axis_frame_monitor.sv]]
add_files -norecurse [list [file join $root rtl axis_raw10_to_bayer8.sv]]
add_files -norecurse [list [file join $root rtl axis_vision_pipeline.v]]
add_files -norecurse [list [file join $root rtl axis_gray_to_rgb.v]]
create_bd_design system
set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
  -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} $ps7
puts "PS_CONFIG_ENET0=[get_property CONFIG.PCW_ENET0_PERIPHERAL_ENABLE $ps7]"
puts "PS_CONFIG_DDR=[get_property CONFIG.PCW_UIPARAM_DDR_ENABLE $ps7]"
foreach pin [get_bd_pins ps7/*CLK*] {puts "PS_CLOCK_PIN=$pin"}
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins ps7/M_AXI_GP0_ACLK]
set_property CONFIG.PCW_USE_S_AXI_HP0 {1} $ps7
set_property CONFIG.PCW_EN_CLK1_PORT {1} $ps7
set_property CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {200.000000} $ps7
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins ps7/S_AXI_HP0_ACLK]

set vdma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 camera_vdma]
set_property -dict [list CONFIG.c_include_mm2s {1} \
  CONFIG.c_include_s2mm {1} \
  CONFIG.c_m_axi_s2mm_data_width {64} CONFIG.c_num_fstores {3} \
  CONFIG.c_m_axis_mm2s_tdata_width {8}] $vdma
set iic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.1 camera_iic]
make_bd_intf_pins_external [get_bd_intf_pins camera_iic/IIC]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config {Master "/ps7/M_AXI_GP0" Clk "Auto"} [get_bd_intf_pins camera_vdma/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config {Master "/ps7/M_AXI_GP0" Clk "Auto"} [get_bd_intf_pins camera_iic/S_AXI]
puts "HP_PINS=[get_bd_intf_pins ps7/*HP*]"
puts "VDMA_PINS=[get_bd_intf_pins camera_vdma/*]"
set hp_axi [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 hp_axi]
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] $hp_axi
connect_bd_intf_net [get_bd_intf_pins camera_vdma/M_AXI_S2MM] [get_bd_intf_pins hp_axi/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins camera_vdma/M_AXI_MM2S] [get_bd_intf_pins hp_axi/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins hp_axi/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]
foreach pin [get_bd_pins camera_vdma/*clk*] {puts "VDMA_CLOCK_PIN=$pin"}
puts "RESET_CELLS=[get_bd_cells *rst*]"
puts "HP_AXI_CLOCK_PINS=[get_bd_pins hp_axi/*CLK*]"
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
  [get_bd_pins {camera_vdma/m_axi_s2mm_aclk camera_vdma/s_axis_s2mm_aclk camera_vdma/m_axi_mm2s_aclk camera_vdma/m_axis_mm2s_aclk hp_axi/ACLK hp_axi/S00_ACLK hp_axi/S01_ACLK hp_axi/M00_ACLK}]
connect_bd_net [get_bd_pins rst_ps7_50M/peripheral_aresetn] \
  [get_bd_pins {hp_axi/ARESETN hp_axi/S00_ARESETN hp_axi/S01_ARESETN hp_axi/M00_ARESETN}]
assign_bd_address
set csi [create_bd_cell -type ip -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem:6.0 csi_rx]
set_property -dict [list CONFIG.CMN_NUM_LANES {2} \
  CONFIG.CMN_PXL_FORMAT {RAW10} CONFIG.C_HS_LINE_RATE {292} \
  CONFIG.CMN_NUM_PIXELS {1} CONFIG.CMN_INC_VFB {true}] $csi
set vision [create_bd_cell -type module -reference axis_vision_pipeline vision]
puts "CSI_PINS=[get_bd_pins csi_rx/*]"
puts "CSI_INTERFACES=[get_bd_intf_pins csi_rx/*]"
puts "VISION_PINS=[get_bd_pins vision/*]"
puts "VDMA_STREAM_PINS=[get_bd_pins camera_vdma/s_axis*]"
puts "PS_FCLKS=[get_bd_pins ps7/FCLK*]"
puts "VDMA_STREAM_WIDTH=[get_property LEFT [get_bd_pins camera_vdma/s_axis_s2mm_tdata]]:[get_property RIGHT [get_bd_pins camera_vdma/s_axis_s2mm_tdata]]"
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins {csi_rx/lite_aclk csi_rx/video_aclk vision/aclk}]
connect_bd_net [get_bd_pins ps7/FCLK_CLK1] [get_bd_pins csi_rx/dphy_clk_200M]
connect_bd_net [get_bd_pins rst_ps7_50M/peripheral_aresetn] \
  [get_bd_pins {csi_rx/lite_aresetn csi_rx/video_aresetn vision/aresetn}]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config {Master "/ps7/M_AXI_GP0" Clk "Auto"} [get_bd_intf_pins csi_rx/csirxss_s_axi]
puts "VISION_INTERFACES=[get_bd_intf_pins vision/*]"
connect_bd_intf_net [get_bd_intf_pins csi_rx/video_out] [get_bd_intf_pins vision/s_axis]
set pack [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 pack_pixels]
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {1} CONFIG.M_TDATA_NUM_BYTES {4}] $pack
connect_bd_intf_net [get_bd_intf_pins vision/m_axis] [get_bd_intf_pins pack_pixels/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins pack_pixels/M_AXIS] [get_bd_intf_pins camera_vdma/S_AXIS_S2MM]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins pack_pixels/aclk]
connect_bd_net [get_bd_pins rst_ps7_50M/peripheral_aresetn] [get_bd_pins pack_pixels/aresetn]
make_bd_intf_pins_external [get_bd_intf_pins csi_rx/mipi_phy_if]

# DDR frame playback to HDMI OUT. VDMA read data is one luma byte per pixel;
# RGB expansion preserves the frame-start and end-of-line stream markers.
set gray_rgb [create_bd_cell -type module -reference axis_gray_to_rgb gray_to_rgb]
connect_bd_intf_net [get_bd_intf_pins camera_vdma/M_AXIS_MM2S] [get_bd_intf_pins gray_to_rgb/s_axis]
set video_out [create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 video_out]
set_property -dict [list CONFIG.C_HAS_ASYNC_CLK {1} CONFIG.C_VTG_MASTER_SLAVE {1}] $video_out
connect_bd_intf_net [get_bd_intf_pins gray_to_rgb/m_axis] [get_bd_intf_pins video_out/video_in]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins {gray_to_rgb/aclk video_out/aclk}]
connect_bd_net [get_bd_pins rst_ps7_50M/peripheral_aresetn] [get_bd_pins {gray_to_rgb/aresetn video_out/aresetn}]
set vtc [create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.2 hdmi_vtc]
set_property -dict [list CONFIG.enable_detection {false} CONFIG.enable_generation {true} \
  CONFIG.VIDEO_MODE {Custom} \
  CONFIG.GEN_HACTIVE_SIZE {640} CONFIG.GEN_HFRAME_SIZE {800} \
  CONFIG.GEN_HSYNC_START {656} CONFIG.GEN_HSYNC_END {752} \
  CONFIG.GEN_VACTIVE_SIZE {480} CONFIG.GEN_F0_VFRAME_SIZE {525} \
  CONFIG.GEN_F0_VSYNC_VSTART {490} CONFIG.GEN_F0_VSYNC_VEND {492}] $vtc
connect_bd_intf_net [get_bd_intf_pins hdmi_vtc/vtiming_out] [get_bd_intf_pins video_out/vtiming_in]
connect_bd_net [get_bd_pins video_out/vtg_ce] [get_bd_pins hdmi_vtc/gen_clken]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config {Master "/ps7/M_AXI_GP0" Clk "Auto"} [get_bd_intf_pins hdmi_vtc/ctrl]

set hdmi_clk [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 hdmi_clk]
set_property -dict [list CONFIG.PRIM_IN_FREQ {50.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.000} \
  CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {125.000} \
  CONFIG.RESET_TYPE {ACTIVE_LOW}] $hdmi_clk
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins hdmi_clk/clk_in1]
connect_bd_net [get_bd_pins rst_ps7_50M/peripheral_aresetn] [get_bd_pins hdmi_clk/resetn]
set tx [create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 hdmi_tx]
set_property -dict [list CONFIG.kGenerateSerialClk {false} CONFIG.kRstActiveHigh {false}] $tx
connect_bd_intf_net [get_bd_intf_pins video_out/vid_io_out] [get_bd_intf_pins hdmi_tx/RGB]
connect_bd_net [get_bd_pins hdmi_clk/clk_out1] [get_bd_pins {hdmi_tx/PixelClk video_out/vid_io_out_clk hdmi_vtc/clk}]
connect_bd_net [get_bd_pins hdmi_clk/clk_out2] [get_bd_pins hdmi_tx/SerialClk]
set pixel_rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 pixel_reset]
connect_bd_net [get_bd_pins hdmi_clk/clk_out1] [get_bd_pins pixel_reset/slowest_sync_clk]
connect_bd_net [get_bd_pins hdmi_clk/locked] [get_bd_pins pixel_reset/dcm_locked]
connect_bd_net [get_bd_pins rst_ps7_50M/peripheral_reset] [get_bd_pins pixel_reset/ext_reset_in]
connect_bd_net [get_bd_pins pixel_reset/peripheral_aresetn] \
  [get_bd_pins {hdmi_tx/aRst_n hdmi_vtc/resetn video_out/vid_io_out_resetn}]
make_bd_intf_pins_external [get_bd_intf_pins hdmi_tx/TMDS]
set_property name hdmi_out [get_bd_intf_ports TMDS_0]
validate_bd_design
save_bd_design
set bd_file [get_files system.bd]
puts "BD_FILE=$bd_file"
set_property synth_checkpoint_mode None $bd_file
generate_target all $bd_file
set wrapper [make_wrapper -files $bd_file -top]
add_files -norecurse [list $wrapper]
set_property top system_wrapper [current_fileset]
add_files -fileset constrs_1 -norecurse [list [file join $root fpga pcam_system.xdc]]
add_files -fileset constrs_1 -norecurse [list [file join $root fpga hdmi_out.xdc]]
if {[info exists ::env(ZCAM_VALIDATE_ONLY)] && $::env(ZCAM_VALIDATE_ONLY) eq "1"} {
  puts "SYSTEM_BD_VALIDATED=Complete"
  close_project
  exit 0
}
synth_design -top system_wrapper -part xc7z010clg400-1
puts "SYSTEM_SYNTH_STATUS=Complete"
file mkdir [file join $root docs]
report_utilization -file [file join $root docs system_utilization.txt]
report_timing_summary -file [file join $root docs system_timing.txt]
opt_design
place_design
route_design
puts "SYSTEM_ROUTE_STATUS=Complete"
report_utilization -file [file join $root docs system_routed_utilization.txt]
report_timing_summary -file [file join $root docs system_routed_timing.txt]
report_drc -file [file join $root docs system_drc.txt]
write_bitstream -force [file join $build zybo_camera_system.bit]
puts "SYSTEM_BITSTREAM_STATUS=Complete"
close_project

