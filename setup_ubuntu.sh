#!/bin/bash
# =============================================================================
# Open-Source EDA Flow — Ubuntu / WSL2 Setup Script
# =============================================================================
# Tested on: Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, WSL2
# Installs: Yosys, Verilator, sv2v, GTKWave, and OpenSTA (built from source)
# =============================================================================

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${BOLD}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

# -----------------------------------------------------------------------------
# 1. System packages
# -----------------------------------------------------------------------------
info "Updating apt and installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    unzip \
    python3 \
    python3-pip \
    yosys \
    verilator \
    gtkwave \
    tcl-dev \
    swig \
    bison \
    flex \
    libeigen3-dev \
    libgoogle-perftools-dev \
    pkg-config

success "System packages installed."

# -----------------------------------------------------------------------------
# 2. sv2v (pre-built binary — not in apt)
# -----------------------------------------------------------------------------
info "Checking for sv2v..."
if command -v sv2v &> /dev/null; then
    success "sv2v already installed at $(which sv2v)."
else
    info "Downloading sv2v binary from GitHub releases..."
    TMP_DIR="$(mktemp -d)"

    # Pull the latest release tag from GitHub API
    LATEST=$(curl -s https://api.github.com/repos/zachjs/sv2v/releases/latest \
             | grep '"tag_name"' | head -n 1 | cut -d'"' -f4)

    if [ -z "$LATEST" ]; then
        error "Could not fetch sv2v release info. Check your internet connection."
    fi

    wget -q --show-progress \
        "https://github.com/zachjs/sv2v/releases/download/${LATEST}/sv2v-Linux.zip" \
        -O "${TMP_DIR}/sv2v.zip"

    unzip -q "${TMP_DIR}/sv2v.zip" -d "${TMP_DIR}"
    sudo install -m 755 "${TMP_DIR}/sv2v" /usr/local/bin/sv2v
    rm -rf "${TMP_DIR}"

    success "sv2v ${LATEST} installed."
fi

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
# 4. OpenSTA (built from source)
# -----------------------------------------------------------------------------
info "Checking for OpenSTA..."
if command -v sta &> /dev/null; then
    success "OpenSTA already installed at $(which sta)."
else
    info "Building OpenSTA from source (this takes a few minutes)..."

    # CUDD is optional for OpenSTA; skip it to avoid a separate source build
    rm -rf /tmp/OpenSTA_build
    git clone --recursive https://github.com/The-OpenROAD-Project/OpenSTA.git /tmp/OpenSTA_build
    mkdir -p /tmp/OpenSTA_build/build
    cd /tmp/OpenSTA_build/build

    cmake .. \
        -DCUDD=0 \
        -DCMAKE_BUILD_TYPE=Release

    make -j"$(nproc)"
    sudo make install
    cd -
    rm -rf /tmp/OpenSTA_build

    success "OpenSTA built and installed."
fi

# -----------------------------------------------------------------------------
# 5. WSL2 display hint
# -----------------------------------------------------------------------------
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo ""
    warn "WSL2 detected. GTKWave needs a display server to open waveforms."
    warn "  Windows 11 (WSLg):  Should work automatically — try 'gtkwave file.vcd'"
    warn "  Windows 10:         Install VcXsrv and run: export DISPLAY=:0"
fi

# -----------------------------------------------------------------------------
# 6. Verification
# -----------------------------------------------------------------------------
info "Verifying installation..."

MISSING=()
for cmd in yosys verilator sv2v sta gtkwave python3; do
    if command -v "$cmd" &> /dev/null; then
        success "$cmd → $(which $cmd)"
    else
        MISSING+=("$cmd")
        warn "$cmd not found."
    fi
done

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
echo "  Waveforms:  gtkwave output/<program>.vcd"
