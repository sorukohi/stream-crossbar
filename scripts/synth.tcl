set output_dir ./tmp/synth_output             
file mkdir $output_dir

read_verilog  [ glob ./rtl/*.sv ]
read_xdc ./constrs/clk.xdc

synth_design -top stream_xbar -part xc7a100tcsg324-1
write_checkpoint -force $output_dir/post_synth
report_timing_summary -file $output_dir/post_synth_timing_summary.rpt
report_utilization -file $output_dir/post_synth_utilization.rpt
report_power -file $output_dir/post_synth_power.rpt