set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts "ZCAM_VTC_CONTROL=[mrd 0x43C10000]"
puts "ZCAM_VDMA_CONTROL=[mrd 0x43000000]"
puts "ZCAM_VDMA_STATUS=[mrd 0x43000004]"
puts "ZCAM_BAR0=[mrd 0x10000000]"
puts "ZCAM_BAR1=[mrd 0x10000050]"
puts "ZCAM_BAR2=[mrd 0x100000A0]"
disconnect
