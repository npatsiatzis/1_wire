#non-project batch flow
#
# NOTE:  typical usage would be "vivado -mode tcl -source 1_wire_npm_batch.tcl"
#
# STEP#0: define output directory area.
#

set outputDir ./single_wire        
file mkdir $outputDir
#
# STEP#1: setup design sources and constraints
#
read_vhdl ../rtl/toggle_synchronizer.vhd 
read_vhdl ../rtl/user_registers.vhd 
read_vhdl ../rtl/clock_divider.vhd 
read_vhdl ../rtl/single_wire.vhd 
read_vhdl ../rtl/single_wire_top.vhd 
set_property file_type {VHDL 2008} [ get_files [ glob ../rtl/*.vhd ] ]

read_xdc ./Basys3_Master.xdc
#
# STEP#2: run synthesis, report utilization and timing estimates, write checkpoint design
#
synth_design -top single_wire_top -part xc7a35tcpg236-1		
write_checkpoint -force $outputDir/post_synth
report_timing_summary -file $outputDir/post_synth_timing_summary.rpt
report_power -file $outputDir/post_synth_power.rpt
#
# STEP#3: run placement and logic optimzation, report utilization and timing estimates, write checkpoint design
#
opt_design
place_design
phys_opt_design
write_checkpoint -force $outputDir/post_place
report_timing_summary -file $outputDir/post_place_timing_summary.rpt
#
# STEP#4: run router, report actual utilization and timing, write checkpoint design, run drc, write verilog and xdc out
#
route_design
write_checkpoint -force $outputDir/post_route
report_timing_summary -file $outputDir/post_route_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/post_route_timing.rpt
report_clock_utilization -file $outputDir/clock_util.rpt
report_utilization -file $outputDir/post_route_util.rpt
report_power -file $outputDir/post_route_power.rpt
report_drc -file $outputDir/post_imp_drc.rpt
write_verilog -force $outputDir/bft_impl_netlist.v
write_xdc -no_fixed_only -force $outputDir/bft_impl.xdc

set WNS [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "Post Route WNS = $WNS"

#
# STEP#5: generate a bitstream
# 
#write_bitstream -force $outputDir/bft.bit
