# Read only the OV5647 chip ID through AXI IIC at 0x41600000.
# 7-bit sensor address 0x36; register pointer 0x300A; expect 0x56, 0x47.
# AXI IIC dynamic-mode sequence follows AMD PG090. No camera GPIO is driven.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts "ZCAM_IIC_BEFORE_SR=[mrd 0x41600104]"
mwr 0x41600040 0x0000000A
mwr 0x41600120 0x0000000F
mwr 0x41600100 0x00000002
mwr 0x41600100 0x00000001
mwr 0x41600108 0x0000016C
mwr 0x41600108 0x00000030
mwr 0x41600108 0x0000000A
mwr 0x41600108 0x0000016D
mwr 0x41600108 0x00000202
after 200
puts "ZCAM_IIC_AFTER_CR=[mrd 0x41600100]"
puts "ZCAM_IIC_AFTER_SR=[mrd 0x41600104]"
puts "ZCAM_IIC_AFTER_ISR=[mrd 0x41600020]"
puts "ZCAM_IIC_AFTER_TX_OCC=[mrd 0x41600114]"
puts "ZCAM_IIC_AFTER_RX_OCC=[mrd 0x41600118]"
disconnect
