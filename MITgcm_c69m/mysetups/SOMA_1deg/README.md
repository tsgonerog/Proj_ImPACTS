# SOMA_1deg

Wind-driven, bowl-shaped idealised basin. **62 × 62 × 31**, spherical polar,
`delX = delY = 1°`, `ygOrigin = 14.` so the domain spans **14°N–76°N**,
~3500 m deep, `dT = 1200 s`. Secondary configuration; `DINO_1deg/` is primary.

**Serial only.** `SIZE.h_mpi` exists in `code_tap/` but no script stages it, and
no submit script expects it.

## Build

```bash
./build_tapAdj.sh                      # the one you normally want
```

| Script | Build directory | Executable |
| --- | --- | --- |
| `build_tapAdj.sh` | `build_tapAdj/` | `mitgcmuv_tap_adj` |
| `build_tapAdj_rawTapenade.sh` | `build_tapAdj_rawTapenade/` | `mitgcmuv_tap_adj` |

The **unmarked** script is the working configuration; only deviations carry a
token. `build_tapAdj.sh` uses the patched `genmake2`, which injects the
hand-corrected `code_tap/forward_step_b.f_modified` over the routine Tapenade
generates. `build_tapAdj_rawTapenade.sh` is the control, compiling Tapenade's
output uncorrected; nothing submits it.

There is no forward-only build script here — SOMA is adjoint-only in this repo.

Building a second variant re-stages `code_tap/`, and build directories symlink
back into it. Never run bare `make` in an older build directory afterwards —
re-run its build script.

## Run

```bash
../../../tools/submit.sh submit_tapAdj_030d.sh
```

| Script | Simulated days |
| --- | --- |
| `submit_tapAdj_001d_smoketest.sh` | 1 — quick check that the executable runs; job name `test` |
| `submit_tapAdj_005d.sh` | 5 |
| `submit_tapAdj_030d.sh` | 30 |
| `submit_tapAdj_180d.sh` | 180 |
| `submit_tapAdj_360d.sh` | 360 |

All use `build_tapAdj/`. Durations are pre-made as separate scripts because
adjoint cost grows quickly with integration length; the duration is `endTime_days`
at the top of each. Names are zero-padded so they sort in order.

Unlike DINO there is no `adjViscBoost` variant here, and no `test_cases`
mechanism — SOMA has a single `input_tap/data`.

## Files

| Path | Contents |
| --- | --- |
| `code/`, `input/` | forward model |
| `code_tap/`, `input_tap/` | adjoint model — adds `data.autodiff`, `data.cost`, `data.ctrl`, `data.grdchk` |
| `input_binaries/` | **untracked**, but regenerates: `python3 input/gendata.py` |
| `input_adj_binaries/` | **untracked.** `ones_64b.bin`, the uniform control weight |
| `00_archive/` | superseded scripts and namelists — nothing live reads it |
| `.gitignore` | setup-local, ignores `*.out` / `*.err` |

For what the individual `code_tap/` sources and `input_tap/` namelists do, see
the **Reading the code** section of `../DINO_1deg/README.md` — the two setups
share the same structure, and SOMA's `code_tap/` is a subset of DINO's.

The cost function is `code_tap/cost_atlantic_heat.F` with indices compiled in
(`isecbeg=1, isecend=62, jsec=27` — a zonal section at ~40°N — and
`kmaxdepth=21`). Changing the section means editing the file and rebuilding.

`useGrdchk = .TRUE.`, so every adjoint job also runs the finite-difference
gradient check. KPP and GM/Redi are off in `input_tap/data.pkg`.

## A trap that cost real time

Two bugs sat here for a long time, each masking the other, and both are fixed:

1. `MITGCM_ROOT` in the build scripts pointed at `$SCRIPT_DIR/../MITgcm`, which
   resolves to `mysetups/MITgcm` — a directory that has never existed.
2. `code_tap/the_main_loop.F` included `GMREDI_TAVE.h`, a header **removed
   upstream in checkpoint69m**. DINO's copy has no such include, which is why
   only SOMA was affected. It sits inside `#ifdef ALLOW_GMREDI`, and
   `ALLOW_GMREDI` is defined because `packages.conf` pulls the `oceanic` group,
   so it is reached even though GM/Redi is disabled at runtime.

With (1) present, `genmake2` failed first and (2) was never visible. If this
setup starts failing again, check whether `code_tap/` still carries c69f-era
sources that reference something c69m has dropped.
