# Dump a stopped S2MM frame buffer to an ignored build artifact.
set root [file normalize [file join [file dirname [info script]] ..]]
set label colorbars
if {$argc > 0} {set label [lindex $argv 0]}
if {![regexp {^[a-zA-Z0-9_]+$} $label]} {
    error "Frame label must contain only letters, digits, and underscores"
}
set output [file join $root build capture "ov5647_${label}_640x480.raw"]
file mkdir [file dirname $output]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
if {[expr {[mrd -value 0x43000034] & 1}] != 1} {
    error "S2MM must be stopped before dumping a coherent frame"
}
mrd -bin -file $output 0x11000000 76800
puts "FRAME_DUMP=$output"
puts "FRAME_BYTES=[file size $output]"
disconnect
