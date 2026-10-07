set root [file normalize [file join [file dirname [info script]] ..]]
set build [file join $root build system]
set_param board.repoPaths [list [file join $root fpga board_files]]
open_project [file join $build zybo_camera_system.xpr]
# The in-process place/route flow has no project implementation run, so the
# separate .bit cannot be selected with -include_bit here.
write_hw_platform -fixed -force [file join $build zybo_camera_system.xsa]
close_project
