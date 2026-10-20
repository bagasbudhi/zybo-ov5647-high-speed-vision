set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
mwr 0x41600100 0x00000000
mwr 0x41600040 0x0000000A
puts "ZCAM_IIC_RESET_CR=[mrd 0x41600100]"
puts "ZCAM_IIC_RESET_SR=[mrd 0x41600104]"
disconnect
