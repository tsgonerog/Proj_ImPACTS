#!/bin/bash

#SBATCH -J soma6
#SBATCH -o soma6.%j.out
#SBATCH -e soma6.%j.err
#SBATCH -N 6
#SBATCH -n 144
#SBATCH -t 72:00:00

#SBATCH --mail-user=sreich@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

nprocs=144

#---- 1.set variables ------
#pickupts1="0001051920"

#--- 2.set dir ------------
basedir=/home/shoshi/MITgcm_c68q/soma6
scratchdir=/scratch/shoshi/soma6
#pickupdir=/scratch/shoshi/baroclinic_gyre/run_20yrs

workdir=$scratchdir/run_100yrs

mkdir ${workdir}
cd ${workdir}

#--- 6. NAMELISTS ---------
#ln -s ${basedir}/input_cal/* .
cp ${basedir}/input/* .
ln -s ${basedir}/input_binaries/* .

#--- 7. executable --------
cp -p ${basedir}/build/mitgcmuv .


mkdir -p $workdir/diags/state_avg_2d
mkdir -p $workdir/diags/state_avg_3d


#--- 11. run ----------------------------------
set -x
date > run.MITGCM.timing

mpiexec -n ${nprocs} ./mitgcmuv

date >> run.MITGCM.timing
