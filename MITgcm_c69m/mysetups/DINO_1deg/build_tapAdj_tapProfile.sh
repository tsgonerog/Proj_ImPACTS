#!/bin/bash
# Build the Tapenade ADJOINT with Tapenade's CHECKPOINTING PROFILER compiled in.
#   sources : code_tap/ + input_tap/ + tools/tapenade_profiling/mods_profile/
#          -> build_tapAdj_tapProfile/mitgcmuv_tap_adj
#
# Same stock genmake2 + flow_tap_local hook wiring as build_tapAdj_ckpAll.sh
# (see there for how the ADJ* dump call is generated), plus two things:
#
#   * "-profile" on the Tapenade command line, through -tap_extra. Tapenade
#     then brackets every checkpointed call in the generated adjoint with
#     ADPROFILEADJ_* calls that time each checkpoint's recomputation and
#     measure the snapshot it stores, and accumulate per call site the time
#     that NOT checkpointing it would save and the peak memory it would cost.
#   * a second -mods directory, tools/tapenade_profiling/mods_profile/, listed
#     FIRST so it shadows code_tap/ and the vendored tree. It supplies
#     adProfile.c (the runtime those calls need, copied from the installed
#     Tapenade's ADFirstAidKit: c69m ships an older, API-incompatible copy and
#     does not compile it) and a the_model_main.F that, after THE_MAIN_LOOP_B,
#     prints the tape peak and writes the per-process cost/benefit table
#     (tapenade_profile.NNNN.txt in the run directory).
#
# This is a DIAGNOSTIC build. Its adjoint does exactly what build_tapAdj_ckpAll's
# does (same checkpointing, same numbers) with timing calls added, so it is
# somewhat slower and must not be used for production runs or as a runtime
# reference. Pair it with submit_tapAdj_tapProfile.sh (30-day default), and
# read tools/tapenade_profiling/README.md for how to turn the table into a
# -nocheckpoint list for build_tapAdj_nocheckpoint.sh. It deliberately does
# NOT carry that list: a profile of the tuned build would only show the
# residual cost, while the list is derived by seeing every checkpoint.
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

# The profiler runtime + main program. genmake2 gets the path relative to the
# build directory, like ../code_tap, so the generated Makefile carries no
# extra machine path; the existence check below resolves the same directory
# from this script's location (one level up from the build directory).
PROFILE_MODS="../../../../tools/tapenade_profiling/mods_profile"
for f in adProfile.c the_model_main.F; do
    if [ ! -f "$SCRIPT_DIR/../../../tools/tapenade_profiling/mods_profile/$f" ]; then
        echo "ERROR: tools/tapenade_profiling/mods_profile/$f not found"
        echo "       (looked from $SCRIPT_DIR/../../../)"
        exit 1
    fi
done

# Ensure build directory exists
if [ ! -d build_tapAdj_tapProfile ]; then
    echo "Creating the directory build_tapAdj_tapProfile..."
    mkdir build_tapAdj_tapProfile
fi

# Go to build directory
cd build_tapAdj_tapProfile || { echo "Failed to enter build_tapAdj_tapProfile"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here). -mods lists the
# profiler directory first so its two files win over code_tap/ and upstream;
# -adof names the setup's Tapenade options file (stock options +
# code_tap/flow_tap_local, see build_tapAdj_ckpAll.sh); -tap_extra carries
# the profiler switch.
"$MITGCM_ROOT/tools/genmake2" -mpi -tap \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods="$PROFILE_MODS ../code_tap" \
    -adof=../code_tap/adjoint_tap_local \
    -tap_extra "-profile"

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj

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

# Profiler-specific checks: Tapenade must have emitted the instrumentation,
# the shadowed main program must be the one compiled, and its runtime linked.
if ! grep -q 'CALL ADPROFILEADJ_SNPWRITE' forward_step_b.f; then
    echo "ERROR: forward_step_b.f carries no ADPROFILEADJ_* calls;"
    echo "       -profile did not reach the Tapenade command line."
    exit 1
fi
if ! grep -q 'ADPROFILEADJ_SHOWPROFILESFILE' the_model_main.f; then
    echo "ERROR: the compiled the_model_main.f is not the profiling variant;"
    echo "       check the -mods order (mods_profile must come first)."
    exit 1
fi
[ -f adProfile.o ] || { echo "ERROR: adProfile.o missing; adProfile.c was not compiled."; exit 1; }
echo "OK: profiler instrumentation, main program and runtime are all in place."

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
    echo "tapenade_checkpointing=ckpAll        # every call checkpointed, as the profile must see them"
    echo "variant=tapProfile                   # -profile instrumentation + mods_profile/ main program; diagnostic only"
    echo "run_token=tapAdj_ckpAll_tapProfile"
    echo "tap_extra=$(sed -n 's/^TAP_EXTRA *= *//p' Makefile)"
    echo "git_commit=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "git_modified_tracked_files=${dirty}   # in this setup"
    echo "built=$(date '+%Y-%m-%d %H:%M:%S %Z') on $(hostname)"
} > build_info.txt
echo "OK: wrote $(basename "$PWD")/build_info.txt (run_token=tapAdj_ckpAll_tapProfile)."
