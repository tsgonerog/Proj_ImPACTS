#!/bin/bash

# Set root directory for MITgcm
MITGCM_ROOT=../MITgcm

# Replace SIZE.h and the_main_loop_b.f_for_genmake2 with serial versions
cp code_tap/SIZE.h_serial code_tap/SIZE.h
cp code_tap/the_main_loop_b.f_for_genmake2_serialPatched code_tap/the_main_loop_b.f_for_genmake2

# Ensure build directory exists
if [ ! -d build_tapAdj_serial ]; then
    echo "Creating the directory build_tapAdj_serial..."
    mkdir build_tapAdj_serial
fi

# Go to build directory
cd build_tapAdj_serial || { echo "Failed to enter build_tapAdj_serial"; exit 1; }

# Clean any previous build
make CLEAN

# Configure the build
$MITGCM_ROOT/tools/genmake2 -tap \
    -rd=$MITGCM_ROOT \
    -of=$MITGCM_ROOT/tools/build_options/linux_amd64_ifort \
    -mods=../code_tap \
    -adof=$MITGCM_ROOT/tools/adjoint_options/adjoint_default

# Generate dependency list
make depend

# Build the adjoint model using 8 threads
make -j 8 tap_adj
