# Timing constraints for building the CNN core (top_cnn) on its own, out of context.
# In the system build (tools/build_bd.tcl) the saved block design's clock wizard is removed, so
# top_0/clk and every AXI BRAM controller's bram_clk_a are driven directly by PS7 FCLK_CLK0 at
# 100 MHz. All clocks below therefore share one 10 ns period and waveform, so Vivado analyzes them
# synchronously, as in the full system. Used by tools/build_hw.tcl.
create_clock -name clk        -period 10.000 [get_ports clk]
create_clock -name input_clka -period 10.000 [get_ports input_clka]
create_clock -name conv_clka  -period 10.000 [get_ports conv_clka]
create_clock -name fcl_clka_0 -period 10.000 [get_ports fcl_clka_0]
create_clock -name fcl_clka_1 -period 10.000 [get_ports fcl_clka_1]
create_clock -name fcl_clka_2 -period 10.000 [get_ports fcl_clka_2]
create_clock -name fcl_clka_3 -period 10.000 [get_ports fcl_clka_3]
create_clock -name fcl_clka_4 -period 10.000 [get_ports fcl_clka_4]
create_clock -name fcl_clka_5 -period 10.000 [get_ports fcl_clka_5]
create_clock -name fcl_clka_6 -period 10.000 [get_ports fcl_clka_6]
create_clock -name fcl_clka_7 -period 10.000 [get_ports fcl_clka_7]
create_clock -name fcl_clka_8 -period 10.000 [get_ports fcl_clka_8]
create_clock -name fcl_clka_9 -period 10.000 [get_ports fcl_clka_9]

# An out-of-context build has no board pinout (the block design supplies it); relax I/O
# so the report reflects core logic timing rather than unconstrained pad delays.
set_false_path -from [all_inputs] -to [all_registers]
set_false_path -from [all_registers] -to [all_outputs]
