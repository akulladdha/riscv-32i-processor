# Vivado non-project build for the Basys 3 (XC7A35T-1CPG236C).
#
#   cd fpga
#   vivado -mode batch -source build.tcl
#
# Run from fpga/: $readmemh("demo.hex") in instruction_mem resolves relative
# to the working directory, and this script reads sources relative to it too.
# Outputs land in fpga/build/ (gitignored).
#
# Each step below is one stage of the FPGA flow. Read the reports it writes;
# they are where the FPGA lessons are.

set part  xc7a35tcpg236-1
set top   basys3_top
set out   build
file mkdir $out

# ---- sources ----
read_verilog [glob ../src/*.v]
read_verilog [glob ./*.v]          ;# board wrapper; fpga/sim/ is NOT read
read_xdc     basys3.xdc

# ---- 1. synthesis: RTL -> generic netlist of LUTs, flops, BRAM, DSP ----
synth_design -top $top -part $part
write_checkpoint -force $out/post_synth.dcp
report_utilization    -file $out/utilization_synth.rpt
report_timing_summary -file $out/timing_synth.rpt   ;# estimate only: no routing yet

# ---- 2. logic optimization ----
opt_design

# ---- 3. placement: assign each cell to a physical site on the die ----
place_design

# ---- 4. routing: connect the placed cells through the FPGA's wiring ----
route_design
write_checkpoint -force $out/post_route.dcp

# The reports that matter. Timing after routing is the real answer: check
# WNS (worst negative slack). Negative WNS = the design is too slow for the
# 100 MHz clock constraint.
report_utilization    -file $out/utilization.rpt
report_timing_summary -file $out/timing.rpt -max_paths 10
report_drc            -file $out/drc.rpt

# ---- 5. bitstream ----
write_bitstream -force $out/$top.bit
puts "Bitstream: [file normalize $out/$top.bit]"
