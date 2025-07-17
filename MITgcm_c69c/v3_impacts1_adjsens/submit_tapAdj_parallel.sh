#!/bin/bash

#SBATCH -J parV3imp
#SBATCH -o parV3imp.%j.out
#SBATCH -e parV3imp.%j.err
#SBATCH -N 2
#SBATCH -n 4
#SBATCH -t 48:00:00

#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

# necessary modules have been loaded through .bashrc

# === Define key paths ===
home_dir=/home/tshahriar/Proj_ImPACTS/MITgcm_c69c/v3_impacts1_adjsens
build_dir=$home_dir/build_tapAdj_parallel
input_dir=$home_dir/input_tap
run_dir=/scratch2/tshahriar/parV3imp_run_$SLURM_JOB_ID  # unique per job

# === Create run directory in scratch and move into it ===
mkdir -p "$run_dir"
cd "$run_dir"

# === Link input files into run directory ===
ln -s "$input_dir"/* .

# === Run the input preparation script ===
bash "$input_dir/prepare_run"

# === Link MITgcm executable to run directory ===
ln -s "$build_dir/mitgcmuv_tap_adj" .

# === Record run time ===
date > run_timing.txt

# === Run the model in parallel ===
mpiexec -n 4 ./mitgcmuv_tap_adj > output_tap_adj.txt 2>&1

# === Record end time ===
date >> run_timing.txt
