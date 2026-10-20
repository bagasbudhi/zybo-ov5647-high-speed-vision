# Read the camera-enable GPIO output register without changing it.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts "ZCAM_POWER_GPIO_DATA=[mrd 0x41200000]"
puts "ZCAM_POWER_GPIO_TRI=[mrd 0x41200004]"
disconnect
