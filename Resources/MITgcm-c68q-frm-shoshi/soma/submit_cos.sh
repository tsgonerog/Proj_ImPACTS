#!/bin/bash

#SBATCH -J soma1_w5_20yr
#SBATCH -o soma1_w5_20yr.%j.out
#SBATCH -e soma1_w5_20yr.%j.err
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -t 48:00:00
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

workdir=$scratchdir/run_winds4_20yrs_pkp2592000_kpp_diags_B

mkdir ${workdir}
cd ${workdir}

#--- 6. NAMELISTS ---------
#ln -s ${basedir}/input_cal/* .
cp ${basedir}/input/* .
ln -s ${basedir}/input_binaries/* .

#sed -i -e 's/'"zonalWindFile='wind_sv_0.1_0.4_cos.bin'"'/'"zonalWindFile='wind_sv_0.1_0.5_cos_redo.bin'"'/g' data
#sed -i -e 's/'"useDiagnostics = .TRUE.'"'/'"useDiagnostics = .FALSE.'"'/g' data.pkg

rm data.diagnostics
mv data.diagnostics_dev data.diagnostics

#--- 7. executable --------
cp -p ${basedir}/build/mitgcmuv .


mkdir -p $workdir/diags/state_avg_2d
mkdir -p $workdir/diags/state_avg_3d

#----- pickups ---------------
ln -s /scratch/shoshi/soma/run_winds4_100yrs/pickup.0002592000.data pickup.0000000001.data
ln -s /scratch/shoshi/soma/run_winds4_100yrs/pickup.0002592000.meta pickup.0000000001.meta


#--- 11. run ----------------------------------
set -x
date > run.MITGCM.timing

mpiexec -n ${nprocs} ./mitgcmuv

date >> run.MITGCM.timing
