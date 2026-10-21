# Clear latched VDMA S2MM SOF/EOL startup status after OV5647 video settles.
# The board application continues running; no bitstream or ELF is reloaded.
set root [file normalize [file join [file dirname [info script]] ..]]
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
puts [format "S2MM_BEFORE=0x%08X" [mrd -value 0x43000034]]
mwr 0x43000034 0x0000F990
after 1000
set status [mrd -value 0x43000034]
puts [format "S2MM_AFTER=0x%08X" $status]
puts [format "VDMA_PARK=0x%08X" [mrd -value 0x43000028]]
disconnect
if {$status & 0x0000F991} {
    error "S2MM still has an error; inspect camera timing and VDMA configuration"
}
