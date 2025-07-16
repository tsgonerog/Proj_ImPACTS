#!/bin/bash

#SBATCH -J soma1
#SBATCH -o soma1.%j.out
#SBATCH -e soma1.%j.err
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -t 36:00:00

#SBATCH --mail-user=sreich@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

nprocs=4

#---- 1.set variables ------
#pickupts1="0001051920"

#--- 2.set dir ------------
basedir=/home/shoshi/MITgcm_c68q/soma
scratchdir=/scratch/shoshi/soma
#pickupdir=/scratch/shoshi/baroclinic_gyre/run_20yrs

workdir=$scratchdir/run_vary_winds_0.1_0.4

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
