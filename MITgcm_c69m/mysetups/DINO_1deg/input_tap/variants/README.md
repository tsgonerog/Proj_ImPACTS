# `input_tap/variants/` — alternative namelists

The **adjoint** model's variants. The forward model's are in [`../../input/variants/`](../../input/variants/), organised the same way and using the same group names where a study has both halves.

**Nothing here is staged unless it is asked for.** `input_tap/` itself holds exactly
the files MITgcm reads and every one of them is copied into every run; this
directory is skipped entirely (`find -maxdepth 1`), and only the variant a run
selects is staged.

## How a variant is selected

```bash
IMPACTS_TEST_CASE=<group>/<tag> ../../../tools/submit.sh <submit script>
```

which stages `variants/<group>/data_<tag>` as `data`.

## The two rules

**1. A file is named after the MITgcm file it replaces.** The name is
`<mitgcm-file>_<tag>` — so `data_M3` replaces `data`, `data.pkg_M3` replaces
`data.pkg`, `data.autodiff_M3` replaces `data.autodiff`. The part before the
first underscore tells you which file you are looking at.

**2. Every file sharing a tag inside a group is staged together.** Selecting a
tag stages its `data` *and* every sibling `<mitgcm-file>_<tag>` beside it. That
is what lets one variant change a package flag as well as the namelist:
`scheme_tests/from_rest_viscRef_kppON` stages both `data_...kppON` and
`data.pkg_...kppON`, so the run really does get `useKPP=.TRUE.`. Before this
existed only the `data` half was staged and that experiment silently ran
without KPP.

## Groups

| Group | What it varies |
| --- | --- |
| [`baseline/`](baseline/) | The reference adjoint configuration the committed default points at (`from180yrPk_visc2x`) |
| [`viscosity_study/`](viscosity_study/) | Adjoint runs at the `viscAhGrid` settings of the forward-side study of the same name |
| [`adjointViscosity/`](adjointViscosity/) | `data.autodiff` with adjoint-mode viscosity inflation (`viscFacInAd = 10.`). **Needs the matching build and submit script** — `build_tapAdj_adjViscBoost.sh` + `submit_tapAdj_adjViscBoost.sh` |
| [`kappa_v_ensemble/`](kappa_v_ensemble/) | The vertical-mixing perturbation ensemble of `notes/directions/nn_surrogate/` — the 5-year adjoints |
| [`grdchk_repair/`](grdchk_repair/) | The finite-difference gradient check with its perturbation moved onto the sensitivity peak and `useGrdchk` switched on — the check that can actually pass (0.9 % at the peak, run 31037), unlike the committed `data.grdchk` point |

## Adding to this

- **A new member of an existing study** — drop `data_<tag>` into that group. If
  it needs another MITgcm file changed, add `<that-file>_<tag>` beside it with
  the *same* tag and it is staged automatically.
- **A new study** — make `variants/<name>/`, give it a `README.md` saying what
  it varies and why, and put its members in. Nothing else needs editing: the
  submit scripts resolve any `<group>/<tag>`.
- Name the group for the question it asks, not the method, so it survives a
  change of approach. Keep the same group name on both sides where a study has a
  forward and an adjoint half.

The run directory is named after the **tag only**, not the group — a run is
described by its physics, not by where its namelist lives in this repository.
So `kappa_v_ensemble/M3` produces `..._M3_run<jobid>`.
