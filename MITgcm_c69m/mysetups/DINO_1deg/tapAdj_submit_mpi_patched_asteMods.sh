#!/bin/bash

#SBATCH -J DINO_1deg_tapAdj_asteMods     # Set main part of the job name once here
#SBATCH -o %x.%j.out                               # %x = job name, %j = job ID
#SBATCH -e %x.%j.err
#SBATCH -N 1
#SBATCH -n 27
#SBATCH -t 240:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu   # override: sbatch --mail-user=...
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# Fail fast if anything is wrong in this script
set -e
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

# ========== TEST CASE FLAG ==========

# Set to "" for default (i.e., use input_tap/data)
test_cases=""

# Build optional suffix; set suffix to "_<test_cases>" if non-empty, otherwise empty (avoids extra underscore)
suffix=${test_cases:+_$test_cases}

# ========== SET SOME TIME STEPPING PARAMETERS (IN DAYS) IN input_tap/data ==========

simulation_duration_with_dT1800_days=1830
monitorFreq_days=5
adjMonitorFreq_days=5
adjDumpFreq_days=5

#----------- do not edit below --------------------------
namelist_data="$SLURM_SUBMIT_DIR/input_tap/data${suffix}"

# Safety check
if [[ ! -f "$namelist_data" ]]; then
  echo "ERROR: File $namelist_data not found!"
  exit 1
fi

# Auto-detect all *_days variables and strip suffix
params=($(compgen -v | grep '_days$' | sed 's/_days$//'))

# Convert each <name>_days → seconds and patch only the RHS value (keep commas/spaces)
for name in "${params[@]}"; do
  eval days_val="\$${name}_days"

  # Special handling: simulation_duration_with_dT1800_days → nTimeSteps
  if [[ "$name" == "simulation_duration_with_dT1800" ]]; then
    total_seconds=$(awk -v d="$days_val" 'BEGIN{printf "%.0f", d*86400}')
    nsteps=$(awk -v s="$total_seconds" 'BEGIN{printf "%.0f", s/1800}')
    sed -i -E "s|^([[:space:]]*nTimeSteps=)[^,]+|\1${nsteps}|g" "$namelist_data"
    continue
  fi

  # Default handling: days → seconds, patch <name>=..
  secs=$(awk -v d="$days_val" 'BEGIN{printf "%.0f", d*86400}')
  newval="${secs}."
  sed -i -E "s|^([[:space:]]*${name}=)[^,]+|\1${newval}|g" "$namelist_data"
done

# ========== PATHS & NAMES ==========

job_name="$SLURM_JOB_NAME"      # capture the job name set above
base_dir="$SLURM_SUBMIT_DIR"    # directory from where the job was submitted
build_dir="$base_dir/build_tapAdj_mpi_patched_asteMods"
run_dir="$SCRATCH_ROOT/DINO_1deg_tapAdj_runs/${job_name}_${simulation_duration_with_dT1800_days}d${suffix}_run$SLURM_JOB_ID"  # unique per job

# ========== STAGE THE RUN DIRECTORY ==========

# create run directory in scratch and move into it
mkdir -p "$run_dir"
cd "$run_dir"

# copy and link input files into run directory
cp "$base_dir/input_tap"/* .
ln -s "$base_dir/input_binaries"/* .
ln -s "$base_dir/input_adj_binaries"/* .

# Replace data file correctly
rm -f data
cp "$namelist_data" data
rm data.autodiff
mv data.autodiff_adapted-frm-aste-90x150x60 data.autodiff

# >>> disable GMRedi and KPP if needed (comment out if you want to keep the default version) <<<
#sed -i -E "s|(useKPP[[:space:]]*=[[:space:]]*)\.TRUE\.|\1.FALSE.|" data.pkg
#sed -i -E "s|(useGMRedi[[:space:]]*=[[:space:]]*)\.TRUE\.|\1.FALSE.|" data.pkg


# copy MITgcm executable to run directory
cp -p "$build_dir/mitgcmuv_tap_adj" .

#----- pickups ---------------
#ln -s $SCRATCH_ROOT/DINO_1deg_frd_runs/runs_prod/crashed_runs/DINO_1deg_frd_200yr_from_rest_viscD2x_Zref_crashed_126p3y_run19369/pickup.0000878400.data pickup.0000878400.data
#ln -s $SCRATCH_ROOT/DINO_1deg_frd_runs/runs_prod/crashed_runs/DINO_1deg_frd_200yr_from_rest_viscD2x_Zref_crashed_126p3y_run19369/pickup.0000878400.meta pickup.0000878400.meta

# ========== RUN & TIMING ==========

# record start time
run_start_time=$(date +%s)
echo "Run started at: $(date)" > run_timing.txt

# run the model in parallel
$MPI_LAUNCHER $SLURM_NTASKS ./mitgcmuv_tap_adj > output_tap_adj.txt 2>&1

# record end time
run_end_time=$(date +%s)
echo "Run ended at:   $(date)" >> run_timing.txt

# calculate and append elapsed time
elapsed=$((run_end_time - run_start_time))
printf "Total runtime:  %02d:%02d:%02d (HH:MM:SS)\n" \
    $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60)) >> run_timing.txt
