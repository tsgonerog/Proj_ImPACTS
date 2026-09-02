# TODO — DINO_1deg

- [x] ~~Rerun the kappa_v ensemble with the ADEXCH-fixed build~~ (added
  2026-08-31, **done 2026-09-01**). Reference 31039 + members 31040–31046,
  fresh `build_tapAdj/` from `main`, member pickups repointed per
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

- [ ] **Decide whether `build_tapAdj_nocheckpoint.sh` becomes the default
  adjoint** (added 2026-09-01 on branch `tapenade-profiling`, merged into `main` 2026-09-02). Its 30-day run
  31054 is bitwise identical to the plain build's 31052 (`fc`, 32 `adxx_*`,
  73 `ADJ*`) and 1.5× faster (8:47 vs 13:13); at 5 years (31055 vs 31039)
  it is again bitwise identical (fc, 32 `adxx_*`, 4 393 `ADJ*`) in 9:35:58
  against 14:05:45 (1.47×, 4.5 h saved). If adopted: fold the `-tap_extra` list into
  `build_tapAdj.sh` (and `build_tapAdj_adjViscBoost.sh` — the list is not
  specific to the `_OG` staging), retire the `_nocheckpoint` pair, and
  re-validate the adjViscBoost pairing once (31025 vs a tuned rerun). Port to
  SOMA needs its own profile (`mods_profile/` is setup-agnostic; drop `-mpi`).

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
