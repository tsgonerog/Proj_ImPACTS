#!/bin/bash
# Build the FORWARD model (no adjoint).
#   sources : code/ + input/          ->  build_frd/mitgcmuv
# DINO is MPI-only: code/SIZE.h is nPx=3, nPy=9 over sNx=17, sNy=22 = 27 ranks.
#
# This file says WHAT to build; HOW is tools/lib/build_body.sh, the body every
# build script in every setup shares (machine profile, genmake2, make,
# build_info.txt). Run from the setup directory: ./scripts/build_frd.sh
# Pair with submit_frd.sh.

set -euo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUILD_DIR=build_frd
BUILD_MODE=frd
PARALLEL=mpi
MODS=(../code)
RUN_TOKEN=frd

source "$SETUP_DIR/../../../tools/lib/build_body.sh"
