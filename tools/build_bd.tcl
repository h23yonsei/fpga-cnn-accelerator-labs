# Rebuild a Zynq block-design lab (PS7 + AXI + custom IP) from the committed sources.
#
#   vivado -mode batch -nojournal -source tools/build_bd.tcl -tclargs <axi|sobel|cnn>
#
#   axi    07-axi-custom-ip    memory controller IP + control/status register IP
#   sobel  08-sobel-filter     Sobel filter IP + control/status register IP
#   cnn    09-cnn-accelerator  CNN accelerator IP + control/status/result register IP
#
# The course projects' packaged IP (component.xml) was not kept, so the custom cores are re-packaged
# from their HDL under the names the saved block designs refer to (xilinx.com:user:<name>:1.0). The
# block design (bd/design_1.bd, saved by Vivado 2021.1) is imported into a fresh project, its Xilinx
# IP is upgraded, and the design is implemented through bitstream and exported as an .xsa.
# Run with Vivado 2022.1; everything is written under build/bd/<lab>/ and no file in the repository
# is modified.
#
# Variables carry a bdb_ prefix: Vivado sources its own scripts into the global namespace during IP
# generation, and those overwrite common names such as `dir`. Paths are absolute and passed wrapped
# in [list ...], because Vivado's file arguments are lists and the repository path may contain a space.

if {[llength $argv] != 1} {
    puts "usage: vivado -mode batch -source tools/build_bd.tcl -tclargs <axi|sobel|cnn>"
    exit 1
}
set bdb_lab  [lindex $argv 0]
set bdb_repo [file normalize [file dirname [info script]]/..]
set bdb_part xc7z020clg400-1

#        lab     directory           register IP (dir, top, name)  core IP (name, top module)          constraints
set bdb_labs {
    axi   {07-axi-custom-ip    csr_1.0  csr_v1_0   csr   top_memory_ctrlr  top_memory_ctrlr  {}}
    sobel {08-sobel-filter     csr_1.0  csr_v1_0   csr   top_memory_ctrlr  top_memory_ctrlr  constraints/pynq_z2.xdc}
    cnn   {09-cnn-accelerator  csrr_1.0 csrr_v1_0  csrr  top               top_cnn           constraints/pynq_z2.xdc}
}
if {![dict exists $bdb_labs $bdb_lab]} {
    puts "BUILD: FAILED - unknown lab '$bdb_lab'"
    exit 1
}
lassign [dict get $bdb_labs $bdb_lab] bdb_src bdb_regdir bdb_regtop bdb_regname bdb_corename bdb_coretop bdb_xdc
set bdb_src $bdb_repo/$bdb_src
set bdb_out $bdb_repo/build/bd/$bdb_lab
file delete -force $bdb_out
file mkdir $bdb_out/ip_repo
# Vivado writes some files (such as NA/ps7_summary.html) to the working directory
cd $bdb_out

proc bdb_package_ip {name top files out part} {
    create_project -force pkg_$name $out/pkg_$name -part $part
    add_files -norecurse $files
    set_property top $top [current_fileset]
    update_compile_order -fileset sources_1
    ipx::package_project -root_dir $out/ip_repo/$name -vendor xilinx.com -library user \
        -taxonomy /UserIP -import_files -set_current true
    set core [ipx::current_core]
    set_property name $name $core
    set_property version 1.0 $core
    set_property display_name $name $core
    ipx::create_xgui_files $core
    ipx::update_checksums $core
    ipx::check_integrity $core
    ipx::save_core $core
    close_project
    puts "BUILD: packaged xilinx.com:user:$name:1.0 (top $top)"
}

bdb_package_ip $bdb_regname  $bdb_regtop  [glob $bdb_src/ip/$bdb_regdir/hdl/*.v] $bdb_out $bdb_part
bdb_package_ip $bdb_corename $bdb_coretop [glob $bdb_src/rtl/*.v]               $bdb_out $bdb_part

create_project -force $bdb_lab $bdb_out/proj -part $bdb_part
set_property ip_repo_paths [list $bdb_out/ip_repo] [current_project]
update_ip_catalog -rebuild

import_files -norecurse [list $bdb_src/bd/design_1.bd]
set bdb_bd [get_files design_1.bd]
open_bd_design $bdb_bd
set bdb_stale [get_ips -quiet -filter {UPGRADE_VERSIONS != ""}]
if {[llength $bdb_stale]} { upgrade_ip $bdb_stale }

# The CNN core meets timing at 100 MHz, so the clock wizard that divided the PS clock down to 50 MHz
# is removed and FCLK_CLK0 (100 MHz) drives everything the wizard's output drove. The saved block
# design is left as it was; this edit is made in the build project only.
if {$bdb_lab eq "cnn"} {
    set bdb_clk_net [get_bd_nets clk_wiz_0_clk_out1]
    set bdb_sinks   [get_bd_pins -of_objects $bdb_clk_net -filter {DIR == I}]
    delete_bd_objs $bdb_clk_net [get_bd_nets processing_system7_0_FCLK_CLK0] [get_bd_cells clk_wiz_0]
    connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] $bdb_sinks
    puts "BUILD: clock wizard removed; FCLK_CLK0 (100 MHz) clocks [llength $bdb_sinks] pins"
}
assign_bd_address -quiet
validate_bd_design
save_bd_design

generate_target all $bdb_bd
make_wrapper -files $bdb_bd -top -import
set_property top design_1_wrapper [current_fileset]
if {$bdb_xdc ne ""} { add_files -fileset constrs_1 -norecurse [list $bdb_src/$bdb_xdc] }
update_compile_order -fileset sources_1
puts "BUILD: block design imported, IP upgraded, wrapper generated"

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%" ||
    ![string match "*Complete*" [get_property STATUS [get_runs impl_1]]]} {
    puts "BUILD: FAILED - synth_1: [get_property STATUS [get_runs synth_1]], impl_1: [get_property STATUS [get_runs impl_1]]"
    exit 1
}

open_run impl_1
# -file takes one path string, not a list (braces would become part of the name)
report_utilization    -file $bdb_out/utilization_placed.rpt
report_timing_summary -max_paths 10 -report_unconstrained -file $bdb_out/timing_summary_routed.rpt
write_hw_platform -fixed -include_bit -force -file $bdb_out/design_1.xsa
puts "BUILD: $bdb_lab WNS = [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] ns"
puts "BUILD: OK - build/bd/$bdb_lab/design_1.xsa"
exit 0
