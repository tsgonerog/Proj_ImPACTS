#!/bin/bash

# Set root directory for MITgcm
MITGCM_ROOT=../MITgcm

# Check MPI_OPTFILE
if [ -z "$MPI_OPTFILE" ]; then
    echo "ERROR: MPI_OPTFILE is not set. Please export it or define it in the script or add in your bashrc."
    exit 1
fi

# Ensure build directory exists
if [ ! -d build_frd_mpi ]; then
    echo "Creating build_frd_mpi..."
    mkdir build_frd_mpi
fi

# Go to build directory
cd build_frd_mpi || { echo "Failed to enter build_frd_mpi"; exit 1; }

# Clean any previous build
make CLEAN

# Configure the build
$MITGCM_ROOT/tools/genmake2 -mpi \
    -rd=$MITGCM_ROOT \
    -of=$MPI_OPTFILE \
    -mods=../code

# Generate dependency list
make depend

# Build the forward model using 8 threads
make -j 8
