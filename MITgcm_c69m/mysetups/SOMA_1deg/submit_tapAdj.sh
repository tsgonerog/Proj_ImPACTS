#!/bin/bash
# Submit the Tapenade ADJOINT.     build_tapAdj/mitgcmuv_tap_adj
# Run it with ../../../tools/submit.sh so the per-machine sbatch flags are added.
#

#SBATCH -J SOMA_1deg_tapAdj     # Set main part of the job name once here
#SBATCH -o logs/%x.%j.out                      # %x = job name, %j = job ID
# No -e: given only -o, sbatch sends both streams to that one file. The set -x
# trace below is stderr, so it lands there. A separate .err was the only file
# with content and the .out was empty on every job that ever ran.
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 48:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu   # override: sbatch --mail-user=...
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# Fail fast if anything is wrong in this script
set -e
# Enable command tracing for the entire script || all commands will be echoed (with variable expansions) into the .out file
set -x

# ========== MACHINE SETTINGS & MODULES ==========

# Per-machine scratch root, MPI launcher and module stack. On sverdrup this
# reproduces what ~/.bashrc already provides and changes nothing; on Perlmutter
# it loads PrgEnv-gnu and friends. SLURM_SUBMIT_DIR is used rather than
# BASH_SOURCE because Slurm runs this script from a spooled copy.
REPO_ROOT="$(cd "$SLURM_SUBMIT_DIR/../../.." && pwd)"
source "$REPO_ROOT/tools/machine_env.sh"
impacts_load_modules

# ========== TEST CASE FLAG ==========

# Set to "" for default (i.e., use input_tap/data)
# IMPACTS_TEST_CASE overrides this per run. The `-` (not `:-`) is deliberate:
# IMPACTS_TEST_CASE= selects the live input_tap/data, which `:-` would swallow.
# SOMA carries no variants yet (input_tap/variants/ does not exist), so the
# committed default is the live namelist; the machinery is here so a variant
# added later works exactly as in DINO.
test_cases="${IMPACTS_TEST_CASE-}"

# Build optional suffix from the tag: "_<tag>" if non-empty, otherwise empty
# (avoids a trailing underscore). Only the LAST component of the tag is used:
# the group says where the namelist lives in this repository, not anything about
# the run (see ../DINO_1deg/submit_tapAdj.sh for the full rationale).
suffix=${test_cases:+_${test_cases##*/}}

# ========== SET SOME TIME STEPPING PARAMETERS (IN DAYS) ==========

# These are patched into the STAGED namelist in the run directory; the tracked
# file under input_tap/ is never modified. The values here are the committed
# defaults (the cheap regression configuration, = validated baseline run 31031);
# override per run on the command line, which leaves the tree clean:
#
#     IMPACTS_DURATION_DAYS=30 ../../../tools/submit.sh submit_tapAdj.sh
#
# SOMA's namelist sets the duration through endTime (dT = 1200 s), so the
# override patches endTime rather than DINO's nTimeSteps.
endTime_days="${IMPACTS_DURATION_DAYS:-5}"
monitorFreq_days="${IMPACTS_MONITOR_FREQ_DAYS:-1}"
adjMonitorFreq_days="${IMPACTS_ADJ_MONITOR_FREQ_DAYS:-1}"
adjDumpFreq_days="${IMPACTS_ADJ_DUMP_FREQ_DAYS:-1}"

# Which of the above get patched into the namelist, listed explicitly.
# Do NOT go back to `compgen -v | grep '_days$'`: that also enumerates exported
# environment variables, so any *_days variable in the submitting shell would
# silently become a namelist key (sbatch exports the environment by default).
time_params=(endTime monitorFreq adjMonitorFreq adjDumpFreq)

#----------- do not edit below --------------------------

# The duration feeds integer arithmetic below; reject junk early rather than
# letting bash evaluate an unset name as 0 and silently run zero timesteps.
if ! [[ "$endTime_days" =~ ^[0-9]+$ ]]; then
  echo "ERROR: duration must be a whole number of days, got '$endTime_days'"
  exit 1
fi

# Empty test_cases uses the live input_tap/data. Otherwise the tag names a file
# under input_tap/variants/, in one of two forms:
#
#   <tag>               -> variants/data_<tag>              a standalone config
#   <experiment>/<tag>  -> variants/<experiment>/data_<tag> one member of an
#                                                           experiment
if [[ -z "$test_cases" ]]; then
    namelist_data="$SLURM_SUBMIT_DIR/input_tap/data"
elif [[ "$test_cases" == */* ]]; then
    namelist_data="$SLURM_SUBMIT_DIR/input_tap/variants/${test_cases%/*}/data_${test_cases##*/}"
else
    namelist_data="$SLURM_SUBMIT_DIR/input_tap/variants/data_${test_cases}"
fi

# Safety check
if [[ ! -f "$namelist_data" ]]; then
  echo "ERROR: File $namelist_data not found!"
  exit 1
fi

# ========== PATHS & NAMES ==========

job_name="$SLURM_JOB_NAME"      # capture the job name set above
base_dir="$SLURM_SUBMIT_DIR"    # directory from where the job was submitted
build_dir="$base_dir/build_tapAdj"
# Duration label: whole 360-day years as "<n>yr", otherwise "<n>d", so the run
# directory matches the scratch naming convention (SOMA uses a 360-day year).
if (( endTime_days % 360 == 0 )); then
    dur_label="$(( endTime_days / 360 ))yr"
else
    dur_label="${endTime_days}d"
fi
run_dir="$SCRATCH_ROOT/SOMA_1deg_tapAdj_runs/${job_name}_${dur_label}${suffix}_run$SLURM_JOB_ID"  # unique per job

# ========== STAGE THE RUN DIRECTORY ==========

# create run directory in scratch and move into it
mkdir -p "$run_dir"
cd "$run_dir"

# copy and link input files into run directory
# -maxdepth 1 -type f skips a future input_tap/variants/; a plain glob would
# try to copy that directory and abort the script under set -e.
find "$base_dir/input_tap" -maxdepth 1 -type f -exec cp {} . \;
ln -s "$base_dir/input_binaries"/* .
ln -s "$base_dir/input_adj_binaries"/* .

# Replace data file correctly
rm -f data
cp "$namelist_data" data

# ---------- sibling overrides: a variant may replace more than just `data` ----------
# Any file beside the chosen namelist named <mitgcm-file>_<tag> is staged over
# <mitgcm-file>; see ../DINO_1deg/submit_tapAdj.sh for why. No-op while SOMA
# has no variants.
variant_tag="${test_cases##*/}"
if [[ -n "$variant_tag" ]]; then
  for extra in "$(dirname "$namelist_data")"/*_"$variant_tag"; do
    [[ -f "$extra" ]] || continue
    target="$(basename "$extra")"; target="${target%_$variant_tag}"
    [[ "$target" == data ]] && continue          # the namelist itself, already staged
    cp "$extra" "$target"
    echo "staged sibling override: $(basename "$extra") -> $target"
  done
fi

# ---------- time stepping: patch the STAGED copy, not the tracked namelist ----------
# This runs here, after staging, so the repo is never written to. It matters for
# more than tidiness: this script body executes on the compute node when the job
# STARTS, so a sed against $namelist_data would race any other job that happens
# to start around the same time, and each run would stage whichever value landed
# last while its run-directory name claimed its own.
# Convert each <name>_days → seconds and patch only the RHS value (keep commas/spaces).
for name in "${time_params[@]}"; do
  eval days_val="\$${name}_days"
  secs=$(awk -v d="$days_val" 'BEGIN{printf "%.0f", d*86400}')
  newval="${secs}."
  sed -i -E "s|^([[:space:]]*${name}=)[^,]+|\1${newval}|g" data
  # sed exits 0 when it matches nothing, which would leave the namelist's own
  # value in place and run a different experiment silently. Assert instead.
  grep -qE "^[[:space:]]*${name}=${newval}," data \
    || { echo "ERROR: ${name} not patched to ${newval} in staged data"; exit 1; }
done

# >>> disable GMRedi and KPP if needed (comment out if you want to keep the default version) <<<
#sed -i -E "s|(useKPP[[:space:]]*=[[:space:]]*)\.TRUE\.|\1.FALSE.|" data.pkg
#sed -i -E "s|(useGMRedi[[:space:]]*=[[:space:]]*)\.TRUE\.|\1.FALSE.|" data.pkg

# copy MITgcm executable to run directory
cp -p "$build_dir/mitgcmuv_tap_adj" .

# ========== RUN & TIMING ==========

# record start time
run_start_time=$(date +%s)
echo "Run started at: $(date)" > run_timing.txt

# run the model in serial (SOMA's adjoint is serial-only; see SIZE.h_serial)
./mitgcmuv_tap_adj > output_tap_adj.txt 2>&1

# record end time
run_end_time=$(date +%s)
echo "Run ended at:   $(date)" >> run_timing.txt

# calculate and append elapsed time
elapsed=$((run_end_time - run_start_time))
printf "Total runtime:  %02d:%02d:%02d (HH:MM:SS)\n" \
    $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60)) >> run_timing.txt
