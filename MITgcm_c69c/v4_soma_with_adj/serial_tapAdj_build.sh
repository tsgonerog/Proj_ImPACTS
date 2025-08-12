#!/bin/bash

# Set root directory for MITgcm (absolute path is safest)
MITGCM_ROOT=/home/tshahriar/Proj_ImPACTS/MITgcm_c69c/MITgcm

# Go to build directory
cd build_tapAdj_serial || { echo "Failed to enter build_tapAdj_serial"; exit 1; }

# Clean any previous build
make CLEAN

# Configure the build
$MITGCM_ROOT/tools/genmake2 -tap \
    -of=$MPI_OPTFILE \
    -rd=$MITGCM_ROOT \
    -mods=../code_tap \
    -adof=$MITGCM_ROOT/tools/adjoint_options/adjoint_default

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj
