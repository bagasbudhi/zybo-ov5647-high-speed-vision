# Reversible first sensor-write check: put OV5647 in software standby.
# AXI IIC dynamic TX FIFO: START+write address, 16-bit register, STOP+data.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts "ZCAM_CAM_POWER=[mrd 0x41200000]"
mwr 0x41600040 0x0000000A
mwr 0x41600100 0x00000002
mwr 0x41600100 0x00000001
mwr 0x41600108 0x0000016C
mwr 0x41600108 0x00000001
mwr 0x41600108 0x00000000
mwr 0x41600108 0x00000200
after 20
puts "ZCAM_WRITE_STANDBY_SR=[mrd 0x41600104]"
puts "ZCAM_WRITE_STANDBY_ISR=[mrd 0x41600020]"
puts "ZCAM_WRITE_STANDBY_TX_OCC=[mrd 0x41600114]"
disconnect
