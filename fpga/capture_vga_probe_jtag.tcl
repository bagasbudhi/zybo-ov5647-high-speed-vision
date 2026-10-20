# Probe AXI VDMA S2MM capture into three reserved DDR buffers.
# Requires PS DDR init and a running OV5647 VGA mode. Volatile only.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts "S2MM_STATUS_BEFORE=[mrd 0x43000034]"
mwr 0x11000000 0xA5A50100
mwr 0x11080000 0xA5A50200
mwr 0x11100000 0xA5A50300
puts "DDR_FRAME0_SENTINEL=[mrd 0x11000000]"
puts "DDR_FRAME1_SENTINEL=[mrd 0x11080000]"
puts "DDR_FRAME2_SENTINEL=[mrd 0x11100000]"
mwr 0x43000030 0x00000004
after 20
mwr 0x43000030 0x00000003
mwr 0x430000AC 0x11000000
mwr 0x430000B0 0x11080000
mwr 0x430000B4 0x11100000
mwr 0x430000A8 640
mwr 0x430000A4 640
mwr 0x430000A0 480
after 500
puts "S2MM_CONTROL_RUNNING=[mrd 0x43000030]"
puts "S2MM_STATUS_RUNNING=[mrd 0x43000034]"
puts "VDMA_PARK_PTR=[mrd 0x43000028]"
# Clear sticky startup status while streaming, then observe fresh flags.
mwr 0x43000034 0x0000F990
after 500
puts "S2MM_STATUS_FRESH=[mrd 0x43000034]"
puts "DDR_FRAME0_FIRST=[mrd 0x11000000]"
puts "DDR_FRAME0_MIDDLE=[mrd 0x11026000]"
puts "DDR_FRAME1_FIRST=[mrd 0x11080000]"
puts "DDR_FRAME2_FIRST=[mrd 0x11100000]"
mwr 0x43000030 0x00000000
after 20
puts "S2MM_STATUS_STOPPED=[mrd 0x43000034]"
disconnect
