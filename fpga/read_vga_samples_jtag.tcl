# Inspect sparse, stopped S2MM buffers after capture_vga_probe_jtag.tcl.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
foreach base {0x11000000 0x11080000 0x11100000} {
    puts [format "FRAME_BASE=0x%08X" $base]
    foreach y {0 120 240 360 479} {
        foreach x {0 80 160 240 320 400 480 560 636} {
            set address [expr {$base + $y * 640 + $x}]
            puts [format "PIXEL_WORD_%03d_%03d=%s" $x $y [mrd $address]]
        }
    }
}
disconnect
