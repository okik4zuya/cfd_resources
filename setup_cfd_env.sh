#!/bin/bash
# =============================================================================
# CFD Environment Setup — RunPod Instance
# OpenFOAM v2312 (ESI) + ParaView + utilities
# Run once on every new instance: bash setup_cfd_env.sh
# =============================================================================

set -eo pipefail   # Note: no -u — avoids false positives from apt/OF scripts

# --- Colours for output -------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Config -------------------------------------------------------------
OF_VERSION="openfoam2312"
OF_BASHRC="/usr/lib/openfoam/${OF_VERSION}/etc/bashrc"
WORKSPACE="${WORKSPACE:-/workspace}"
CASES_DIR="${WORKSPACE}/cases"
SCRIPTS_DIR="${WORKSPACE}/scripts"

# ========================================================================
echo ""
echo "============================================================"
echo "  CFD Environment Setup — OpenFOAM ${OF_VERSION}"
echo "  $(date)"
echo "============================================================"
echo ""

# --- 1. System update ---------------------------------------------------
info "Updating apt package lists..."
apt-get update -qq

# --- 2. Core dependencies -----------------------------------------------
info "Installing core dependencies..."
apt-get install -y --no-install-recommends \
    curl wget git vim htop screen tmux \
    python3-pip python3-venv \
    bc ca-certificates gnupg 2>/dev/null

# --- 3. OpenFOAM v2312 --------------------------------------------------
info "Adding ESI OpenFOAM repository..."
curl -s https://dl.openfoam.com/add-debian-repo.sh | bash

info "Installing OpenFOAM ${OF_VERSION}..."
apt-get update -qq
apt-get install -y ${OF_VERSION}-default \
    || error "OpenFOAM installation failed."

[ -f "${OF_BASHRC}" ] || error "OpenFOAM bashrc not found at ${OF_BASHRC}."
info "OpenFOAM installed successfully."

# --- 4. ParaView --------------------------------------------------------
# Ubuntu 24.04 + ESI OF2312: use standard 'paraview' apt package.
# paraviewopenfoam2312 does not exist for this distro/branch.
info "Installing ParaView..."
apt-get install -y paraview \
    || warn "ParaView install failed — post-process locally with a matching client."

# --- 5. Python CFD utilities --------------------------------------------
# --break-system-packages is correct for a RunPod root container.
# --quiet --no-warn-script-location suppresses the pip-as-root warning.
info "Installing Python utilities (numpy, matplotlib, pandas, scipy)..."
pip3 install --quiet --break-system-packages \
    --no-warn-script-location \
    numpy matplotlib pandas scipy

# --- 6. Source OpenFOAM in .bashrc --------------------------------------
BASHRC_LINE="source ${OF_BASHRC}"
if grep -qF "${BASHRC_LINE}" ~/.bashrc; then
    warn "OpenFOAM already sourced in ~/.bashrc — skipping."
else
    echo ""                          >> ~/.bashrc
    echo "# OpenFOAM ${OF_VERSION}" >> ~/.bashrc
    echo "${BASHRC_LINE}"           >> ~/.bashrc
    info "OpenFOAM sourced in ~/.bashrc."
fi

# --- 7. Persistent volume directory structure ---------------------------
if [ -d "${WORKSPACE}" ]; then
    info "Setting up persistent volume directories at ${WORKSPACE}..."
    mkdir -p "${CASES_DIR}" "${SCRIPTS_DIR}" "${WORKSPACE}/logs"
    cp "$0" "${SCRIPTS_DIR}/setup_cfd_env.sh" 2>/dev/null \
        && info "Script saved to ${SCRIPTS_DIR}/setup_cfd_env.sh" \
        || warn "Could not copy script to persistent volume."
else
    warn "Persistent volume not found at ${WORKSPACE}."
    warn "Set WORKSPACE=/your/mount/path and re-run to configure case directories."
fi

# --- 8. Set FOAM_RUN to persistent volume if available ------------------
if [ -d "${CASES_DIR}" ]; then
    FOAM_RUN_LINE="export FOAM_RUN=${CASES_DIR}"
    if grep -qF "${FOAM_RUN_LINE}" ~/.bashrc; then
        warn "FOAM_RUN already set in ~/.bashrc — skipping."
    else
        echo "${FOAM_RUN_LINE}" >> ~/.bashrc
        info "FOAM_RUN set to ${CASES_DIR} (persistent volume)."
    fi
fi

# --- 9. Smoke test ------------------------------------------------------
# OpenFOAM's bashrc cannot be sourced inside a non-interactive script
# without triggering "pop_var_context" bash errors. We skip in-script
# sourcing entirely and verify via the installed binary path directly.
info "Verifying OpenFOAM install..."
OF_BIN="/usr/lib/openfoam/${OF_VERSION}/platforms/linux64GccDPInt32Opt/bin"
if [ -f "${OF_BIN}/icoFoam" ]; then
    info "icoFoam binary found at ${OF_BIN}/icoFoam ✓"
else
    warn "icoFoam binary not found — run 'source ~/.bashrc && icoFoam -help' to verify manually."
fi

# --- 10. Summary --------------------------------------------------------
echo ""
echo "============================================================"
echo "  Setup complete — $(date)"
echo "============================================================"
echo ""
echo "  OpenFOAM : ${OF_VERSION}"
echo "  Bashrc   : ${OF_BASHRC}"
echo "  Cases dir: ${CASES_DIR}"
echo ""
echo "  !! REQUIRED — activate OpenFOAM in this terminal:"
echo ""
echo "      source ~/.bashrc"
echo ""
echo "  Then verify with:"
echo ""
echo "      icoFoam -help"
echo "      blockMesh -help"
echo "============================================================"