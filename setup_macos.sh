#!/bin/bash
# =============================================================================
# Open-Source EDA Flow — macOS Setup Script
# =============================================================================
# Installs: Yosys, Verilator, sv2v, GTKWave, and OpenSTA (built from source)
# Requires: Homebrew (https://brew.sh)
# =============================================================================

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()    { echo -e "${BOLD}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

# -----------------------------------------------------------------------------
# 1. Preflight checks
# -----------------------------------------------------------------------------
info "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    error "Homebrew not found. Install it first: https://brew.sh"
fi
success "Homebrew found at $(which brew)"

# -----------------------------------------------------------------------------
# 2. Homebrew dependencies
# -----------------------------------------------------------------------------
info "Installing Homebrew dependencies from Brewfile..."
brew bundle --file=Brewfile
success "Homebrew dependencies installed."

# -----------------------------------------------------------------------------
# 3. Sky130 standard cell liberty library
# -----------------------------------------------------------------------------
LIB_FILE="sky130_fd_sc_hd__tt_025C_1v80.lib"
info "Checking for Sky130 liberty library..."
if [ ! -f "$LIB_FILE" ]; then
    info "Downloading Sky130 liberty library..."
    wget -q --show-progress \
        https://raw.githubusercontent.com/shariethernet/RTL-design-using-Verilog-with-SKY130-Technology/main/my_lib/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
    success "Sky130 library downloaded."
else
    success "Sky130 library already present."
fi

# -----------------------------------------------------------------------------
# 4. OpenSTA (built from source — no Homebrew formula exists)
# -----------------------------------------------------------------------------
info "Checking for OpenSTA..."
if command -v sta &> /dev/null; then
    success "OpenSTA already installed at $(which sta)."
else
    info "Building OpenSTA from source (this takes a few minutes)..."

    rm -rf /tmp/OpenSTA_build
    git clone --recursive https://github.com/The-OpenROAD-Project/OpenSTA.git /tmp/OpenSTA_build
    mkdir -p /tmp/OpenSTA_build/build
    cd /tmp/OpenSTA_build/build

    # Auto-detect TCL paths from Homebrew
    TCL_PREFIX="$(brew --prefix tcl-tk)"
    TCL_INC="$(find "${TCL_PREFIX}/include" -name "tcl.h" | head -n 1 | xargs dirname)"
    TCL_LIB="$(ls "${TCL_PREFIX}/lib/libtcl"*.dylib | head -n 1)"

    if [ -z "$TCL_INC" ] || [ -z "$TCL_LIB" ]; then
        error "Could not locate TCL headers/libs under $(brew --prefix tcl-tk). Try: brew reinstall tcl-tk"
    fi

    cmake .. \
        -DCMAKE_PREFIX_PATH="$(brew --prefix tcl-tk);$(brew --prefix eigen);$(brew --prefix googletest);$(brew --prefix cudd)" \
        -DFLEX_EXECUTABLE="$(brew --prefix flex)/bin/flex" \
        -DFLEX_INCLUDE_DIR="$(brew --prefix flex)/include" \
        -DBISON_EXECUTABLE="$(brew --prefix bison)/bin/bison" \
        -DTCL_LIBRARY="${TCL_LIB}" \
        -DTCL_HEADER="${TCL_INC}/tcl.h"

    make -j"$(sysctl -n hw.ncpu)"
    sudo make install
    cd -
    rm -rf /tmp/OpenSTA_build

    success "OpenSTA built and installed."
fi

# -----------------------------------------------------------------------------
# 5. Verification
# -----------------------------------------------------------------------------
info "Verifying installation..."

MISSING=()
for cmd in yosys verilator sv2v sta python3; do
    if command -v "$cmd" &> /dev/null; then
        success "$cmd → $(which $cmd)"
    else
        MISSING+=("$cmd")
        warn "$cmd not found."
    fi
done

# GTKWave is a .app bundle on macOS — check the app, not a CLI command
if [ -d "/Applications/GTKWave.app" ]; then
    success "GTKWave → /Applications/GTKWave.app"
else
    MISSING+=("gtkwave")
    warn "GTKWave.app not found in /Applications."
fi

if [ ${#MISSING[@]} -ne 0 ]; then
    echo ""
    warn "The following tools were not found: ${MISSING[*]}"
    warn "Review the output above for errors and re-run, or open an issue."
    exit 1
fi

echo ""
echo -e "${GREEN}${BOLD}Setup complete!${NC}"
echo "  Simulate:   make <program>"
echo "  Synthesize: make yosys_synth"
echo "  Waveforms:  open output/<program>.vcd -a /Applications/GTKWave.app"
