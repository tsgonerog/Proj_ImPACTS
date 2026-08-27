# DINO_1deg

Idealised single-basin "DINO" ocean, pole to pole. **51 × 198 × 36**, curvilinear,
`delX = 1°`, `delY = 0.77°`, `dT = 1800 s`, 366-day year.

**MPI only.** `SIZE.h_serial` exists in `code_tap/` but no script stages it.

## Build

```bash
./build_tapAdj.sh          # the one you normally want
```

| Script | Build directory | Executable |
| --- | --- | --- |
| `build_frd.sh` | `build_frd/` | `mitgcmuv` (forward only) |
| `build_tapAdj.sh` | `build_tapAdj/` | `mitgcmuv_tap_adj` |
| `build_tapAdj_adjViscBoost.sh` | `build_tapAdj_adjViscBoost/` | `mitgcmuv_tap_adj` |
| `build_tapAdj_rawTapenade.sh` | `build_tapAdj_rawTapenade/` | `mitgcmuv_tap_adj` |

The **unmarked** script is the working configuration; only deviations carry a
token. `build_tapAdj.sh` uses the patched `genmake2`, which injects the
hand-corrected `code_tap/forward_step_b.f_modified` over the routine Tapenade
generates — Tapenade differentiates `forward_step.F` automatically but its output
needs manual correction, and that correction is what makes the adjoint usable.

`build_tapAdj_rawTapenade.sh` is the control: identical except it calls the stock
`genmake2`, so the generated routine is compiled uncorrected. Nothing submits it.

Building a second variant re-stages `code_tap/`, and build directories symlink
back into it. Never run bare `make` in an older build directory afterwards —
re-run its build script.

## Run

```bash
../../../tools/submit.sh submit_tapAdj.sh
```

| Submit script | Uses build directory |
| --- | --- |
| `submit_frd.sh` | `build_frd/` |
| `submit_tapAdj.sh` | `build_tapAdj/` |
| `submit_tapAdj_adjViscBoost.sh` | `build_tapAdj_adjViscBoost/` |

A job leaves `<job-name>.<job-id>.out` and `.err` beside the submit script, in
the setup directory. They are gitignored, and the scripts run under `set -x`, so
the `.err` file is a full trace of the staging steps — a staging failure shows up
there rather than in the model output on scratch. `./clean_slurm_logs.sh` clears
them: it prompts first, and touches only the current directory, never
recursively.

`adjViscBoost` runs the adjoint with **larger viscosity and diffusivity than the
forward** — the standard trick for stopping a long adjoint from blowing up.
`viscFacInAd = 10.` against `viscFacInFw = 1.`, `inAdviscArNr = 2.E-3` against a
forward `1.2E-4`, plus added `inAddiffKhT/S`; the `outAd*` values restore the
forward settings on the way out. Values were adapted from the ASTE 90x150x60
regional setup.

It is a **build and a namelist variant**. The build stages the ASTE-derived
`AUTODIFF_PARAMS.h` and friends, which is what provides the `inAd*`/`outAd*`
parameters at all; the submit script swaps `data.autodiff_adjViscBoost` in at run
time, which is what sets them. **The two must be used together** — pairing the
plain submit script with this build silently runs the ordinary configuration.

**27 ranks**, fixed by `SIZE.h_mpi` (`nPx=3, nPy=9` over `sNx=17, sNy=22`).
Changing the decomposition means changing `SIZE.h_mpi` *and* `#SBATCH -n`.

Durations are set in **days** at the top of the submit script and converted
automatically. `nIter0` is not — it comes from the `data_<tag>` that `test_cases`
selects, and the matching pickup is a hardcoded `ln -s` further down. Changing
the duration is safe; changing the starting point means editing both.

## Files

| Path | Contents |
| --- | --- |
| `code/`, `input/` | forward model |
| `code_tap/`, `input_tap/` | adjoint model — adds `data.autodiff`, `data.cost`, `data.ctrl`, `data.grdchk` |
| `input*/variants/` | alternative namelists; the submit script copies **one** in as `data` |
| `input_binaries/` | **untracked, 179 MB.** Produced outside this repo; nothing here regenerates it |
| `input_adj_binaries/` | **untracked.** `ones_64b.bin`, the uniform control weight every `data.ctrl` entry points at |
| `00_archive/` | superseded config in `code_tap/`, `input_tap/`, `scripts/`, mirroring the live dirs — nothing live reads it; has its own `README.md` |

## Namelists and variants

`input/` and `input_tap/` hold exactly the files MITgcm reads — the same list a
run directory ends up with. Alternatives live one level down:

```
input_tap/
├── data              <- the live namelist
├── data.autodiff     <- ... and the other ten MITgcm reads
├── ...
└── variants/
    ├── data_from180yrPk_visc2x
    ├── data_from50yrPk_viscGrid1p8e-2
    ├── data_from_rest_viscGrid1p8e-2
    └── data.autodiff_adjViscBoost
```

Selecting one is a single edit at the top of a submit script:

```bash
test_cases="from180yrPk_visc2x"      # -> variants/data_from180yrPk_visc2x
test_cases=""                        # -> the live input_tap/data
```

The script copies it in as `data`, and the run directory name records which was
used. A typo aborts the job immediately rather than silently running the wrong
configuration.

**Adding an alternative means putting it in `variants/`**, named
`data_<start>_<viscosity>[_extras]` — see the root `README.md` for that
vocabulary. Files directly in `input_tap/` are staged into every run, so a stray
one there becomes part of every configuration.

Only the selected variant is copied to scratch, so a run directory contains the
12 namelists MITgcm reads and nothing else.

## Reading the code

### Where the adjoint actually happens

Four files matter more than the rest when following how a sensitivity is produced:

| File | Role |
| --- | --- |
| `code_tap/the_main_loop.F` | **The differentiation head.** `genmake2` runs `tapenade -b -head 'the_main_loop(fc)/(xx_genarr3d_dummy, xx_genarr2d_dummy, xx_gentim2d_dummy)'` — the cost `fc` is differentiated with respect to those control dummies, so everything reachable from this routine is what gets an adjoint |
| `code_tap/cost_atlantic_heat.F` | **The cost function** `fc`: meridional heat transport across a zonal section. Section indices are compiled in as `parameter` statements, so moving the section means editing this file and rebuilding |
| `code_tap/addummy_in_stepping.F` | **Where `ADJ*` output is written.** `CALL DUMP_ADJ_XYZ(..., 'ADJtheta', ...)` and friends — this is the routine that produces the files the analysis notebooks read |
| `code_tap/forward_step_b.f_modified` | **The hand-corrected adjoint of `forward_step.F`.** Tapenade generates this routine automatically but the result needs manual correction; the patched `genmake2` copies this over Tapenade's version at build time |

### `code_tap/` — adjoint source overrides

Files whose name ends in a suffix (`_OG`, `_mpi`, `_serial`, `_aste_90x150x60`,
`_adapted_frm_aste_90x150x60`) are **staged variants**: a build script copies one
over the bare filename before configuring. **Edit the suffixed file, never the
bare one** — the bare one is regenerated on every build and your edits vanish.

| File | Purpose |
| --- | --- |
| `the_main_loop.F` | differentiation head, see above |
| `the_model_main.F` | model driver that calls it (`_OG` variant staged) |
| `cost_atlantic_heat.F` | the cost function |
| `addummy_in_stepping.F`, `addummy_for_etan.F` | hooks called inside the adjoint loop; where `ADJ*` fields are dumped |
| `adcommon.h` | common blocks for the adjoint variables |
| `autodiff_readparms.F` | reads `data.autodiff` (`_OG` / `_aste_90x150x60` variants) |
| `autodiff_inadmode_set_ad.F` | applies the `inAd*` parameters entering adjoint mode |
| `AUTODIFF_PARAMS.h` | declares them (`_OG` has no `inAd*`; the ASTE variant adds them — this is what `build_tapAdj_adjViscBoost.sh` selects) |
| `monitor_ad.F` | adjoint monitor output |
| `ini_procs.F` | tile/process setup |
| `SIZE.h` | grid and decomposition (`_mpi` staged; `_serial` present but unused) |
| `CTRL_SIZE.h` | control-vector dimensions |
| `DIAGNOSTICS_SIZE.h` | diagnostics buffer sizes |
| `packages.conf` | which packages compile — drops `cd_code`, adds `tapenade` and the `adjoint` group (`autodiff, ctrl, cost, grdchk`) |
| `*_OPTIONS.h` | CPP flags per package. `COST_OPTIONS.h` is the one to check: it defines `ALLOW_COST_ATLANTIC_HEAT` and `..._DOMASS` |

### `input_tap/` — adjoint namelists

Beyond the forward set, the adjoint adds four:

| Namelist | Controls |
| --- | --- |
| `data.cost` | `mult_atl` — scales the cost function |
| `data.ctrl` | which controls are optimised (`xx_theta`, `xx_salt`, `xx_diffkr`, wind stress, heat and freshwater flux) and their weight files — every `xx_*_weight` points at `ones_64b.bin` |
| `data.autodiff` | checkpointing and adjoint-mode behaviour; `data.autodiff_adjViscBoost` is the inflated-viscosity variant |
| `data.grdchk` | the finite-difference gradient check: `grdchk_eps`, `grdchkvarname`, and the `iGloPos/jGloPos/kGloPos` point to perturb |

`data_<start>_<viscosity>` variants are selected by `test_cases` in a submit
script; see the root `README.md` for that vocabulary.

### `code/` and `input/` — the forward model

Much smaller: `SIZE.h` (+ `_mpi`/`_serial`), `packages.conf`, `CPP_OPTIONS.h`,
`DIAGNOSTICS_SIZE.h`, `GMREDI_OPTIONS.h`, `MOM_COMMON_OPTIONS.h`, `ini_procs.F`.
`input/` holds `data`, its `data_*` variants, and the standard `data.pkg`,
`data.diagnostics`, `data.exch2`.

`code/pc` is a stray five-line fragment of a `packages.conf`, referenced by
nothing — ignore it.

---

The cost function is `code_tap/cost_atlantic_heat.F`, with its section indices
compiled in as `parameter` statements (`isecbeg=1, isecend=51, jsec=127`,
`kmaxdepth=25`). Moving the section means editing that file and rebuilding — it is
not a namelist setting. Indices are located with
`analyses/DINO_1deg/00_grid_and_cost_sections.ipynb`.

`useGrdchk = .TRUE.`, so **every adjoint job also runs the finite-difference
gradient check** and pays for it — a 30-day adjoint recorded 18,622 forward-step
calls against the 1,440 the adjoint itself needs. Check this first if a run seems
to be doing more work than expected.

**The check does not currently verify anything.** It perturbs `xx_theta` at
`iGloPos=4, jGloPos=8, kGloPos=1`, but the cost section is at `j=127` and
sensitivity at the check point is ~6e-10 against a field maximum of ~3.9e-02. The
finite difference measures run-to-run noise, not the perturbation, and fails by
~8 orders of magnitude. It has always done so. To make it meaningful use
`iGloPos=2, jGloPos=127, kGloPos=26` with `grdchk_eps` around 1e-3. See
"Verification status" in the root `README.md`.

KPP and GM/Redi are off (`input_tap/data.pkg`), which makes the
`useKPPinAdMode` / `useGMRediInAdMode` flags in `data.autodiff` inert.
