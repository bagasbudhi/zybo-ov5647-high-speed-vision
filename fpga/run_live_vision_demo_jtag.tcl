# One-command live OV5647 -> Bayer/ROI RTL -> DDR/VDMA -> HDMI demonstration.
# Requires a powered Zybo, working ARM/DAP JTAG, USB JTAG attached, and the
# OV5647 ribbon seated with board power off during insertion.
set root [file normalize [file join [file dirname [info script]] ..]]
set fpga_dir [file join $root fpga]

# Program PL, initialize PS/DDR, power the camera, configure live VGA mode,
# enable auto exposure/gain, and start camera capture plus HDMI playback.
source [file join $fpga_dir start_hdmi_smoke_jtag.tcl]
source [file join $fpga_dir enable_camera_power_jtag.tcl]
source [file join $fpga_dir configure_ov5647_vga_jtag.tcl]
source [file join $fpga_dir set_ov5647_live_controls_jtag.tcl]
source [file join $fpga_dir start_camera_hdmi_jtag.tcl]
source [file join $fpga_dir check_camera_hdmi_jtag.tcl]

proc read_value {address} {
    return [mrd -value $address]
}

connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
loadhw [file join $root artifacts zybo_camera_system.xsa]
set capture_dir [file join $root build capture]
file mkdir $capture_dir
set csv_path [file join $capture_dir live_vision_metrics.csv]
set csv [open $csv_path w]
puts $csv "sample_ms,frame_count,bright_pixels_roi,detected,x_min,x_max,y_min,y_max,s2mm_status,mm2s_status,csi_packet_count"
for {set sample 0} {$sample < 20} {incr sample} {
    set bx [read_value 0x41210008]
    set by [read_value 0x41220000]
    set frame_count [read_value 0x41220008]
    set bright_count [read_value 0x41210000]
    set detected [expr {($bx >> 20) & 1}]
    set xmin [expr {$bx & 0x3FF}]
    set xmax [expr {($bx >> 10) & 0x3FF}]
    set ymin [expr {$by & 0x1FF}]
    set ymax [expr {($by >> 9) & 0x1FF}]
    set s2mm [read_value 0x43000034]
    set mm2s [read_value 0x43000004]
    set csi [expr {([read_value 0x43C00010] >> 16) & 0xFFFF}]
    set sample_ms [expr {$sample * 500}]
    puts $csv "$sample_ms,$frame_count,$bright_count,$detected,$xmin,$xmax,$ymin,$ymax,$s2mm,$mm2s,$csi"
    flush $csv
    puts [format "LIVE_METRIC t=%dms frames=%u hits=%u detected=%u bbox=(%u,%u)-(%u,%u) s2mm=0x%08X mm2s=0x%08X csi_packets=%u" \
        $sample_ms $frame_count $bright_count $detected $xmin $ymin $xmax $ymax $s2mm $mm2s $csi]
    after 500
}
close $csv
puts "LIVE_METRICS_CSV=$csv_path"
disconnect
