# `scheme_tests/` — one scheme or package at a time

Viscosity is held at the **reference** field (`viscRef`) so that what changes is
the scheme or the package, not the dissipation.

| Tag | What it turns on |
| --- | --- |
| `from_rest_viscRef_adv30` | advection scheme 30 |
| `from_rest_viscRef_CDscheme` | the C-D scheme (`useCDscheme=.TRUE.`, which is why `pkg/cd_code` is compiled in) |
| `from_rest_viscRef_kppON` | KPP vertical mixing |

**`kppON` is the two-file case that the staging rule exists for.** Turning KPP
on needs both

- `data_from_rest_viscRef_kppON` — `ivdc_kappa` commented out, since convective
  adjustment and KPP should not both be doing the job, and
- `data.pkg_from_rest_viscRef_kppON` — `useKPP=.TRUE.`

and they share a tag, so selecting `scheme_tests/from_rest_viscRef_kppON`
stages both. Before the variants were grouped the `data.pkg` half was named
`data.pkg_kppON`, sat in the flat directory with a tag matching nothing, and was
never staged by any live script — so this experiment silently ran with
`useKPP=.FALSE.`. Any result predating 2026-08-28 that claims to be a KPP run
should be treated with suspicion.
