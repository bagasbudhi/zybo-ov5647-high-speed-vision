# Read detector and frame-counter AXI GPIO registers over the ARM DAP/JTAG.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
set bright_count [mrd -value 0x41210000]
set bbox_x [mrd -value 0x41210008]
set bbox_y [mrd -value 0x41220000]
set frame_count [mrd -value 0x41220008]
puts [format "DETECTOR_FRAME_COUNT=%u" $frame_count]
puts [format "BRIGHT_PIXELS_IN_ROI_LAST_FRAME=%u" $bright_count]
puts [format "OBJECT_DETECTED=%u" [expr {($bbox_x >> 20) & 1}]]
puts [format "BBOX_X_MIN=%u" [expr {$bbox_x & 0x3FF}]]
puts [format "BBOX_X_MAX=%u" [expr {($bbox_x >> 10) & 0x3FF}]]
puts [format "BBOX_Y_MIN=%u" [expr {$bbox_y & 0x1FF}]]
puts [format "BBOX_Y_MAX=%u" [expr {($bbox_y >> 9) & 0x1FF}]]
puts [format "S2MM_STATUS=0x%08X" [mrd -value 0x43000034]]
puts [format "MM2S_STATUS=0x%08X" [mrd -value 0x43000004]]
disconnect
