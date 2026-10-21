# Synthesize the standalone quantized patch-classifier RTL for the Zybo Z7-10.
# This does not insert the neural block into the camera/HDMI system.
set root [file normalize [file join [file dirname [info script]] ..]]
set rtl [file join $root rtl]
create_project -in_memory tiny_patch_mlp -part xc7z010clg400-1
set_property include_dirs [list $rtl] [current_fileset]
add_files -norecurse [list [file join $rtl tiny_patch_mlp.sv]]
synth_design -top tiny_patch_mlp -part xc7z010clg400-1
file mkdir [file join $root docs]
report_utilization -file [file join $root docs tiny_nn_synthesis_utilization.txt]
puts "TINY_NN_SYNTHESIS=Complete"
close_project
