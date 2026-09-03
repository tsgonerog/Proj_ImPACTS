#!/bin/bash
# Adjoint built for ADJOINT-MODE VISCOSITY INFLATION.
#   sources : code_tap/ + input_tap/  ->  build_tapAdj_adjViscBoost/mitgcmuv_tap_adj
#
# Same stock genmake2 + flow_tap_local hook wiring as build_tapAdj_ckpAll.sh
# (see there for how the ADJ* dump call is generated), and like it EVERY call
# is checkpointed: this build deliberately does NOT carry the default build's
# -nocheckpoint list. Tested 2026-09-02 (run 31056, this build + the list, vs
# 31025, without it): fc and the %MON stream byte-identical, but every ADJ*
# dump and adxx_* gradient differed at order one -- while the plain pair is
# bitwise identical under the same list. In joint mode Tapenade re-runs each
# routine's primal inside the backward sweep, after AUTODIFF_INADMODE_SET_B has
# boosted the viscosities, so the boost reaches every recomputed intermediate;
# in split mode those intermediates were taped in the forward sweep at forward
# viscosities and the boost reaches only what the _BWD code reads live. Only
# the joint-mode boost is what the ASTE/TAF-style mechanism was designed as
# and what 31025 validated. Record: analyses/DINO_1deg/adjoint/
# tapenade_profiling/compare_30d_adjViscBoost_run31025_vs_nocheckpoint_run31056.md.
#
# What differs from build_tapAdj_ckpAll.sh is a second -mods directory,
# code_tap/variants/adjViscBoost/, listed FIRST so that its four files shadow
# both code_tap/ and the vendored tree: AUTODIFF_PARAMS.h / autodiff_readparms.F
# declare and read the inAd*/outAd* parameters, autodiff_inadmode_set_ad.F /
# autodiff_inadmode_unset_ad.F apply and restore them. Those let the model run
# with larger viscosity and diffusivity during the adjoint sweep than in the
# forward - the standard trick for keeping a long adjoint from blowing up.
# Nothing is copied into code_tap/; the check after make confirms the variant
# is what got compiled.
#
# The build only provides the machinery; the values come from
# input_tap/data.autodiff_adjViscBoost at run time (viscFacInAd = 10 vs
# viscFacInFw = 1, inAdviscArNr = 2.E-3 against a forward 1.2E-4, and added
# inAddiffKhT/S). So this build MUST be paired with
# submit_tapAdj_adjViscBoost.sh, which swaps that namelist in. Pairing it with
# submit_tapAdj.sh silently runs the plain configuration.
#
# Validation history: run 31025 (30 d from rest, live input_tap/data) is the
# first working adjViscBoost adjoint (fc bit-identical to plain 31026, every
# sensitivity damped); 31056 is the rejected split-mode variant.
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

# MPI_OPTFILE is defaulted by machine_env.sh; this catches a machine with none.
if [ -z "$MPI_OPTFILE" ] || [ ! -f "$MPI_OPTFILE" ]; then
    echo "ERROR: MPI_OPTFILE is unset or missing: '$MPI_OPTFILE'"
    echo "       Set it for machine '$MACHINE' in tools/machine_env.sh, or export it."
    exit 1
fi

# No main-program staging: code_tap/ carries no the_model_main.F, so the
# vendored model/src/the_model_main.F is compiled. (The c69f-era use_TapProfile
# switch that used to live here staged an _OG copy -- byte-identical to
# upstream -- or a _ForTapProfile one, now archived in 00_archive/code_tap/,
# and selected among patched genmake2 copies that do not exist in c69m.)
# Tapenade profiling and -nocheckpoint tuning are separate builds driven by
# -tap_extra; see tools/tapenade_profiling/README.md.

# Ensure build directory exists
if [ ! -d build_tapAdj_adjViscBoost ]; then
    echo "Creating the directory build_tapAdj_adjViscBoost..."
    mkdir build_tapAdj_adjViscBoost
fi

# Go to build directory
cd build_tapAdj_adjViscBoost || { echo "Failed to enter build_tapAdj_adjViscBoost"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here); -adof names the
# setup's Tapenade options file (stock options + code_tap/flow_tap_local,
# see build_tapAdj_ckpAll.sh). No -nocheckpoint here, on
# purpose -- see the header. -mods names the variant directory FIRST: genmake2
# gives a file in an earlier -mods directory preference over a same-named file
# anywhere later, so the four files in code_tap/variants/adjViscBoost/ replace
# their code_tap/ and pkg/autodiff/ counterparts without any copy step.
"$MITGCM_ROOT/tools/genmake2" -mpi -tap \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods="../code_tap/variants/adjViscBoost ../code_tap" \
    -adof=../code_tap/adjoint_tap_local

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj

# The variant must be what was compiled: genmake2 links the first match it
# finds, so a wrong -mods order would silently build the plain adjoint under
# this build's name. The inAd*/outAd* names exist only in the variant sources.
for f in autodiff_readparms.f autodiff_inadmode_set_ad.f autodiff_inadmode_unset_ad.f; do
    if ! grep -qE 'inAdviscAhGrid|outAdviscAhGrid' "$f"; then
        echo "ERROR: the compiled $f is not the adjViscBoost variant;"
        echo "       check the -mods order (code_tap/variants/adjViscBoost must come first)."
        exit 1
    fi
done
echo "OK: the compiled autodiff sources are the adjViscBoost variant."

# Same generated-call checks as build_tapAdj_ckpAll.sh: each hook's _B argument
# list must match its hand-written routine; F77 would silently misalign a
# mismatch, so fail loudly instead.
check_gen_call() {
    local name=$1 expect=$2 file=$3 n
    n=$(awk -v pat="CALL ${name}\\\\(" '$0 ~ pat {f=1}
         f{buf=buf $0; if (index($0,")")) exit}
         END{if (buf=="") {print 0} else {print gsub(/,/,",",buf)+1}}' \
        "$file")
    if [ "${n:-0}" -ne "$expect" ]; then
        echo "ERROR: generated CALL ${name} in ${file} has ${n:-0}"
        echo "       arguments, expected ${expect}. Align the hand-written"
        echo "       routine with the generated call before using this"
        echo "       executable."
        exit 1
    fi
    echo "OK: generated ${name} call has ${expect} arguments."
}
check_gen_call DUMMY_IN_STEPPING_B 25 forward_step_b.f
check_gen_call AUTODIFF_INADMODE_SET_B 5 forward_step_b.f
check_gen_call AUTODIFF_INADMODE_UNSET_B 5 forward_step_b.f
check_gen_call DUMMY_FOR_ETAN_B 5 integr_continuity_b.f

# The hook adjoints must have kept their bodies. dummy_tap.F includes
# AD_CONFIG.h, the only definition of ALLOW_ADJOINT_RUN, which guards the ADJ*
# dump code: without it the adjoint is still bitwise correct but writes no ADJ*
# files (2026-09-02, runs 31071-31073). Fail here rather than after a run.
ndump=$(grep -c 'CALL DUMP_ADJ_' dummy_tap.f)
if [ "${ndump:-0}" -lt 10 ]; then
    echo "ERROR: the compiled dummy_tap.f carries only ${ndump:-0} DUMP_ADJ_* calls (expected 10):"
    echo "       the ADJ* dump bodies were preprocessed away -- check the AD_CONFIG.h include."
    exit 1
fi
echo "OK: the compiled dummy_tap.f carries ${ndump} ADJ* dump calls."

# ========== BUILD RECORD ==========
# Written last, after every check above passed, so build_info.txt can only
# describe an executable this script built and verified. The submit scripts
# refuse an executable without it (or newer than it) and take run_token from
# it, so a run directory is named from what was actually built, not from what
# the submit script assumes:  DINO_1deg_<run_token>_<duration>[_<tag>]_run<jobid>
dirty=$(git -C "$SCRIPT_DIR" diff --name-only HEAD -- . 2>/dev/null | wc -l)
{
    echo "build_script=$(basename "$(readlink -f "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")")")"   # resolved from the setup dir: after the cd above, a relative BASH_SOURCE would not resolve the symlink
    echo "invoked_as=$(basename "${BASH_SOURCE[0]}")"
    echo "build_dir=$(basename "$PWD")"
    echo "exe_md5=$(md5sum mitgcmuv_tap_adj | cut -d' ' -f1)"   # identity of the binary this record describes; the submit scripts verify it
    echo "tapenade_checkpointing=ckpAll        # every call checkpointed; the -nocheckpoint list is NOT equivalent under the boost (run 31056 vs 31025)"
    echo "variant=adjViscBoost                 # code_tap/variants/adjViscBoost/ compiled ahead of code_tap/ (inAd*/outAd*); pair with submit_tapAdj_adjViscBoost.sh"
    echo "run_token=tapAdj_ckpAll_adjViscBoost"
    echo "tap_extra=$(sed -n 's/^TAP_EXTRA *= *//p' Makefile)"
    echo "git_commit=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "git_modified_tracked_files=${dirty}   # in this setup"
    echo "built=$(date '+%Y-%m-%d %H:%M:%S %Z') on $(hostname)"
} > build_info.txt
echo "OK: wrote $(basename "$PWD")/build_info.txt (run_token=tapAdj_ckpAll_adjViscBoost)."
