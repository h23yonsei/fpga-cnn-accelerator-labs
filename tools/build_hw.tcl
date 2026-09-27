# Build one lab from the committed sources with Vivado's non-project flow.
#
#   vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs <lab>
#
#   <lab>   counter | fsm | vending | uart    Arty S7-50 (xc7s50csga324-1): synthesis, implementation
#                                            and bitstream with the lab's pin constraints
#           cnn                              the CNN core (top_cnn) on the Zynq-7020 (xc7z020clg400-1),
#                                            out of context with constraints/cnn_ooc.xdc
#
# Run from the repository root with Vivado 2022.1. Results go to build/hw/<lab>/:
# utilization_placed.rpt, utilization_hierarchical_synth.rpt, timing_summary_routed.rpt and, for the
# board labs, <top>.bit. The Block Memory Generator cores are the behavioral models committed in
# each lab's rtl/ directory, so Vivado infers block RAM from them.

if {[llength $argv] != 1} {
    puts "usage: vivado -mode batch -source tools/build_hw.tcl -tclargs <counter|fsm|vending|uart|cnn>"
    exit 1
}
set lab  [lindex $argv 0]
set repo [file normalize [file dirname [info script]]/..]

#          lab       directory                      top              part               constraints          board
set labs {
    counter {02-counter-and-fsm/counter  top_counter      xc7s50csga324-1  constraints/arty_s7.xdc  1}
    fsm     {02-counter-and-fsm/fsm      top_fsm          xc7s50csga324-1  constraints/arty_s7.xdc  1}
    vending {03-vending-machine          vending_machine  xc7s50csga324-1  constraints/arty_s7.xdc  1}
    uart    {06-uart-loopback            top_loopback     xc7s50csga324-1  constraints/arty_s7.xdc  1}
    cnn     {09-cnn-accelerator          top_cnn          xc7z020clg400-1  constraints/cnn_ooc.xdc  0}
}
if {![dict exists $labs $lab]} {
    puts "BUILD: FAILED - unknown lab '$lab'"
    exit 1
}
lassign [dict get $labs $lab] dir top part xdc board

# Work with paths relative to the repository root: Vivado's file arguments are lists, so an absolute
# path containing a space would be split in two.
cd $repo
set src $dir
set out build/hw/$lab
file delete -force $out
file mkdir $out

read_verilog [glob $src/rtl/*.v]
read_xdc [list $src/$xdc]

if {$board} {
    synth_design -top $top -part $part
} else {
    synth_design -top $top -part $part -mode out_of_context
}
report_utilization -hierarchical -file $out/utilization_hierarchical_synth.rpt

opt_design
place_design
phys_opt_design
report_utilization -file $out/utilization_placed.rpt
route_design
report_timing_summary -max_paths 10 -report_unconstrained -file $out/timing_summary_routed.rpt

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "BUILD: $lab top=$top part=$part WNS=$wns ns"
if {$board} {
    write_bitstream -force $out/$top.bit
    puts "BUILD: bitstream $out/$top.bit"
}
puts "BUILD: OK - $lab"
exit 0
