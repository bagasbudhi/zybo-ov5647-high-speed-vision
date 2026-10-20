# Raspberry Pi Camera Rev 1.3 CAM_IO0 power-enable probe.
# Requires the GPIO-enabled bitstream/XSA. Drives only Pcam pin 11 (G20).
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts "ZCAM_POWER_GPIO_BEFORE=[mrd 0x41200000]"
mwr 0x41200000 0x00000000
mwr 0x41200004 0x00000000
mwr 0x41200000 0x00000001
after 50
puts "ZCAM_POWER_GPIO_AFTER=[mrd 0x41200000]"
puts "ZCAM_POWER_GPIO_TRI=[mrd 0x41200004]"
disconnect
