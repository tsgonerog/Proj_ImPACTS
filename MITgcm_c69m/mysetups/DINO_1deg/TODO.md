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
