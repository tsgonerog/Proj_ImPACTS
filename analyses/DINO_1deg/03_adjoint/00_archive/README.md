# `03_adjoint/00_archive/`

Two different things, both kept for reference. See `analyses/README.md` for the
full per-notebook index and the run-to-notebook mapping.

## Earlier serial exploratory runs

Superseded by the 5-year MPI adjoints one level up. These are 180- and 360-day
**serial** runs from the period before DINO became MPI-only, named for their
starting point and viscosity setting.

| Notebook | Run |
| --- | --- |
| `serial_180d_from_rest_viscRef.ipynb` | 18232 |
| `serial_360d_from_rest_viscRef.ipynb` | 18222 |
| `serial_180d_from_80yr_pickup_viscD2x_Zref.ipynb` | 22038 |
| `serial_360d_from_80yr_pickup_viscD2x_Zref.ipynb` | 22039 |
| `serial_180d_from_50yr_pickup_after_profile.ipynb` | 24020 |

The last one carries no viscosity token in its name because run 24020 is gone
from scratch and its namelist cannot be read back. Several of these also
reference run 18238, likewise deleted. `tools/pre_push_check.sh` reports those
unresolved paths as **notes, not failures** — they were dead before the
2026-08-18 scratch rename and were deliberately left pointing at the original
run rather than repointed at a different one.

## `poster_scidac_pi_meeting_aug2026/`

A finished deliverable rather than superseded work: the poster prepared for the
SciDAC PI meeting, August 2026. Both notebooks read run 28486.

| Notebook | What it does |
| --- | --- |
| `01_adj_field_animations.ipynb` | animates the 3-D and 2-D `ADJ*` fields |
| `02_poster_panel_frames.ipynb` | trimmed version that writes the nine `poster_frames/*.png` panels of the 3 × 3 sensitivity grid |
