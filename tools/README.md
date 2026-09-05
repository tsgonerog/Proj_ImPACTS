# `tools/`

Repository-level tooling: the things that are shared by every setup, or that
act on the repository as a whole. Three of them are scripts you run, one is a
file you *source*, and two are reference directories that no build script
touches.

Nothing here is MITgcm source, and nothing here is read by MITgcm. Per-setup
build and submit scripts live in the setup directories
(`MITgcm_c69m/mysetups/DINO_1deg/`); this directory holds what those scripts
call, plus the checks that guard the repository around them.

| | What it is | Run it? |
| --- | --- | --- |
| [`machine_env.sh`](machine_env.sh) | The single place cluster differences live — scratch root, MPI launcher, optfiles, sbatch flags, module stack | **Source it**, never execute (it is deliberately not `+x`) |
| [`submit.sh`](submit.sh) | `sbatch` wrapper that adds the per-machine flags. Submit through this, not bare `sbatch` | `./tools/submit.sh <script> [sbatch flags]` |
| [`compare_adj_runs.sh`](compare_adj_runs.sh) | Bit-compares two adjoint run directories and writes a verdict report; can wait on a running job first | `tools/compare_adj_runs.sh [opts] <ref> <new>` |
| [`pre_push_check.sh`](pre_push_check.sh) | Read-only standing check: filters, side effects you did not author, derived output, dead notebook paths | `./tools/pre_push_check.sh` |
| [`optfile_templates/`](optfile_templates/) | `genmake2` optfiles written here and **not yet validated** on their target machine | see its own [README](optfile_templates/README.md) |
| [`tapenade_profiling/`](tapenade_profiling/) | How to profile the adjoint and tune checkpointing on c69m, plus the c69f originals | see its own [README](tapenade_profiling/README.md) |

Shared conventions:

- **Every script locates the repository from its own path** (`dirname
  "${BASH_SOURCE[0]}"`), so it can be invoked from anywhere. The exception is
  the *setup* scripts these call, which use relative paths and must be run from
  the setup directory — which is why `submit.sh` `cd`s there for you.
- **Exit status is meaningful.** `0` = fine, `1` = a real problem, `2` = you
  used it wrong. `pre_push_check.sh` and `compare_adj_runs.sh` are designed to
  be usable in a conditional or a job dependency.
- **Nothing here commits, pushes, or edits a tracked file.** Every script in
  this directory is read-only with respect to the repository; the ones that
  write, write into a build or run directory on scratch.

---

## `machine_env.sh` — the porting layer

Sourced by every live build and submit script, and by `submit.sh` and
`pre_push_check.sh`. Porting to a new cluster means adding one `case` block
here rather than editing a dozen scripts; [`PORTING.md`](../PORTING.md) is the
walkthrough.

```bash
source tools/machine_env.sh      # from the repo root
impacts_check_env                # optional: warn about broken-build conditions
```

It **must be sourced, not executed** — it exports into your shell and defines
functions. Its file mode has no `+x` bit on purpose, so a stray `./` fails
immediately instead of running in a subshell and silently doing nothing.

### What it exports

| Variable | sverdrup | perlmutter |
| --- | --- | --- |
| `MACHINE` | `sverdrup` (the default — sverdrup sets nothing reliable to detect) | `perlmutter`, detected from `NERSC_HOST` |
| `SCRATCH_ROOT` | `/scratch2/$USER` | `$SCRATCH`, else `/pscratch/sd/<u>/$USER` |
| `MPI_LAUNCHER` | `mpirun -n` | `srun -n` (NERSC does not support `mpirun`) |
| `MPI_OPTFILE` | Intel optfile from `crios_computing` | `tools/optfile_templates/linux_amd64_gnu+mpi_perlmutter` — **untested** |
| `SERIAL_OPTFILE` | `MITgcm/tools/build_options/linux_amd64_ifort` | the same untested template |
| `SBATCH_EXTRA` | empty | `-A $NERSC_ACCOUNT -C cpu -q $PERLMUTTER_QOS -t $PERLMUTTER_WALLTIME` |
| `MAIL_USER` | notification address | same |
| `MITGCM_ROOT` | `$IMPACTS_ROOT/MITgcm_c69m/MITgcm` | same |

An unknown `MACHINE` is an error, not a fallback: it prints what to do and
returns 1.

### Overrides

Most values use `: "${VAR:=default}"`, so **anything already set in your
environment wins** and a one-off override needs no edit:

```bash
SCRATCH_ROOT=/tmp/test ../../../tools/submit.sh submit_tapAdj.sh
IMPACTS_MACHINE=perlmutter source tools/machine_env.sh    # force a profile
```

**The two optfiles are the deliberate exception.** They are assigned
unconditionally from the machine, because `~/.bashrc` on sverdrup exports
`MPI_OPTFILE` and honouring that would silently build Perlmutter with the Intel
sverdrup optfile. Their explicit overrides are `IMPACTS_MPI_OPTFILE` and
`IMPACTS_SERIAL_OPTFILE`.

### Two functions

- **`impacts_load_modules`** — loads the compiler/MPI stack. A **no-op on
  sverdrup**, where `~/.bashrc` already provides it; on Perlmutter it loads
  `PrgEnv-gnu`, `cray-mpich`, `cray-hdf5`, `cray-netcdf` and appends
  `$TAPENADE_HOME/bin` to `PATH`. Called at the top of every submit script.
- **`impacts_check_env`** — returns 1 and warns if `tapenade` is not on `PATH`
  (an adjoint build will fail), if `MPI_OPTFILE` does not exist, if
  `NERSC_ACCOUNT` is unset on Perlmutter, or if an untested optfile template is
  in use. It only warns — `submit.sh` prints the warnings and continues.

Two blockers it exists to catch, because neither is in this repository:
**Tapenade** is a Java tool on `$PATH`, not vendored here; and DINO's 179 MB of
`input_binaries/dino_*.bin` is untracked and produced elsewhere.

### DINO example

```bash
cd "$(git rev-parse --show-toplevel)"          # the repo root
source tools/machine_env.sh && impacts_check_env
echo "$MACHINE $SCRATCH_ROOT"                  # sverdrup /scratch2/<user>
ls "$SCRATCH_ROOT/DINO_1deg_outputs/runs/adjoint/"
```

`build_tapAdj.sh` sources this file to get `MPI_OPTFILE` for `genmake2 -of`, and
`submit_tapAdj.sh` sources it to get `SCRATCH_ROOT` for the run directory and
`MPI_LAUNCHER` for the model invocation. Neither takes an optfile argument —
that is the point.

---

## `submit.sh` — submit with this, not `sbatch`

```
./tools/submit.sh <submit-script> [extra sbatch flags...]
```

The submit scripts carry the `#SBATCH` directives that are the same everywhere
(job name, `-N`, `-n`, output files). Account, QOS, constraint and walltime
differ per machine and cannot be directives without breaking the other machine,
so they come from `SBATCH_EXTRA` and are passed on the command line, where
sbatch lets them override the script. On sverdrup `SBATCH_EXTRA` is empty, so
this is exactly `sbatch --export=ALL <script>`.

It has **no options of its own** — everything after the script path is handed
to `sbatch`. What it does: validates the script exists, sources
`machine_env.sh`, runs `impacts_check_env` (warns, continues), `cd`s to the
script's directory so the job's `$SLURM_SUBMIT_DIR` resolves `input_tap/`,
`input_binaries/` and the build directory correctly, prints what it is about to
run, then `exec`s sbatch.

Exit status: `2` with usage if given no arguments, `1` if the script does not
exist, otherwise sbatch's own.

**Three things to know:**

- **Extra flags go *before* the script name.** sbatch's usage is `sbatch
  [OPTIONS] script [args]`, so anything after the script name goes to the
  script instead — which is why `submit.sh <script> --test-only` used to submit
  a real job rather than dry-run it. `submit.sh` places them correctly.
- **`--export=ALL` is stated explicitly** although it is sbatch's default,
  because the jobs depend on it: `impacts_load_modules` is a no-op on sverdrup,
  so the Intel/MPI stack *and* the `IMPACTS_*` per-run overrides reach the
  compute node only through the inherited environment. A user-supplied
  `--export=` still wins, coming later on the command line.
- **`--parsable` needs `| tail -1`.** `submit.sh` prints a three-line banner to
  stdout before `exec`ing sbatch, so a bare `$(... --parsable)` captures the
  banner too:

  ```bash
  jid=$(../../../tools/submit.sh submit_tapAdj.sh --parsable | tail -1)
  ```

### DINO examples

```bash
cd MITgcm_c69m/mysetups/DINO_1deg

# committed defaults: forward, then adjoint
../../../tools/submit.sh submit_frd.sh
../../../tools/submit.sh submit_tapAdj.sh

# per-run overrides — these leave the working tree clean
IMPACTS_DURATION_DAYS=73200 ../../../tools/submit.sh submit_frd.sh          # 200 yr
IMPACTS_TEST_CASE=kappa_v_ensemble/M3 ../../../tools/submit.sh submit_tapAdj.sh
IMPACTS_TEST_CASE=grdchk_repair/from180yrPk_visc2x_grdchkON \
  IMPACTS_DURATION_DAYS=30 ../../../tools/submit.sh submit_tapAdj.sh

# the adjViscBoost pairing — build and namelist must match
../../../tools/submit.sh submit_tapAdj_adjViscBoost.sh

# dry-run: extra flags are passed through, and land before the script name
../../../tools/submit.sh submit_tapAdj.sh --test-only

# chain: adjoint waits for a forward leg (the job-chaining recipe in the project notes)
fwd=$(IMPACTS_TEST_CASE=kappa_v_ensemble/M3 ../../../tools/submit.sh submit_frd.sh --parsable | tail -1)
adj=$(IMPACTS_TEST_CASE=kappa_v_ensemble/M3 ../../../tools/submit.sh submit_tapAdj.sh \
        --parsable --dependency=afterok:$fwd | tail -1)
echo "M3: forward $fwd -> adjoint $adj"
```

The DINO adjoint requests `-n 27` because `code_tap/SIZE.h` sets `nPx=3, nPy=9`;
changing the decomposition means changing both. `IMPACTS_TEST_CASE` uses
`${VAR-default}`, so an explicit empty value (`IMPACTS_TEST_CASE=`) selects the
live `input_tap/data` rather than the committed variant.

Output lands in two places: `<job-name>.<job-id>.{out,err}` in the setup
directory (the `.err` is a full `set -x` trace of staging, which is where
staging failures appear), and the run itself under
`$SCRATCH_ROOT/DINO_1deg_outputs/runs/adjoint/DINO_1deg_<run_token>_<duration>[_<tag>]_run<jobid>/`,
where `run_token` (`tapAdj_<ckp>[_<variant>]`, e.g. `tapAdj_nocheckpoint`,
`tapAdj_ckpAll`, `tapAdj_ckpAll_adjViscBoost`, `tapAdj_ckpAll_tapProfile`)
is read from the build directory's `build_info.txt` — written by the build
script, copied into the run directory — so the name records the build as well
as the namelist, and a submit script cannot claim a build it did not get.
The duration label is whole 366-day years as `<n>yr` and anything else as
`<n>d`, so the default 1830 days becomes `5yr` and `IMPACTS_DURATION_DAYS=30`
becomes `30d`; the tag is the **last component only** of `IMPACTS_TEST_CASE`, so
`kappa_v_ensemble/M3` names the directory `_M3`. That is worth knowing before
you run `compare_adj_runs.sh`, since you have to name the directory yourself.

---

## `compare_adj_runs.sh` — did this change alter the answer?

```
tools/compare_adj_runs.sh [options] <reference-run-dir> <new-run-dir>
```

The regression test for anything that touches the adjoint: rebuild, rerun, and
compare against a run whose result you trust. It was promoted out of the
throwaway script that compared the new reference adjoint against the
pre-cleanup one, once the same comparison was wanted for each of the seven κ_v
ensemble members. It was checked both ways before being trusted: `EQUIVALENT`
with exit 0 on runs 30948 and 30994, which differ only in `useGrdchk`, across
196 sensitivity fields; and `NOT CLEAN` with exit 1 on two runs with genuinely
different windows.

| Option | Meaning |
| --- | --- |
| `--wait <jobid>` | Poll `squeue` until the job leaves the queue, then compare. Requires **two consecutive empty results 60 s apart**, so a transient `squeue` failure cannot be mistaken for "finished" and compare a half-written run |
| `--report <file>` | Where to write the report. Default: `<new-run-dir>/comparison_vs_<ref basename>.txt` |
| `--no-report` | Print the report, write no file |
| `--work <dir>` | Keep the intermediate listings here. Default: a `mktemp` directory, **which is not cleaned up** — the report's last line names it |
| `-h`, `--help` | The header, as usage |

Exit status: **0 if the two runs are equivalent, 1 if not, 2 on a usage error.**
The report is always printed to stdout as well as written.

### The seven sections

1. **Job completion** — `sacct` (if `--wait` was used), `run_timing.txt`, and
   the `NORMAL END` count, which is one per rank (**27** for the MPI DINO
   adjoint). Zero prints the tail of the output file.
2. **File inventory** — common / only-in-reference / only-in-new.
3. **Sensitivity fields** — every common `ADJ*` and `adxx*` file, `cmp`'d byte
   for byte. This is the section that matters.
4. **All other common files** — excluding `STDOUT.*`/`STDERR.*` (build date,
   node, timers), the executable, and `run_timing.txt` (wall clock).
   Differences are classified, not just listed.
5. **Cost function** — the first `global fc` line from `STDOUT.0000` of each.
   Later `global fc` lines in a `grdchk` run are its perturbed forward
   integrations; only the first is the reference cost.
6. **Monitor stream** — every `%MON` line. A `grdchk` run emits extra ones after
   the main run, so the new run's lines are matched against the reference's
   **leading block of the same length** rather than compared wholesale.
7. **Verdict** — `EQUIVALENT` only if there was a `NORMAL END`, zero differing
   sensitivities, zero unexpected other differences, an identical `fc` and an
   identical monitor stream.

**Three differences are expected** between a run with `useGrdchk=.TRUE.` and one
with it `.FALSE.`, and are tagged `[expected: grdchk]` rather than failing the
verdict: `data.pkg` (the flag), `output_tap_adj.txt` (grdchk's `ph-test` /
`ph-grd` chatter), and `xx_theta.effective.*` (grdchk leaves its last probe's
perturbation behind — exactly one element differing by exactly `grdchk_eps`,
which the script confirms with a small numpy check, skipped gracefully if numpy
is unavailable). Everything else is tagged `[UNEXPECTED]` and fails the verdict.

Deliberately no `set -e`: every check must run and the report must be written
even when an earlier one fails.

### DINO examples

```bash
R=/scratch2/$USER/DINO_1deg_outputs/runs/adjoint

# the comparison that established 30995 reproduces the May baseline exactly
# (2026-08-28; 30995 was deleted after the 2026-09-01 rerun — the rerun's own
#  validation reports sit in each 31039-31046 run directory as
#  comparison_vs_*.txt, ADJ* differing seam-only there by design)
tools/compare_adj_runs.sh \
  "$R/sensitivity/DINO_1deg_tapAdj_ckpAll_5yr_from180yrPk_visc2x_run28486" \
  "$R/DINO_1deg_tapAdj_5yr_from180yrPk_visc2x_run30995"   # 30995: gone
echo "verdict: $?"          # 0 = equivalent
#   EQUIVALENT: all 8116 sensitivity fields bit-identical, fc identical to every
#   printed digit (3.30992121938681E-01), 18801 %MON lines byte-identical.
#   Its report went with the deleted directory; the surviving reports are the
#   rerun ones described above

# the 2026-09-02 ensemble rerun with the -nocheckpoint build: one call per pair,
# each report landing in the new run directory as comparison_vs_<ckpAll run>.txt
# (all eight EQUIVALENT -- 8850 sensitivity fields bit-identical, fc and the
#  18801 %MON lines identical; 31060-31067 against 31039-31046)
tools/compare_adj_runs.sh \
  "$R/kappa_v_ensemble/DINO_1deg_tapAdj_ckpAll_5yr_M3_run31042" \
  "$R/kappa_v_ensemble/DINO_1deg_tapAdj_nocheckpoint_5yr_M3_run31063"   # 31063: gone

# submit and compare unattended, from the setup directory
cd MITgcm_c69m/mysetups/DINO_1deg
jid=$(IMPACTS_DURATION_DAYS=30 ../../../tools/submit.sh submit_tapAdj.sh --parsable | tail -1)
nohup ../../../tools/compare_adj_runs.sh --wait "$jid" \
  "$R/toolchain_validation/DINO_1deg_tapAdj_ckpAll_30d_from180yrPk_visc2x_run31022" \
  "$R/DINO_1deg_tapAdj_nocheckpoint_30d_from180yrPk_visc2x_run$jid" &
#   note the asymmetry: the reference sits in a campaign directory, the new run
#   does not — a fresh run lands directly in runs/adjoint/ and is filed later
#   (submit_tapAdj.sh is the nocheckpoint default since 2026-09-02; its output
#    is bitwise identical to the ckpAll runs, so this comparison still holds)

# print only, keep the listings for a closer look (still in the setup directory)
../../../tools/compare_adj_runs.sh --no-report --work /tmp/cmp_31032 \
  "$R/toolchain_validation/DINO_1deg_tapAdj_ckpAll_30d_from180yrPk_visc2x_run31022" \
  "$R/toolchain_validation/DINO_1deg_tapAdj_ckpAll_30d_from180yrPk_visc2x_run31032"
```

A cleaner way to arrange the second one, without a background process holding
the terminal, is a SLURM dependency — put the `compare_adj_runs.sh` call in a
small job script and submit it `--dependency=afterany:$jid`. The job-chaining
recipe in the project notes covers the pattern in full.

Two things about DINO runs that bear on how you read a comparison: pre-31022
`ADJ*` dumps carry a tile-edge artifact (mask ~2 cells around `i=17|18`,
`34|35`, every `j` multiple of 22, and the periodic seam) that never affected
`fc` or `adxx_*`; and `fc` itself is decomposition-dependent, so only compare
runs built with the same `SIZE.h`.

---

## `pre_push_check.sh` — before concluding the tree is clean

```
./tools/pre_push_check.sh
```

Read-only — it never edits, stages, or pushes. It exists because **`git status`
alone does not distinguish a change you authored from one a build or submit
script made**, and because several things here rot silently.

Exit status is **1 only if something would actually break a push or a run**
(the `FAIL` lines); `note` lines are informational and do not affect it.

| Group | Checks | Severity |
| --- | --- | --- |
| notebook output filter | `filter.nbstrip.clean` is configured — filters live in untracked `.git/config`, so **a fresh clone commits notebooks unstripped** until `./analyses/tools/install_git_filters.sh` is run | **FAIL** |
| | `tools/machine_env.sh` sources cleanly, and reports the resolved `MACHINE` | **FAIL** |
| side effects you did not author | a modified `*/mysetups/*/input*/data*` — submit scripts now patch the staged copy in the run directory, so a modified namelist should only ever be one you edited by hand | note |
| derived output | `*.png/jpg/gif/html` staged under `analyses/` — figures belong in the scratch run directory | **FAIL** |
| | staged blobs over 10 MB (GitHub hard-fails at 100 MB) | note |
| notebook scratch paths | every `/scratch*/...` path a notebook builds still exists on disk, reassembling literals split across lines first | note |

That last check currently reports ~32 unresolved paths in 13 notebooks — mostly
`00_archive/` notebooks and three runs that no longer exist on scratch (18238,
18153, 24020). It prints the first six notebooks and three paths each; the count
in the header is the total.

### DINO example

A build no longer touches the tree (since 2026-09-02 nothing is copied into
`code_tap/`; the boost variant is a second `-mods` directory), so after
building any variant the check should report nothing:

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
./build_tapAdj_adjViscBoost.sh
./build_tapAdj.sh                    # symlink -> _nocheckpoint

cd ../../..
./tools/pre_push_check.sh            # a diff here is yours, or a regression
```

Build variants **in the order you want `code_tap/` left in**, and never `make`
in an older build directory after building a different variant — `genmake2`
symlinks headers back into `code_tap/`, so the older build's headers now resolve
to the other variant. Re-run its build script instead.

## `optfile_templates/` and `tapenade_profiling/`

Reference directories that live outside any setup — but **each one is read by a
script**, so neither is inert: `machine_env.sh` points `MPI_OPTFILE` and
`SERIAL_OPTFILE` at `optfile_templates/linux_amd64_gnu+mpi_perlmutter` when
`MACHINE=perlmutter`, and `build_tapAdj_tapProfile.sh` passes
`tapenade_profiling/mods_profile/` to `genmake2` as its *first* `-mods`
directory, failing with exit 1 if `adProfile.c` or `the_model_main.F` is
missing. What you do copy from by hand is the rest: the `c69f_originals/`
`genmake2` copies and the c69f 64-routine `-nocheckpoint` list.

- **[`optfile_templates/`](optfile_templates/)** — `genmake2` optfiles written
  for this project that have not been validated on the machine they target,
  kept out of `MITgcm/tools/build_options/` so they are not mistaken for peers
  of the 93 supported upstream optfiles that do work. It currently holds
  `linux_amd64_gnu+mpi_perlmutter`, which `machine_env.sh` points at when
  `MACHINE=perlmutter` so a first build produces real compiler errors rather
  than failing on a missing file. `impacts_check_env` warns for as long as a
  template is in use. `-fconvert=big-endian` in it is **not** optional: every
  pickup, input binary and `ADJ*`/`adxx*` file in this project was written
  big-endian on sverdrup.
- **[`tapenade_profiling/`](tapenade_profiling/)** — how the DINO adjoint is
  profiled (`build_tapAdj_tapProfile.sh`: `-tap_extra "-profile"` plus the
  `mods_profile/` directory, which supplies the installed Tapenade's
  `adProfile.c` and an instrumented `the_model_main.F`) and how recomputation
  is traded for memory (`build_tapAdj_nocheckpoint.sh`: `-tap_extra
  '-nocheckpoint "…"'` with the 33-routine list in
  `code_tap/tap_nocheckpoint.txt` — the DINO default since 2026-09-02, bitwise
  identical to the checkpoint-everything build and 1.5× faster). On c69m both
  are **flags**, not patched `genmake2` copies — c69m's `genmake2` takes
  `-tap_extra` and passes it straight to Tapenade. The two `c69f_originals/`
  are kept as the record of what was tried and **must not be installed** into
  `MITgcm/tools/`: they are full copies of the *c69f* `genmake2`, ~200 lines
  adrift; the c69f 64-routine list beside them shares 8 routines with the
  current one. The `use_TapProfile` switch is gone from every build script.

---

## Environment variables

**None of these are set anywhere in the repository — you set them, on the
command line, at submission time.** There is no config file for them. Every
occurrence in a script is a *read with a default*, never an assignment:

```bash
# MITgcm_c69m/mysetups/DINO_1deg/submit_tapAdj.sh -> submit_tapAdj_nocheckpoint.sh
test_cases="${IMPACTS_TEST_CASE-baseline/from180yrPk_visc2x}"           # :43
simulation_duration_with_dT1800_days="${IMPACTS_DURATION_DAYS:-1830}"   # :65
monitorFreq_days="${IMPACTS_MONITOR_FREQ_DAYS:-5}"                      # :66
adjMonitorFreq_days="${IMPACTS_ADJ_MONITOR_FREQ_DAYS:-5}"               # :67
adjDumpFreq_days="${IMPACTS_ADJ_DUMP_FREQ_DAYS:-5}"                     # :68
```

Every `IMPACTS_X=value` you find elsewhere in the repository is a documentation
example showing the command line to type. The one real assignment anywhere is
`IMPACTS_ROOT` in `machine_env.sh:35`, which defaults itself to the repo root.

| Variable | Read by | Effect |
| --- | --- | --- |
| `IMPACTS_MACHINE` | `machine_env.sh` | Force a machine profile instead of detecting one |
| `IMPACTS_MPI_OPTFILE` / `IMPACTS_SERIAL_OPTFILE` | `machine_env.sh` | The only way to override an optfile — plain `MPI_OPTFILE` is ignored on purpose |
| `SCRATCH_ROOT`, `MPI_LAUNCHER`, `SBATCH_EXTRA`, `MAIL_USER`, `MITGCM_ROOT`, `IMPACTS_ROOT` | `machine_env.sh` | Pre-set to override the machine default |
| `NERSC_ACCOUNT`, `PERLMUTTER_QOS`, `PERLMUTTER_WALLTIME` | `machine_env.sh` | Perlmutter `sbatch` flags; the account is mandatory there |
| `TAPENADE_HOME` | `impacts_load_modules` | Appended to `PATH` on Perlmutter |
| `IMPACTS_TEST_CASE` | setup submit scripts | Namelist variant, `<group>/<tag>` or a bare `<tag>`. Empty string selects the live `input*/data` |
| `IMPACTS_DURATION_DAYS` | setup submit scripts | Run length in days (DINO patches `nTimeSteps` at dT 1800; SOMA patches `endTime` at dT 1200) |
| `IMPACTS_MONITOR_FREQ_DAYS` | setup submit scripts | Monitor frequency |
| `IMPACTS_ADJ_MONITOR_FREQ_DAYS`, `IMPACTS_ADJ_DUMP_FREQ_DAYS` | adjoint submit scripts | Adjoint monitor and `ADJ*` dump frequency |

The committed default beside each read is the cheap regression configuration,
not the production one; each setup's own README tabulates the defaults and the
namelist key every variable lands on.

### How a per-run override actually reaches the model

```bash
IMPACTS_DURATION_DAYS=30 ../../../tools/submit.sh submit_tapAdj.sh
└────────── 1 ─────────┘
```

1. **`VAR=value command`** is bash's per-command environment prefix. It sets the
   variable for that one process only; your interactive shell is untouched.
2. `submit.sh` passes **`--export=ALL`**, so sbatch snapshots the submitting
   environment into the job.
3. On the compute node the submit script reads it and `sed`s the value into the
   **staged copy** of the namelist in the run directory.

That chain is the whole reason an override leaves `git status` clean: no
tracked file is edited, and `--export=ALL` is the only thing carrying the value
across. It is also why `submit.sh` states `--export=ALL` explicitly although it
is already sbatch's default — these overrides depend on it.

### Three consequences

- **The value is fixed at submit time, not at job start.** Once queued, a job
  carries the environment it was submitted with; exporting a different value
  later changes nothing for it, exactly as editing the submit script does not
  reach an already-spooled job. Cancel and resubmit instead.
- **Prefer the prefix form over `export`.** `export IMPACTS_DURATION_DAYS=30`
  in your shell silently applies to *every* later submission from that shell,
  and `--export=ALL` faithfully forwards it. The prefix form scopes it to one
  command. This is also why the submit scripts list the parameters to patch in
  an explicit `time_params` array: the old `compgen -v | grep '_days$'`
  auto-detection also enumerated exported environment variables, so any
  `*_days` variable in the submitting shell became a namelist key.
- **`-` versus `:-` is deliberate.** `IMPACTS_TEST_CASE` uses `${VAR-default}`,
  so an explicitly empty `IMPACTS_TEST_CASE=` selects the live `input*/data`;
  `:-` would swallow that and hand you the committed variant instead. The
  duration and frequency variables use `:-`, where unset and empty should mean
  the same thing.

### Two families, used differently

The `machine_env.sh` variables describe **the machine**, so they belong in
`~/.bashrc` as `export`s — `IMPACTS_MACHINE`, `IMPACTS_MPI_OPTFILE`,
`NERSC_ACCOUNT`, `TAPENADE_HOME`. They affect builds. The `IMPACTS_*` submit
variables describe **one run**, so they belong on the command line as a prefix.
Exporting one of those is the trap above; exporting one of the former is the
intended use.

`nIter0` is in neither family. The start iteration is baked into whichever
`data_<tag>` the test case selects, and the matching pickup is a hardcoded
`ln -s` further down the same submit script. Changing the duration is safe;
changing the starting point means editing both by hand.

---

## A full DINO cycle

Everything above, in the order it is normally used.

```bash
cd "$(git rev-parse --show-toplevel)"

# 0. is this machine able to build and run at all?
source tools/machine_env.sh && impacts_check_env

# 1. build the adjoint (the build script sources machine_env.sh itself)
cd MITgcm_c69m/mysetups/DINO_1deg
./build_tapAdj.sh                       # -> build_tapAdj_nocheckpoint/mitgcmuv_tap_adj (symlink to the default variant)

# 2. submit a cheap 30-day regression adjoint from the 180-yr pickup
jid=$(IMPACTS_DURATION_DAYS=30 ../../../tools/submit.sh submit_tapAdj.sh --parsable | tail -1)
echo "submitted $jid"

# 3. when it lands, bit-compare it against a run you trust
R=$SCRATCH_ROOT/DINO_1deg_outputs/runs/adjoint
../../../tools/compare_adj_runs.sh --wait "$jid" \
  "$R/toolchain_validation/DINO_1deg_tapAdj_ckpAll_30d_from180yrPk_visc2x_run31022" \
  "$R/DINO_1deg_tapAdj_nocheckpoint_30d_from180yrPk_visc2x_run$jid"
#   -> writes comparison_vs_..._run31022.txt into the new run directory,
#      which lands unfiled in runs/adjoint/ — move it into a campaign later
#      (the run_token in the name comes from build_info.txt; the default
#       build is nocheckpoint, bitwise identical to the ckpAll reference)
#      exit 0 = every ADJ*/adxx* bit-identical, fc and %MON identical

# 4. before pushing, check what in the tree is actually yours
cd ../../..
./tools/pre_push_check.sh               # builds no longer touch the tree; any diff is yours
```

Related reading: [`README.md`](../README.md) for the science and layout,
[`CLAUDE.md`](../CLAUDE.md) for the mechanics that only show up across several
scripts, [`PORTING.md`](../PORTING.md) for a new cluster, the setup's own
[`README.md`](../MITgcm_c69m/mysetups/DINO_1deg/README.md) for DINO's grid and
build/submit pairings. Workflows that have actually run are written up in the
project notes, which live in the companion `impacts-notes` repository.
