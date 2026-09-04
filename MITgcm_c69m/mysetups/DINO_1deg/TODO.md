# TODO — DINO_1deg

- [x] ~~Rerun the kappa_v ensemble with the ADEXCH-fixed build~~ (added
  2026-08-31, **done 2026-09-01**). Reference 31039 + members 31040–31046,
  fresh `build_tapAdj/` (renamed `build_tapAdj_ckpAll/` on 2026-09-02) from `main`, member pickups repointed per
  `notes/references/slurm_job_chaining/` §2.2. Validated per run against the
  originals (30995, 31003–31009): `fc` + all 32 `adxx_*` bitwise identical;
  `ADJ*` differences seam-confined (0 cells outside the mask in all 4,026
  dump pairs/run) — and only for the 7 horizontal-stencil fields, the 4
  local-operator fields (`ADJdiffkr`, `ADJqnet`, `ADJqsw`, `ADJempmr`) being
  bit-identical; `ADJetan` new, 367 dumps/run, finite except M4 beyond its
  documented overflow lead. Analysis suite re-executed against the new runs;
  the only moved conclusion number is M4's departure lead 0.72 → 0.70 yr
  (52 → 50/366 usable dumps). Old runs cleared for scratch deletion.

- [x] ~~Rerun the kappa_v ensemble with the `-nocheckpoint` build and compare~~
  (added and **done 2026-09-02/03**). Jobs 31060–31067 (REF + M1–M7; same
  pickups and namelists; submitted through temporary copies of
  `submit_tapAdj_nocheckpoint.sh` with the member pickup repointed, see
  `notes/references/slurm_job_chaining/` §2.2). Every pair **bitwise
  identical** to 31039–31046 (`fc`, 32 `adxx_*`, 4 393 `ADJ*`, `%MON`), the
  four blow-ups included; wall time 114.6 h → 76.8 h over the eight runs
  (1.45–1.65× per run, 1.54× on the reverse sweep, forward sweep unchanged).
  The executable rebuilt on 2026-09-02 also reproduces 31055 bitwise. Report
  and script in `analyses/DINO_1deg/adjoint/tapenade_profiling/`; the
  ensemble analysis keeps reading 31039–31046 (the sets are interchangeable).

- [x] ~~**Scratch layout: separate runs from analysis, executables and logs**~~
  (added and **done 2026-09-03**). `/scratch2/<user>/DINO_1deg_outputs/` was a
  flat `{frd,tapAdj}/` pair with `kappa_v_ensemble_analysis/` and
  `executables_preserved/` sitting among the run directories. It is now
  `runs/{forward,adjoint}/<campaign>/`, `analysis/<campaign>/`, `executables/`
  and `logs/`, with a `README.md` on scratch giving the campaign map. The five
  DINO submit scripts write to `runs/forward/` or `runs/adjoint/` directly, so
  **a new run lands unfiled at that level** and is moved into a campaign when
  it joins one — filing a run means updating the notebook that reads it. Run
  directory *names* are unchanged, so the `build_info.txt` `run_token` contract
  still holds and the job ID is still the durable key. All six pickup symlink
  targets were re-verified to resolve. Also pruned: `STDOUT.0001`–`0026` from
  every run (20.6 GB; only rank 0 writes `%MON`, the rest are `cg2d:` traces
  with no ERROR or WARNING anywhere) — moved to
  `/scratch2/<user>/_trash_20260903/`, not deleted.

- [ ] **Retry the four blown ensemble members (M1/M4/M5/M7) with adjViscBoost**
  (added 2026-08-31). Not possible before: the boost was silently inert under
  Tapenade until the 2026-08-31 mode-switch hooks, now `AUTODIFF_INADMODE_SET/UNSET`
  (first working boost: run 31025 vs
  31026 — `fc` bit-identical, adjoints damped). Pair
  `build_tapAdj_adjViscBoost.sh` with `submit_tapAdj_adjViscBoost.sh` and the
  member test case.

- [x] ~~Rebuild `build_tapAdj_adjViscBoost/` (and `build_tapAdj_rawTapenade/`
  if still wanted) so they pick up the ADEXCH fix.~~ Done 2026-08-31 in the
  hook redesign: `build_tapAdj_adjViscBoost/` was rebuilt with the
  `TAP_*` hooks (validated end to end, run 31025) and
  `build_tapAdj_rawTapenade.sh` was retired — raw Tapenade output *is* the
  working configuration now, so DINO has no control build to keep current.
  (Its leftover `build_tapAdj_rawTapenade/` directory was deleted 2026-09-02.)

- [x] ~~**Decide whether `build_tapAdj_nocheckpoint.sh` becomes the default
  adjoint**~~ (added 2026-09-01 on branch `tapenade-profiling`, merged into
  `main` 2026-09-02; **decided and done 2026-09-02**). Its 30-day run 31054 is
  bitwise identical to the plain build's 31052 (`fc`, 32 `adxx_*`, 73 `ADJ*`)
  and 1.5× faster (8:47 vs 13:13); at 5 years (31055 vs 31039) it is again
  bitwise identical (fc, 32 `adxx_*`, 4 393 `ADJ*`) in 9:35:58 against
  14:05:45 (1.47×, 4.5 h saved). What was done: `build_tapAdj.sh` /
  `submit_tapAdj.sh` are now symlinks to the `_nocheckpoint` pair (kept under
  its explicit name rather than retired, so every report and run name stays
  true); the plain pair was renamed `build_tapAdj_ckpAll.sh` /
  `submit_tapAdj_ckpAll.sh` (build directory `build_tapAdj_ckpAll/`); the list
  was tried in `build_tapAdj_adjViscBoost.sh` and reverted the same day (next
  item); every build script writes
  `build_info.txt` and the submit scripts name run directories from its
  `run_token`; all adjoint run directories on scratch were renamed to carry
  the build token. **Still open below: the SOMA port.**

- [x] ~~**adjViscBoost revalidation after the list fold-in**~~ (added and
  **done 2026-09-02 — and it failed, informatively**). Job 31056
  (`DINO_1deg_tapAdj_nocheckpoint_adjViscBoost_30d_from_rest_viscRef_run31056`,
  boost + the list, 8:48) vs 31025 (boost, every call checkpointed, 13:19):
  `fc` and all 441 `%MON` lines byte-identical, but all 66 `ADJ*` dumps and
  all 8 real `adxx_*` gradients differ at order one (RMS ratio 0.3–0.9) —
  where the plain pair is bitwise identical under the same list. Joint-mode
  recomputation runs *after* the mode-switch adjoint (then `TAP_INADMODE_SET_B`,
  now `AUTODIFF_INADMODE_SET_B`) has boosted the viscosities;
  split-mode tapes were taken in the forward sweep at forward viscosities, so
  the boost only reaches what the `_BWD` code reads live. The list was
  removed from `build_tapAdj_adjViscBoost.sh` again (run token
  `tapAdj_ckpAll_adjViscBoost`); 31056 stays on scratch as the record, report in
  `analyses/DINO_1deg/adjoint/tapenade_profiling/compare_30d_adjViscBoost_run31025_vs_nocheckpoint_run31056.md`.
  A faster boosted adjoint would need the boost applied to the taped
  intermediates too (i.e. boosting the *forward* sweep's recorded viscosities,
  which changes the forward trajectory) or a list restricted to routines whose
  taped values do not depend on the boosted parameters — a study, not a flag.

- [ ] **SOMA `-nocheckpoint` port needs its own profile** (added 2026-09-02).
  `mods_profile/` is setup-agnostic; a SOMA profiling build is the DINO one
  without `-mpi`. Until then SOMA's `build_tapAdj.sh` is a real script that
  checkpoints every call, so the bare name means different things per setup.

- [ ] **More binomial snapshots for the 5-year adjoint — only with more
  nodes, and for a small gain** (added 2026-09-01, corrected the same day).
  `C$AD BINOMIAL-CKP nTimeSteps+1 98 1` re-runs each step up to three times at
  87 841 steps; 418 snapshots would bring that to two. But 98 is a hard cap in
  the vendored `pkg/tapenade/adBinomial.c` (`nbSnap > 98` fails in
  `adBinomial_init`), so going higher needs a `-mods` shadow of that file with
  larger arrays; a `MAIN_DO_LOOP` snapshot is 8.98 MB per process (107
  arrays), so 418 of them are 3.8 GB per rank, ~109 GB for 27 ranks — three
  nodes, not one; and the binomial re-runs are only 17 % of the 5-year wall
  time (primal step 0.034 s vs 0.48 s per adjoint turn), so the whole exercise
  saves about 47 min of 14 h. It also changes the reverse schedule of the whole
  run and can only be validated at full length. Details under "Other levers" in
  `tools/tapenade_profiling/README.md`.

- [x] ~~**Retire the copy-staged source variants in `code/` and `code_tap/`**~~
  (added and **done 2026-09-02**, branch `code_tap-variants-cleanup`). The
  `_OG` / `_aste_90x150x60` / `_adapted_frm_aste_90x150x60` / `_mpi` /
  `_serial` siblings, and the bare files the build scripts regenerated from
  them, are gone (git history keeps them): `SIZE.h` is the one decomposition,
  the plain builds compile the vendored `pkg/autodiff` files (the `_OG`
  copies were byte-identical to them), the `TAP_INADMODE_*_B/_D` wrappers
  live in `code_tap/tap_inadmode.F` (moved into `code_tap/dummy_tap.F` by the
  next entry), and the four ASTE-derived shadows live
  in `code_tap/variants/adjointViscosity/` under their real names as a second
  `-mods` directory (`-mods="../code_tap/variants/adjointViscosity ../code_tap"`,
  asserted after `make`). Also removed: the debug-print `ini_procs.F` shadow
  (both copies), `code/pc`, the ASTE CVS header in `packages.conf`, SOMA's
  unused `SIZE.h_mpi`/`_serial`, and the staged-variants clause of
  `tools/pre_push_check.sh` — a build now leaves `git status` clean.
  Validation: all five builds rebuilt; against a pre-change snapshot their
  generated `.f` differ only in the files the change touches (the wrapper
  move, `ini_procs`, the build stamp). Run 31069 (default build, 30 d from
  the 180-yr pickup) is bitwise identical to 31054 — `fc`, 32 `adxx_*`,
  73 `ADJ*`, 441 `%MON` lines, 8:45 vs 8:47 — and run 31070 (boost, 30 d
  from rest) to 31025 — `fc`, 32 `adxx_*`, 66 `ADJ*`, 441 `%MON`, 13:15 vs
  13:19; its 14 `ADJetan` files are new only because 31025 predates that
  hook. Reports: `comparison_vs_*.txt` in the two run directories.

- [x] ~~**Give the Tapenade hooks their upstream names and layout**~~ (added and
  **done 2026-09-02**, branch `tapenade-hooks-upstream-shape`). `TAP_DUMMY_IN_STEPPING`,
  `TAP_DUMMY_FOR_ETAN` and `TAP_INADMODE_SET/UNSET` are gone: the upstream hooks
  keep their names and gain the wider interface under `#ifdef ALLOW_TAPENADE`
  in shadows of their own `pkg/autodiff` files (`#else` = upstream), the
  `_B`/`_D` bodies fill the stubs upstream ships in `pkg/tapenade/dummy_tap.F`
  (a shadow that also carries the mode-switch wrappers), and `flow_tap_local`
  re-declares the hooks under their upstream names. Tapenade keeps the *last*
  declaration of an external, so the library now rides in through
  `code_tap/adjoint_tap_local` (a `-adof` file sourcing the stock options and
  appending `-ext ../code_tap/flow_tap_local`) instead of `-tap_extra`. Same in
  SOMA (dump hooks only). Validation: every adjoint build's generated code is
  token-identical to the previous layout's after the renames (the profiling
  build differs only in the routine-name strings its instrumentation embeds);
  run 31074 (default, 30 d from the 180-yr pickup) is bitwise identical to
  31069 — `fc`, 32 `adxx_*`, 73 `ADJ*`, 441 `%MON`, 8:45 — run 31075 (boost,
  30 d from rest) to 31070 — `fc`, 32 `adxx_*`, 73 `ADJ*`, 441 `%MON`, 14:14 —
  and SOMA run 31076 (5 d) to 31033 — `fc`, 32 `adxx_*`, 61 `ADJ*`, 390 `%MON`.
  One trap found on the way: `dummy_tap.F` must include `AD_CONFIG.h`, the only
  definition of `ALLOW_ADJOINT_RUN`; without it the adjoint was still bitwise
  correct but wrote no `ADJ*` files (runs 31071–31073, deleted) — every adjoint
  build script now asserts after `make` that the compiled `dummy_tap.f` carries
  the 10 dump calls. At 5 years (2026-09-03): run 31077 (default build, from the
  180-yr pickup) is bitwise identical to 31055 — `fc`, 32 `adxx_*`, 4 393
  `ADJ*`, 18 801 `%MON` lines — in 9:36:30 against 9:35:58. Merged to `main`
  2026-09-03 (rebased, fast-forward; `main` = ea6f75f); the pre-merge state —
  the last commit with the `TAP_*` names — is tag
  `archive/20260903_pre-hook-upstream-rename`.

- [x] ~~**Write the hook redesign up as a talk, and take the internal name out
  of it**~~ (added and **done 2026-09-04**).
  `notes/references/tapenade_hooks/upstream_slides/` is a 13-frame Beamer deck
  derived from the change note beside it, with its own Overleaf project
  (mapped in `project_url()` as
  `references/tapenade_hooks/upstream_slides`). Each of the twelve modified
  files appears as `code_tap/<file>` → the checkpoint69m file it shadows, the
  first path linked to its blob on GitHub. DINO-only, and deliberately without
  an evidence table or an open-questions frame — both were cut in review; §4
  and §5 of the change note still hold that material. One error the review
  caught and the note now records: the Tapenade path already writes `adxx_*`
  control gradients through `pkg/ctrl`'s active-file machinery, so it is only
  the `ADJ*` adjoint-state dumps that the hooks supply.
  In the same pass `code_tap/variants/adjViscBoost/` and
  `input_tap/variants/adjViscBoost/` became `…/variants/adjointViscosity/`
  (namelist `data.autodiff_adjointViscosity`), since `adjViscBoost` was an
  internal coinage appearing in a document for outside readers. **The build
  identity keeps the old tag on purpose** — `build_tapAdj_adjViscBoost.sh`,
  `build_tapAdj_adjViscBoost/`, `run_token=tapAdj_ckpAll_adjViscBoost` —
  because run directories are named from `run_token` and runs 31025, 31056,
  31070 and 31075 already carry it. The rule: the directory is
  `adjointViscosity`, the build and its runs are `adjViscBoost`.
  `build_tapAdj_adjViscBoost/` was rebuilt afterwards, since the rename left
  its four `-mods` symlinks dangling, and the rebuild was validated by run
  31090 (30 d from rest, the configuration of 31075): all 210 `ADJ*`/`adxx_*`
  files bitwise identical, `fc` = 3.99075406661494E-01 to every printed digit,
  all 441 `%MON` lines byte-identical, 27 `NORMAL END`, 13:50 against 14:14.
  The only file that differs is `build_info.txt`, which records the new
  `exe_md5`, commit and build time and is supposed to.
