# TODO — DINO_1deg

- [ ] **Rerun the kappa_v ensemble with the ADEXCH-fixed build** (added
  2026-08-31). The 2026-08-28/29 ensemble (reference 30995 + members
  31003–31009) was run before the `code_tap/stubs_tap_adj.F` override, so its
  `ADJ*` dumps carry the tile-edge/periodic-seam artifact. Only the dumps need
  refreshing — `fc` and `adxx_*` from those runs are unaffected (validated
  bitwise, run 31022 vs 30994). Same recipe as before: `submit_tapAdj.sh` with
  `IMPACTS_TEST_CASE=kappa_v_ensemble/M<n>` per member, plain 5-yr defaults
  for the reference. Analysis suite:
  `analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/`.

- [ ] **Rebuild `build_tapAdj_adjViscBoost/` (and `build_tapAdj_rawTapenade/`
  if still wanted) so they pick up the ADEXCH fix.** Only `build_tapAdj/` was
  rebuilt on 2026-08-31; the sibling build directories still hold pre-fix
  binaries, so submitting `submit_tapAdj_adjViscBoost.sh` today would run
  without the implemented `ADEXCH_*` routines. Rebuild in the order you want
  `code_tap/` left staged (see CLAUDE.md on symlinked build directories).
