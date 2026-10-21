# Display live OV5647 Bayer8 frames via RTL demosaic and ROI detection on HDMI TX.
# Run after the HDMI smoke setup,
# camera power enable, sensor mode configuration, and optical controls scripts.
# Uses three 640x480 grayscale frame buffers in DDR, with separate S2MM/MM2S
# VDMA channels. This only changes volatile DDR/FPGA registers.
set root [file normalize [file join [file dirname [info script]] ..]]

proc read_word {address} {
    set response [mrd $address]
    if {![regexp {:\s*([[:xdigit:]]+)} $response -> digits]} {
        error "Cannot parse mrd response: $response"
    }
    scan $digits %x value
    return $value
}

connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]

if {[read_word 0x41200000] != 1} {
    error "Camera power is off; run fpga/enable_camera_power_jtag.tcl first"
}

puts [format "CSI_PACKET_COUNT_BEFORE=%u" [expr {([read_word 0x43C00010] >> 16) & 0xFFFF}]]

# Stop and clear both directions before assigning the three DDR frame slots.
mwr 0x43000030 0x00000000
mwr 0x43000000 0x00000000
after 20
mwr 0x43000034 0x0000F990
mwr 0x43000004 0x0000F990

# Camera RAW10 is converted to one Bayer8 byte per pixel by the custom RTL.
# Frame buffers have 512 KiB spacing; each 640x480 image occupies 300 KiB.
mwr 0x43000030 0x00000004
after 20
mwr 0x43000030 0x00000003
mwr 0x430000AC 0x11000000
mwr 0x430000B0 0x11080000
mwr 0x430000B4 0x11100000
mwr 0x430000A8 640
mwr 0x430000A4 640
mwr 0x430000A0 480

# Play the same circular buffer set through the Bayer-to-RGB/ROI HDMI path.
mwr 0x43000000 0x00000004
after 20
mwr 0x43000000 0x00000003
mwr 0x4300005C 0x11000000
mwr 0x43000060 0x11080000
mwr 0x43000064 0x11100000
mwr 0x43000058 640
mwr 0x43000054 640
mwr 0x43000050 480

after 1000
puts [format "CSI_PACKET_COUNT_AFTER=%u" [expr {([read_word 0x43C00010] >> 16) & 0xFFFF}]]
puts [format "S2MM_CONTROL=0x%08X" [read_word 0x43000030]]
puts [format "S2MM_STATUS=0x%08X" [read_word 0x43000034]]
puts [format "MM2S_CONTROL=0x%08X" [read_word 0x43000000]]
puts [format "MM2S_STATUS=0x%08X" [read_word 0x43000004]]
puts [format "DDR_FRAME0_WORD=0x%08X" [read_word 0x11000000]]
puts "ZCAM_CAMERA_TO_HDMI_RUNNING"
disconnect
