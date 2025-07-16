#!/bin/bash

#SBATCH -J impacts1 
#SBATCH -o impacts1.%j.out
#SBATCH -e impacts1.%j.err
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -t 48:00:00

#SBATCH --mail-user=sreich@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

#--- 0.load modules ------
#module purge
#module load intel/2023.1.0
#module load openmpi4/4.1.5
#module load phdf5/1.14.0
#module load netcdf-fortran/4.6.0
#module load netcdf/4.9.0
#module load prun

module list

#echo $LD_LIBRARY_PATH

ulimit -s hard
ulimit -u hard

nprocs=4

#---- 1.set variables ------
#pickupts1="0001051920"

#--- 2.set dir ------------
basedir=/home/shoshi/MITgcm_c68q/impacts1
scratchdir=/scratch/shoshi/impacts1
#pickupdir=/scratch/shoshi/baroclinic_gyre/run_20yrs

workdir=$scratchdir/run_100yrs

mkdir ${workdir}
cd ${workdir}

#--- 6. NAMELISTS ---------
ln -s ${basedir}/input/* .

echo "input"

#--- 7. executable --------
cp -p ${basedir}/build/mitgcmuv ./

echo "build"
#--- 8. pickups -----------
#NOTE: for pickup: copy instead of link to prevent accidental over-write
#cp -f ${pickupdir}/pickup${extpickup}.${pickupts1}.data ./pickup.${pickupts1}.data
#cp -f ${pickupdir}/pickup${extpickup}.${pickupts1}.meta ./pickup.${pickupts1}.meta


mkdir -p $workdir/diags/state_avg_2d
mkdir -p $workdir/diags/state_avg_3d

echo "diags"
#--- 11. run ----------------------------------
set -x
date > run.MITGCM.timing
#mpiexec --mca btl ^tcp,openib --mca mtl psm2 ${workdir}/mitgcmuv
mpiexec -n ${nprocs} ./mitgcmuv
#prun ${workdir}/mitgcmuv
date >> run.MITGCM.timing
