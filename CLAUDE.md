# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

MITgcm adjoint-sensitivity experiments built with the **Tapenade** AD toolchain (`pkg/tapenade`) instead of TAF/OpenAD. It contains experiment configurations, build/SLURM scripts, and analysis notebooks — plus a **fully vendored, locally patched MITgcm source tree**. Model output is not here; it lives on cluster scratch.

`README.md` documents the science (cost function, controls, namelist tags, grids) in detail. This file covers the mechanics that only become clear from reading several scripts at once.

There is no root build system, no test suite, no linter, and no package manifest. Fortran is built per-setup via `genmake2` + `make`; Python analysis happens in notebooks with no checked-in environment file (`numpy`, `xarray`, `xmitgcm`, `matplotlib`).

## Layout

- `MITgcm_c69m/` — checkpoint69m tree (`MITgcm/`) + setups under `mysetups/`
- `analyses/` — notebooks reading run output from `/scratch2/...`
- `resources/` — collaborator reference notebooks
- `00_archive/` — frozen reference copies, at both tree level (`MITgcm_c69m/00_archive/MITgcm-pkg-tapenade`) and setup level (inside each of `DINO_1deg/` and `SOMA_1deg/`, holding ASTE-derived namelists, spare `code_tap` sources, and superseded build/submit scripts). Nothing here is live configuration; no build or submit script reads from it. Grep hits inside these directories are history, not current behaviour. The `00_` prefix exists to keep them sorted above `build*/` and `code*/` in a plain `ls`.

The primary configuration is `MITgcm_c69m/mysetups/DINO_1deg/` (DINO, 51 × 198 × 36 curvilinear). `MITgcm_c69m/mysetups/SOMA_1deg/` is the secondary.

**The checkpoint69f tree is no longer in this repository.** `MITgcm_c69f/` — the c69f source tree, the earlier DINO and `sr_soma` ports, and the `tutorial_*_with_adj` / `tutorial_global_oce_biogeo` test-bed setups — was removed on 2026-08-17 because work has moved entirely to c69m. It survives in full, working tree and history both, at `/home/tshahriar/Proj_ImPACTS_old` (remote `git@github.com:tsgonerog/Proj_ImPACTS_old.git`). Go there rather than trying to reconstruct it; several things documented below (Tapenade profiling, the tutorial cross-checks against `code_ad`/`code_oad`) exist only in that copy.

**The vendored `MITgcm/` tree is not read-only upstream code.** `MITgcm/tools/` carries patched `genmake2` copies that the build depends on. Do not replace the tree wholesale, and do not assume a file under `MITgcm/` matches upstream.

## Build

Each setup builds itself; scripts resolve `MITGCM_ROOT` relative to their own location, so they can be invoked from anywhere but expect to be *run from the setup directory* (they use relative paths like `code_tap/`).

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
export MPI_OPTFILE=/path/to/mpi/optfile      # required by every MPI build script
./tapAdj_build_mpi_patched.sh                # -> build_tapAdj_mpi_patched/mitgcmuv_tap_adj
```

Serial builds (`serial_tapAdj_build_patched.sh`, `tapAdj_build_serial_*.sh`) need no `MPI_OPTFILE` — they hardcode `MITgcm/tools/build_options/linux_amd64_ifort`. Forward-only builds use `frd_build_*.sh`. Every script does the same five steps: stage variant files, `make CLEAN`, run a patched `genmake2` with `-tap -adof=<root>/tools/adjoint_options/adjoint_tap -mods=../code_tap`, `make depend`, `make -j 8 tap_adj`.

**Parallelism is a property of the setup, not a flag you pass.** Only the adjoint build scripts that exist are usable: DINO is MPI-only, `SOMA_1deg` is serial-only. Both `SIZE.h` variants (and both `forward_step_b.f_modified_*` variants) are nonetheless present in most `code_tap/` directories, so finding `SIZE.h_serial` in the c69m DINO setup does not mean a serial adjoint build is wired up there — no script stages it and no submit script expects it.

Build directories (`build*/`) are gitignored and fully reproducible. They are **not relocatable**: `genmake2` bakes the setup's absolute path into the generated `Makefile` (~23 references), so renaming or moving a setup directory invalidates any build inside it. Re-run the build script rather than trying to patch the `Makefile`.

### Variant staging — the most important gotcha

Build scripts **overwrite tracked files by copying variant siblings over them** before configuring, e.g.:

```
code_tap/SIZE.h_mpi                  -> code_tap/SIZE.h
code_tap/the_model_main.F_OG         -> code_tap/the_model_main.F
code_tap/AUTODIFF_PARAMS.h_OG        -> code_tap/AUTODIFF_PARAMS.h
code_tap/autodiff_readparms.F_OG     -> code_tap/autodiff_readparms.F
code_tap/forward_step_b.f_modified_mpi -> code_tap/forward_step_b.f_modified
```

Both sides are tracked in git. So:

- **Edit the suffixed variant, never the bare destination file** — `SIZE.h`, `the_model_main.F`, `AUTODIFF_PARAMS.h`, `autodiff_readparms.F`, `autodiff_inadmode_set_ad.F`, `forward_step_b.f_modified` are all regenerated and your edits will vanish on the next build.
- Running any build script dirties the working tree even when nothing was authored. Check `git diff` before assuming a change is yours.

Suffix meanings: `_mpi` / `_serial` (parallelism), `_OG` (original) vs `_aste_90x150x60` / `_adapted_frm_aste_90x150x60` (adapted from the ASTE regional setup — this is what the `asteMods` experiment variant selects), `_ForTapProfile` (Tapenade profiling build).

### The genmake2 patch

The patch is one injected line that overrides Tapenade's generated reverse-mode routine with a hand-corrected one:

```
cp ../code_tap/forward_step_b.f_modified forward_step_b.f
```

Tapenade differentiates `forward_step.F` automatically but the result needs manual correction; `forward_step_b.f_modified` is that correction and the patched `genmake2` is how it survives a rebuild.

**`patched` vs `noTpatched` is the naming axis that runs through every script and build directory**, and it means exactly this patch:

- `*_patched.sh` → calls `$MITGCM_ROOT/tools/$GENMAKE_SCRIPT` (a `patched_*_genmake2`), so the hand-corrected `forward_step_b.f` wins. This is the working configuration; use it unless you specifically want otherwise.
- `*_noTpatched.sh` → calls stock `$MITGCM_ROOT/tools/genmake2` with otherwise identical flags, leaving Tapenade's own `forward_step_b.f` in place. It is the control build, kept to demonstrate what raw Tapenade output does.

The two write to sibling build directories (`build_tapAdj_mpi_patched/` vs `build_tapAdj_mpi_noTpatched/`), so both can exist at once — check which executable a submit script's `build_dir` actually points at.

`use_TapProfile` at the top of each build script selects the mode (`NO` / `YES` / `AFTER`) and picks both the `genmake2` variant and the matching `the_model_main.F`. **Only the `NO` mode works here:** `MITgcm_c69m/MITgcm/tools/` has just `patched_NoTapProfile_genmake2`, and DINO's `code_tap/` has no `the_model_main.F_ForTapProfile`. Setting `use_TapProfile` to `YES` or `AFTER` will fail. Reviving profiling needs two pieces, and only one of them is still here: `the_model_main.F_ForTapProfile` survives in `00_archive/code_tap_files_MITgcm_c69f/` (archive, so not staged by any script — it would have to be copied into `code_tap/`), but `patched_ForTapProfile_genmake2` and `patched_AfterTapProfile_genmake2` exist only in the archived c69f tree at `Proj_ImPACTS_old/MITgcm_c69f/MITgcm/tools/`.

## Run

SLURM batch scripts targeting the **`sverdrup`** cluster:

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
sbatch tapAdj_submit_mpi_patched_on_sverdrup.sh
./clean_slurm_logs.sh          # prompts, then deletes *.out/*.err in cwd only
```

A submit script: selects a namelist via `test_cases`; rewrites time-stepping parameters; stages a job-ID-stamped run directory under `/scratch2/<user>/<setup>_<mode>_runs/` (`_tapAdj_` or `_frd_`), copying `input_tap/` and symlinking the gitignored `input_binaries/` and `input_adj_binaries/`; symlinks any pickups; then runs the executable and writes `run_timing.txt`.

Things to know before editing or submitting one:

- **`-n` must match `SIZE.h`.** The MPI DINO adjoint requests 27 ranks because `SIZE.h_mpi` sets `nPx=3, nPy=9` over `sNx=17, sNy=22` tiles. Changing the decomposition means changing both.
- **Durations are written in days at the top of the script** (`simulation_duration_with_dT1800_days`, `monitorFreq_days`, `adjMonitorFreq_days`, `adjDumpFreq_days`). The script auto-detects every `*_days` variable, converts to seconds (`nTimeSteps` for the duration, assuming `dT=1800`), and `sed -i`-patches the namelist.
- **That `sed -i` edits the tracked namelist in `$SLURM_SUBMIT_DIR/input_tap/`, not a copy.** Submitting a job modifies the repo. Expect and inspect the resulting diff.
- **`nIter0` is *not* one of the auto-patched parameters — the start iteration and the pickup are coupled by hand.** `nIter0` is baked into whichever `data_<tag>` the `test_cases` string selects (`frmSt` → `0`, `frm50yPk` → `878400`, `frm180yPk` → `3162240`), while the pickup itself is a hardcoded `ln -s` line further down the same script. Changing `test_cases` to a different `frm*Pk` tag without editing that symlink to the matching `pickup.<nIter0>.{data,meta}` gets you a run that cannot find its pickup. Changing the duration is safe; changing the starting point is not.
- **`asteMods` is a build *and* a namelist variant, not just a build.** `tapAdj_submit_mpi_patched_on_sverdrup_asteMods.sh` points `build_dir` at `build_tapAdj_mpi_patched_asteMods/` and additionally does `rm data.autodiff` + `mv data.autodiff_adapted-frm-aste-90x150x60 data.autodiff` in the staged run directory. Pairing the plain submit script with the asteMods build (or the reverse) silently runs a mismatched configuration.
- **Paths and the notification address are hardcoded** (`/scratch2/tshahriar/...`, `tanvirshahriar@utexas.edu`, and absolute pickup paths). Change them before running as anyone else.
- Namelist variants live beside `data` as `data_<tag>` and are chosen by `test_cases` (empty string = plain `input_tap/data`); tags compose. See README for the tag vocabulary.
- Serial SOMA scripts are pre-made per duration (`submit_tapAdj_serial_on_sverdrup_{5,30,180,360}_day_patched.sh`) because adjoint cost grows fast with integration length.

### Where the output lands

Two different places, which matters when a run fails:

- **In the setup directory** (i.e. in the repo, untracked): `<job-name>.<job-id>.out` and `.err`. The scripts run under `set -x`, so the `.err` file is a full trace of the staging steps — this is where staging failures show up, not in the model output. `./clean_slurm_logs.sh` deletes these (prompts first, cwd only, non-recursive).
- **In scratch**: `/scratch2/<user>/<setup>_tapAdj_runs/<job-name>_<duration>d<suffix>_run<job-id>/`, holding `output_tap_adj.txt` (all model stdout/stderr), `run_timing.txt`, the staged namelists, and the `ADJ*` / monitor output the notebooks read. The `<suffix>` is `_$test_cases`, so the run directory name records which namelist variant was used — the only durable record of it, since `test_cases` lives in a script that gets edited between runs.

**Scratch output is split across old and new setup names.** Both setups were renamed on 2026-08-17, and only the `run_dir` in the live submit scripts was repointed:

| Setup, now | Was | Runs before 2026-08-17 | Runs after |
| --- | --- | --- | --- |
| `DINO_1deg` | `DINO_MITgcm_v011526` | `/scratch2/tshahriar/DINO_MITgcm_v011526_{frd,tapAdj}_runs/` | `DINO_1deg_{frd,tapAdj}_runs/` |
| `SOMA_1deg` | `v4_soma` | `/scratch2/tshahriar/v4_soma_tapAdj_runs/` | `SOMA_1deg_tapAdj_runs/` |

The old trees were deliberately left in place: every analysis notebook reads absolute paths into them, and the run directory names themselves embed the old strings (`DINO-MITgcm-v011526_frd_…`, `pd_v4StP_srl_…`). Do not "fix" those notebook paths — they point at real directories that still carry those names. The pickup symlinks in the DINO submit scripts point into the old tree for the same reason.

## Forward vs adjoint configuration

The `code/` + `input/` pair is the forward model; `code_tap/` + `input_tap/` is the adjoint. They differ structurally, not just by a flag:

- `code_tap/packages.conf` drops `cd_code` and adds `tapenade` plus the `adjoint` pkg group (`autodiff, ctrl, cost, grdchk`).
- `input_tap/` adds `data.autodiff`, `data.cost`, `data.ctrl`, `data.grdchk`.
- `code_tap/COST_OPTIONS.h` defines `ALLOW_COST_ATLANTIC_HEAT` and `ALLOW_COST_ATLANTIC_HEAT_DOMASS`.

The cost function `code_tap/cost_atlantic_heat.F` has its **section indices compiled in as `parameter` statements** — a zonal section (DINO: `isecbeg=1, isecend=51, jsec=127`) and a meridional one (`jsecbeg=1, jsecend=62, isec=30`) are both declared. Moving a section requires editing this file and rebuilding, not a namelist change; `mult_atl` in `data.cost` only scales the result. Indices are located with `analyses/DINO_analyses/exploring_DINO_grids.ipynb`. Because the values are compiled in, the authoritative record of what a past run measured is the `.f` file in that run's build directory, not the current source.

`kmaxdepth` is likewise compiled in, and per-setup: DINO uses 25, SOMA 21. Both live in the `ALLOW_COST_ATLANTIC_HEAT_DOMASS` branch, which is the active one in every setup that enables this cost function — the `#else` value of 14 inherited from `pkg/cost` is dead code here, so don't read it as a default.

**KPP and GM/Redi are off in every adjoint run.** Both DINO and `SOMA_1deg` set `useKPP`/`useGMRedi` `.FALSE.` statically in `input_tap/data.pkg`, and their submit scripts carry the equivalent `sed -i` lines commented out. The `useKPPinAdMode`/`useGMRediInAdMode` flags in `data.autodiff` are therefore inert as currently configured. Check both the namelist and the submit script before concluding a package is active — the now-archived `sr_soma` setup did it the other way round, leaving the namelist `.TRUE.` and disabling the packages from the submit script instead.

## Verifying correctness

There are no unit tests. Adjoint correctness is checked by **finite-difference gradient checks** — configured by `input_tap/data.grdchk` (`grdchk_eps=1e-5`, a `grdchkvarname` such as `xx_theta`, and the `iGloPos/jGloPos/kGloPos` point to perturb). This runs inside the model executable, not as a separate command. **`useGrdchk = .TRUE.` in both the DINO and SOMA setups**, so this is not an opt-in mode — every adjoint job as currently configured also does the perturbed forward runs, and pays for them. If a run seems to be doing more work than the adjoint alone should require, check this flag before looking elsewhere.

The second check used historically — the `tutorial_*_with_adj` setups reproducing stock MITgcm tutorials through the Tapenade path, with `tutorial_global_oce_biogeo/` keeping `code_ad` / `code_oad` / `code_tap` side by side to compare AD backends — lived in the c69f tree and is now only in `Proj_ImPACTS_old`. There is no tutorial-level regression check in this repository.

## Analyses

Notebooks read output directly from cluster scratch with `xmitgcm.open_mdsdataset(grid_dir='/scratch2/...', prefix=['ADJtheta', ...], read_grid=True, delta_t=1800)`, `geometry="curvilinear"` for DINO. Where raw tiled binaries are read instead, shapes are reconstructed from the same `sNx/sNy/OLx/OLy/Nr` values as `SIZE.h` — keep those in sync when the decomposition changes.

Notebooks are committed with outputs embedded, so they are large; `**/.ipynb_checkpoints/` is gitignored but some checkpoint dirs predate that rule.

## Not tracked

`**/build*/`, `**/.ipynb_checkpoints/`, and the `input_binaries/` + `input_adj_binaries/` directories for every DINO and SOMA setup. SOMA inputs regenerate with `input/gendata.py`; DINO's `dino_*.bin` files are produced outside this repository and must be staged into `input_binaries/` before a run.

`input_adj_binaries/` is small but not optional: it holds `ones_64b.bin`, the uniform weight file that *every* `xx_gentim2d_weight`/`xx_genarr3d_weight` entry in `data.ctrl` points at. Since it is untracked and the submit script only symlinks the directory contents, a fresh clone has no adjoint run until it is put back.
