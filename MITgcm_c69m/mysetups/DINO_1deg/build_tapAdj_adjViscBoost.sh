#!/bin/bash
# Adjoint built for ADJOINT-MODE VISCOSITY INFLATION.
#   sources : code_tap/ + input_tap/  ->  build_tapAdj_adjViscBoost/mitgcmuv_tap_adj
#
# Same stock genmake2 + flow_tap_local hook wiring as build_tapAdj.sh (see
# there for how the ADJ* dump call is generated), but stages the ASTE-derived
# AUTODIFF_PARAMS.h / autodiff_readparms.F / autodiff_inadmode_set_ad.F, which
# add the inAd*/outAd* parameters. Those let the model run with larger viscosity
# and diffusivity during the adjoint sweep than in the forward - the standard
# trick for keeping a long adjoint from blowing up.
#
# The build only provides the machinery; the values come from
# input_tap/data.autodiff_adjViscBoost at run time (viscFacInAd = 10 vs
# viscFacInFw = 1, inAdviscArNr = 2.E-3 against a forward 1.2E-4, and added
# inAddiffKhT/S). So this build MUST be paired with
# submit_tapAdj_adjViscBoost.sh, which swaps that namelist in. Pairing it with
# submit_tapAdj.sh silently runs the plain configuration.
#
# Numbers were adapted from the ASTE 90x150x60 regional setup.
#
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
cp code_tap/AUTODIFF_PARAMS.h_aste_90x150x60 code_tap/AUTODIFF_PARAMS.h
cp code_tap/autodiff_readparms.F_aste_90x150x60 code_tap/autodiff_readparms.F
cp code_tap/autodiff_inadmode_set_ad.F_adapted_frm_aste_90x150x60 code_tap/autodiff_inadmode_set_ad.F
cp code_tap/autodiff_inadmode_unset_ad.F_adapted_frm_aste_90x150x60 code_tap/autodiff_inadmode_unset_ad.F

# MPI_OPTFILE is defaulted by machine_env.sh; this catches a machine with none.
if [ -z "$MPI_OPTFILE" ] || [ ! -f "$MPI_OPTFILE" ]; then
    echo "ERROR: MPI_OPTFILE is unset or missing: '$MPI_OPTFILE'"
    echo "       Set it for machine '$MACHINE' in tools/machine_env.sh, or export it."
    exit 1
fi

###############################################
# Choose TapProfile behavior here:
#   NO    : no Tapenade profiling      -> tools/genmake2_override_forward_step_b
#   YES   : use Tapenade profiling      -> patched_ForTapProfile_genmake2    (NOT here)
#   AFTER : after acting on its advice  -> patched_AfterTapProfile_genmake2  (NOT here)
#
# Only NO works in this repository. The YES/AFTER variants keep their original
# names because that is what they are called in the one place they still exist,
# Proj_ImPACTS_old/MITgcm_c69f/MITgcm/tools/.
###############################################

use_TapProfile="NO"   # <-- change this to "YES" or "AFTER" as needed

# Decide which the_model_main.F and which patched_genmake2 to use
case "$use_TapProfile" in
    "NO")
        echo "Not Using Tapenade Profiling Tool"
        cp code_tap/the_model_main.F_OG code_tap/the_model_main.F
        GENMAKE_SCRIPT="genmake2"
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
if [ ! -d build_tapAdj_adjViscBoost ]; then
    echo "Creating the directory build_tapAdj_adjViscBoost..."
    mkdir build_tapAdj_adjViscBoost
fi

# Go to build directory
cd build_tapAdj_adjViscBoost || { echo "Failed to enter build_tapAdj_adjViscBoost"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here); -tap_extra injects
# the setup-local external library that makes Tapenade generate the ADJ*
# dump-hook call (see build_tapAdj.sh).
"$MITGCM_ROOT/tools/$GENMAKE_SCRIPT" -mpi -tap \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_tap" \
    -tap_extra "-ext ../code_tap/flow_tap_local"

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj

# Same generated-call checks as build_tapAdj.sh: each hook's _B argument
# list must match its hand-written routine; F77 would silently misalign a
# mismatch, so fail loudly instead.
check_gen_call() {
    local name=$1 expect=$2 n
    n=$(awk -v pat="CALL ${name}\\\\(" '$0 ~ pat {f=1}
         f{buf=buf $0; if (index($0,")")) exit}
         END{if (buf=="") {print 0} else {print gsub(/,/,",",buf)+1}}' \
        forward_step_b.f)
    if [ "${n:-0}" -ne "$expect" ]; then
        echo "ERROR: generated CALL ${name} in forward_step_b.f has ${n:-0}"
        echo "       arguments, expected ${expect}. Align the hand-written"
        echo "       routine with the generated call before using this"
        echo "       executable."
        exit 1
    fi
    echo "OK: generated ${name} call has ${expect} arguments."
}
check_gen_call TAP_DUMMY_IN_STEPPING_B 25
check_gen_call TAP_INADMODE_SET_B 5
check_gen_call TAP_INADMODE_UNSET_B 5
