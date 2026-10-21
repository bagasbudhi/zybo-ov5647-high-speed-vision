# Enable live OV5647 auto exposure and gain after VGA mode setup.
# Keeps the sensor test-pattern generator disabled.
set root [file normalize [file join [file dirname [info script]] ..]]

proc write_sensor {address value} {
    mwr 0x41600040 0x0000000A
    mwr 0x41600100 0x00000002
    mwr 0x41600100 0x00000001
    mwr 0x41600108 0x0000016C
    mwr 0x41600108 [expr {($address >> 8) & 0xFF}]
    mwr 0x41600108 [expr {$address & 0xFF}]
    mwr 0x41600108 [expr {0x200 | $value}]
    after 5
    set isr [mrd -value 0x41600020]
    if {$isr & 0x02} {
        error [format "IIC write error at 0x%04X" $address]
    }
}

connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
if {[mrd -value 0x41200000] != 1} {
    error "CAM_IO0 is low; run fpga/enable_camera_power_jtag.tcl first"
}
write_sensor 0x503D 0x00
write_sensor 0x3503 0x00
after 500
puts "OV5647_TEST_PATTERN=disabled"
puts "OV5647_EXPOSURE_GAIN=auto"
disconnect
