# =============================================================================
#  run.do  -  UVM FIFO project (QuestaSim)
#
#  - compiles the DUT with code coverage (branch, condition, expression,
#    statement, FSM, toggle) and the UVM testbench without it
#  - runs fifo_test with assertion / cover-directive / covergroup collection
#  - saves the UCDB and writes the code, functional and sequential-domain
#    (assertion) coverage reports
#
#  Run it from the folder that contains the .sv files:
#      vsim -do run.do         (GUI - waveform stays open for screenshots)
#      vsim -c -do run.do      (batch)
# =============================================================================

set SEED 1

# run a command; print a warning instead of aborting the whole script
proc try {cmd} {
    if {[catch {uplevel #0 $cmd} err]} {
        echo "WARNING: '$cmd' failed -> $err"
    }
}

try {quit -sim}

# ---------------------------------------------------------------- compile ---
if {[file exists work]} { vdel -lib work -all }
vlib work

# interface + shared package (no coverage)
vlog shared_pkg.sv fifo_if.sv

# design with all code-coverage types
vlog +cover=bcesft FIFO.sv

# assertions, UVM packages (compile order = dependency order), test and top
vlog fifo_sva.sv \
     fifo_seq_item_pkg.sv \
     fifo_config_pkg.sv \
     fifo_sequencer_pkg.sv \
     fifo_driver_pkg.sv \
     fifo_monitor_pkg.sv \
     fifo_agent_pkg.sv \
     fifo_coverage_pkg.sv \
     fifo_scoreboard_pkg.sv \
     fifo_env_pkg.sv \
     fifo_sequence_pkg.sv \
     fifo_test.sv \
     fifo_top.sv

# --------------------------------------------------------------- simulate ---
vsim -voptargs=+acc work.top -coverage -assertdebug -classdebug -uvmcontrol=all \
     -sv_seed $SEED +UVM_VERBOSITY=UVM_LOW -l sim.log

# ------------------------------------------------------------------- wave ---
try {add wave -group "Interface"     /top/f_if/*}
try {add wave -group "DUT internals" /top/DUT/wr_ptr /top/DUT/rd_ptr /top/DUT/count}
try {add wave -group "Assertions"    /top/DUT/SVA/*}

# stay in the simulator after UVM calls $finish so the coverage can be saved
try {onfinish stop}
coverage save -onexit fifo_top.ucdb

# -------------------------------------------------------------------- run ---
run -all

# --------------------------------------------------------------- coverage ---
try {coverage save fifo_top.ucdb}

# code coverage (statement / branch / condition / expression / FSM / toggle)
try {vcover report fifo_top.ucdb -details -code bcestf -output code_coverage_report.txt}
# functional coverage (covergroups in fifo_coverage)
try {vcover report fifo_top.ucdb -details -cvg -output functional_coverage_report.txt}
# sequential-domain coverage (assertions + cover directives in fifo_sva)
try {vcover report fifo_top.ucdb -details -assert -directive -output sequential_coverage_report.txt}
# browsable version of everything
try {vcover report fifo_top.ucdb -html -details -htmldir covhtmlreport}

echo "----------------------------------------------------------------------"
echo " Simulation log : sim.log"
echo " UCDB           : fifo_top.ucdb"
echo " Reports        : code_coverage_report.txt"
echo "                  functional_coverage_report.txt"
echo "                  sequential_coverage_report.txt"
echo "                  covhtmlreport/index.html"
echo "----------------------------------------------------------------------"

# --- optional: zoom on each sequence for the waveform screenshots ------------
# (1 item = 1 clock period = 2 ns with the default 1 ns timescale)
#   reset_assert        0 ns -    2 ns       wave zoom range 0ns 4ns
#   Write_only          2 ns -   22 ns       wave zoom range 2ns 24ns
#   Read_only          22 ns -   42 ns       wave zoom range 22ns 44ns
#   Write_Read         42 ns - 2042 ns       wave zoom range 42ns 142ns
#   Write_Read_Always 2042 ns - 2062 ns      wave zoom range 2042ns 2064ns

try { if {[batch_mode]} {quit -f} }
