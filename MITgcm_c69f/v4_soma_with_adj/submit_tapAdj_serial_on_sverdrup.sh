#!/bin/bash

#SBATCH -J v4StP_srl     # Set job name once here
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

# ========== LOAD NECESSARY MODULES ==========

# necessary modules have been loaded through .bashrc

# ========== SET SOME TIME STEPPING PARAMETERS (IN DAYS) ==========

endTime_days=15
dumpFreq_days=0
monitorFreq_days=1
adjMonitorFreq_days=1
adjDumpFreq_days=1

#----------- do not edit below --------------
namelist_data="$SLURM_SUBMIT_DIR/input_tap/data"

# Auto-detect all *_days variables and strip suffix
params=($(compgen -v | grep '_days$' | sed 's/_days$//'))

# Convert each <name>_days → seconds and patch only the RHS value (keep commas/spaces)
for name in "${params[@]}"; do
  eval days_val="\$${name}_days"
  secs=$(awk -v d="$days_val" 'BEGIN{printf "%.0f", d*86400}')
  newval="${secs}."
  sed -i -E "s|^([[:space:]]*${name}=)[^,]+|\1${newval}|g" "$namelist_data"
done

# ========== PATHS & NAMES ==========

job_name="$SLURM_JOB_NAME"      # capture the job name set above
base_dir="$SLURM_SUBMIT_DIR"  # directory from where the job was submitted
build_dir="$base_dir/build_tapAdj_serial"
run_dir="/scratch2/tshahriar/v4_soma_tapAdj_runs/${job_name}_${endTime_days}d_run$SLURM_JOB_ID"  # unique per job

# ========== STAGE THE RUN DIRECTORY ==========

# create run directory in scratch and move into it
mkdir -p "$run_dir"
cd "$run_dir"

# copy and link input files into run directory
cp "$base_dir/input_tap"/* .
ln -s "$base_dir/input_binaries"/* .
ln -s "$base_dir/input_adj_binaries"/* .

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
