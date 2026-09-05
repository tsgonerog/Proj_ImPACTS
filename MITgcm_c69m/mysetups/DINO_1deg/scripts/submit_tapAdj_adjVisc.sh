#!/bin/bash
# Submit the adjoint with ADJOINT-MODE VISCOSITY INFLATION.
#                                  build_tapAdj_adjVisc/mitgcmuv_tap_adj
#
# Besides pointing at that build, this script replaces data.autodiff with
# input_tap/variants/adjointViscosity/data.autodiff_adjointViscosity in the
# staged run directory, which is what actually turns the inAd*/outAd*
# parameters on. Build and submit script are a pair - neither works as
# intended without the other - and the run token check below enforces it. The
# build checkpoints every call, like build_tapAdj_ckpAll.sh -- the default
# build's -nocheckpoint list is NOT equivalent under the boost (2026-09-02, run
# 31056 vs 31025; see the build script) -- so its run directories are named
# tapAdj_ckpAll_adjVisc_*.
#
# This file says WHAT to run; HOW is tools/lib/submit_body.sh, shared by every
# submit script. Run it from the setup directory through the wrapper:
#     ../../../tools/submit.sh scripts/submit_tapAdj_adjVisc.sh

#SBATCH -J DINO_1deg_tapAdj_adjVisc   # job name: names the log file only; the run directory is named from build_info.txt
#SBATCH -o logs/%x.%j.out                  # %x = job name, %j = job ID; relative to the setup directory, where tools/submit.sh runs sbatch
# No -e: given only -o, sbatch sends both streams to that one file. The set -x
# trace below is stderr, so it lands there.
#SBATCH -N 1
#SBATCH -n 27
#SBATCH -t 240:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu   # override: sbatch --mail-user=...
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

set -e      # fail fast if anything is wrong
set -x      # trace every command (with expansions) into the log: the record of what was staged

# ========== WHAT THIS SCRIPT RUNS ==========

BUILD_DIR=build_tapAdj_adjVisc
RUN_MODE=tapAdj
PARALLEL=mpi                                  # -n above must match code_tap/SIZE.h (nPx=3, nPy=9 = 27 ranks)
EXPECT_RUN_TOKEN=tapAdj_ckpAll_adjVisc   # refuse a build directory holding any other variant

# ========== TEST CASE ==========

# Set to "" for default (i.e., use input_tap/data). IMPACTS_TEST_CASE overrides
# this per run. The `-` (not `:-`) is deliberate: IMPACTS_TEST_CASE= selects the
# live input_tap/data, which `:-` would swallow. The committed default here IS
# the live namelist (a 30-day run of it is 31025/31075/31090, from rest); the
# run is then named from the namelist (from_rest_viscRef).
test_cases="${IMPACTS_TEST_CASE-}"

# ========== TIME STEPPING PARAMETERS (IN DAYS) ==========

# These are patched into the STAGED namelist in the run directory; the tracked
# file under input_tap/ is never modified. The values here are the committed
# defaults; override per run on the command line, which leaves the tree clean:
#
#     IMPACTS_DURATION_DAYS=3660 ../../../tools/submit.sh scripts/submit_tapAdj_adjVisc.sh
#
duration_days="${IMPACTS_DURATION_DAYS:-1830}"              # 5 years at 366 d/yr -> nTimeSteps
monitorFreq_days="${IMPACTS_MONITOR_FREQ_DAYS:-5}"
adjMonitorFreq_days="${IMPACTS_ADJ_MONITOR_FREQ_DAYS:-5}"
adjDumpFreq_days="${IMPACTS_ADJ_DUMP_FREQ_DAYS:-5}"

# Which of the *_days above get patched into the namelist (besides the
# duration), listed explicitly -- see the body for why not auto-detected.
TIME_PARAMS=(monitorFreq adjMonitorFreq adjDumpFreq)

# ========== THE ADJOINT-MODE VISCOSITY NAMELIST ==========

# A copy from variants/, not a mv of an already-staged file: only the selected
# variant's files are staged, so data.autodiff in the run directory is the
# plain one until this replaces it. Runs after the namelist and its siblings
# are staged.
stage_extra() {
    rm data.autodiff
    cp "$SLURM_SUBMIT_DIR/input_tap/variants/adjointViscosity/data.autodiff_adjointViscosity" data.autodiff
}

# ========== PICKUP ==========

# from_rest needs none. Uncomment for a from50yrPk / from70yrPk / from180yrPk
# start, matching the nIter0 baked into whichever data_<tag> test_cases selects.
#
# NOTE (2026-09-03): these used to come from crashed run 19369
# (viscD2x_Zref, the 50 yr anchor) and crashed run 18277 (the 70 yr one).
# Both runs were deleted in the scratch consolidation. The 200-yr visc2x
# spin-up 30983 carries all 2 402 pickups and is now the only source, so a
# 50 yr or 70 yr start is a *visc2x* state, not the viscD2x_Zref state the
# earlier runs used. That changes the experiment, not just the path.
stage_pickups() {
    :   # nothing for from_rest
    #ln -s $SCRATCH_ROOT/DINO_1deg_outputs/runs/forward/spinup_200yr_visc2x/DINO_1deg_frd_200yr_from_rest_visc2x_run30983/pickup.0000878400.data pickup.0000878400.data
    #ln -s $SCRATCH_ROOT/DINO_1deg_outputs/runs/forward/spinup_200yr_visc2x/DINO_1deg_frd_200yr_from_rest_visc2x_run30983/pickup.0000878400.meta pickup.0000878400.meta
    #ln -s $SCRATCH_ROOT/DINO_1deg_outputs/runs/forward/spinup_200yr_visc2x/DINO_1deg_frd_200yr_from_rest_visc2x_run30983/pickup.0001229760.data pickup.0001229760.data
    #ln -s $SCRATCH_ROOT/DINO_1deg_outputs/runs/forward/spinup_200yr_visc2x/DINO_1deg_frd_200yr_from_rest_visc2x_run30983/pickup.0001229760.meta pickup.0001229760.meta
    #ln -s $SCRATCH_ROOT/DINO_1deg_outputs/runs/forward/spinup_200yr_visc2x/DINO_1deg_frd_200yr_from_rest_visc2x_run30983/pickup.0003162240.data pickup.0003162240.data
    #ln -s $SCRATCH_ROOT/DINO_1deg_outputs/runs/forward/spinup_200yr_visc2x/DINO_1deg_frd_200yr_from_rest_visc2x_run30983/pickup.0003162240.meta pickup.0003162240.meta
}

source "$SLURM_SUBMIT_DIR/../../../tools/lib/submit_body.sh"
