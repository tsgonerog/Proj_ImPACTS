#!/bin/bash

#SBATCH -J v4soma_frd_test    # Set job name once here
#SBATCH -o %x.%j.out   # %x = job name, %j = job ID
#SBATCH -e %x.%j.err
#SBATCH -N 2
#SBATCH -n 4
#SBATCH -t 48:00:00
#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# necessary modules have been loaded through .bashrc

# === Use the job name set above ===
job_name=$SLURM_JOB_NAME

# === Define key paths ===
home_dir=/home/tshahriar/Proj_ImPACTS/MITgcm_c69c/v4_soma_with_adj
build_dir=$home_dir/build_frd_parallel
input_dir=$home_dir/input
run_dir=/scratch2/tshahriar/${job_name}_run$SLURM_JOB_ID  # unique per job

# === Create run_data directory in scratch and move into it ===
mkdir -p "$run_dir"
cd "$run_dir"

# === Link input files into run directory ===
ln -s "$input_dir"/* .

# === Link MITgcm executable to run directory ===
ln -s "$build_dir/mitgcmuv" .

# === Record start time ===
start_time=$(date +%s)
echo "Run started at: $(date)" > run_timing.txt

# === Run the model in parallel ===
mpiexec -n $SLURM_NTASKS ./mitgcmuv > output.txt 2>&1

# === Record end time ===
end_time=$(date +%s)
echo "Run ended at:   $(date)" >> run_timing.txt

# === Calculate and append elapsed time ===
elapsed=$((end_time - start_time))
printf "Total runtime:  %02d:%02d:%02d (HH:MM:SS)\n" $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60)) >> run_timing.txt
