# Read OV5647 software-standby register 0x0100; expect 0 after standby write.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
mwr 0x41600040 0x0000000A
mwr 0x41600120 0x0000000F
mwr 0x41600100 0x00000002
mwr 0x41600100 0x00000001
mwr 0x41600108 0x0000016C
mwr 0x41600108 0x00000001
mwr 0x41600108 0x00000000
mwr 0x41600108 0x0000016D
mwr 0x41600108 0x00000201
after 20
puts "ZCAM_STANDBY_RX_OCC=[mrd 0x41600118]"
puts "ZCAM_STANDBY_VALUE=[mrd 0x4160010C]"
disconnect
