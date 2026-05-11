# EECS 470 Integration Guide

This guide covers how to use the open-source EDA flow with your existing EECS 470 LC2K processor project.

---

## Tool Mapping

| What you do on CAEN | What you do locally |
| :--- | :--- |
| `vcs -sverilog *.sv` | `make <program>` (runs Verilator) |
| `dc_shell-t -f synth.tcl` | `make yosys_synth` |
| Open Verdi | `gtkwave output/<program>.vcd` |
| `lc2k_assembler program.lc2k` | `python3 programs/assembler.py program.lc2k out.mem` |

The `Makefile` is designed to auto-detect which environment it's in. On CAEN it uses VCS/DC; locally it uses Verilator/Yosys. No changes needed when you push to submit.

---

## Files to Add to Your Project

Copy these files from this repo into the root of your 470 project:

```
setup_macos.sh
setup_ubuntu.sh
Brewfile
synth/synth.ys
synth/sta.tcl
synth/constraints.sdc
sky130_fd_sc_hd__tt_025C_1v80.lib
```

The `sky130` liberty file is large (~40MB). You may want to either:
- Commit it directly (fine for a private class repo)
- Add it to `.gitignore` and have the setup script download it (already handled)

---

## The Synthesis Flow, Step by Step

Understanding what each stage does helps when debugging synthesis failures.

### 1. SystemVerilog → Verilog (`sv2v`)

Yosys has limited SystemVerilog support. `sv2v` converts your `.sv` files into a single flat `.v` file first:

```bash
sv2v verilog/*.sv -w synth_input.v
```

Your Makefile's `yosys_synth` target should run this automatically before invoking Yosys.

### 2. Synthesis (`yosys`)

`synth.ys` does four things:
1. Reads `synth_input.v`
2. Checks module hierarchy (`-top cpu`)
3. Maps your logic to Sky130 standard cells (`dfflibmap`, `abc`)
4. Writes the synthesized netlist to `synth/cpu.vg`

```bash
yosys synth/synth.ys 2>&1 | tee synth/cpu.rep
```

### 3. Timing Analysis (`OpenSTA`)

`sta.tcl` reads:
- The Sky130 liberty file (cell timing models)
- `synth/cpu.vg` (your synthesized netlist)
- `cpu.clock` (your target clock period in ns — written by your Makefile)
- `synth/constraints.sdc` (I/O timing constraints)

It then reports setup/hold slack and estimated power:

```bash
sta synth/sta.tcl
```

A negative slack means your design cannot meet timing at that clock period.

---

## Suggested Makefile Targets

Add these to your existing `Makefile`. Adjust `VERILOG_SRCS` to match your file layout:

```makefile
VERILOG_SRCS := $(wildcard verilog/*.sv)
CLOCK_PERIOD  ?= 10.0   # ns — override with: make yosys_synth CLOCK_PERIOD=8.0

.PHONY: yosys_synth

yosys_synth: synth/cpu.vg synth/cpu.rep

synth_input.v: $(VERILOG_SRCS)
	sv2v $^ -w $@

synth/cpu.vg: synth_input.v synth/synth.ys
	mkdir -p synth
	yosys synth/synth.ys 2>&1 | tee synth/yosys.log

synth/cpu.rep: synth/cpu.vg synth/sta.tcl synth/constraints.sdc
	echo "$(CLOCK_PERIOD)" > cpu.clock
	sta synth/sta.tcl 2>&1 | tee synth/cpu.rep
	@grep -E "slack|Endpoint" synth/cpu.rep | head -20
```

---

## Reading the Timing Report

After `make yosys_synth`, open `synth/cpu.rep`. Key lines to look for:

```
slack (MET)             2.14   ← Design meets timing. You have 2.14ns of margin.
slack (VIOLATED)       -0.87   ← Design fails timing. Critical path is 0.87ns too slow.
```

If you have violations, common fixes:
- Increase your clock period (`CLOCK_PERIOD=12.0`)
- Pipeline the critical path
- Check for wide combinational chains (large muxes, adders without carry-select)

---

## What's Different vs. CAEN

| Aspect | CAEN (Synopsys) | Local (Open-Source) |
| :--- | :--- | :--- |
| Cell library | SAED 32nm EDU | Sky130 (130nm) |
| Area/timing numbers | Different scale | Different scale |
| Simulation semantics | Cycle-accurate | Cycle-accurate (same) |
| Submission target | CAEN only | — |

**The local numbers won't match CAEN** because the cell libraries are completely different (different process nodes). Use the local flow for fast iteration and catching functional bugs. Use CAEN for final timing verification before submission.

---

## Common Issues

**`hierarchy check failed`**
Yosys can't find your top-level module named `cpu`. Either rename your top module or change `-top cpu` in `synth.ys` to match your actual top module name.

**`sv2v: unknown/unsupported construct`**
Some advanced SystemVerilog features aren't supported by sv2v. Check the [sv2v issue tracker](https://github.com/zachjs/sv2v/issues) for workarounds. Common culprits: `interface`, `class`, `bind`, certain `generate` patterns.

**OpenSTA reports `cannot find liberty cell`**
The synthesized netlist references a Sky130 cell not in the liberty file. This usually means a `dfflibmap` mismatch — make sure `synth.ys` and `sta.tcl` both reference the same `.lib` file.
