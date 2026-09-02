#!/bin/bash
# Build the Tapenade ADJOINT with PROFILE-GUIDED -nocheckpoint tuning.
#   sources : code_tap/ + input_tap/  ->  build_tapAdj_nocheckpoint/mitgcmuv_tap_adj
#
# THE DEFAULT adjoint build since 2026-09-02: ./build_tapAdj.sh is a symlink
# to this file (and ./submit_tapAdj.sh to submit_tapAdj_nocheckpoint.sh).
# The former default, with every call checkpointed, is build_tapAdj_ckpAll.sh;
# this build is bitwise identical to it in fc, adxx_* and ADJ* at 30 d (run
# 31054 vs 31052) and 5 yr (31055 vs 31039) and 1.5x faster. The routine list
# below is a profile of ONE configuration (KPP/GM off, 27 ranks, this package
# set): the _FWD check at the bottom catches a name that vanished, not a list
# that stopped being the right list, so re-profile with
# build_tapAdj_tapProfile.sh whenever the adjoint's package set, physics or
# decomposition changes.
#
# Same stock genmake2 + flow_tap_local hook wiring as build_tapAdj_ckpAll.sh
# (see there for how the ADJ* dump call is generated), with one Tapenade flag
# added: -nocheckpoint "<routines>". By default Tapenade checkpoints every
# call inside a time step ("joint" mode): the callee's primal is run once in
# the enclosing forward sweep and run AGAIN, recording, inside its own _B
# routine -- and that re-execution multiplies with nesting depth. For a routine
# named in -nocheckpoint Tapenade generates a _FWD/_BWD pair instead ("split"
# mode): the primal runs once, recording, and its tape simply lives until the
# backward sweep reaches it. Recomputation is traded for tape memory, within a
# single time step -- the binomial checkpointing of the time loop itself
# (C$AD BINOMIAL-CKP in code_tap/the_main_loop.F) is untouched.
#
# The routine list is code_tap/tap_nocheckpoint.txt (one name per line, '#'
# comments allowed). It was derived from the cost/benefit table of the
# build_tapAdj_tapProfile.sh run -- tools/tapenade_profiling/README.md records
# how, and what the validation against build_tapAdj_ckpAll gave. Re-profile before
# editing it: a routine Tapenade never checkpoints is a no-op here and the
# check at the bottom rejects it, so the list stays honest.
#
# Pair with submit_tapAdj_nocheckpoint.sh (or its ./submit_tapAdj.sh symlink).
# The adjoint is mathematically the same as build_tapAdj_ckpAll's (same
# values, stored instead of recomputed).
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

# The routines to differentiate in split mode: strip comments and blank lines,
# one space-separated string for Tapenade. Lower case is how Tapenade names
# units internally; it matches case-insensitively, but keep the file lower case.
NOCP_FILE="code_tap/tap_nocheckpoint.txt"
[ -f "$NOCP_FILE" ] || { echo "ERROR: $NOCP_FILE not found"; exit 1; }
mapfile -t NOCP_LIST < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$NOCP_FILE" | grep -v '^$' | tr 'A-Z' 'a-z')
if [ "${#NOCP_LIST[@]}" -eq 0 ]; then
    echo "ERROR: $NOCP_FILE names no routine; use build_tapAdj_ckpAll.sh for the plain adjoint."
    exit 1
fi
NOCP="${NOCP_LIST[*]}"
echo "-nocheckpoint list (${#NOCP_LIST[@]} routines): $NOCP"

# Ensure build directory exists
if [ ! -d build_tapAdj_nocheckpoint ]; then
    echo "Creating the directory build_tapAdj_nocheckpoint..."
    mkdir build_tapAdj_nocheckpoint
fi

# Go to build directory
cd build_tapAdj_nocheckpoint || { echo "Failed to enter build_tapAdj_nocheckpoint"; exit 1; }

# Clean any previous build (ignore if Makefile not created yet)
make CLEAN || true

# Configure the build (this creates the Makefile here). -tap_extra carries
# both flags: the split-mode routine list and the setup-local external
# library that makes Tapenade generate the ADJ* dump-hook call (see
# build_tapAdj_ckpAll.sh). genmake2 writes the string verbatim into the Makefile's
# TAP_EXTRA, so the inner quotes survive to the shell that runs Tapenade.
"$MITGCM_ROOT/tools/genmake2" -mpi -tap \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_tap" \
    -tap_extra "-nocheckpoint \"$NOCP\" -ext ../code_tap/flow_tap_local"

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
check_gen_call TAP_DUMMY_IN_STEPPING_B 25 forward_step_b.f
check_gen_call TAP_INADMODE_SET_B 5 forward_step_b.f
check_gen_call TAP_INADMODE_UNSET_B 5 forward_step_b.f
check_gen_call TAP_DUMMY_FOR_ETAN_B 5 integr_continuity_b.f

# Every listed routine must actually have gone split: Tapenade emits a
# <NAME>_FWD / <NAME>_BWD pair for it. A name it does not know, or one it never
# checkpoints, is silently ignored by Tapenade -- fail here instead, so the
# list cannot drift out of step with the code.
missing=""
for r in "${NOCP_LIST[@]}"; do
    R=$(echo "$r" | tr 'a-z' 'A-Z')
    if ! grep -qE "^ *SUBROUTINE ${R}_FWD\(" ./*_b.f; then
        missing="$missing $r"
    fi
done
if [ -n "$missing" ]; then
    echo "ERROR: no _FWD/_BWD pair was generated for:$missing"
    echo "       Either the name is wrong or Tapenade never checkpointed that"
    echo "       routine here. Remove it from $NOCP_FILE or fix the spelling."
    exit 1
fi
echo "OK: all ${#NOCP_LIST[@]} listed routines were generated in split (_FWD/_BWD) mode."

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
    echo "tapenade_checkpointing=nocheckpoint  # routines in nocheckpoint_list differentiated in split _FWD/_BWD mode"
    echo "variant=plain                        # code_tap/ alone: no variant directory, no profiler"
    echo "run_token=tapAdj_nocheckpoint"
    echo "tap_extra=$(sed -n 's/^TAP_EXTRA *= *//p' Makefile)"
    echo "nocheckpoint_list=$NOCP"
    echo "git_commit=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "git_modified_tracked_files=${dirty}   # in this setup"
    echo "built=$(date '+%Y-%m-%d %H:%M:%S %Z') on $(hostname)"
} > build_info.txt
echo "OK: wrote $(basename "$PWD")/build_info.txt (run_token=tapAdj_nocheckpoint)."
