# SOMA_1deg

Wind-driven, bowl-shaped idealised basin. **62 × 62 × 31**, spherical polar,
`delX = delY = 1°`, `ygOrigin = 14.` so the domain spans **14°N–76°N**,
~3500 m deep, `dT = 1200 s`.

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
at the top of each. Names are zero-padded so they sort in order. **You pick a
script rather than editing one**, which is why SOMA has no `IMPACTS_DURATION_DAYS`
override — DINO's three scripts do, because there you would otherwise edit the
duration in place.

Each script patches the **staged** `data` in its own run directory, never the
tracked `input_tap/data`, so submitting leaves the working tree clean. That
matters most here: all five scripts name the same `input_tap/data`, and the
script body runs on the compute node when the job *starts*, so under the old
in-place `sed` two of these started together would each stage whichever
`endTime` landed last — while each run directory name still claimed its own
duration. Running `005d` and `030d` at once is exactly the workflow these five
scripts exist to support, so the window was not hypothetical.

These scripts carry `set -x` but **not `set -e`**, deliberately: a non-zero exit
from the model must not abort the script, or `run_timing.txt` would lose its
"Run ended" lines on precisely the failures you want to time. The staging steps
therefore carry their own guards (`cd "$run_dir" || exit 1`, an existence check
on the namelist, and an assertion after each `sed` that the value actually
changed) instead of relying on `set -e`.

A job leaves `<job-name>.<job-id>.out` and `.err` beside the submit script, in
the setup directory. They are gitignored, and the scripts run under `set -x`, so
the `.err` file is a full trace of the staging steps — a staging failure shows up
there rather than in the model output on scratch. `./clean_slurm_logs.sh` clears
them: it prompts first, and touches only the current directory, never
recursively.

Unlike DINO there is no `adjViscBoost` variant here, and no `test_cases`
mechanism — SOMA has a single `input_tap/data`.

## Files

| Path | Contents |
| --- | --- |
| `code/`, `input/` | forward model |
| `code_tap/`, `input_tap/` | adjoint model — adds `data.autodiff`, `data.cost`, `data.ctrl`, `data.grdchk` |
| `input_binaries/` | **untracked**, but regenerates: `python3 input/gendata.py` |
| `input_adj_binaries/` | **untracked.** `ones_64b.bin`, the uniform control weight |
| `00_archive/` | superseded submit scripts in `scripts/`, mirroring the live dirs — nothing live reads it; has its own `README.md` |
| `.gitignore` | setup-local, ignores `*.out` / `*.err` |

For what the individual `code_tap/` sources and `input_tap/` namelists do, see
the **Reading the code** section of `../DINO_1deg/README.md` — the two setups
share the same structure. **Since the 2026-08-31 dump-hook redesign the two
`code_tap/` directories implement the `ADJ*` dump differently**: SOMA still
uses the old mechanism (`adcommon.h` + `addummy_in_stepping.F` reading
Tapenade's adjoint commons, one call hand-inserted via
`forward_step_b.f_modified` and the patched
`genmake2_override_forward_step_b`), while DINO moved to Tapenade-native
`TAP_*` hooks with stock `genmake2`. DINO's README section *"How the Tapenade
hooks work"* describes the target state; converting SOMA the same way is the
natural follow-up, and until then the override script and SOMA's
`forward_step_b.f_modified` must not be deleted.

The cost function is `code_tap/cost_atlantic_heat.F` with indices compiled in
(`isecbeg=1, isecend=62, jsec=27` — a zonal section at ~40°N — and
`kmaxdepth=21`). Changing the section means editing the file and rebuilding.

`useGrdchk = .TRUE.`, so every adjoint job also runs the finite-difference
gradient check and pays for it. As in DINO, whether its perturbation point sits
where the adjoint actually has sensitivity has not been checked here — see
"Verification status" in the root `README.md` before trusting its output.
KPP and GM/Redi are off in `input_tap/data.pkg`.

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
