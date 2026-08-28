# `baseline/` — the production forward configuration

What `submit_frd.sh` runs when you give it no `IMPACTS_TEST_CASE`:

```bash
test_cases="${IMPACTS_TEST_CASE-baseline/from_rest_visc2x}"
```

`data_from_rest_visc2x` is the configuration of the **200-year spin-up** (run
30983, and run 28463 before the repository cleanup), from rest with both
`viscAhDfile` and `viscAhZfile` at `dino_viscAhD_2p00.bin` — 2× the reference
field. Every other group here is a departure from this one, so change it only
when the production configuration itself changes.

The committed *duration* is 10 years, not 200: that is the cheap regression
configuration. A 10-year run from rest reproduces the first 10 years of the
spin-up bit-identically, which is the standing check that a rebuild has not
altered the physics. The full spin-up is the same namelist with
`IMPACTS_DURATION_DAYS=73200`.

`visc2x` rather than `viscD2x_Zref` is not cosmetic: the spin-up first ran as
`viscD2x_Zref` and **crashed at 126.3 years**. See `analyses/README.md`.
