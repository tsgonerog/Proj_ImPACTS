#!/bin/bash

#SBATCH -J soma3
#SBATCH -o soma3.%j.out
#SBATCH -e soma3.%j.err
#SBATCH -N 1
#SBATCH -n 9
#SBATCH -C cpu
#SBATCH -q regular
#SBATCH -t 00:05:00

#SBATCH --mail-user=tanvirshahriar@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

#SBATCH --account=m4259

ln -s ../input/* .

cp -p ../build/mitgcmuv .

srun -n 9 -c 28 --cpu_bind=cores  ./mitgcmuv
