# Run from the repository root with XSCT. Programs volatile PL and initializes
# PS/DDR, then plays a known 640x480 grayscale frame from DDR through HDMI.
# This does not configure the OV5647 or write board flash/storage.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
puts "ZCAM_TARGETS=[targets]"
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
stop
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #1"}
stop
targets -set -filter {name =~ "xc7z010"}
fpga [file join $root artifacts zybo_camera_system.bit]
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
source [file join $root build jtag ps7_init.tcl]
ps7_init
ps7_post_config
dow -data [file join $root build jtag hdmi_bars_640x480.bin] 0x10000000

# VTC generation and circular VDMA MM2S. Addresses are from system.hwh.
mwr 0x43C10000 0x01ffff07
mwr 0x43000000 0x00000003
mwr 0x4300005C 0x10000000
mwr 0x43000060 0x10000000
mwr 0x43000064 0x10000000
mwr 0x43000058 640
mwr 0x43000054 640
mwr 0x43000050 480
after 1000
puts "ZCAM_VTC_CONTROL=[mrd 0x43C10000]"
puts "ZCAM_VDMA_MM2S_CONTROL=[mrd 0x43000000]"
puts "ZCAM_VDMA_MM2S_STATUS=[mrd 0x43000004]"
puts "ZCAM_DDR_FIRST_WORD=[mrd 0x10000000]"
puts "ZCAM_HDMI_SMOKE_SETUP_DONE"
disconnect
