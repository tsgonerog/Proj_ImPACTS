# analyses/

Jupyter notebooks that read MITgcm run output from cluster scratch
(`/scratch2/<user>/...`) and produce the diagnostics and figures for this
project. Nothing here reads from the repository itself — the model output lives
outside git.

Directory and notebook names carry a leading number giving the order the work is
meant to be read in. `00_archive/` holds superseded, crashed, or replaced
notebooks; it is kept for provenance and nothing live depends on it. Each
archive also carries its own `README.md` giving what every file in it is and
why it is not live — read that before assuming anything there is revivable.

## Layout

```
analyses/
├── DINO_1deg/                        primary configuration (51 x 198 x 36)
│   ├── 00_grid_and_cost_sections.ipynb   locates the cost-function section indices
│   ├── 01_first_look_at_output.ipynb     entry point for reading a DINO run
│   ├── 02_forward/
│   │   ├── 00_archive/                     crashed 200-year attempts
│   │   ├── 01_viscosity_study/             PARM05 viscAh*file vs PARM01 viscAhGrid
│   │   ├── 02_spinup_200yr_visc2x.ipynb
│   │   └── 03_moc_amoc_animation_visc2x.ipynb
│   └── 03_adjoint/
│       ├── 00_archive/                     earlier serial runs + the SciDAC poster
│       ├── 01_5yr_from_180yr_pickup_visc2x.ipynb
│       ├── 02_5yr_from_50yr_pickup_viscD2x_Zref.ipynb
│       ├── 03_5yr_from_50yr_pickup_viscGrid1p8e-2_adjViscBoost.ipynb
│       ├── 04_5yr_from_rest_viscGrid1p8e-2_adjViscBoost.ipynb
│       └── 05_kappa_v_ensemble/            the kappa_v perturbation ensemble (7 notebooks)
├── SOMA_1deg/                        secondary configuration (62 x 62 x 31)
├── reference_notebooks/              collaborator material the above derives from
│   ├── dinocean_package_usage_from_matt.ipynb
│   ├── dino_output_walkthrough_from_matt.ipynb
│   └── moc_amoc_animation_reference.ipynb
└── tools/
    └── strip_animation_outputs.py    keeps notebooks under GitHub's size limit
```

## Scratch layout

Runs live in two campaign directories, named to match the setups:

```
/scratch2/<user>/DINO_1deg_frd_runs/      forward
/scratch2/<user>/DINO_1deg_tapAdj_runs/   adjoint
```

Run directories follow
`DINO_1deg_<mode>[_srl]_<duration>_<start>_<settings>_run<jobid>`, with the same
configuration tokens the notebooks use. The job ID is the durable key: it is
what ties a notebook to its run, and it never changes.

Durations are quoted in years where the run tag used days: DINO runs on a
366-day year at `dT=1800`, so `73200d` is 200 years, `1830d` is 5 years, and
`366d` is 1 year.

## Configuration tokens in file names

DINO notebook names end in the viscosity setting the run used, because that is
the axis most of these experiments vary. The reference field is
`dino_viscAhD.bin`, built as `dxC * 0.27 / 2` by
`02_forward/01_viscosity_study/00_build_viscAhD_binaries.ipynb`; the `_2p00`
file is that field doubled.

| Token | Meaning |
| --- | --- |
| `visc2x` | `viscAhDfile` = `viscAhZfile` = `dino_viscAhD_2p00.bin` — both components at **2× reference**, through `PARM05` |
| `viscD2x_Zref` | `viscAhDfile` at 2× but `viscAhZfile` left at the reference field — a **mixed** setting, not the same experiment as `visc2x` |
| `viscRef` | both files at the unscaled reference |
| `viscGrid<v>` | scalar `viscAhGrid` in `PARM01` instead, `PARM05` files commented out; `viscGrid1p8e-2` is `viscAhGrid=1.8E-2` |
| `adjViscBoost` | adjoint-mode viscosity inflation: `viscFacInAd = 10.` against `viscFacInFw = 1.`, from `data.autodiff_adjViscBoost`. Needs the matching build *and* submit script |

Reading `p` as the decimal point keeps the tokens shell-safe: `1p135e-2` is
`1.135E-2`. Every notebook repeats its setting in full in a banner directly
under the title, with the run number, so nothing depends on decoding the name.

The distinction `visc2x` vs `viscD2x_Zref` is not cosmetic. The 200-year
spin-up first ran as `viscD2x_Zref` and **crashed at 126.3 years** (run 19369);
raising `viscAhZ` to 2× as well is what produced the run that completed
(run 28463). Both notebooks are kept, the crashed one in `00_archive/`.

## DINO_1deg

`00_grid_and_cost_sections.ipynb` is the one other parts of the repo point at —
it is how `isecbeg/isecend/jsec` in `code_tap/cost_atlantic_heat.F` were chosen,
and both `README.md` and `CLAUDE.md` cite it by name.

### 02_forward

| Notebook | Run | What it shows |
| --- | --- | --- |
| `01_viscosity_study/00_build_viscAhD_binaries.ipynb` | 28402 | builds and verifies `dino_viscAhD.bin` against `dxC * 0.27 / 2`, and scales it to the `_2p50`/`_3p00`/`_5p00` variants |
| `01_viscosity_study/01_viscRef_vs_viscGrid1p0e-2.ipynb` | 28402 vs 28447 | reference `PARM05` files against `viscAhGrid=1.0E-2` |
| `01_viscosity_study/02_viscGrid1p135e-2_increased.ipynb` | 28402 vs 28448 | same comparison, `viscAhGrid` raised to `1.135E-2` |
| `01_viscosity_study/03_viscGrid9p0e-3_decreased.ipynb` | 28402 vs 28451 | same comparison, `viscAhGrid` lowered to `9.0E-3` |
| `02_spinup_200yr_visc2x.ipynb` | 28463 | the 200-year spin-up that completed: MOC in depth and density space, barotropic streamfunction, AMOC timeseries. Writes everything in `figures/` |
| `03_moc_amoc_animation_visc2x.ipynb` | 28463 | renders the MOC + AMOC-timeseries frames into `moc_anim/` and `moc_anim_jpg_std2/` |

`00_archive/` holds the two 200-year attempts that crashed:
`200yr_from_rest_viscD2x_Zref_crashed_126y.ipynb` (run 19369) and
`200yr_from_rest_viscGrid1p8e-2_crashed_13y.ipynb` (run 28452).

### 03_adjoint

All read `/scratch2/<user>/DINO_1deg_tapAdj_runs/`. Notebooks 01–04 each
read one 5-year (1830-day) MPI adjoint; they differ in where they start and how
viscosity is set. 06 compares a half-year adjoint against the 5-yr reference.

| Notebook | Run | Start (`nIter0`) | Viscosity / mods |
| --- | --- | --- | --- |
| `01_5yr_from_180yr_pickup_visc2x.ipynb` | 28486 | 180-year pickup (3162240) | `viscAhD` = `viscAhZ` = 2× reference |
| `02_5yr_from_50yr_pickup_viscD2x_Zref.ipynb` | 24493 | 50-year pickup (878400) | `viscAhD` 2×, `viscAhZ` at reference |
| `03_5yr_from_50yr_pickup_viscGrid1p8e-2_adjViscBoost.ipynb` | 28461 | 50-year pickup (878400) | `viscAhGrid=1.8E-2`, adjoint-mode visc boost |
| `04_5yr_from_rest_viscGrid1p8e-2_adjViscBoost.ipynb` | 28453 | rest (0) | `viscAhGrid=1.8E-2`, adjoint-mode visc boost |
| `06_0p5yr_from_180yr_pickup_visc2x_vs_5yr_ref.ipynb` | 31028 vs 30995 | 180-year pickup (3162240) | `visc2x`, Tapenade-native-hook build (31028); matched-lead comparison against the 5-yr reference 30995, seam-masked because 30995 predates the ADEXCH stubs fix. Figures/animations go to 31028's run directory |

Settings in this table were read back from each run's own staged `data`
namelist on scratch, not from the run-directory tag.

`05_kappa_v_ensemble/` is a seven-notebook suite (2026-08-30) analysing the
vertical-diffusivity perturbation ensemble of the `notes/nn_surrogate` master
plan, Part I: the new reference adjoint 30995 (bit-identical to 28486) against
members M1–M7 (runs 31003–31009, κ_v scaled 0.25×–32×), plus the
internal-variability noise floor reconstructed from spin-up 30983's 2,402
pickups. It has its own `README.md` (run table, reading order, conventions);
shared code lives in `ensemble_common.py`, and `build_cache.py` /
`build_jproxy.py` must be run once before re-executing the notebooks — they
write the intermediates the notebooks read. Unlike the single-run notebooks,
this suite spans nine runs, so everything it generates goes to the sibling
scratch directory `/scratch2/<user>/DINO_1deg_tapAdj_runs/kappa_v_ensemble_analysis/`
(`cache/`, `figures/`, `animations/`, `stats/`) rather than into any one run
directory.

`00_archive/` holds four earlier serial exploratory runs at 180 and 360 days,
named for their starting point and viscosity setting — `viscRef` from rest
(runs 18232, 18222), `viscD2x_Zref` from the 80 yr pickup (runs 22038, 22039).
A fifth, `serial_180d_from_50yr_pickup_after_profile.ipynb`, keeps no setting
in its name: run 24020 is gone from scratch, so its namelist cannot be read
back. Alongside them is
`poster_scidac_pi_meeting_aug2026/` — the poster prepared for the SciDAC PI
meeting in August 2026. Both of its notebooks read run 28486:
`01_adj_field_animations.ipynb` animates the 3-D and 2-D `ADJ*` fields, and
`02_poster_panel_frames.ipynb` is the trimmed version that writes the nine
`poster_frames/*.png` panels of the 3 x 3 sensitivity grid.

### Where the outputs go

**No figures or animations live in this repository.** Every notebook writes its
output into the scratch run directory it read, so a run directory is
self-contained and deleting a run takes its figures with it:

```
<run>/
├── figures/       PNGs, and poster_frames/ for the SciDAC panels
└── animations/    gif + html exports, and the frame directories
```

Notebooks derive those paths from the `run_dir` they already define
(`FIG_DIR = run_dir / "figures"`, `ANIM_DIR = os.path.join(run_dir, "animations")`),
so the output follows the run automatically if it is ever moved again. Nothing
needs editing in two places.

The one deliberate exception is `05_kappa_v_ensemble/`, which reads nine runs
and therefore writes everything to the sibling directory
`/scratch2/<user>/DINO_1deg_tapAdj_runs/kappa_v_ensemble_analysis/` instead of
into any one run (details in that suite's own `README.md`). Its two
publication figures are additionally committed under
`notes/nn_surrogate/briefs/kappa_ensemble_results/figures/` — they are LaTeX
sources for that brief, and the only images tracked in this repository.

Current locations:

| Output | Lives in |
| --- | --- |
| 200-year spin-up figures, `moc.gif`, `moc_anim*/` | `DINO_1deg_frd_runs/runs_prod/DINO_1deg_frd_200yr_from_rest_visc2x_run28463/` |
| `ADJ*` gif/html, `adj_*_z14/`, `poster_frames/` | `DINO_1deg_tapAdj_runs/DINO_1deg_tapAdj_5yr_from180yrPk_visc2x_run28486/` |

The `.gitignore` rules for `analyses/**/*.{png,jpg,gif,html}` are only a safety
net against a cell being re-run with a repo-local output path.

## SOMA_1deg

| Notebook | Runs | What it shows |
| --- | --- | --- |
| `01_first_look_at_dyndiag.ipynb` | `v4soma_tapAdj_test_run_5975` | first look at a SOMA run: `dynDiag` temperature and velocity |
| `02_sensitivity_vs_run_length.ipynb` | `v4StP_srl_*` 5–150 d | manual tile stitching and halo removal, `adxx_theta` by depth, and an animation of how sensitivity grows with run length |
| `03_sensitivity_theta_salt_diffkr.ipynb` | `pd_v4StP_srl_*` 30/180/360 d | three controls: temperature, salinity, vertical diffusivity |
| `04_sensitivity_full_control_set.ipynb` | `pd_v4StP_srl_*` 30/180/360 d | the full control set — adds velocities, wind stress, and surface heat and freshwater fluxes |

KPP and GM/Redi are disabled in all of them and the cost section is at 40°N, so
neither is repeated in the file names.

## Reading the output files

`adxx_*` and `xx_*` control files are **`float64`**; the `ADJ*` diagnostic dumps
follow `data.diagnostics` and are `float32`. Read the `.meta` beside a file rather
than assuming — guessing wrong silently reshapes the array into plausible-looking
garbage. `xmitgcm.open_mdsdataset` handles this for you; raw `np.fromfile` does not.

Two runs were added on 2026-08-18 for verification rather than science:

| Run | What it is |
| --- | --- |
| `DINO_1deg_frd_10yr_from_rest_visc2x_run30945` | 10-year forward, confirmed **bit-identical** to the first 10 years of run 28463. Carries `figures/` with the MOC, AMOC and reproduction-check plots |
| `DINO_1deg_tapAdj_30d_from180yrPk_visc2x_run31032` | 30-day adjoint, confirms `ADJ*`/`adxx*` output (incl. `ADJetan`) and sensitivity on the cost section. Successor of the 2026-08-18 original (30948, superseded and removable): 31032 is the current-toolchain rerun of the same config, bitwise-validated back to it through the 31022 chain |

## Notebook size discipline

`matplotlib`'s `anim.to_jshtml()` embeds *every frame of an animation as a
separate base64 PNG* in a single `text/html` output. Eight such animations were
enough to make one notebook 228 MB — past GitHub's hard 100 MB per-file limit,
which blocks the push outright.

That is handled automatically now, by a git **clean filter**. Outputs stay in
your working copy, so you can open a notebook and show it to someone; git
strips the oversized ones on the way into the index, so what gets committed and
pushed is small. Nothing has to be remembered before a push.

Filters live in `.git/config`, which is not tracked, so **each clone runs this
once**:

```bash
./analyses/tools/install_git_filters.sh                # default: >1 MB animations
./analyses/tools/install_git_filters.sh --all-outputs  # strip every output
./analyses/tools/install_git_filters.sh --uninstall
```

The default removes only animation payloads above 1 MB and leaves static figures
alone, so plots still render for anyone reading the repository on GitHub. Each
stripped output is replaced by a note saying what was removed and that re-running
the cell regenerates it. `--all-outputs` clears everything, which takes the
notebooks here from 29.6 MB to 1.4 MB but leaves no figures visible on GitHub.

Until the installer is run, `.gitattributes` is inert and notebooks commit as-is.

**One caveat.** The stored copy is the stripped one, so any git operation that
overwrites a notebook in the working tree — `checkout`, `stash`, `merge`,
`reset --hard` — replaces it with the stripped version, and whatever was
stripped is gone locally. Re-run the cell, or keep an export outside the repo:

```bash
jupyter nbconvert --to html --output-dir ~/nb_for_advisor <notebook>
```

The same script still works as a one-shot pass over files on disk, which is what
was used before the filter existed:

```bash
python3 analyses/tools/strip_animation_outputs.py            # whole tree
python3 analyses/tools/strip_animation_outputs.py --dry-run  # report only
```

That in-place mode rewrites the files themselves; the filter mode does not.

Before pushing, `./tools/pre_push_check.sh` at the repo root confirms the filter
is installed and that no figures or unresolved scratch paths have crept in. See
"Workflow: before you push" in the root `README.md`.

## What is deliberately not in git

Only code and notebooks. Model output, figures and animations all live on
cluster scratch. The notebooks are committed with their inline outputs, so the
plots still render on GitHub even though no image files are tracked.

Before committing a notebook containing animations, run
`python3 analyses/tools/strip_animation_outputs.py` — `anim.to_jshtml()` embeds
every frame as base64 and has produced single notebooks over GitHub's 100 MB
hard limit.
