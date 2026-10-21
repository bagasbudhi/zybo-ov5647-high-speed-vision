# Check fresh camera/HDMI DMA status while both streams continue to run.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
set csi_before [mrd -value 0x43C00010]
mwr 0x43000034 0x0000F990
mwr 0x43000004 0x0000F990
after 500
set csi_after [mrd -value 0x43C00010]
puts [format "CSI_PACKET_COUNT_BEFORE=%u" [expr {($csi_before >> 16) & 0xFFFF}]]
puts [format "CSI_PACKET_COUNT_AFTER=%u" [expr {($csi_after >> 16) & 0xFFFF}]]
puts [format "S2MM_STATUS_FRESH=0x%08X" [mrd -value 0x43000034]]
puts [format "MM2S_STATUS_FRESH=0x%08X" [mrd -value 0x43000004]]
puts [format "DDR_FRAME0_WORD=0x%08X" [mrd -value 0x11000000]]
disconnect
