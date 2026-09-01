#!/bin/bash
# Submit the SOMA adjoint for 180 days.   build_tapAdj/mitgcmuv_tap_adj
#
# Durations are pre-made as separate scripts because adjoint cost grows quickly
# with integration length; edit endTime_days at the top to vary one.
#
# Run it with ../../../tools/submit.sh so the per-machine sbatch flags are added.
#

#SBATCH -J pd_StP_srl_no-kpp-GM     # Set job name once here
#SBATCH -o %x.%j.out     # %x = job name, %j = job ID
#SBATCH -e %x.%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 48:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# Enable command tracing for the entire script || all commands will be echoed (with variable expansions) into the .err file
set -x

# ========== MACHINE SETTINGS & MODULES ==========

# Per-machine scratch root, MPI launcher and module stack. On sverdrup this
# reproduces what ~/.bashrc already provides and changes nothing; on Perlmutter
# it loads PrgEnv-gnu and friends. SLURM_SUBMIT_DIR is used rather than
# BASH_SOURCE because Slurm runs this script from a spooled copy.
REPO_ROOT="$(cd "$SLURM_SUBMIT_DIR/../../.." && pwd)"
source "$REPO_ROOT/tools/machine_env.sh"
impacts_load_modules

# ========== LOAD NECESSARY MODULES ==========

# necessary modules have been loaded through .bashrc

# ========== SET SOME TIME STEPPING PARAMETERS (IN DAYS) ==========
# Patched into the STAGED namelist in the run directory; the tracked
# input_tap/data is never modified.

endTime_days=180
monitorFreq_days=5
adjMonitorFreq_days=5
adjDumpFreq_days=5

# Which of these get patched into the namelist, listed explicitly.
# Do NOT go back to `compgen -v | grep '_days$'`: that also enumerates exported
# environment variables, so any *_days variable in the submitting shell would
# silently become a namelist key (sbatch exports the environment by default).
time_params=(endTime monitorFreq adjMonitorFreq adjDumpFreq)

#----------- do not edit below --------------------------
namelist_data="$SLURM_SUBMIT_DIR/input_tap/data"

# Safety check. These scripts carry no `set -e`, so check explicitly.
if [[ ! -f "$namelist_data" ]]; then
  echo "ERROR: File $namelist_data not found!"
  exit 1
fi

# ========== PATHS & NAMES ==========

job_name="$SLURM_JOB_NAME"      # capture the job name set above
base_dir="$SLURM_SUBMIT_DIR"    # directory from where the job was submitted
build_dir="$base_dir/build_tapAdj"
run_dir="$SCRATCH_ROOT/SOMA_1deg_tapAdj_runs/${job_name}_${endTime_days}d_run$SLURM_JOB_ID"  # unique per job

# ========== STAGE THE RUN DIRECTORY ==========

# create run directory in scratch and move into it
mkdir -p "$run_dir"
# No `set -e` in these scripts: without || exit 1 a failed cd would run the
# whole staging block in the repo directory.
cd "$run_dir" || exit 1

# copy and link input files into run directory
cp "$base_dir/input_tap"/* .
ln -s "$base_dir/input_binaries"/* .
ln -s "$base_dir/input_adj_binaries"/* .

# Replace data file correctly. The glob above already copied it, but stage it
# explicitly so the loop below has a named target and $namelist_data does not
# survive as dead code naming a repo path -- which is how the sed came to be
# pointed at the tracked file in the first place.
rm -f data
cp "$namelist_data" data

# ---------- time stepping: patch the STAGED copy, not the tracked namelist ----------
# This runs here, after staging, so the repo is never written to. It matters for
# more than tidiness: this script body executes on the compute node when the job
# STARTS, and all five SOMA duration scripts patch the SAME input_tap/data. Two
# of them started together would each stage whichever endTime landed last, while
# each run directory name still claimed its own duration.
# Convert each <name>_days -> seconds and patch only the RHS value (keep commas/spaces).
for name in "${time_params[@]}"; do
  eval days_val="\$${name}_days"
  secs=$(awk -v d="$days_val" 'BEGIN{printf "%.0f", d*86400}')
  newval="${secs}."
  sed -i -E "s|^([[:space:]]*${name}=)[^,]+|\1${newval}|g" data
  # sed exits 0 when it matches nothing, which would leave the namelist's own
  # value in place and run a different experiment silently. No `set -e` here,
  # so assert explicitly.
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

# run the model in serial
./mitgcmuv_tap_adj > output_tap_adj.txt 2>&1

# record end time
run_end_time=$(date +%s)
echo "Run ended at:   $(date)" >> run_timing.txt

# calculate and append elapsed time
elapsed=$((run_end_time - run_start_time))
printf "Total runtime:  %02d:%02d:%02d (HH:MM:SS)\n" $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60)) >> run_timing.txt
