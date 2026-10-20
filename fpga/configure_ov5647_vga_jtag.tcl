# Configure Raspberry Pi Camera Rev 1.3 / OV5647 for 640x480 RAW10.
# Register tables in ov5647_vga_regs.tcl are derived from the GPL-2.0 Linux driver.
# Requires the programmed FPGA, initialized PS, and camera power GPIO high.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join [file dirname [info script]] ov5647_vga_regs.tcl]

proc read_word {address} {
    set response [mrd $address]
    if {![regexp {:\s*([[:xdigit:]]+)} $response -> digits]} {
        error "Cannot parse mrd response: $response"
    }
    scan $digits %x value
    return $value
}

proc write_sensor {address value} {
    # Reset and flush IIC for each independent dynamic-mode transaction.
    mwr 0x41600040 0x0000000A
    mwr 0x41600100 0x00000002
    mwr 0x41600100 0x00000001
    mwr 0x41600108 0x0000016C
    mwr 0x41600108 [expr {($address >> 8) & 0xFF}]
    mwr 0x41600108 [expr {$address & 0xFF}]
    mwr 0x41600108 [expr {0x200 | $value}]
    after 5
    set status [read_word 0x41600104]
    set interrupt [read_word 0x41600020]
    if {($interrupt & 0x02) || ($status & 0x04)} {
        error [format "IIC error writing 0x%04X=0x%02X: SR=0x%08X ISR=0x%08X" $address $value $status $interrupt]
    }
}

connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
if {[read_word 0x41200000] != 1} {
    error "CAM_IO0 is low; run fpga/enable_camera_power_jtag.tcl first"
}
puts [format "CSI_ISR_BEFORE=0x%08X" [read_word 0x43C00024]]

set count 0
foreach pair $ov5647_common_regs {
    lassign $pair address value
    write_sensor $address $value
    incr count
    if {$address == 0x0103} {after 20}
}
foreach pair $ov5647_vga_regs {
    lassign $pair address value
    if {$address == 0x0100} {continue}
    write_sensor $address $value
    incr count
}

# Linux driver applies timing controls and stream-specific registers after mode selection.
foreach pair {
    {0x380C 0x07} {0x380D 0x3C}
    {0x380E 0x01} {0x380F 0xF8}
    {0x4814 0x00} {0x4800 0x04}
    {0x4202 0x00} {0x300D 0x00}
} {
    lassign $pair address value
    write_sensor $address $value
    incr count
}

# Sensor-generated color bars isolate CSI link tests from optics and illumination.
write_sensor 0x503D 0x80
incr count
write_sensor 0x0100 0x01
incr count
after 100
puts "OV5647_REGISTER_WRITES=$count"
puts [format "CSI_CORE_CONFIG=0x%08X" [read_word 0x43C00000]]
puts [format "CSI_CORE_STATUS=0x%08X" [read_word 0x43C00010]]
puts [format "CSI_ISR_AFTER=0x%08X" [read_word 0x43C00024]]
puts [format "CSI_CLK_LANE=0x%08X" [read_word 0x43C0003C]]
puts [format "CSI_DATA_LANE0=0x%08X" [read_word 0x43C00040]]
puts [format "CSI_DATA_LANE1=0x%08X" [read_word 0x43C00044]]
disconnect
