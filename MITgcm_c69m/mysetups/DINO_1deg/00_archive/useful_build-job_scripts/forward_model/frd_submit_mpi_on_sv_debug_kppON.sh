#!/bin/bash

#SBATCH -J debug_tr7     # Set job name once here
#SBATCH -o %x.%j.out     # %x = job name, %j = job ID
#SBATCH -e %x.%j.err
#SBATCH -N 1
#SBATCH -n 27
#SBATCH -t 48:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# Enable command tracing for the entire script || all commands will be echoed (with variable expansions) into the .err file
set -x

# ========== LOAD NECESSARY MODULES ==========

# necessary modules have been loaded through .bashrc

# ========== PATHS & NAMES ==========

job_name="$SLURM_JOB_NAME"      # capture the job name set above
base_dir="$SLURM_SUBMIT_DIR"    # directory from where the job was submitted
build_dir="$base_dir/build_frd_mpi"
run_dir="/scratch2/tshahriar/DINO_MITgcm_v011526_frd_runs/${job_name}_720000d_kppON_run$SLURM_JOB_ID"  # unique per job

# ========== STAGE THE RUN DIRECTORY ==========

# create run directory in scratch and move into it
mkdir -p "$run_dir"
cd "$run_dir"

# copy and link input files into run directory
cp "$base_dir/input"/* .
ln -s "$base_dir/input_binaries"/* .

rm data.diagnostics
mv data.diagnostics_debug data.diagnostics
rm data
mv data_debug_kppON data
rm data.pkg
mv data.pkg_kppON data.pkg

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
