# `kappa_v_ensemble/` — adjoint runs

Vertical-mixing perturbation ensemble, Part I of
[`notes/directions/nn_surrogate/`](../../../../../../notes/directions/nn_surrogate/). These seven
namelists are the **5-year adjoint**, year 2180 → 2185, each at its own vertical
diffusivity; the forward legs that produce their pickups live in
[`../../../input/variants/kappa_v_ensemble/`](../../../input/variants/kappa_v_ensemble/),
which carries the κ table.

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
IMPACTS_TEST_CASE=kappa_v_ensemble/M3 ../../../tools/submit.sh submit_tapAdj.sh
```

Each file is identical to `../data_from180yrPk_visc2x` apart from
`diffKrFile`, because the whole design rests on κ_v being the only difference
between a member and the reference. `nIter0=3162240` is year 2180 and
`nTimeSteps=87840` is five years.

**The pickup must be repointed by hand.** `submit_tapAdj.sh` carries it as a
hardcoded `ln -s`, and each member's adjoint has to read *its own* forward
leg's `pickup.0003162240`, not the spin-up's. Chaining the two halves so the
adjoint waits for its forward leg is written up in
[`notes/references/slurm_job_chaining/`](../../../../../../notes/references/slurm_job_chaining/).

Members run with `useGrdchk=.FALSE.` (set in `input_tap/data.pkg`, so it applies
to the reference adjoint too). The check cannot pass where it is currently
pointed and costs roughly 2.6× the adjoint proper; the ensemble's own
finite-difference comparison was to serve as the real validation — see the
outcome below for how that turned out.

**Outcome (runs 31003–31009, 2026-08-29; analysed 2026-08-30).** All seven
completed, but only `M2` (0.5×) and `M3` (2×) produced healthy full-length
adjoints; `M6` (16×) is structurally degraded, and `M1`/`M4`/`M5`/`M7` blow up
partway through the reverse sweep (non-monotonically in κ — a property of each
member's adjusted background state, with the plain, non-`adjViscBoost` build).
The finite-difference comparison ran but fails as a validation: the response is
nonlinear already at factor-2 steps. Full analysis:
`analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/`; results prose:
`notes/directions/nn_surrogate/` (master Part I §Results and the `kappa_ensemble_results`
brief). Rerunning a blown member as-is reproduces the blow-up — pair these
namelists with the `adjViscBoost` build+submit pair if a stable large-κ adjoint
is the goal.
