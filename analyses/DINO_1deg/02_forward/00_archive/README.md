# `02_forward/00_archive/`

Post-mortems of forward spin-ups that **crashed before completing**. Kept
because the failure is the result — they record which viscosity settings were
tried and how far each got before blowing up.

Not superseded analysis: the notebooks work, and the runs they read still exist
on scratch. See `analyses/README.md` for the full per-notebook index.

| Notebook | Run | Reached |
| --- | --- | --- |
| `200yr_from_rest_viscD2x_Zref_crashed_126y.ipynb` | 19369 | 126 of 200 years |
| `200yr_from_rest_viscGrid1p8e-2_crashed_13y.ipynb` | 28452 | 13 of 200 years |

The attempt that *did* complete is `../02_spinup_200yr_visc2x.ipynb` (run 28463),
which is also the baseline for the forward reproducibility check described under
"Verification status" in the root `README.md`.
