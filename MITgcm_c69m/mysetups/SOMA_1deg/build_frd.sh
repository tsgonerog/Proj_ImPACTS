#!/bin/bash
# Build the FORWARD model (no adjoint).
#   sources : code/ + input/          ->  build_frd/mitgcmuv
# SOMA's forward configuration is MPI: code/SIZE.h is nPx=2, nPy=2 over
# sNx=31, sNy=31 = 4 ranks (unlike the adjoint, which is serial-only).
#
# mpi build of forward SOMA-MITgcm

# Exit immediately if a command fails (-e),
# treat unset variables as errors (-u),
# and make pipelines fail if any part fails (pipefail).
set -euo pipefail

# Set root directory for MITgcm relative to THIS script (works after cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MITGCM_ROOT="$SCRIPT_DIR/../../MITgcm"

# Per-machine optfiles, module stack and Tapenade check. Defaults reproduce the
# sverdrup settings, so nothing changes here; on another machine add a case
# block to tools/machine_env.sh rather than editing this script.
source "$SCRIPT_DIR/../../../tools/machine_env.sh"
impacts_load_modules

# code/ has a single SIZE.h (the 2x2 MPI decomposition); nothing to stage.

# MPI_OPTFILE is defaulted by machine_env.sh; this catches a machine with none.
if [ -z "$MPI_OPTFILE" ] || [ ! -f "$MPI_OPTFILE" ]; then
    echo "ERROR: MPI_OPTFILE is unset or missing: '$MPI_OPTFILE'"
    echo "       Set it for machine '$MACHINE' in tools/machine_env.sh, or export it."
    exit 1
fi

# Ensure build directory exists
if [ ! -d build_frd ]; then
    echo "Creating the directory build_frd..."
    mkdir build_frd
fi

# Go to build directory
cd build_frd || { echo "Failed to enter build_frd"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here)
"$MITGCM_ROOT/tools/genmake2" -mpi \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods=../code \

# Generate dependency list
make depend

# Build the forward model using 8 threads
make -j 8
