#!/bin/bash

#SBATCH -J DINO_1deg_frd     # Set main part of the job name once here
#SBATCH -o %x.%j.out                   # %x = job name, %j = job ID
#SBATCH -e %x.%j.err
#SBATCH -N 1
#SBATCH -n 27
#SBATCH -t 240:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# Fail fast if anything is wrong in this script
set -e
# Enable command tracing for the entire script || all commands will be echoed (with variable expansions) into the .err file
set -x

# ========== LOAD NECESSARY MODULES ==========

# necessary modules have been loaded through .bashrc

# ========== TEST CASE FLAG ==========

# Set to "" for default (i.e., use input/data)
test_cases="frmSt-vA4Gd-vAhGd"

# Build optional suffix; set suffix to "_<test_cases>" if non-empty, otherwise empty (avoids extra underscore)
suffix=${test_cases:+_$test_cases}

# ========== SET SOME TIME STEPPING PARAMETERS (IN DAYS) IN input/data ==========

simulation_duration_with_dT1800_days=73200
monitorFreq_days=30.5 # on average there is 30.5 days in a month

#----------- do not edit below --------------------------
namelist_data="$SLURM_SUBMIT_DIR/input/data${suffix}"

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
build_dir="$base_dir/build_frd_mpi"
run_dir="/scratch2/tshahriar/DINO_1deg_frd_runs/${job_name}_${simulation_duration_with_dT1800_days}d${suffix}_run$SLURM_JOB_ID"  # unique per job

# ========== STAGE THE RUN DIRECTORY ==========

# create run directory in scratch and move into it
mkdir -p "$run_dir"
cd "$run_dir"

# copy and link input files into run directory
cp "$base_dir/input"/* .
ln -s "$base_dir/input_binaries"/* .

# Replace data file correctly
rm -f data
cp "$namelist_data" data

# >>> disable GMRedi and KPP if needed (comment out if you want to keep the default version) <<<
#sed -i -E "s|(useKPP[[:space:]]*=[[:space:]]*)\.TRUE\.|\1.FALSE.|" data.pkg
#sed -i -E "s|(useGMRedi[[:space:]]*=[[:space:]]*)\.TRUE\.|\1.FALSE.|" data.pkg

# copy MITgcm executable to run directory
cp -p "$build_dir/mitgcmuv" .

#----- pickups ---------------
#ln -s /scratch2/tshahriar/DINO_MITgcm_v011526_frd_runs/DINO_MITgcm_v011526_frd_73200d_run18277_dT1800_crashed/pickup.0001229760.data pickup.0001229760.data
#ln -s /scratch2/tshahriar/DINO_MITgcm_v011526_frd_runs/DINO_MITgcm_v011526_frd_73200d_run18277_dT1800_crashed/pickup.0001229760.meta pickup.0001229760.meta

# ========== RUN & TIMING ==========

# record start time
run_start_time=$(date +%s)
echo "Run started at: $(date)" > run_timing.txt

# run the model in parallel
mpirun -n $SLURM_NTASKS ./mitgcmuv > output.txt 2>&1

# record end time
run_end_time=$(date +%s)
echo "Run ended at:   $(date)" >> run_timing.txt

# calculate and append elapsed time
elapsed=$((run_end_time - run_start_time))
printf "Total runtime:  %02d:%02d:%02d (HH:MM:SS)\n" \
    $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60)) >> run_timing.txt
