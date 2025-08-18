#!/bin/bash

# Set root directory for MITgcm
MITGCM_ROOT=../MITgcm

# Replace SIZE.h and the_main_loop_b.f_for_genmake2 with mpi versions
cp code_tap/SIZE.h_mpi code_tap/SIZE.h
cp code_tap/the_main_loop_b.f_for_genmake2_mpiPatched code_tap/the_main_loop_b.f_for_genmake2

# Go to build directory
cd build_tapAdj_mpi || { echo "Failed to enter build_tapAdj_mpi"; exit 1; }

# Clean any previous build
make CLEAN

# Configure the build
$MITGCM_ROOT/tools/genmake2 -tap -mpi \
    -of=$MPI_OPTFILE \
    -rd=$MITGCM_ROOT \
    -mods=../code_tap \
    -adof=$MITGCM_ROOT/tools/adjoint_options/adjoint_default

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj
