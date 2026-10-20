open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet *]
puts "ZCAM_HW_TARGETS=$targets"
foreach target $targets {
    if {[catch {open_hw_target $target} err]} {
        puts "ZCAM_OPEN_TARGET_ERROR=$target $err"
        continue
    }
    puts "ZCAM_HW_DEVICES=[get_hw_devices -quiet *]"
    foreach device [get_hw_devices -quiet *] {
        puts "ZCAM_HW_DEVICE_PART=[get_property PART $device]"
        puts "ZCAM_HW_DEVICE_NAME=[get_property NAME $device]"
    }
    close_hw_target
}
disconnect_hw_server
close_hw_manager
