# Stray gendata scripts

These four files sat in `DINO_1deg/input/` and `DINO_1deg/input_tap/` but do not
belong to DINO. They generate a **62 x 62 grid, 1800 m deep**, writing
`bathy.bin`, `SST_relax.bin` and `windx_cosy.bin`.

DINO is **51 x 198 x 36, 4600 m deep**, and its inputs are the `dino_*.bin` files
in `input_binaries/`, which are produced outside this repository — nothing here
regenerates them.

So these are residue from whichever template the setup was copied from. Nothing
in the repo referenced them. Moved here 2026-08-18 rather than deleted, in case a
line in them is still wanted.

`SOMA_1deg/input/gendata.py` is a *different* file and is genuine — SOMA's inputs
really do regenerate from it.
