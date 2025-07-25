#!/bin/bash

#SBATCH -J soma60
#SBATCH -o soma60.%j.out
#SBATCH -e soma60.%j.err
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -t 48:00:00

#SBATCH --mail-user=trostel@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

module load intel/2023.1.0
module load openmpi4/4.1.5
module load phdf5/1.14.1
module load netcdf-fortran/4.6.0
module load netcdf/4.9.0
module load prun

ln -s ../input/* .

cp -p ../build/mitgcmuv .

prun ./mitgcmuv

#mpiexec --mca btl ^tcp,openib --mca mtl psm2 ./mitgcmuv
