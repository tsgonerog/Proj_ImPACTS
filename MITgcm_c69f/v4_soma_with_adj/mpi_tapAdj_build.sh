#!/bin/bash
# mpi Tapenade-adjoint build for MITgcm

# Exit immediately if a command fails (-e),
# treat unset variables as errors (-u),
# and make pipelines fail if any part fails (pipefail).
set -euo pipefail

# Set root directory for MITgcm relative to THIS script (works after cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MITGCM_ROOT="$SCRIPT_DIR/../MITgcm"

# Replace SIZE.h and the_main_loop_b.f_for_patched_genmake2 with mpi versions
cp code_tap/SIZE.h_mpi code_tap/SIZE.h
cp code_tap/the_main_loop_b.f_for_patched_genmake2_mpiPatch code_tap/the_main_loop_b.f_for_patched_genmake2

# Check MPI_OPTFILE
if [ -z "$MPI_OPTFILE" ]; then
    echo "ERROR: MPI_OPTFILE is not set. Please export it or define it in the script or add it in your bashrc."
    exit 1
fi

# Ensure build directory exists
if [ ! -d build_tapAdj_mpi ]; then
    echo "Creating build_tapAdj_mpi..."
    mkdir build_tapAdj_mpi
fi

# Go to build directory
cd build_tapAdj_mpi || { echo "Failed to enter build_tapAdj_mpi"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here)
"$MITGCM_ROOT/tools/patched_genmake2" -tap -mpi \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_default"

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj
