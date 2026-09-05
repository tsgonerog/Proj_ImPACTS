#!/bin/bash
# Submit the FORWARD model.        build_frd/mitgcmuv
#
# This file says WHAT to run -- the #SBATCH header and the committed defaults --
# and HOW is tools/lib/submit_body.sh, the body every submit script in every
# setup shares (variant resolution, build record check, staging, namelist
# patching, the run, timing). Run it from the setup directory through the
# wrapper, which adds the per-machine sbatch flags:
#     ../../../tools/submit.sh scripts/submit_frd.sh

#SBATCH -J SOMA_1deg_frd          # job name: names the log file only; the run directory is named from build_info.txt
#SBATCH -o logs/%x.%j.out         # %x = job name, %j = job ID; relative to the setup directory, where tools/submit.sh runs sbatch
# No -e: given only -o, sbatch sends both streams to that one file. The set -x
# trace below is stderr, so it lands there.
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -t 48:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu   # override: sbatch --mail-user=...
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

set -e      # fail fast if anything is wrong
set -x      # trace every command (with expansions) into the log: the record of what was staged

# ========== WHAT THIS SCRIPT RUNS ==========

BUILD_DIR=build_frd
RUN_MODE=frd
PARALLEL=mpi                # -n above must match code/SIZE.h (nPx=nPy=2 = 4 ranks)
EXPECT_RUN_TOKEN=frd        # refuse a build directory holding anything else

# ========== TEST CASE ==========

# Set to "" for default (i.e., use input/data). IMPACTS_TEST_CASE overrides
# this per run. The `-` (not `:-`) is deliberate: IMPACTS_TEST_CASE= selects the
# live input/data, which `:-` would swallow. SOMA carries no variants yet
# (input/variants/ does not exist), so the committed default is the live
# namelist; the machinery is shared with DINO, so a variant added later works
# exactly as it does there.
test_cases="${IMPACTS_TEST_CASE-}"

# ========== TIME STEPPING PARAMETERS (IN DAYS) ==========

# These are patched into the STAGED namelist in the run directory; the tracked
# file under input/ is never modified. The values here are the committed
# defaults; override per run on the command line, which leaves the tree clean:
#
#     IMPACTS_DURATION_DAYS=360 ../../../tools/submit.sh scripts/submit_frd.sh
#
# SOMA's namelist sets the duration through endTime (dT = 1200 s), so the
# override patches endTime rather than DINO's nTimeSteps (scripts/setup_params.sh).
duration_days="${IMPACTS_DURATION_DAYS:-30}"
monitorFreq_days="${IMPACTS_MONITOR_FREQ_DAYS:-10}"

# Which of the *_days above get patched into the namelist (besides the
# duration), listed explicitly -- see the body for why not auto-detected.
TIME_PARAMS=(monitorFreq)

# No pickup: SOMA runs start from rest.

source "$SLURM_SUBMIT_DIR/../../../tools/lib/submit_body.sh"
