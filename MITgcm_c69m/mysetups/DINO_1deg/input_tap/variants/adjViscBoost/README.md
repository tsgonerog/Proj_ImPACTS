# `adjViscBoost/` — inflated viscosity during the adjoint sweep

`data.autodiff_adjViscBoost` sets a **larger viscosity and diffusivity in the
adjoint sweep than in the forward**: `viscFacInAd = 10.` against
`viscFacInFw = 1.`, `inAdviscArNr = 2.E-3` against a forward `1.2E-4`, plus
added `inAddiffKhT/S`. The `outAd*` values restore the forward settings on the
way out. It is the standard trick for keeping a long adjoint from blowing up,
and the values were adapted from the ASTE 90×150×60 regional setup.

**This is a build *and* a namelist variant, and the two must be used together.**

| Piece | Supplies |
| --- | --- |
| `build_tapAdj_adjViscBoost.sh` | stages the ASTE-derived `AUTODIFF_PARAMS.h` and friends, which is what makes the `inAd*`/`outAd*` parameters exist at all |
| `submit_tapAdj_adjViscBoost.sh` | copies this file over `data.autodiff` in the staged run directory, which is what gives them values |

Pairing the plain submit script with the adjViscBoost build, or the reverse,
silently runs the ordinary configuration.

This file is *not* selected through `IMPACTS_TEST_CASE`; the submit script
copies it by name, independently of whichever `data` variant is chosen.
