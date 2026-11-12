# Vivado non-project build for the Basys 3 (XC7A35T-1CPG236C).
#
#   In the Vivado Tcl Shell:
#     source C:/Users/akull/OneDrive/Desktop/riscv_processor/fpga/build.tcl
#
# The build runs OUTSIDE the repo, in %LOCALAPPDATA%/riscv_fpga_build (or
# $RISCV_BUILD_DIR if set). The repo lives in OneDrive, and OneDrive locks the
# scratch directories Vivado creates (.Xil) while it syncs them, which kills
# synthesis with "path ... is not writable". Vivado creates .Xil in the
# current directory, so we cd to the build directory before running anything.
#
# Each step below is one stage of the FPGA flow. Read the reports it writes;
# they are where the FPGA lessons are.

set part     xc7a35tcpg236-1
set top      basys3_top
set fpga_dir [file normalize [file dirname [info script]]]
set src_dir  [file normalize [file join $fpga_dir .. src]]

if {[info exists env(RISCV_BUILD_DIR)]} {
    set out [file normalize $env(RISCV_BUILD_DIR)]
} else {
    set out [file normalize [file join $env(LOCALAPPDATA) riscv_fpga_build]]
}
file mkdir $out

# $readmemh("demo.hex") resolves against the working directory, so the
# program goes next to where synthesis runs.
file copy -force [file join $fpga_dir demo.hex] [file join $out demo.hex]

set start_dir [pwd]
cd $out
puts "Building in $out"

# ---- sources (absolute paths, so the cd above does not matter) ----
read_verilog [glob [file join $src_dir *.v]]
read_verilog [glob [file join $fpga_dir *.v]]   ;# board wrapper; fpga/sim/ is NOT read
read_xdc     [file join $fpga_dir basys3.xdc]

# ---- 1. synthesis: RTL -> generic netlist of LUTs, flops, BRAM, DSP ----
synth_design -top $top -part $part
write_checkpoint -force post_synth.dcp
report_utilization    -file utilization_synth.rpt
report_timing_summary -file timing_synth.rpt   ;# estimate only: no routing yet

# ---- 2. logic optimization ----
opt_design

# ---- 3. placement: assign each cell to a physical site on the die ----
place_design

# ---- 4. routing: connect the placed cells through the FPGA's wiring ----
route_design
write_checkpoint -force post_route.dcp

# The reports that matter. Timing after routing is the real answer: check
# WNS (worst negative slack). Negative WNS = the design is too slow for the
# 100 MHz clock constraint.
report_utilization    -file utilization.rpt
report_timing_summary -file timing.rpt -max_paths 10
report_drc            -file drc.rpt

# ---- 5. bitstream ----
write_bitstream -force $top.bit

cd $start_dir
puts ""
puts "Bitstream: [file join $out $top.bit]"
puts "Reports:   [file join $out utilization.rpt]"
puts "           [file join $out timing.rpt]"
