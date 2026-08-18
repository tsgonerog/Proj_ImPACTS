#!/bin/bash
# CONTROL BUILD - Tapenade's raw output, deliberately uncorrected.
#   sources : code_tap/ + input_tap/  ->  build_tapAdj_rawTapenade/mitgcmuv_tap_adj
#
# Identical to build_tapAdj.sh except it calls the STOCK genmake2, so the
# hand-corrected forward_step_b.f is NOT injected. Kept to show what raw
# Tapenade output does. No submit script uses this build.
#
# Serial Tapenade-adjoint build for MITgcm

# Exit immediately if a command fails (-e),
# treat unset variables as errors (-u),
# and make pipelines fail if any part fails (pipefail).
set -euo pipefail

# Set root directory for MITgcm relative to THIS script (works after cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ../MITgcm was wrong: the tree lives one level higher, at MITgcm_c69m/MITgcm.
MITGCM_ROOT="$SCRIPT_DIR/../../MITgcm"

# Per-machine optfiles, module stack and Tapenade check. Defaults reproduce the
# sverdrup settings; add a case block to tools/machine_env.sh for a new machine.
source "$SCRIPT_DIR/../../../tools/machine_env.sh"
impacts_load_modules

# Replace SIZE.h and the_main_loop_b.f_for_patched_genmake2 with serial versions
cp code_tap/SIZE.h_serial code_tap/SIZE.h
#cp code_tap/the_main_loop_b.f_for_patched_genmake2_serialPatch code_tap/the_main_loop_b.f_for_patched_genmake2

# Ensure build directory exists
if [ ! -d build_tapAdj_rawTapenade ]; then
    echo "Creating the directory build_tapAdj_rawTapenade..."
    mkdir build_tapAdj_rawTapenade
fi

# Go to build directory
cd build_tapAdj_rawTapenade || { echo "Failed to enter build_tapAdj_rawTapenade"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here)
"$MITGCM_ROOT/tools/genmake2" -tap \
    -rd="$MITGCM_ROOT" \
    -of="$SERIAL_OPTFILE" \
    -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_tap"

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj
