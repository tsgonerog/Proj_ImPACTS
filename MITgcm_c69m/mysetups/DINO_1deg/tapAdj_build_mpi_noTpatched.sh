#!/bin/bash
# MPI Tapenade-adjoint build for MITgcm

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

# Replace SIZE.h with mpi version
cp code_tap/SIZE.h_mpi code_tap/SIZE.h
cp code_tap/AUTODIFF_PARAMS.h_OG code_tap/AUTODIFF_PARAMS.h
cp code_tap/autodiff_readparms.F_OG code_tap/autodiff_readparms.F
cp code_tap/autodiff_inadmode_set_ad.F_OG code_tap/autodiff_inadmode_set_ad.F

# MPI_OPTFILE is defaulted by machine_env.sh; this catches a machine with none.
if [ -z "$MPI_OPTFILE" ] || [ ! -f "$MPI_OPTFILE" ]; then
    echo "ERROR: MPI_OPTFILE is unset or missing: '$MPI_OPTFILE'"
    echo "       Set it for machine '$MACHINE' in tools/machine_env.sh, or export it."
    exit 1
fi

# Ensure build directory exists
if [ ! -d build_tapAdj_mpi_noTpatched ]; then
    echo "Creating the directory build_tapAdj_mpi_noTpatched..."
    mkdir build_tapAdj_mpi_noTpatched
fi

# Go to build directory
cd build_tapAdj_mpi_noTpatched || { echo "Failed to enter build_tapAdj_mpi_noTpatched"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here)
"$MITGCM_ROOT/tools/genmake2" -mpi -tap \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_tap"

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj
