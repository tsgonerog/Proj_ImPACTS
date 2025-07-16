#!/bin/bash

#SBATCH -J tut_bar_gyre 
#SBATCH -o tut_bar_gyre.%j.out
#SBATCH -e tut_bar_gyre.%j.err
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -t 28:00:00

#SBATCH --mail-user=sreich@utexas.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

#--- 0.load modules ------
module purge
module load intel/2023.1.0
module load impi/2021.9.0
module load netcdf/4.9.2
module load netcdf-fortran/4.6.1
module load phdf5/1.14.0

module list

#echo $LD_LIBRARY_PATH

ulimit -s hard
ulimit -u hard

#---- 1.set variables ------

#--- 2.set dir ------------
basedir=/home/shoshi/MITgcm_c68q/MITgcm/verification/tutorial_baroclinic_gyre
scratchdir=/scratch/shoshi/baroclinic_gyre
pickupdir=/scratch/shoshi/baroclinic_gyre/run_20yrs

workdir=$scratchdir/run_tutorial_100yrs

mkdir ${workdir}
cd ${workdir}

#--- 6. NAMELISTS ---------
ln -s ${basedir}/input/* .
#unlink data
#mv data_sr data

unlink data.diagnostics
cp /home/shoshi/MITgcm_c68q/baroclinic_gyre/input/data.diagnostics .

#--- 7. executable --------
cp -p ${basedir}/build/mitgcmuv .

#--- 8. pickups -----------
#NOTE: for pickup: copy instead of link to prevent accidental over-write
#cp -f ${pickupdir}/pickup${extpickup}.${pickupts1}.data ./pickup.${pickupts1}.data
#cp -f ${pickupdir}/pickup${extpickup}.${pickupts1}.meta ./pickup.${pickupts1}.meta


mkdir -p $workdir/diags/state_avg_2d
mkdir -p $workdir/diags/state_avg_3d


#--- 11. run ----------------------------------
set -x
date > run.MITGCM.timing
# mpiexec --mca btl ^tcp,openib --mca mtl psm2 ${workdir}/mitgcmuv
#prun ${workdir}/mitgcmuv
mpirun -np 4 ./mitgcmuv
date >> run.MITGCM.timing
