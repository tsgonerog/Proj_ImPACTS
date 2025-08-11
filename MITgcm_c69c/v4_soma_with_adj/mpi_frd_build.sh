#!/bin/bash

# Set root directory for MITgcm (absolute path is safest)
MITGCM_ROOT=/home/tshahriar/Proj_ImPACTS/MITgcm_c69c/MITgcm

# Go to build directory
cd build_frd_mpi || { echo "Failed to enter build_fd_mpi"; exit 1; }

# Clean any previous build
make CLEAN

# Configure the build
$MITGCM_ROOT/tools/genmake2 -mpi \
    -of=$MPI_OPTFILE \
    -rd=$MITGCM_ROOT \
    -mods=../code

# Generate dependency list
make depend

# Build the forward model using 8 threads
make -j 8
