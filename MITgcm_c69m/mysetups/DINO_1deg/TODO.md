# TODO — DINO_1deg

- [ ] **Rerun the kappa_v ensemble with the ADEXCH-fixed build** (added
  2026-08-31). The 2026-08-28/29 ensemble (reference 30995 + members
  31003–31009) was run before the `code_tap/stubs_tap_adj.F` override, so its
  `ADJ*` dumps carry the tile-edge/periodic-seam artifact. Only the dumps need
  refreshing — `fc` and `adxx_*` from those runs are unaffected (validated
  bitwise, run 31022 vs 30994). Same recipe as before: `submit_tapAdj.sh` with
  `IMPACTS_TEST_CASE=kappa_v_ensemble/M<n>` per member, plain 5-yr defaults
  for the reference. The current `build_tapAdj/` (Tapenade-native hooks incl. the
  `ADJetan` hook, validated bitwise: 31032 ≡ 31022 ≡ 31023 ≡ 31024) is the
  right build for this — and it now also produces `ADJetan`.
  Analysis suite: `analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/`.

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
