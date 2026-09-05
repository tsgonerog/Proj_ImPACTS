#!/bin/bash
# Build the FORWARD model (no adjoint).
#   sources : code/ + input/          ->  build_frd/mitgcmuv
# SOMA's forward model is MPI over 4 ranks: code/SIZE.h is nPx=nPy=2 over
# sNx=sNy=31. (Restored 2026-08-31 when the two setups' workflows were
# aligned; code/packages.conf drops the c69f-era timeave, removed upstream in
# c69m.)
#
# This file says WHAT to build; HOW is tools/lib/build_body.sh, the body every
# build script in every setup shares. Run from the setup directory:
# ./scripts/build_frd.sh   Pair with submit_frd.sh.

set -euo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUILD_DIR=build_frd
BUILD_MODE=frd
PARALLEL=mpi
MODS=(../code)
RUN_TOKEN=frd

source "$SETUP_DIR/../../../tools/lib/build_body.sh"
