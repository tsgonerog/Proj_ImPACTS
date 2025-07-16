#!/bin/bash
#SBATCH -J skpp
#SBATCH -o skpp.%j.out
#SBATCH -e skpp.%j.err
#SBATCH -p normal 
#SBATCH -A OCE23001
#SBATCH -N 1
#SBATCH -n 36
#SBATCH -t 12:00:00

#SBATCH --mail-user=sreich@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

#--- 0.load modules ------
ulimit -s unlimited
module purge
module load intel/19.1.1 impi/19.0.9 netcdf/4.6.2 
module list

#---- 1.set variables ------
nprocs=36

#--- 2.set dir ------------
basedir=/work/08382/shoshi/ls6/MITgcm_c68q/baroclinic_gyre
scratchdir=/scratch/08382/shoshi/baroclinic_gyre

workdir=$scratchdir/run_40yrs

mkdir ${workdir}
cd ${workdir}

#--- 6. NAMELISTS ---------
ln -s ${basedir}/input/* .

#--- 7. executable --------
cp -p ${basedir}/build/mitgcmuv .


#--- 12. run ----------------------------------

set -x 
date > timing.txt

ibrun -n ${nprocs} ${workdir}/mitgcmuv

date >> timing.txt
