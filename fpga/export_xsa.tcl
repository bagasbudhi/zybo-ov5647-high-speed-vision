set root [file normalize [file join [file dirname [info script]] ..]]
set build [file join $root build system]
set_param board.repoPaths [list [file join $root fpga board_files]]
open_project [file join $build zybo_camera_system.xpr]
# Vitis 2025.2 accepts a standalone platform only when the XSA declares
# embedded design intent. The default Vivado export marks this false.
set_property platform.design_intent.embedded true [current_project]
# The in-process place/route flow has no project implementation run, so the
# separate .bit cannot be selected with -include_bit here.
write_hw_platform -fixed -force [file join $build zybo_camera_system.xsa]
close_project
