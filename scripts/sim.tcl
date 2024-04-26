if {[llength $argv] != 2} {
	puts stderr "Usage: $argv0 <condition>"
	exit 1
}
lassign $argv test_name gui

set source_files [glob "./rtl/*.sv"]

if {$test_name == "crossbar_3x4"} {
	set tb_files ./tb/tb_stream_xbar_3x4.sv
} elseif {$test_name == "crossbar_3x3"} {
	set tb_files ./tb/tb_stream_xbar_3x3.sv
} elseif {$test_name == "crossbar_1x1"} {
	set tb_files ./tb/tb_stream_xbar_1x1.sv
}

if {$gui == 1} {
	start_gui
}

create_project simulation ./tmp/sim_output

add_files -fileset sources_1 $source_files
add_files -fileset sim_1 $tb_files

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation