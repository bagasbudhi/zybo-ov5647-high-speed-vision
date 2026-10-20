connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
set root [file normalize [file join [file dirname [info script]] ..]]
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts "ZCAM_IIC_CR=[mrd 0x41600100]"
puts "ZCAM_IIC_SR=[mrd 0x41600104]"
puts "ZCAM_IIC_ISR=[mrd 0x41600020]"
puts "ZCAM_IIC_TX_OCC=[mrd 0x41600114]"
puts "ZCAM_IIC_RX_OCC=[mrd 0x41600118]"
disconnect
