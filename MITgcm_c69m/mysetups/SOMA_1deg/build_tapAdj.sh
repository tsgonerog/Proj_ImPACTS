#!/bin/bash
# Build the Tapenade ADJOINT. This is the one you normally want.
#   sources : code_tap/ + input_tap/  ->  build_tapAdj/mitgcmuv_tap_adj
#
# Uses the PATCHED genmake2, which injects code_tap/forward_step_b.f_modified
# over the routine Tapenade generates. Tapenade differentiates forward_step.F
# automatically but its output needs manual correction; that corrected copy is
# what makes the adjoint usable.
#
# SOMA is serial-only: code_tap/SIZE.h_serial is nPx=nPy=1 over sNx=sNy=62.
#
# Serial Tapenade-adjoint build for MITgcm

# Exit immediately if a command fails (-e),
# treat unset variables as errors (-u),
# and make pipelines fail if any part fails (pipefail).
set -euo pipefail

###############################################
# Choose TapProfile behavior here:
#   NO    : Don't want to use Tapenade profiling, use patched_NoTapProfile_genmake2
#   YES   : Want to use Tapenade profiling, use patched_ForTapProfile_genmake2
#   AFTER : After implementing suggession provided by Tapenade profiling tool, use patched_AfterTapProfile_genmake2
###############################################
use_TapProfile="NO"   # <-- change this to "YES" or "AFTER" as needed

# Set root directory for MITgcm relative to THIS script (works after cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ../MITgcm was wrong: the tree lives one level higher, at MITgcm_c69m/MITgcm.
MITGCM_ROOT="$SCRIPT_DIR/../../MITgcm"

# Per-machine optfiles, module stack and Tapenade check. Defaults reproduce the
# sverdrup settings; add a case block to tools/machine_env.sh for a new machine.
source "$SCRIPT_DIR/../../../tools/machine_env.sh"
impacts_load_modules

# Replace SIZE.h with serial version
cp code_tap/SIZE.h_serial code_tap/SIZE.h

# Decide which the_model_main.F and which patched_genmake2 to use
case "$use_TapProfile" in
    "NO")
        echo "Not Using Tapenade Profiling Tool"
        cp code_tap/the_model_main.F_OG code_tap/the_model_main.F
        GENMAKE_SCRIPT="patched_NoTapProfile_genmake2"
        ;;

    "YES")
        echo "Using Tapenade Profiling Tool"
        cp code_tap/the_model_main.F_ForTapProfile code_tap/the_model_main.F
        GENMAKE_SCRIPT="patched_ForTapProfile_genmake2"
        ;;

    "AFTER")
        echo "Have Implemented Suggession Provided by Tapenade Profiling Tool"
        cp code_tap/the_model_main.F_OG code_tap/the_model_main.F
        GENMAKE_SCRIPT="patched_AfterTapProfile_genmake2"
        ;;

    *)
        echo "ERROR: Invalid use_TapProfile='$use_TapProfile'. Must be NO, YES, or AFTER." >&2
        exit 1
        ;;
esac

# Ensure build directory exists
if [ ! -d build_tapAdj ]; then
    echo "Creating the directory build_tapAdj..."
    mkdir build_tapAdj
fi

# Go to build directory
cd build_tapAdj || { echo "Failed to enter build_tapAdj"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here)
"$MITGCM_ROOT/tools/$GENMAKE_SCRIPT" -tap \
    -rd="$MITGCM_ROOT" \
    -of="$SERIAL_OPTFILE" \
    -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_tap"

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj
