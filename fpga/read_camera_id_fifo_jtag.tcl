# Read two bytes already returned by the AXI IIC chip-ID transaction.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts "ZCAM_ID_RX_OCC_BEFORE=[mrd 0x41600118]"
puts "ZCAM_ID_BYTE_HIGH=[mrd 0x4160010C]"
puts "ZCAM_ID_BYTE_LOW=[mrd 0x4160010C]"
puts "ZCAM_ID_RX_OCC_AFTER=[mrd 0x41600118]"
disconnect
