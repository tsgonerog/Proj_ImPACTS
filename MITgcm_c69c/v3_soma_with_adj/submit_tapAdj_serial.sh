#!/bin/bash

#SBATCH -J serV3imp
#SBATCH -o serV3imp.%j.out
#SBATCH -e serV3imp.%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 48:00:00

#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

module load gnu12/12.2.0
module load phdf5/1.14.0
module load netcdf-fortran/4.6.0
module load netcdf/4.9.0

# Prepare run directory and execute model
cd run_tap_serial
rm *
ln -s ../input_tap/* .
../input_tap/prepare_run
ln -s ../build_tapAdj_serial/mitgcmuv_tap_adj .
./mitgcmuv_tap_adj > output_tap_adj.txt 2>&1
