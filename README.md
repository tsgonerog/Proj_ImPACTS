# Proj_ImPACTS

Adjoint sensitivity experiments with the [MITgcm](https://mitgcm.readthedocs.io),
built with the **Tapenade** automatic-differentiation toolchain (`pkg/tapenade`)
rather than the traditional TAF/OpenAD route.

The scientific target is the **meridional overturning and heat transport** of
idealised ocean basins: the adjoint model answers *"what upstream conditions and
forcings did this heat transport depend on, and how strongly?"* by propagating a
scalar cost function backwards in time to produce sensitivity maps
(`ADJtheta`, `ADJsalt`, `ADJtaux`, `ADJqnet`, …).

This repository holds the **experiment configurations, build and job scripts,
and analysis notebooks**. Model output lives outside the repo on cluster scratch
storage; large input binaries are generated locally and are deliberately not
tracked.

---

## Contents

| Path | What it is |
| --- | --- |
| `MITgcm_c69m/` | MITgcm **checkpoint69m** (2026-03-30) source tree plus the experiments built against it |
| `analyses/` | Jupyter notebooks that read run output from scratch and produce diagnostics/figures |
| `resources/` | Reference notebooks from collaborators (e.g. `dinocean` package usage) |

The MITgcm tree is vendored in full (~6,400 tracked files), not a submodule,
because it carries **locally patched build tooling** — see
[The Tapenade adjoint toolchain](#the-tapenade-adjoint-toolchain).

### Experiment setups

| Setup | Grid | Description |
| --- | --- | --- |
| `MITgcm_c69m/mysetups/DINO_1deg/` | 51 × 198 × 36, curvilinear | Primary configuration. Idealised single-basin "DINO" ocean spanning pole to pole |
| `MITgcm_c69m/mysetups/SOMA_1deg/` | 62 × 62 × 31, 1° spherical polar | SOMA — wind-driven bowl-shaped basin, 15°N–75°N, ~3500 m deep |

### The checkpoint69f tree

An earlier **checkpoint69f** (2025-07-10) tree used to sit alongside this one at
`MITgcm_c69f/`, carrying earlier ports of both setups plus three tutorial
configurations (`tutorial_barotropic_gyre_with_adj`,
`tutorial_baroclinic_gyre_with_adj`, `tutorial_global_oce_biogeo`) that served
as the graduated test bed — verifying that the Tapenade build path reproduced
known-good results before the machinery was pointed at DINO and SOMA.

It was removed on 2026-08-17, since work has moved entirely to c69m and the tree
accounted for roughly half the repository. It is preserved in full, working tree
and history alike, at `Proj_ImPACTS_old`
(<https://github.com/tsgonerog/Proj_ImPACTS_old>).

### Directory convention inside a setup

Every setup follows the same layout, which mirrors MITgcm's own `verification/`
convention with `_tap` variants added:

```
<setup>/
├── code/          # forward-model source overrides (SIZE.h, packages.conf, CPP_OPTIONS.h …)
├── code_tap/      # adjoint-model source overrides — the interesting one
├── input/         # forward-model namelists
├── input_tap/     # adjoint-model namelists (adds data.autodiff, data.cost, data.ctrl, data.grdchk)
├── 00_archive/    # frozen reference copies of files known to work elsewhere (e.g. ASTE 90×150×60)
├── *_build_*.sh   # build drivers
├── *_submit_*.sh  # SLURM job scripts
└── clean_slurm_logs.sh
```

`code/` and `code_tap/` also carry `_serial` / `_mpi` variants of `SIZE.h`; the
build scripts copy the right one into place before configuring, so the same
setup builds either way without hand editing.

---

## The Tapenade adjoint toolchain

This is the part of the repository that differs most from stock MITgcm, and the
reason the model source is vendored rather than referenced.

**Patched `genmake2`.** `MITgcm/tools/` contains `patched_NoTapProfile_genmake2`
alongside the original `genmake2`. Two further variants —
`patched_ForTapProfile_genmake2` (instrumented for Tapenade's profiling tool)
and `patched_AfterTapProfile_genmake2` (after acting on the profiler's advice) —
exist only in the archived c69f tree and would need porting before profiling
could be run here.

The patch itself is a single line that injects a hand-modified
`forward_step_b.f` into the Tapenade-generated code:

```diff
+ cp ../code_tap/forward_step_b.f_modified forward_step_b.f
```

Tapenade differentiates `forward_step.F` automatically, but the generated
reverse-mode routine needs manual correction; `code_tap/forward_step_b.f_modified`
(with separate `_serial` and `_mpi` versions) is that correction, and the
patched `genmake2` is how it survives a rebuild.

**Which profiling mode to use** is selected at the top of the build script:

```bash
use_TapProfile="NO"   # <-- only "NO" is wired up in this tree
```

Each mode also swaps in the matching `the_model_main.F` variant. Setting this to
`"YES"` or `"AFTER"` will fail here, because the `ForTapProfile` /
`AfterTapProfile` `genmake2` copies are not in this tree — see
[The checkpoint69f tree](#the-checkpoint69f-tree). The matching
`the_model_main.F_ForTapProfile` *is* still available, under
`DINO_1deg/00_archive/code_tap_files_MITgcm_c69f/`.

**Hand-adapted AD sources.** `code_tap/` carries several files in `_OG`
(original) and `_aste_90x150x60` (adapted from the ASTE regional setup) flavours
— `AUTODIFF_PARAMS.h`, `autodiff_readparms.F`, `autodiff_inadmode_set_ad.F`.
Build scripts choose between them, which is how the `asteMods` experiment
variant is produced.

---

## Building

Both build drivers resolve the MITgcm root relative to their own location, so
they can be run from anywhere:

```bash
cd MITgcm_c69m/mysetups/DINO_1deg

export MPI_OPTFILE=/path/to/your/mpi/optfile   # required for MPI builds
./tapAdj_build_mpi_patched.sh                  # → build_tapAdj_mpi_patched/mitgcmuv_tap_adj
```

Serial equivalents (`serial_tapAdj_build_*.sh`, `tapAdj_build_serial_*.sh`) use
a build-options file from `MITgcm/tools/build_options/` directly. Forward-only
builds use the `frd_build_*.sh` scripts.

Each script does the same five things: stage the right `SIZE.h` and AD source
variants, `make CLEAN`, run the chosen `genmake2` with `-tap` and
`-adof=.../adjoint_tap`, `make depend`, then `make -j 8 tap_adj`.

Build directories (`build*/`) are gitignored — they are large and fully
reproducible.

## Running

Jobs are SLURM batch scripts targeting the **`sverdrup`** cluster. The MPI DINO
adjoint runs on 27 ranks, matching `nPx=3, nPy=9` in `SIZE.h_mpi`:

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
sbatch tapAdj_submit_mpi_patched_on_sverdrup.sh
```

A submit script:

1. selects a namelist variant via a `test_cases` string at the top;
2. rewrites time-stepping parameters **in days**, converting to seconds/timesteps
   with `sed` — set `simulation_duration_with_dT1800_days`, `monitorFreq_days`,
   `adjMonitorFreq_days`, `adjDumpFreq_days` and the script does the arithmetic;
3. stages a fresh, job-ID-stamped run directory under
   `/scratch2/<user>/<setup>_runs/`, copying `input_tap/` and symlinking the
   gitignored input binaries;
4. symlinks any pickup files needed to restart from a spun-up state;
5. runs the executable and writes `run_timing.txt`.

Serial SOMA scripts come pre-made for a range of durations
(`submit_tapAdj_serial_on_sverdrup_{5,30,180,360}_day_patched.sh`) since adjoint
cost grows quickly with integration length.

> Run directories, scratch paths, and the notification e-mail address are
> hardcoded in these scripts. Change them before running as a different user.

### Namelist variants

Rather than editing `data` in place, alternative configurations live beside it
as `data_<tag>` and are selected by the `test_cases` variable. Tags compose, and
read as follows:

| Tag | Meaning |
| --- | --- |
| `frmSt` | from start (`nIter0=0`) |
| `70yPk`, `180yPk` | restart from a 70- / 180-year pickup (`nIter0` set accordingly) |
| `dc-vAr`, `dc-kappa` | decreased `viscAr` / `ivdc_kappa` |
| `adv30` | advection scheme 30 instead of 33 |
| `vAhGd`, `vA4Gd` | grid-scaled `viscAhGrid` / `viscA4Grid` in `PARM01` |
| `vAhD-vAhZ-2p00` | spatially varying viscosity read from `dino_viscAhD_2p00.bin` via `PARM05` |
| `C4Leith`, `CDsh` | Leith / Smagorinsky-style viscosity closures |
| `kppON`, `no-kpp-GM` | KPP and GM/Redi enabled or disabled |

Whether viscosity is set through `PARM01` scalars or through `PARM05` binary
files is itself an object of study — see
`analyses/DINO_1deg/02_forward/01_viscosity_study/`.

---

## Cost function and controls

**Cost** (`code_tap/cost_atlantic_heat.F`, enabled by `mult_atl` in
`data.cost`): meridional heat transport across a zonal section. Section indices
are compiled in — for DINO, `isecbeg=1, isecend=51, jsec=127`, chosen with
`analyses/DINO_1deg/00_grid_and_cost_sections.ipynb`. Vertical extent is set by
`kmaxdepth`, also compiled in, and guarded by
`#ifdef ALLOW_COST_ATLANTIC_HEAT_DOMASS`. Every setup that defines
`ALLOW_COST_ATLANTIC_HEAT` also defines `DOMASS`, so the `#else` branch
(14 levels, inherited from `pkg/cost`) is never the one in effect — and the
live value is per setup, not shared:

| Setup | `kmaxdepth` | Depth |
| --- | --- | --- |
| DINO | 25 | upper 982 m of 36 levels / 4600 m |
| SOMA | 21 | upper 954 m of 31 levels / 3500 m |

**Controls** (`data.ctrl`), via `ctrl_genarr`/`ctrl_gentim`:

- *2-D, time varying*: wind stress `xx_tauu` / `xx_tauv`, net heat flux
  `xx_qnet`, freshwater flux `xx_empmr`, shortwave `xx_qsw`, wind speeds
  `xx_uwind` / `xx_vwind`, `xx_fu` / `xx_fv`
- *3-D, time invariant*: initial `xx_theta`, `xx_salt`, `xx_uvel`, `xx_vvel`,
  and vertical diffusivity `xx_diffkr`

Physical bounds are supplied for the tracer and diffusivity controls; the flux
controls have bounds available but commented out.

**Adjoint approximations** (`data.autodiff`): both setups set
`useKPPinAdMode=.FALSE.` and `useGMRediInAdMode=.FALSE.` — the standard tactic of
running a scheme forward but skipping it in the reverse sweep to keep the adjoint
stable. **In practice these flags are currently inert**, because no adjoint run
has the packages switched on to begin with. Both disable them statically in
`input_tap/data.pkg`:

| Setup | forward `input/data.pkg` | adjoint, as run |
| --- | --- | --- |
| `DINO_1deg` | `useGMRedi=.TRUE.`, `useKPP=.FALSE.` | both `.FALSE.` in `input_tap/data.pkg` |
| `SOMA_1deg` | both `.TRUE.` | both `.FALSE.` in `input_tap/data.pkg` |

Both setups' submit scripts carry the equivalent `sed -i` lines **commented
out**, since their namelists already have the packages off. Worth knowing when
reading older run records: the archived `sr_soma` setup did it the other way
round, leaving `input_tap/data.pkg` at `.TRUE.` and having each
`submit_tapAdj_serial_on_sverdrup_*_day.sh` rewrite them to `.FALSE.` in the
staged run directory. So check both places before concluding a package is
active.

Note also that KPP is off even in the DINO *forward* run; only GM/Redi is active
there.

`data.grdchk` configures finite-difference gradient checks
(`grdchk_eps=1e-5`, default variable `xx_theta`) for verifying the adjoint.

**Diagnostics** (`data.diagnostics`) are split into `surfDiag`, `dynDiag`,
`atmDiag`, and `viscDiag` streams.

---

## Analyses

Notebooks read run output straight from the cluster scratch directories
(`/scratch2/<user>/DINO_1deg_{frd,tapAdj}_runs/`) with
`xmitgcm.open_mdsdataset` (`geometry="curvilinear"` for DINO) and, where raw
tiled binaries are read directly, reconstruct shapes from the same
`sNx/sNy/OLx/OLy/Nr` values used in `SIZE.h`.

```
analyses/
├── DINO_1deg/
│   ├── 00_grid_and_cost_sections.ipynb   # locate section indices for the cost function
│   ├── 01_first_look_at_output.ipynb     # entry point for reading a DINO run
│   ├── 02_forward/                       # 200-year spin-up, MOC/AMOC, viscosity study
│   └── 03_adjoint/                       # ADJ* sensitivity fields, from-rest vs from-pickup
├── SOMA_1deg/                            # 40°N heat-transport adjoint, KPP/GM disabled
├── reference_notebooks/                  # collaborator material the above was derived from
└── tools/                                # strip_animation_outputs.py
```

Directories are numbered in the order the work is meant to be read, and
`00_archive/` inside `02_forward/` and `03_adjoint/` holds superseded or
crashed-run notebooks. See `analyses/README.md` for the per-notebook index.

Python dependencies (no environment file is checked in): `numpy`, `xarray`,
`xmitgcm`, `matplotlib`, and for the notebooks in
`analyses/reference_notebooks/`, the external `dinocean` package.

---

## What is not tracked

`.gitignore` excludes:

- `**/build*/` — all build directories
- `**/.ipynb_checkpoints/`
- `input_binaries/` and `input_adj_binaries/` for every DINO and SOMA setup

Regenerate the SOMA inputs with `input/gendata.py` (bathymetry, wind stress, SST
and SSS relaxation fields as big-endian `float32`). DINO's binaries — `dino_bathy.bin`,
`dino_utau.bin`, `dino_T_star.bin`, `dino_S_star.bin`, `dino_q_solar.bin`,
`dino_T0.bin`, `dino_S0.bin`, `dino_U0.bin`, `dino_V0.bin`, `dino_viscAhD.bin`,
`dino_diffKr.bin` — are produced outside this repository and must be staged into
`input_binaries/` before a run.

## Reference

- MITgcm documentation — <https://mitgcm.readthedocs.io>
- MITgcm automatic differentiation — <https://mitgcm.readthedocs.io/en/latest/autodiff/autodiff.html>
- Tapenade — <https://team.inria.fr/ecuador/en/tapenade/>
