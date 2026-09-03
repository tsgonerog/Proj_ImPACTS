# `scidac_poster_aug2026/`

The poster prepared for the SciDAC PI meeting, August 2026. A finished
deliverable rather than exploratory work, which is why it sits beside the live
adjoint notebooks rather than being retired with the superseded ones.

Both notebooks read the 5-year adjoint
`DINO_1deg_outputs/runs/adjoint/sensitivity/DINO_1deg_tapAdj_ckpAll_5yr_from180yrPk_visc2x_run28486`
and write into that run directory.

| Notebook | What it does | Output |
| --- | --- | --- |
| `adj_field_animations.ipynb` | animates the 3-D and 2-D `ADJ*` fields | `animations/` — gif + html per field, and the `adj_*_z14/` frame directories |
| `poster_panel_frames.ipynb` | the trimmed version that renders the nine panels of the 3 × 3 sensitivity grid | `figures/poster_frames/*.png` |

Until 2026-09-03 this directory lived at
`03_adjoint/00_archive/poster_scidac_pi_meeting_aug2026/`. It moved up a level
when the rest of that archive — five superseded serial notebooks whose runs no
longer exist — was retired to `~/trash/`.

**Caveat on run 28486.** It predates the 2026-08-31 `ADEXCH_*` stub fix, so its
`ADJ*` dumps carry a tile-edge artifact: partial halo sums in the 1–2 cells
straddling each exchange seam (`i=17|18`, `i=34|35`, every `j` multiple of 22,
and the channel's periodic seam at `i∈{1,2,50,51}`, `j≈13–44`). It is
dump-only — `fc` and `adxx_*` were never affected — and it touches only the
seven fields with horizontal stencils. 28486 is the last pre-fix run left on
scratch. Mask ~2 cells around those seams when reading its `ADJ*`, or read the
seam-clean 5-year rerun 31039 in `../kappa_v_ensemble/` instead.
