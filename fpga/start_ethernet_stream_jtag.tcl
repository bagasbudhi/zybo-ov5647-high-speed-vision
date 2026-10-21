# Start live OV5647 Bayer8 UDP streaming from Zybo Z7-10 to laptop port 5005.
# Requires the board powered over 5V, USB JTAG attached, and Ethernet link up.
set root [file normalize [file join [file dirname [info script]] ..]]
set fpga_dir [file join $root fpga]
set bitfile [file join $root artifacts zybo_camera_system.bit]
set xsa [file join $root artifacts zybo_camera_system.xsa]
set elf [file join $root build ethernet_stream.elf]
set ps_init [file join $root build jtag ps7_init.tcl]
set bars [file join $root build jtag hdmi_bars_640x480.bin]
foreach f [list $bitfile $xsa $elf $ps_init $bars] {
    if {![file exists $f]} {error "Required build file missing: $f"}
}

connect
if {[catch {targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}} target_error]} {
    set found [targets]
    disconnect
    error "Cannot start camera streaming because the PS ARM/DAP target is unavailable. Targets: $found. Fully power-cycle the Zybo, reconnect USB JTAG, then rerun this script. Original error: $target_error"
}
catch {stop}
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #1"}
catch {stop}
targets -set -filter {name =~ "xc7z010"}
fpga $bitfile

# Initialize the Zynq PS and DDR before using the camera setup scripts or ELF.
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw $xsa
source $ps_init
ps7_init
ps7_post_config

# The video pipeline reset is synchronized to the HDMI pixel clock. Start VTC
# and a known DDR frame first, even when HDMI is not connected to a display.
dow -data $bars 0x10000000
mwr 0x43C10000 0x01ffff07
mwr 0x43000000 0x00000003
mwr 0x4300005C 0x10000000
mwr 0x43000060 0x10000000
mwr 0x43000064 0x10000000
mwr 0x43000058 640
mwr 0x43000054 640
mwr 0x43000050 480
after 100
disconnect

# Camera power-enable and OV5647 live VGA RAW10 setup through PS IIC.
source [file join $fpga_dir enable_camera_power_jtag.tcl]
set argc 1
set argv [list live]
source [file join $fpga_dir configure_ov5647_vga_jtag.tcl]
set argc 0
set argv {}
source [file join $fpga_dir set_ov5647_live_controls_jtag.tcl]

# The Ethernet firmware starts three-buffer VDMA capture and broadcasts ZCAM
# Bayer8 datagrams to 169.254.255.255:5005. Host uses wildcard UDP bind.
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw $xsa
dow $elf
con
after 500
# Display the camera buffers on HDMI after the S2MM capture channel has started.
mwr 0x4300005C 0x11000000
mwr 0x43000060 0x11080000
mwr 0x43000064 0x11100000
mwr 0x43000058 640
mwr 0x43000054 640
mwr 0x43000050 480
after 1000
# S2MM can latch a transient SOF/EOL error when it starts in the middle of
# a live sensor frame. PG020 recommends clearing those W1C status bits; the
# next complete frame then advances the write frame store pointer.
mwr 0x43000034 0x0000F990
after 3000
# The first clear can land while the camera is still settling. Clear any
# latched startup error once more before judging capture health.
mwr 0x43000034 0x0000F990
after 1000
set s2mm_status [mrd -value 0x43000034]
puts [format "S2MM_STATUS_AFTER_CLEAR=0x%08X" $s2mm_status]
if {$s2mm_status & 0x0000F991} {
    puts "WARNING: S2MM has a startup error; run fpga/clear_s2mm_startup_error_jtag.tcl after the sensor settles"
}
puts "ZCAM_ETHERNET_SENDER_RUNNING board_ip=169.254.80.26 udp_port=5005"
disconnect
