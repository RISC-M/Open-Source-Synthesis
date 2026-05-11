# Starting a Fresh Project

This guide walks through setting up the open-source synthesis and timing flow for a brand new Verilog or SystemVerilog design. No prior EDA experience required.

---

## What You'll Need

- A Verilog (`.v`) or SystemVerilog (`.sv`) design with a defined top-level module
- The setup script run successfully (`setup_macos.sh` or `setup_ubuntu.sh`)
- Basic familiarity with the command line

---

## Step 1: Set Up Your Project Directory

```
my_project/
├── src/            ← your Verilog/SV source files
├── synth/          ← synthesis outputs (auto-created)
├── synth.ys        ← Yosys script (copy from this repo)
├── sta.tcl         ← OpenSTA script (copy from this repo)
├── constraints.sdc ← timing constraints (copy from this repo)
└── sky130_fd_sc_hd__tt_025C_1v80.lib  ← cell library (downloaded by setup script)
```

Copy the synthesis files from this repo:
```bash
cp /path/to/this/repo/synth/synth.ys .
cp /path/to/this/repo/synth/sta.tcl .
cp /path/to/this/repo/synth/constraints.sdc .
cp /path/to/this/repo/sky130_fd_sc_hd__tt_025C_1v80.lib .
```

---

## Step 2: Adapt the Yosys Script

Open `synth.ys` and change the top module name to match yours:

```tcl
read_verilog synth_input.v
hierarchy -check -top <YOUR_TOP_MODULE>   # ← change this
synth -top <YOUR_TOP_MODULE>              # ← and this
dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
clean
write_verilog -noattr synth/cpu.vg
```

If your design uses SystemVerilog, first convert it to Verilog:
```bash
sv2v src/*.sv -w synth_input.v
```

If your design is already plain Verilog:
```bash
cat src/*.v > synth_input.v
```

---

## Step 3: Run Synthesis

```bash
mkdir -p synth
yosys synth.ys 2>&1 | tee synth/synthesis.log
```

Yosys will print a cell usage summary at the end that looks like this:

```
=== my_module ===

   Number of wires:                123
   Number of cells:                456
     sky130_fd_sc_hd__and2_1         8
     sky130_fd_sc_hd__dfxtp_1       32
     sky130_fd_sc_hd__nand2_1       14
     ...
```

This is your post-synthesis area estimate. If synthesis fails, see [common errors](#common-synthesis-errors) below.

---

## Step 4: Set Your Clock and Run Timing Analysis

Timing analysis needs to know your target clock period in nanoseconds. Write it to a file:

```bash
echo "10.0" > cpu.clock   # 10ns = 100 MHz
```

Then run OpenSTA:
```bash
sta sta.tcl 2>&1 | tee synth/timing.rep
```

### Reading the Report

The most important section is the **worst-case path**:

```
Startpoint: reg_a/Q
Endpoint:   reg_b/D
Path Group: clock
slack (MET)   1.43
```

- **`slack (MET)`** — your design meets timing. The number is how much margin you have.
- **`slack (VIOLATED)`** — your design is too slow. The number is how much you need to recover.

A timing report also shows the critical path chain — the sequence of gates that determines your maximum frequency. Read it bottom-up from Endpoint to Startpoint.

---

## Step 5: Iterate

If timing is violated, your options are roughly:

| Approach | When to use |
| :--- | :--- |
| Relax the clock period | Quick check — confirms the design is otherwise correct |
| Pipeline the critical path | The path spans multiple combinational stages |
| Restructure combinational logic | Wide adders, large muxes, deep priority encoders |
| Let the synthesizer optimize harder | Try `synth -top <top> -flatten` in Yosys for more aggressive optimization |

Re-run synthesis and STA after each change. The loop is: edit RTL → `sv2v` (if needed) → `yosys synth.ys` → `sta sta.tcl`.

---

## Understanding the Constraints File

`constraints.sdc` as shipped contains:
```tcl
set_input_delay 0.1 -clock clock [all_inputs]
set_output_delay 0.1 -clock clock [all_outputs]
```

This tells OpenSTA that all primary inputs arrive 0.1ns after the clock edge, and all primary outputs must be valid 0.1ns before the next clock edge. For most student projects this is a reasonable starting point.

For a tighter model, set these based on your actual I/O timing requirements.

---

## Common Synthesis Errors

**`ERROR: Module not found`**
Your top module name in `synth.ys` doesn't match what's in your Verilog. Double-check the `module` declaration in your source.

**`ERROR: Elaboration of cell ... failed`**
Usually caused by unsupported or undefined module references. Make sure all files are included in `synth_input.v`.

**`sv2v: error: ...`**
sv2v has [known limitations](https://github.com/zachjs/sv2v#supported-constructs) with some SystemVerilog constructs. The error message usually identifies the offending line. Common workarounds: avoid `interface`, simplify `generate` blocks, use `logic` instead of `reg`/`wire` consistently.

**`Warning: found no clocks, no timing constraints`**
OpenSTA ran but the `cpu.clock` file is missing or empty. Make sure you ran `echo "10.0" > cpu.clock` before `sta sta.tcl`.

---

## Useful Yosys Commands for Exploration

You can drop into an interactive Yosys session to inspect your design:

```bash
yosys
```

```tcl
# Inside Yosys:
read_verilog synth_input.v
hierarchy -check -top my_module
proc; opt; fsm; memory; techmap
show my_module                    # Renders a schematic (requires xdot)
stat                              # Print area statistics
```

---

## Further Reading

- [Yosys documentation](https://yosyshq.readthedocs.io/)
- [OpenSTA documentation](https://github.com/The-OpenROAD-Project/OpenSTA/blob/master/doc/OpenSTA.pdf)
- [Sky130 PDK reference](https://skywater-pdk.readthedocs.io/)
- [sv2v supported constructs](https://github.com/zachjs/sv2v#supported-constructs)
