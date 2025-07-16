

#---- 1.set variables ------
#pickupts1="0001051920"

#--- 2.set dir ------------
basedir=/home/shoshi/MITgcm_c68q/soma
scratchdir=/scratch/shoshi/soma
#pickupdir=/scratch/shoshi/baroclinic_gyre/run_20yrs

#workdir=$scratchdir/run_test_exf_pkg_E
workdir=$scratchdir/run_test_cal_exf_gdb_new_cpp

mkdir ${workdir}
cd ${workdir}

#--- 6. NAMELISTS ---------
cp ${basedir}/input_cal/* .
ln -s ${basedir}/input_binaries/* .

#--- 7. executable --------
#cp -p ${basedir}/build_devel/mitgcmuv .
cp -p ${basedir}/build_exf_test/mitgcmuv .


mkdir -p $workdir/diags/state_avg_2d
mkdir -p $workdir/diags/state_avg_3d


