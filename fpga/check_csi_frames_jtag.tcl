# Check continued CSI-2 activity after configure_ov5647_vga_jtag.tcl.
set root [file normalize [file join [file dirname [info script]] ..]]
proc read_word {address} {
    set response [mrd $address]
    if {![regexp {:\s*([[:xdigit:]]+)} $response -> digits]} {
        error "Cannot parse mrd response: $response"
    }
    scan $digits %x value
    return $value
}
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
set before [read_word 0x43C00010]
set isr_before [read_word 0x43C00024]
# The ISR is write-one-to-clear. Clear prior sticky events so this window
# reports events that occur while the current sensor mode is running.
mwr 0x43C00024 0xFFFFFFFF
after 250
set after [read_word 0x43C00010]
set isr_after [read_word 0x43C00024]
set info1 [read_word 0x43C00060]
set info2 [read_word 0x43C00064]
puts [format "CSI_PACKET_COUNT_BEFORE=%u" [expr {($before >> 16) & 0xFFFF}]]
puts [format "CSI_PACKET_COUNT_AFTER=%u" [expr {($after >> 16) & 0xFFFF}]]
puts [format "CSI_ISR_BEFORE=0x%08X" $isr_before]
puts [format "CSI_ISR_AFTER_CLEAR_WAIT=0x%08X" $isr_after]
puts [format "CSI_VC0_IMAGE_INFO1=0x%08X" $info1]
puts [format "CSI_VC0_IMAGE_INFO2=0x%08X" $info2]
disconnect
