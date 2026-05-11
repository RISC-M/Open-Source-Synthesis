read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog synth/cpu.vg
link_design cpu

# 1. Read clock period from cpu.clock
set fp [open "cpu.clock" r]
set CLK_PERIOD [read $fp]
close $fp

# 2. Define clock here instead of in SDC
create_clock -name clock -period $CLK_PERIOD [get_ports clock]

# 3. Read remaining constraints (IO delays)
read_sdc constraints.sdc

report_checks
report_power
exit
