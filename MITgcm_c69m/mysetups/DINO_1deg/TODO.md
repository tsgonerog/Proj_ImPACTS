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

- [ ] **Retry the four blown ensemble members (M1/M4/M5/M7) with adjViscBoost**
  (added 2026-08-31). Not possible before: the boost was silently inert under
  Tapenade until the `TAP_INADMODE_*` hooks (first working boost: run 31025 vs
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
  recomputation runs *after* `TAP_INADMODE_SET_B` has boosted the viscosities;
  split-mode tapes were taken in the forward sweep at forward viscosities, so
  the boost only reaches what the `_BWD` code reads live. The list was
  removed from `build_tapAdj_adjViscBoost.sh` again (run token
  `tapAdj_ckpAll_adjViscBoost`); 31056 stays on scratch as the record, report in
  `analyses/DINO_1deg/03_adjoint/07_tapenade_profiling/compare_30d_adjViscBoost_run31025_vs_nocheckpoint_run31056.md`.
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
  live in `code_tap/tap_inadmode.F`, and the four ASTE-derived shadows live
  in `code_tap/variants/adjViscBoost/` under their real names as a second
  `-mods` directory (`-mods="../code_tap/variants/adjViscBoost ../code_tap"`,
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
