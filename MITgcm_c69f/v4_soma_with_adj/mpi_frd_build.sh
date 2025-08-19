#!/bin/bash
# mpi Tapenade-adjoint build for MITgcm

# Exit immediately if a command fails (-e),
# treat unset variables as errors (-u),
# and make pipelines fail if any part fails (pipefail).
set -euo pipefail

# Set root directory for MITgcm relative to THIS script (works after cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MITGCM_ROOT="$SCRIPT_DIR/../MITgcm"

# Check MPI_OPTFILE
if [ -z "$MPI_OPTFILE" ]; then
    echo "ERROR: MPI_OPTFILE is not set. Please export it or define it in the script or add in your bashrc."
    exit 1
fi

# Ensure build directory exists
if [ ! -d build_frd_mpi ]; then
    echo "Creating build_frd_mpi..."
    mkdir build_frd_mpi
fi

# Go to build directory
cd build_frd_mpi || { echo "Failed to enter build_frd_mpi"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here)
"$MITGCM_ROOT/tools/genmake2" -mpi \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods=../code

# Generate dependency list
make depend

# Build the forward model using 8 threads
make -j 8
