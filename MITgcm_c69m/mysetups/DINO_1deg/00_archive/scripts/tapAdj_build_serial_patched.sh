#!/bin/bash
# Serial Tapenade-adjoint build for MITgcm

# Exit immediately if a command fails (-e),
# treat unset variables as errors (-u),
# and make pipelines fail if any part fails (pipefail).
set -euo pipefail

# Set root directory for MITgcm relative to THIS script (works after cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MITGCM_ROOT="$SCRIPT_DIR/../MITgcm"

# Replace SIZE.h with serial version
cp code_tap/SIZE.h_serial code_tap/SIZE.h
cp code_tap/forward_step_b.f_modified_serial code_tap/forward_step_b.f_modified

###############################################
# Choose TapProfile behavior here:
#   NO    : Don't want to use Tapenade profiling, use patched_NoTapProfile_genmake2
#   YES   : Want to use Tapenade profiling, use patched_ForTapProfile_genmake2
#   AFTER : After implementing suggession provided by Tapenade profiling tool, use patched_AfterTapProfile_genmake2
###############################################

use_TapProfile="NO"   # <-- change this to "YES" or "AFTER" as needed

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
if [ ! -d build_tapAdj_serial_patched ]; then
    echo "Creating the directory build_tapAdj_serial_patched..."
    mkdir build_tapAdj_serial_patched
fi

# Go to build directory
cd build_tapAdj_serial_patched || { echo "Failed to enter build_tapAdj_serial_patched"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here)
"$MITGCM_ROOT/tools/$GENMAKE_SCRIPT" -tap \
    -rd="$MITGCM_ROOT" \
    -of="$MITGCM_ROOT/tools/build_options/linux_amd64_ifort" \
    -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_tap"

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj
