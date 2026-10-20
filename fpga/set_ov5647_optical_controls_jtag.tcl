# Stop internal test bars; set manual exposure/gain for optical VGA capture.
# Values follow the pinned Linux driver's 500-line VGA maximum and gain 32.
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
foreach pair {
    {0x3503 0x03}
    {0x3500 0x00} {0x3501 0x1F} {0x3502 0x40}
    {0x350A 0x00} {0x350B 0x20}
    {0x503D 0x00}
} {
    lassign $pair address value
    write_sensor $address $value
}
puts "OV5647_OPTICAL_EXPOSURE_LINES=500"
puts "OV5647_OPTICAL_ANALOG_GAIN=32"
puts "OV5647_TEST_PATTERN=disabled"
disconnect
