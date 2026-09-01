# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

MITgcm adjoint-sensitivity experiments built with the **Tapenade** AD toolchain (`pkg/tapenade`) instead of TAF/OpenAD. It contains experiment configurations, build/SLURM scripts, and analysis notebooks — plus a **fully vendored MITgcm source tree** (byte-for-byte upstream since 2026-08-31). Model output is not here; it lives on cluster scratch.

`README.md` documents the science and the layout; each setup has its own `README.md` (grid, build/submit pairings, quirks); `analyses/README.md` indexes the notebooks; `PORTING.md` covers other clusters. This file covers the mechanics that only become clear from reading several scripts at once.

`./tools/overleaf_sync_selftest.sh` is the one real test in the repository — 40
assertions over `tools/overleaf_sync.sh`, run against a throwaway bare repo
standing in for Overleaf, so it needs no credential and never contacts
overleaf.com. It exists because `overleaf_sync.sh pull` deletes tracked files as
a normal step — and more so since `push --wip`, which sends the working tree and
so makes it routine for a pull to overwrite work that is in no commit. Takes an
optional direction argument; refuses to start on a dirty tree under the
direction it tests, and never commits or moves `HEAD`.

`./tools/pre_push_check.sh` is the other standing check: a read-only
pre-push sanity check covering the nbstrip filter, submit-script namelist churn,
build-script variant staging, stray images under `analyses/`, and notebook
scratch paths that no longer resolve. Exits non-zero only on real breakage. Run
it before concluding a tree is clean — `git status` alone does not distinguish a
change the user authored from one a build or submit script made.

There is no root build system, no linter, and no package manifest, and nothing that tests the Fortran or the notebooks — the two checks above cover tooling only. Fortran is built per-setup via `genmake2` + `make`; Python analysis happens in notebooks with no checked-in environment file (`numpy`, `xarray`, `xmitgcm`, `matplotlib`).

## Layout

- `MITgcm_c69m/` — checkpoint69m tree (`MITgcm/`) + setups under `mysetups/`
- `analyses/` — notebooks reading run output from `/scratch2/...`, split `DINO_1deg/` + `SOMA_1deg/` to match the setup names
- `00_archive/` — frozen reference copies, at tree level (`MITgcm_c69m/00_archive/`) and setup level (inside each of `DINO_1deg/` and `SOMA_1deg/`). **Every archive mirrors the path its contents came from**, so `00_archive/code_tap/X` means "X, which was or would be `code_tap/X`", and `MITgcm_c69m/00_archive/removed_from_MITgcm/pkg/tapenade/` holds what was pulled out of the vendored `MITgcm/pkg/tapenade/`. Each has its own `README.md` giving what/where-from/why-not-live per file — read that before assuming anything here is revivable. The tree-level archive is empty since 2026-08-31: its one resident, `pkg/tapenade/dummy_tap.F`, went back into the vendored tree when the hook redesign removed the symbol collision that had forced it out. Nothing here is live configuration; no build or submit script reads from it. Grep hits inside these directories are history, not current behaviour. The `00_` prefix exists to keep them sorted above `build*/` and `code*/` in a plain `ls`.

The primary configuration is `MITgcm_c69m/mysetups/DINO_1deg/` (DINO, 51 × 198 × 36 curvilinear). `MITgcm_c69m/mysetups/SOMA_1deg/` is the secondary.

**The checkpoint69f tree is no longer in this repository.** `MITgcm_c69f/` — the c69f source tree, the earlier DINO and `sr_soma` ports, and the `tutorial_*_with_adj` / `tutorial_global_oce_biogeo` test-bed setups — was removed on 2026-08-17 because work has moved entirely to c69m. It survives in full, working tree and history both, as its own repository `git@github.com:tsgonerog/Proj_ImPACTS_old.git` — clone that. On this machine the working clone was moved on 2026-08-21 to `/home/tshahriar/backups_and_resources/Proj_ImPACTS/02_20260817_Proj_ImPACTS_old_c69f_tree`. Go there rather than trying to reconstruct it; several things documented below (Tapenade profiling, the tutorial cross-checks against `code_ad`/`code_oad`) exist only in that copy.

**The vendored `MITgcm/` tree is byte-for-byte upstream since 2026-08-31** (see the next section) — but treat it as read-only: everything project-specific belongs in the setups' `-mods` directories or `tools/`, never as edits inside `MITgcm/`.

### How the vendored tree deviates — none since 2026-08-31

A reference copy of the c69m tree sits outside the repo at `~/tools_and_software/MITgcm_collections/MITgcm_c69m/MITgcm/`. **Since 2026-08-31 the deviation set is empty — the vendored tree is byte-for-byte upstream.** The hook redesign (see "The ADJ* dump hook" below) removed both former deviations: the added `tools/genmake2_override_forward_step_b` was deleted when SOMA converted to the Tapenade-native hooks (no build post-edits generated code any more), and the removed `pkg/tapenade/dummy_tap.F` was restored verbatim once the hooks' `TAP_*` renaming eliminated the symbol collision that had forced it out (its four no-op stubs now compile as dead code in both setups).

Everything this project supplies is kept *outside* the vendored tree on purpose — the setups' `-mods` directories shadow sources at build time, the Perlmutter optfile lives in `tools/optfile_templates/` rather than `MITgcm/tools/build_options/`, and `flow_tap_local` rides in as a `-tap_extra` flag. Re-verify with the commands below rather than trusting this statement; any output from any of the three checks now means an unintended deviation.

### Building writes into the source tree

`genmake2` expands ~210 type-specialised sources from `.template` files **in place, under `MITgcm/`** — not into the build directory — as its first step, before configuring anything (`tools/genmake2:2374` for `eesupp/src`, `:2391` for `pkg/exch2` + `pkg/regrid`, `:2571` for `pkg/mnc`). Each is one `sed 's/RX/RL/g' exch_xy_rx.template > exch_xy_rl.F` per type, per `eesupp/src/Makefile`.

Consequences:

- **A built tree is not a pristine tree.** `eesupp/src/`, `pkg/exch2/`, `pkg/regrid/`, `pkg/mnc/` gain `*_r4`/`*_r8`/`*_rl`/`*_rs` files (~2.1 MB) the moment you first build.
- **They never reach git.** All 210 are ignored by MITgcm's *own* upstream `.gitignore`, which lists them because they are build products. A fresh clone has none; the first build creates them. Nothing to clean up, and deleting them only means `make` regenerates them byte-identically.
- **They make a naive `diff -qr` useless** — they drown the two real deviations in ~210 "Only in" lines. Filtering by extension does not work either: it hides `dummy_tap.F` and leaks `pkg/mnc/MNC_ID_HEADER.h`. The reliable filter is `git check-ignore`, since every build product is covered by MITgcm's own `.gitignore`.

Run from the repo root, and re-verify the table above rather than trusting it:

```bash
GT=~/tools_and_software/MITgcm_collections/MITgcm_c69m/MITgcm

# 1. modified upstream files — MUST be empty
diff -qr "$GT/" MITgcm_c69m/MITgcm/ | grep '^Files '

# 2. removed from the tree
diff -qr "$GT/" MITgcm_c69m/MITgcm/ | grep "^Only in $GT"

# 3. added, excluding build products
diff -qr "$GT/" MITgcm_c69m/MITgcm/ \
  | sed -n 's|^Only in \(MITgcm_c69m[^:]*\): |\1/|p' \
  | xargs -r -n1 sh -c 'git check-ignore -q "$0" || echo "$0"'
```

Any output from (1) means someone edited an upstream source; output from (2) or (3) means a file was removed from or added to the tree — nothing here is supposed to do either any more.

## Machines

`tools/machine_env.sh` is the single place cluster differences live; `PORTING.md`
is the walkthrough. Two blockers are worth knowing before assuming a new machine
will work: **Tapenade is not in this repository** (`genmake2 -tap` calls a
`tapenade` binary on `$PATH`, a Java tool installed out-of-tree), and
`input_binaries/` is untracked — DINO's 179 MB of `dino_*.bin` is produced
outside this repo and nothing regenerates it. `impacts_check_env` warns about
both plus a missing `NERSC_ACCOUNT`.

The 200-year spin-up's `-t 240:00:00` exceeds every Perlmutter QOS and would need
a pickup/restart chain; that is not automated.

## Build

Each setup builds itself; scripts resolve `MITGCM_ROOT` relative to their own location, so they can be invoked from anywhere but expect to be *run from the setup directory* (they use relative paths like `code_tap/`).

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
./build_frd.sh                   # -> build_frd/mitgcmuv
./build_tapAdj.sh                # -> build_tapAdj/mitgcmuv_tap_adj
```

Both setups now name scripts action-first: `build_frd.sh`, `build_tapAdj.sh`, `build_tapAdj_adjViscBoost.sh` (DINO only), and `submit_*` counterparts (the `rawTapenade` control builds are retired in both setups — raw Tapenade output *is* the working configuration). Optfiles come from `tools/machine_env.sh`, so nothing needs exporting. Every build script does the same five steps: stage variant files, `make CLEAN`, run **stock** `genmake2` with `-tap -adof=<root>/tools/adjoint_options/adjoint_tap -mods=../code_tap -tap_extra "-ext ../code_tap/flow_tap_local"`, `make depend`, `make -j 8 tap_adj`, then assert every generated hook call's argument count (`check_gen_call`).

**Parallelism is a property of the setup, not a flag you pass.** Only the build scripts that exist are usable: DINO is MPI-only throughout; SOMA's adjoint is serial-only while its forward model (`build_frd.sh`/`submit_frd.sh`, restored 2026-08-31) is MPI over 4 ranks (`code/SIZE.h`, `nPx=nPy=2`). Both `SIZE.h` variants are nonetheless present in most `code_tap/` directories, so finding `SIZE.h_serial` in the c69m DINO setup does not mean a serial adjoint build is wired up there — no script stages it and no submit script expects it.

Build directories (`build*/`) are gitignored and fully reproducible. They are **not relocatable**: `genmake2` bakes the setup's absolute path into the generated `Makefile` (~23 references), so renaming or moving a setup directory invalidates any build inside it. Re-run the build script rather than trying to patch the `Makefile`.

### Variant staging — the most important gotcha

Build scripts **overwrite tracked files by copying variant siblings over them** before configuring, e.g.:

```
code_tap/SIZE.h_mpi                  -> code_tap/SIZE.h
code_tap/the_model_main.F_OG         -> code_tap/the_model_main.F
code_tap/AUTODIFF_PARAMS.h_OG        -> code_tap/AUTODIFF_PARAMS.h
code_tap/autodiff_readparms.F_OG     -> code_tap/autodiff_readparms.F
```

Both sides are tracked in git. So:

- **Edit the suffixed variant, never the bare destination file** — `SIZE.h`, `the_model_main.F`, `AUTODIFF_PARAMS.h`, `autodiff_readparms.F`, `autodiff_inadmode_set_ad.F` are all regenerated and your edits will vanish on the next build.
- Running any build script dirties the working tree even when nothing was authored. Check `git diff` before assuming a change is yours.

Suffix meanings: `_mpi` / `_serial` (parallelism), `_OG` (original) vs `_aste_90x150x60` / `_adapted_frm_aste_90x150x60` (adapted from the ASTE regional setup — this is what the `adjViscBoost` variant selects), `_ForTapProfile` (Tapenade profiling build).

### Build directories symlink back into `code_tap/`

`genmake2` symlinks most staged sources into the build directory
(`build_x/AUTODIFF_PARAMS.h -> ../code_tap/AUTODIFF_PARAMS.h`) rather than copying
them. Only files written into the build directory itself — Tapenade's generated
`*_b.f` — are real files.
**Building a second variant re-stages `code_tap/` and silently repoints
every earlier build's symlinks.** After building `adjViscBoost` and then the plain
`build_tapAdj.sh`, the adjViscBoost build directory's headers resolve to the `_OG`
variants; running `make` there would recompile it as a plain build.

The already-compiled `.o` and generated `.f` files are unaffected — those are real
files frozen at compile time, and they are the reliable evidence of what a build
actually used. To check which variant a build compiled against, diff its generated
`.f` (e.g. `autodiff_readparms.f`), not its symlinked `.h`.

Practical consequence: **build variants in the order you want `code_tap/` left in**,
and never `make` in an older build directory after building a different variant —
re-run its build script instead.

### The ADJ* dump hook — Tapenade-native in both setups

The `ADJ*` sensitivity dumps exist because TAF's `.flow` directives (`ADNAME`/`REQUIRED`) can force a hand-written adjoint routine into the reverse sweep even though the hook `DUMMY_IN_STEPPING(myTime,myIter,myThid)` carries no active data. Tapenade has no such directive — its `-ext` library is purely data-flow driven, so a passive external is simply dropped from the backward sweep. Both setups bridge that gap the same way since 2026-08-31 (DINO first, SOMA later the same day):

**DINO (since the 2026-08-31 redesign): Tapenade generates the hook calls itself.** The pattern covers **four** TAF hooks — the `ADJ*` dump (`DUMMY_IN_STEPPING`), the `ADJetan` dump (`DUMMY_FOR_ETAN`, a separate hook in `INTEGR_CONTINUITY` because the free-surface adjoint is half a time step out of phase with the rest) and the two adjoint-mode switches (`AUTODIFF_INADMODE_SET`/`UNSET`, whose TAF-named adjoints apply/revert the `inAd*` adjViscBoost parameters at the start/end of every backward step; they were dead code under Tapenade before this, so adjViscBoost never actually boosted). The pieces in `code_tap/`, wired by `build_tapAdj.sh`/`build_tapAdj_adjViscBoost.sh` with **stock** `genmake2`:

- `forward_step.F` — a `-mods` shadow that, under `#ifdef ALLOW_TAPENADE`, calls `TAP_DUMMY_IN_STEPPING(theta, salt, uVel, vVel, wVel, fu, fv, Qnet, Qsw, EmPmR, diffKr, myTime, myIter, myThid)` in the `ALLOW_AUTODIFF_MONITOR` block, `TAP_INADMODE_UNSET(uVel, …)` at step start and `TAP_INADMODE_SET(uVel, …)` at step end (the stock TAF hooks otherwise). `uVel` in the mode-switch hooks is only the activity vehicle that forces `_B` generation.
- `integr_continuity.F` — a `-mods` shadow whose only change is calling `TAP_DUMMY_FOR_ETAN(etaN, myTime, myIter, myThid)` instead of `DUMMY_FOR_ETAN` under `#ifdef ALLOW_TAPENADE`.
- `tap_dummy_in_stepping.F`, `tap_dummy_for_etan.F`, `tap_inadmode.F` — the forward no-op bodies. Must never appear in an `*_ad_diff.list`.
- `flow_tap_local` — Tapenade external library declaring each hook's field args active (read-then-written; 11 fields for the stepping dump, `etaN` for the etaN dump, `uVel` for the mode switches), passed via `-tap_extra "-ext ../code_tap/flow_tap_local"`. Because of it, Tapenade emits `CALL TAP_DUMMY_IN_STEPPING_B(theta, thetab, …)` in `forward_step_b.f` and `CALL TAP_DUMMY_FOR_ETAN_B(etaN, etaNb, …)` in `integr_continuity_b.f`, each at the reverse-sweep mirror of its forward call.
- `addummy_in_stepping.F` — hand-written `TAP_DUMMY_IN_STEPPING_B`: ADEXCH-folds the adjoint arguments (the `stubs_tap_adj.F` implementations) and dumps them as `ADJ*`. The adjoint state arrives as arguments, so there is no `adcommon.h` mirror to keep in sync (the old one is archived in `00_archive/code_tap/`). **Layout (since 2026-08-31, second pass): the upstream file byte-for-byte with the `TAP_*` block appended under `#ifdef ALLOW_TAPENADE`** — the TAF `ADDUMMY_IN_STEPPING` above it still compiles under Tapenade, as dead code, exactly as in an upstream Tapenade verification build. Every shadow in `code_tap/` follows this additive convention (upstream content untouched; changes only as guarded call-site switches or appended blocks), and the option headers are the upstream c69m headers with only `#define`/`#undef` toggles changed — so `vimdiff` against the counterpart shows exactly the setup's additions.
- `addummy_for_etan.F` — same layout for `ADJetan`: upstream byte-for-byte + appended hand-written `TAP_DUMMY_FOR_ETAN_B` that dumps `etaNb` (no ADEXCH fold, like upstream) using the separate `dumpAdRecEt` record counter.
- `autodiff_inadmode_set_ad.F` and `autodiff_inadmode_unset_ad.F` (staged variants, `_OG` vs `_adapted_frm_aste_90x150x60`) — the TAF-named mode-switch bodies plus thin `TAP_INADMODE_SET_B`/`UNSET_B` wrappers that call them (and `_D` no-ops for TLM link safety). The `unset` pair is new with the hooks: ASTE's restore side (`outAd*`) was never ported because the whole mechanism was unreachable.

Each `_B` signature is fixed (dump hook: 25 arguments = 11 value/adjoint pairs + 3 passives; etaN dump and mode-switch hooks: 5 each) and **must match what Tapenade generates** — F77 would silently misalign a mismatch, so both build scripts count each generated call's arguments after `make` (`check_gen_call`) and fail loudly on a mismatch. Changing a hook's field set therefore means touching the shadow call, `flow_tap_local`, both `_B`/`_D` bodies *and* the assertion. The `rawTapenade` control builds are retired in both setups — raw Tapenade output *is* the working configuration now, and no generated file is post-edited.

**SOMA (converted 2026-08-31, same day): the same mechanism, dump hooks only.** SOMA carries `forward_step.F` (shadow with the `TAP_DUMMY_IN_STEPPING` call — its inadmode call sites stay stock, since SOMA has no adjViscBoost machinery to switch), `integr_continuity.F` (the `TAP_DUMMY_FOR_ETAN`/`ADJetan` hook), `tap_dummy_in_stepping.F`, `tap_dummy_for_etan.F`, `addummy_in_stepping.F`, `addummy_for_etan.F`, and a `flow_tap_local` with the two dump stanzas. It follows the same additive layout as DINO (the shared-content files are byte-identical between the setups), and its `the_main_loop.F` was rebased from a c69f-era copy onto c69m upstream in the process — which restored upstream's `COST_DRIVER` call, a runtime no-op here (it only drives OBCS/ECCO cost terms, both absent). The conversion **fixed SOMA's c69m adjoint, which had never actually run**: the old frozen `forward_step_b.f_modified` had gone stale against the evolving tree (274 diff lines vs freshly generated code), misaligning Tapenade's tape enough to crash every adjoint at the backward-sweep start (`integer divide by zero` in `pkg/longstep` — runs 31029/31030). The hook build's run 31031 is the first successful c69m SOMA adjoint: `fc` bitwise-identical to the crashed baseline's forward value, full `ADJ*`/`adxx_*` output, finite. With the conversion, `genmake2_override_forward_step_b` and the frozen file were deleted and `pkg/tapenade/dummy_tap.F` restored — the vendored tree is pristine.

`use_TapProfile` at the top of each build script selects the mode (`NO` / `YES` / `AFTER`) and picks both the `genmake2` variant and the matching `the_model_main.F`. **Only the `NO` mode works** (it resolves to stock `genmake2` in both setups now): `MITgcm_c69m/MITgcm/tools/` has no `patched_*TapProfile_genmake2`, and neither setup's `code_tap/` has `the_model_main.F_ForTapProfile` any more (both are in their `00_archive/code_tap/`). Setting `use_TapProfile` to `YES` or `AFTER` fails.

**That switch is the wrong shape for c69m and should not be repaired as-is.** It selects among three patched `genmake2` copies, which is how c69f had to do it. c69m's `genmake2` takes `-tap_extra`, passed straight through to the Tapenade command line (`genmake2:1568`, expanded by the rule at `:3751`), so both profiling modes are now flags rather than files:

| Mode | c69m |
| --- | --- |
| profile the adjoint | `-tap_extra "-profile"`, plus a `pkg/tapenade/adProfile.c` symlink — c69m ships the source but does not expose it to the build |
| skip checkpointing on chosen routines | `-tap_extra '-nocheckpoint "…"'` — nothing else needed |

`tools/tapenade_profiling/` documents both, and carries the 64-routine `-nocheckpoint` list extracted from the c69f work plus the two c69f originals for reference. Those originals are full copies of the *c69f* `genmake2` (~200 lines adrift of c69m's) and must not be installed into `MITgcm/tools/`. `the_model_main.F_ForTapProfile` is still in `00_archive/code_tap/` and would have to be copied into `code_tap/` by hand.

## Run

SLURM batch scripts targeting the **`sverdrup`** cluster:

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
../../../tools/submit.sh submit_frd.sh        # forward, committed default
../../../tools/submit.sh submit_tapAdj.sh     # adjoint, committed default

# per-run overrides; these leave the working tree clean
IMPACTS_DURATION_DAYS=73200 ../../../tools/submit.sh submit_frd.sh   # 200 yr

./clean_slurm_logs.sh          # prompts, then deletes *.out/*.err in cwd only
```

A submit script: selects a namelist via `test_cases`; rewrites time-stepping parameters; stages a job-ID-stamped run directory under `/scratch2/<user>/<setup>_<mode>_runs/` (`_tapAdj_` or `_frd_`), copying `input_tap/` and symlinking the gitignored `input_binaries/` and `input_adj_binaries/`; symlinks any pickups; then runs the executable and writes `run_timing.txt`.

Things to know before editing or submitting one:

- **`-n` must match `SIZE.h`.** The MPI DINO adjoint requests 27 ranks because `SIZE.h_mpi` sets `nPx=3, nPy=9` over `sNx=17, sNy=22` tiles. Changing the decomposition means changing both.
- **Durations are written in days at the top of the script** (`simulation_duration_with_dT1800_days`, `monitorFreq_days`, `adjMonitorFreq_days`, `adjDumpFreq_days`; SOMA uses `endTime_days`). The names to patch are listed explicitly in a `time_params` array beside them. **Do not restore the old `compgen -v | grep '_days$'` auto-detection** — `compgen -v` also enumerates *exported environment variables*, and since sbatch forwards the environment by default, any `*_days` variable in the submitting shell would silently become a namelist key.
- **Submitting a job no longer modifies the repo.** The `sed -i` runs *after* the namelist is staged and targets the copy in the run directory, so `git status` stays clean. This is a correctness fix, not just hygiene: the script body executes on the compute node when the job **starts**, not when you submit, so the old in-place `sed` was shared mutable state between every queued job — two jobs starting close together would each stage whichever value landed last while their run-directory names each claimed their own. It bit SOMA hardest, back when its five (now archived) per-duration scripts all patched the same `input_tap/data`. If a namelist diff ever appears after a run, something has regressed; `tools/pre_push_check.sh` watches for it.
- **Per-run overrides go in the environment, not in an edit.** Every live submit script in both setups reads `IMPACTS_TEST_CASE`, `IMPACTS_DURATION_DAYS`, `IMPACTS_MONITOR_FREQ_DAYS` and (adjoint only) `IMPACTS_ADJ_MONITOR_FREQ_DAYS` / `IMPACTS_ADJ_DUMP_FREQ_DAYS`, defaulting to the committed values, so `IMPACTS_DURATION_DAYS=73200 ../../../tools/submit.sh submit_frd.sh` runs 200 years without touching a tracked file. `IMPACTS_TEST_CASE` uses `${VAR-default}` rather than `${VAR:-default}` so that an explicit empty value selects the live `input*/data`. In DINO the duration patches `nTimeSteps` (dT 1800); in SOMA it patches `endTime` (dT 1200). SOMA joined this scheme on 2026-08-31 — its five pre-made per-duration scripts are archived in `SOMA_1deg/00_archive/scripts/`; a duration is now a submission, not a script. The committed defaults are the cheap regression configurations, not the production ones (SOMA's adjoint default, 5 d with 1-d frequencies, reproduces validated baseline run 31031).
- **`nIter0` is *not* one of the auto-patched parameters — the start iteration and the pickup are coupled by hand.** `nIter0` is baked into whichever `data_<tag>` the `test_cases` string selects (`from_rest` → `0`, `from50yrPk` → `878400`, `from70yrPk` → `1229760`, `from180yrPk` → `3162240`), while the pickup itself is a hardcoded `ln -s` line further down the same script. Changing `test_cases` to a different `from*Pk` tag without editing that symlink to the matching `pickup.<nIter0>.{data,meta}` gets you a run that cannot find its pickup. Changing the duration is safe; changing the starting point is not.
- **`adjViscBoost` is a build *and* a namelist variant, not just a build.** It runs the adjoint with larger viscosity/diffusivity than the forward (`viscFacInAd = 10.` vs `viscFacInFw = 1.`), intended to keep a long adjoint from blowing up. **Before the 2026-08-31 mode-switch hooks it was inert under Tapenade**: the only routine applying those parameters (`ADAUTODIFF_INADMODE_SET`) is TAF-named and was never called, so every earlier "adjViscBoost" configuration silently ran plain physics. The boost engages only in builds carrying the `TAP_INADMODE_*` hooks (see "The ADJ* dump hook" above). Validated 2026-08-31: with hooks + default parameters, run 31024 reproduces 31023 bitwise; with hooks + the adjViscBoost pairing, run 31025 vs plain 31026 (same from-rest config) keeps `fc` bit-identical (the boost never touches the forward trajectory) while every nonzero `adxx_*`/`ADJ*` differs and peak sensitivities are damped — the first functioning adjViscBoost run in this project. `submit_tapAdj_adjViscBoost.sh` points `build_dir` at `build_tapAdj_adjViscBoost/` and additionally does `rm data.autodiff` + `cp "$base_dir/input_tap/variants/adjViscBoost/data.autodiff_adjViscBoost" data.autodiff` in the staged run directory (a copy from `variants/`, not a `mv` of an already-staged file). Pairing the plain submit script with the adjViscBoost build (or the reverse) silently runs a mismatched configuration.
- **Scratch paths come from `$SCRATCH_ROOT`, not literals.** Every live build and submit script sources `tools/machine_env.sh`, which sets `SCRATCH_ROOT`, `MPI_LAUNCHER`, `MPI_OPTFILE`, `SERIAL_OPTFILE` and `SBATCH_EXTRA` per machine (sverdrup by default, perlmutter when `$NERSC_HOST` is set). Do not reintroduce a literal `/scratch2/...`; add a case block instead. The notification address is still a hardcoded `#SBATCH --mail-user` directive.
- **Submit with `tools/submit.sh <script>`, not `sbatch`.** Account, QOS, constraint and walltime cannot be `#SBATCH` directives without breaking the other machine, so the wrapper passes them on the command line where sbatch lets them override. On sverdrup `SBATCH_EXTRA` is empty, so it is `sbatch --export=ALL <script>` and plain `sbatch` still works. Extra arguments are placed **before** the script name, because sbatch's usage is `sbatch [OPTIONS] script [args]` and anything after the script name goes to the script instead — which is why `submit.sh <script> --test-only` used to submit a real job rather than dry-run it. `--export=ALL` is sbatch's default, made explicit because the jobs depend on it: `impacts_load_modules` is a no-op on sverdrup, so the Intel/MPI stack *and* the `IMPACTS_*` overrides both reach the compute node only through the inherited environment.
- **The optfiles are machine-authoritative, deliberately.** `~/.bashrc` on sverdrup exports `MPI_OPTFILE`; honouring it would silently build Perlmutter with the Intel sverdrup optfile, so `machine_env.sh` overwrites it. `IMPACTS_MPI_OPTFILE` is the explicit override.
- Namelist variants live in `input*/variants/<group>/` and are chosen by `test_cases` as `<group>/<tag>` (a bare `<tag>` still resolves to `variants/data_<tag>`; empty string = plain `input_tap/data`). A file is named for the MITgcm file it replaces, `<mitgcm-file>_<tag>`, and **every sibling sharing the tag is staged too** — so `scheme_tests/from_rest_viscRef_kppON` brings its `data.pkg` along. The run directory takes the tag's last component only, never the group. See the setup README for the vocabulary.
- SOMA has one submit script per mode (`submit_frd.sh` MPI ×4, `submit_tapAdj.sh` serial), like DINO; the `test_cases`/variants machinery is present but inert until an `input*/variants/` directory exists there.

### Where the output lands

Two different places, which matters when a run fails:

- **In the setup directory** (i.e. in the repo, untracked): `<job-name>.<job-id>.out` and `.err`. The scripts run under `set -x`, so the `.err` file is a full trace of the staging steps — this is where staging failures show up, not in the model output. `./clean_slurm_logs.sh` deletes these (prompts first, cwd only, non-recursive).
- **In scratch**: `/scratch2/<user>/<setup>_tapAdj_runs/<job-name>_<duration>d<suffix>_run<job-id>/`, holding `output_tap_adj.txt` (all model stdout/stderr), `run_timing.txt`, the staged namelists, and the `ADJ*` / monitor output the notebooks read. The `<suffix>` is `_$test_cases`, so the run directory name records which namelist variant was used — the only durable record of it, since `test_cases` lives in a script that gets edited between runs.

**Scratch run directories were renamed to match the setups on 2026-08-18.** The
old `DINO_MITgcm_v011526_{frd,tapAdj}_runs` trees are gone; everything now lives
under `/scratch2/<user>/DINO_1deg_{frd,tapAdj}_runs/`, with each run directory
named `DINO_1deg_<mode>[_srl]_<duration>_<start>_<settings>_run<jobid>` using the
same configuration tokens as the notebooks (`visc2x`, `viscD2x_Zref`, `viscRef`,
`viscGrid<v>`). **The job ID is the durable key** — settings tokens were derived
by reading each run's own staged `data` namelist, so if a name and a namelist
ever disagree, the namelist wins.

An earlier version of this file said not to "fix" the notebook paths because
they pointed at real directories carrying the old names. That is no longer
true: the directories were renamed and every path was rewritten with them.

Three runs referenced by notebooks no longer exist on scratch at all — 18238
(30 d), 18153 (`frd_defaultd`) and 24020 (`from50yPickup_afterProfile`). Those
references were already dead before the rename and were left as-is rather than
repointed at a different run. Everything else resolves; `00_archive/` submit
scripts also carry pickup paths that never matched a real directory.

`SOMA_1deg` scratch: the c69f-era runs remain under `/scratch2/<user>/v4_soma_tapAdj_runs/`; c69m runs (31029 onward, 2026-08-31) go to `/scratch2/<user>/SOMA_1deg_{frd,tapAdj}_runs/`. Since the 2026-08-31 workflow alignment the run directories follow DINO's convention (`SOMA_1deg_<mode>_<duration>[_<tag>]_run<jobid>`, job names `SOMA_1deg_frd`/`SOMA_1deg_tapAdj`, whole 360-day years as `<n>yr`); runs 31029–31031 predate it and keep their `pd_StP_srl_no-kpp-GM_*`/`test_*` names.

**Figures and animations are not in this repository.** Each notebook writes its
output into the scratch run directory it reads, under `figures/` and
`animations/`, deriving both from the `run_dir` variable it already defines. The
`analyses/**/*.{png,jpg,gif,html}` ignore rules exist only to catch a cell that
is re-run with a repo-local path.

## Forward vs adjoint configuration

The `code/` + `input/` pair is the forward model; `code_tap/` + `input_tap/` is the adjoint. They differ structurally, not just by a flag:

- `code_tap/packages.conf` drops `cd_code` and adds `tapenade` plus the `adjoint` pkg group (`autodiff, ctrl, cost, grdchk`).
- `input_tap/` adds `data.autodiff`, `data.cost`, `data.ctrl`, `data.grdchk`.
- **`input*/` holds only what MITgcm reads; alternatives live in `input*/variants/`, grouped by purpose.** A submit script resolves `test_cases` to `variants/<group>/data_<tag>` (a bare `<tag>` still resolves to `variants/data_<tag>`; empty `test_cases` means the live `input*/data`) and stages only that one, so a run directory carries no unused namelists. **It also stages every sibling `<mitgcm-file>_<tag>` beside the chosen namelist** — that is how `scheme_tests/from_rest_viscRef_kppON` gets `data.pkg` with `useKPP=.TRUE.` as well as its `data`. Before 2026-08-28 only the `data` half was staged, so that variant silently ran without KPP. The run directory is named after the tag alone, never the group. Anything placed directly in `input*/` is copied into *every* run. The staging uses `find -maxdepth 1 -type f` rather than a glob, because `cp dir/*` would hit `variants/` and abort under `set -e`.
- `code_tap/COST_OPTIONS.h` defines `ALLOW_COST_ATLANTIC_HEAT` and `ALLOW_COST_ATLANTIC_HEAT_DOMASS`.

The cost function `code_tap/cost_atlantic_heat.F` has its **section indices compiled in as `parameter` statements** — a zonal section (DINO: `isecbeg=1, isecend=51, jsec=127`) and a meridional one (`jsecbeg=1, jsecend=62, isec=30`) are both declared. Moving a section requires editing this file and rebuilding, not a namelist change; `mult_atl` in `data.cost` only scales the result. Indices are located with `analyses/DINO_1deg/00_grid_and_cost_sections.ipynb`. Because the values are compiled in, the authoritative record of what a past run measured is the `.f` file in that run's build directory, not the current source.

`kmaxdepth` is likewise compiled in, and per-setup: DINO uses 25, SOMA 21. Both live in the `ALLOW_COST_ATLANTIC_HEAT_DOMASS` branch, which is the active one in every setup that enables this cost function — the `#else` value of 14 inherited from `pkg/cost` is dead code here, so don't read it as a default.

Two more things about this cost that are easy to get wrong (verified 2026-08-30
while analysing the kappa_v ensemble; details and the validating proxy in
`analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/`):

- **fc is a terminal-30-day mean, not a run mean.** `pkg/cost` accumulates
  `cMean*` only over the final `lastinterval` seconds of the run, and the
  default (2,592,000 s = 30 d, `cost_readparms.F`) is not overridden in
  `data.cost`. Direct cost forcing therefore enters the adjoint only during
  the last month; everything at longer lead is adjoint dynamics.
- **fc depends on the domain decomposition.** `countV(k)` is computed per MPI
  tile (the `bi,bj` loop runs `i=1,sNx`), and DINO's 51-cell section spans 3
  tiles, so J sums three per-tile-normalised transports — ~3× a globally
  normalised index. Comparisons at fixed decomposition are fine (everything
  here is `nPx=3, nPy=9`), but rebuilding with a different decomposition
  changes the value of J itself, not just performance.

**KPP and GM/Redi are off in every adjoint run.** Both DINO and `SOMA_1deg` set `useKPP`/`useGMRedi` `.FALSE.` statically in `input_tap/data.pkg`, and their submit scripts carry the equivalent `sed -i` lines commented out. The `useKPPinAdMode`/`useGMRediInAdMode` flags in `data.autodiff` are therefore inert as currently configured. Check both the namelist and the submit script before concluding a package is active — the now-archived `sr_soma` setup did it the other way round, leaving the namelist `.TRUE.` and disabling the packages from the submit script instead.

**DINO's `code_tap/stubs_tap_adj.F` overrides the pkg/tapenade copy — and `ADJ*`
dumps written before job 31022 (2026-08-31) carry a tile-edge artifact.**
Upstream ships the five `ADEXCH_*` adjoint halo exchanges as no-op stubs
(printing "Called not yet defined"); the `ADJ*` dump path calls them to fold
tile-halo adjoint contributions into the owning interior cells before writing,
so every pre-fix dump keeps partial sums in the 1–2 cells straddling each
exchange seam: `i=17|18`, `34|35`, every `j` multiple of 22, and the channel's
zonal periodic seam (`i∈{1,2,50,51}`, `j≈13–44`), worst on U-grid fields
(shared C-grid face column). This was **dump-only**: the adjoint dynamics uses
its own correct path (`EXCH2_*_CUBE_AD` via the Tapenade-generated
`EXCH2_*_CUBE_B`), so `fc` and `adxx_*` were never affected — the fix
(implementing the stubs with those same `_AD` routines, via `-mods` same-name
shadowing, keeping the vendored tree pristine) was validated with run 31022 vs
30994: `fc` and all 33 `adxx_*` files bitwise identical, `ADJ*` differences
confined to the seams. When reading `ADJ*` from older runs (including 28486,
30995 and the kappa_v ensemble), mask ~2 cells around those seams. Do not
"clean up" the override into `MITgcm/pkg/tapenade/` — that would create a
modified-upstream deviation the verification procedure above flags. SOMA is
single-tile serial (no seams) and does not need the override.

## Verifying correctness

There are no unit tests. Four things stand in for them, and their status as of
2026-08-30 is:

**1. Forward reproducibility — verified.** A 10-year run from rest with
`from_rest_visc2x` reproduces the first 10 years of the 200-year production run
(28463) **bit-identically**: 161 `dynDiag` field comparisons, all of
`surfDiag`/`atmDiag`/`viscDiag`, 1334 monitor values across 134 variables, and
the AMOC series, every one at exactly zero difference. This is the cheap
regression test — rebuild, run 10 years, diff against 28463. It catches a
compiler or source change that alters the physics.

**2. Adjoint runs end to end — verified.** A 30-day adjoint from the 180-year
pickup produces `ADJ*` and `adxx*` output with sensitivity concentrated on the
cost section (peak `|adxx_theta|` at `i=2, j=127, k=26`, decaying away from it).
That is consistent with a correct adjoint but is not a proof.

**3. The finite-difference gradient check — NOT currently meaningful.**
`input_tap/data.grdchk` perturbs `xx_theta` at `iGloPos=4, jGloPos=8, kGloPos=1`
and compares against the adjoint. It fails by ~8 orders of magnitude, and **it
has always failed** — the May 2026 production run (28486) shows the same, with a
worse RMS ratio (8.0e+12 against 6.6e+08).

The cause is the check point, not the adjoint. `j=8` is near the southern
boundary; the cost section is at `j=127`. Sensitivity there is ~6e-10 against a
field maximum of ~3.9e-02. The cost change the adjoint predicts for
`grdchk_eps=1e-5` is 6e-15, while the perturbed runs differ from the base by
~9e-06 — a billion times larger. Both `FC1` and `FC2` land on the *same side* of
`FC`, which a real first derivative cannot produce. The check is dividing its own
noise by `2*eps` and reporting the result as a gradient.

**So the adjoint is not currently verified by anything in this repository.** To
make the check mean something, move the point into the sensitive region —
`iGloPos=2, jGloPos=127, kGloPos=26` — and raise `grdchk_eps` (1e-3) so the
response clears the noise floor. Until that is done, do not cite `grdchk` output
as evidence either way.

**4. The kappa_v ensemble's adjoint-vs-finite-difference comparison — executed,
and it fails as a validation for a physical reason.** The 2026-08-28/29 ensemble
(reference 30995 + members 31003–31009; analysed in
`analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/`) compared measured ΔJ
against the linear adjoint prediction: wrong sign for 4 of 7 members, none
within 30 %. The failure is dominated by nonlinearity of the 10-yr state
adjustment, so it neither confirms nor refutes the adjoint — the trust radius of
the raw gradient is simply below the factor-2 steps tested. The same analysis
did re-verify bit-reproducibility (30995 ≡ 28486 exactly) and found that four
member adjoints **blow up** (linearisation instability, non-monotonic in κ:
0.25×, 4×, 8×, 32× blow; 0.5×, 2×, 16× survive) — so a plain-build adjoint on a
perturbed background state is not guaranteed to stay finite over 5 years, which
is what `adjViscBoost` exists for (note the ensemble predates the mode-switch
hooks, when adjViscBoost was silently inert — no working boost had ever run). Adjoint correctness therefore still rests on
repairing the gradient check.

**`useGrdchk` differs by setup since 2026-08-28**: DINO's `input_tap/data.pkg`
now sets it `.FALSE.` (verified bit-identical `ADJ*`/`adxx*`; saves 8.2 h per
5-yr adjoint), SOMA still `.TRUE.`. Where it is on, it is not opt-in: every
adjoint job pays for the perturbed forward runs — the 30-day run above recorded
18,622 forward-step calls against the 1,440 the adjoint itself needs. If a SOMA
run is doing far more work than expected, check this flag first.

A further, historical check — the `tutorial_*_with_adj` setups reproducing stock
MITgcm tutorials through the Tapenade path, with `tutorial_global_oce_biogeo/`
holding `code_ad` / `code_oad` / `code_tap` side by side — lived in the c69f tree
and is now only in `Proj_ImPACTS_old`. There is no tutorial-level regression
check here.

## Reading MDS output

`adxx_*` and `xx_*` control files are **`float64`** (hence `ones_64b.bin`), while
the `ADJ*` diagnostic dumps follow `data.diagnostics` and are `float32`. Read the
`.meta` beside a file rather than assuming — guessing the precision silently
reshapes the array and produces plausible-looking garbage.

## Analyses

Notebooks read output directly from cluster scratch with `xmitgcm.open_mdsdataset(grid_dir='/scratch2/...', prefix=['ADJtheta', ...], read_grid=True, delta_t=1800)`, `geometry="curvilinear"` for DINO. Where raw tiled binaries are read instead, shapes are reconstructed from the same `sNx/sNy/OLx/OLy/Nr` values as `SIZE.h` — keep those in sync when the decomposition changes.

The tree mirrors the setup names: `analyses/DINO_1deg/` and `analyses/SOMA_1deg/`, with `02_forward/` and `03_adjoint/` under DINO, plus `reference_notebooks/` (collaborator originals) and `tools/`. Directories and notebooks are numbered in reading order and `00_archive/` holds superseded work. `analyses/README.md` is a per-notebook index saying which scratch run each one reads — that mapping is not recoverable from the file names alone, since several notebooks differ only by job ID.

**Paths are the thing to be careful with here.** Notebooks build `run_dir` by
concatenating adjacent string literals across separate lines, so a naive
search-and-replace on a full path silently rewrites only the fragment it matched
and leaves the rest stale. When run directories move, rewrite by *basename* as
well as by full path, then verify by reassembling the literals and checking each
path exists on disk. `code_tap/cost_atlantic_heat.F` also cites
`analyses/DINO_1deg/00_grid_and_cost_sections.ipynb` by name in a comment.

**Notebook outputs are stripped by a git `clean` filter, not by hand.**
`.gitattributes` points `*.ipynb` at the `nbstrip` filter, defined by
`analyses/tools/strip_animation_outputs.py --filter`. The working tree keeps its
outputs; the committed blob does not. Filters live in `.git/config`, which is
untracked, so **a fresh clone commits notebooks unstripped until
`./analyses/tools/install_git_filters.sh` is run** — check `git config --get
filter.nbstrip.clean` before concluding the filter is active. The default strips
only `to_jshtml` payloads over 1 MB and keeps static figures; `--all-outputs`
strips everything. The script keeps its original in-place mode for one-shot
passes, so `--filter` (stdin to stdout, touches no file) and the default mode
(rewrites files) are different things.

Because git stores the stripped copy, anything that rewrites a notebook in the
working tree (`checkout`, `stash`, `merge`, `reset --hard`) discards the local
outputs.

## Not tracked

`**/build*/` **except `build_options/`**, `**/.ipynb_checkpoints/`, and the `input_binaries/` + `input_adj_binaries/` directories for every DINO and SOMA setup. SOMA inputs regenerate with `input/gendata.py`; DINO's `dino_*.bin` files are produced outside this repository and must be staged into `input_binaries/` before a run.

The `!**/build_options/` negation is load-bearing: `**/build*/` was swallowing
`MITgcm/tools/build_options/`, so all 216 genmake2 optfiles were untracked — the
93 supported ones and the 123 under `unsupported/` — and a fresh clone could not
build on any machine. A negation works only because it un-excludes the directory
itself — git cannot re-include a file inside a directory that stays excluded.

`input_adj_binaries/` is small but not optional: it holds `ones_64b.bin`, the uniform weight file that *every* `xx_gentim2d_weight`/`xx_genarr3d_weight` entry in `data.ctrl` points at. Since it is untracked and the submit script only symlinks the directory contents, a fresh clone has no adjoint run until it is put back.
