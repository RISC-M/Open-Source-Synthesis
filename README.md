# Open-Source EDA Flow

A portable, open-source synthesis and simulation stack for Verilog/SystemVerilog projects — built as an alternative to Synopsys/Cadence toolchains. Originally developed for the **EECS 470** LC2K processor project at the University of Michigan, but usable for any digital design project.

Works on **macOS** and **Ubuntu / WSL2**.

---

## Toolchain at a Glance

| Stage | Commercial Tool | Open-Source Replacement |
| :--- | :--- | :--- |
| SV → Verilog | — | `sv2v` |
| Simulation | Synopsys VCS | `Verilator` |
| Waveforms | Synopsys Verdi | `GTKWave` |
| Synthesis | Synopsys DC | `Yosys` + Sky130 PDK |
| Timing Analysis | Synopsys PrimeTime | `OpenSTA` |

---

## Quick Start

**macOS**
```bash
chmod +x setup_macos.sh
./setup_macos.sh
```

**Ubuntu / WSL2**
```bash
chmod +x setup_ubuntu.sh
./setup_ubuntu.sh
```

Both scripts are fully automated. See the [troubleshooting section](#troubleshooting) if anything fails.

---

## Repository Structure

```
.
├── README.md               # You are here
├── setup_macos.sh          # Automated macOS setup
├── setup_ubuntu.sh         # Automated Ubuntu / WSL2 setup
├── Brewfile                # macOS Homebrew dependency list
├── synth/
│   ├── synth.ys            # Yosys synthesis script
│   ├── sta.tcl             # OpenSTA timing analysis script
│   └── constraints.sdc     # SDC I/O timing constraints
├── sky130_fd_sc_hd__tt_025C_1v80.lib   # Sky130 standard cell liberty file
└── docs/
    ├── EECS470.md          # EECS 470 project-specific integration guide
    └── FRESH_PROJECT.md    # General guide for starting a new project
```

---

## For EECS 470 Students

See **[docs/EECS470.md](docs/EECS470.md)** for instructions on dropping this flow into your existing LC2K project, including Makefile targets and how the open-source flow maps to the CAEN submission flow.

---

## For a Fresh Project

See **[docs/FRESH_PROJECT.md](docs/FRESH_PROJECT.md)** for a step-by-step walkthrough of setting up synthesis and timing analysis for a brand new Verilog/SystemVerilog design.

---

## Troubleshooting

### macOS

**`gtkwave: cask not found`**
Make sure you have an up-to-date Homebrew: `brew update && brew upgrade`.

**OpenSTA build fails on `tcl.h not found`**
The setup script auto-detects your TCL path. If it fails, manually confirm the path with:
```bash
find $(brew --prefix tcl-tk)/include -name "tcl.h"
```
and open an issue with the output.

**`sta` command not found after install**
OpenSTA installs to `/usr/local/bin`. If that's not on your PATH:
```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

### Ubuntu / WSL2

**GTKWave opens but shows no waveform**
On WSL2, GTKWave requires a Windows X server (e.g., [VcXsrv](https://sourceforge.net/projects/vcxsrv/) or the built-in WSLg on Windows 11). Set your display: `export DISPLAY=:0`.

**`sv2v` command not found**
The setup script downloads the pre-built binary. Check that `/usr/local/bin` is on your PATH.

**Yosys version is too old**
Ubuntu's apt package can lag behind. If you need a newer version, build from source:
```bash
git clone https://github.com/YosysHQ/yosys.git && cd yosys && make -j$(nproc) && sudo make install
```

---

## Contributing

Pull requests are welcome. If you run into a setup issue on a specific OS version, please open an issue with your OS, the command that failed, and the error output.

---

## License

MIT
