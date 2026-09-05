# kappa_v ensemble — adjoint-sensitivity analysis

Analysis of the vertical-diffusivity perturbation ensemble (Part I of the
neural-network surrogate proposal): seven members perturbing the uniform background
`kappa_v = 1.2e-5 m²/s` by 0.25×–32×, each with a 10-yr forward leg (years
2170–2180) and a 5-yr adjoint (2180–2185), against the reference adjoint run
31039. The forward legs and original adjoints ran 2026-08-28 and the analysis
was built 2026-08-30; on 2026-09-01 the **adjoints were rerun** (jobs below)
with the Tapenade-native hook build and the analysis re-executed against them.
Validated per run against the originals (reference 30995, members 31003–31009):
`fc` and all 32 `adxx_*` files bitwise identical — every conclusion carries
over — while the rerun's `ADJ*` dumps are seam-clean (the originals carried the
pre-31022 tile-seam artifact within ~2 cells of tile edges) and `ADJetan` is
newly present (367 dumps per run). The artifact only ever affected the seven
dump fields with horizontal stencils: the four local-operator fields —
`ADJdiffkr` (the surrogate target), `ADJqnet`, `ADJqsw`, `ADJempmr` — are
bit-identical between the campaigns at every dump.

On 2026-09-02 all eight adjoints ran a third time, with the profile-guided
`-nocheckpoint` build that became the DINO default that day (jobs 31060–31067,
run directories `DINO_1deg_tapAdj_nocheckpoint_5yr_<tag>_run<job>`; same
namelists, pickups and forward legs). Every pair is **bitwise identical** to its
2026-09-01 run — `fc`, all 32 `adxx_*`, all 4 393 `ADJ*` dumps and the `%MON`
stream, the four blow-ups included — at 1.45–1.65× the speed (9:31–9:45 against
14:03–15:39 wall time). The two sets are interchangeable; this analysis keeps
reading 31039–31046. Report and script:
`../tapenade_profiling/compare_5yr_kappa_ensemble_ckpAll_vs_nocheckpoint.md`.

**Runs 31060–31067 were deleted in the 2026-09-03 scratch consolidation** once
that report had recorded the comparison — being bitwise identical to
31039–31046, they were pure duplication. The last column below is kept as the
job-ID record; those directories are no longer on scratch. The eight
`ckpAll` runs this analysis actually reads all survive.

| run | κ factor | forward job | adjoint job (2026-09-01 rerun; original) | run directory (under `/scratch2/tshahriar/DINO_1deg_outputs/runs/adjoint/`) | `-nocheckpoint` rerun 2026-09-02 (bitwise identical) |
| --- | --- | --- | --- | --- | --- |
| REF | 1× | 30983 (spin-up) | 31039 (30995) | `DINO_1deg_tapAdj_ckpAll_5yr_from180yrPk_visc2x_run31039` | 31060 |
| M1 | 0.25× | 30996 | 31040 (31003) | `DINO_1deg_tapAdj_ckpAll_5yr_M1_run31040` | 31061 |
| M2 | 0.5× | 30997 | 31041 (31004) | `DINO_1deg_tapAdj_ckpAll_5yr_M2_run31041` | 31062 |
| M3 | 2× | 30998 | 31042 (31005) | `DINO_1deg_tapAdj_ckpAll_5yr_M3_run31042` | 31063 |
| M4 | 4× | 30999 | 31043 (31006) | `DINO_1deg_tapAdj_ckpAll_5yr_M4_run31043` | 31064 |
| M5 | 8× | 31000 | 31044 (31007) | `DINO_1deg_tapAdj_ckpAll_5yr_M5_run31044` | 31065 |
| M6 | 16× | 31001 | 31045 (31008) | `DINO_1deg_tapAdj_ckpAll_5yr_M6_run31045` | 31066 |
| M7 | 32× | 31002 | 31046 (31009) | `DINO_1deg_tapAdj_ckpAll_5yr_M7_run31046` | 31067 |

## Reading order

The notebooks are **not numbered** — read them in the order of this table,
top to bottom. Each one assumes the cache written by `build_cache.py` and the
intermediates of the rows above it.

| notebook (in reading order) | question it answers |
| --- | --- |
| `run_inventory_and_cost.ipynb` | Are the nine runs complete and consistent? How does the cost J vary with κ, and does the adjoint gradient predict the measured ΔJ (finite-difference check + initial-state decomposition)? |
| `reference_adjoint_run31039.ipynb` | What does the reference adjoint sensitivity look like (maps, vertical structure, time accumulation)? Continuation of `../sensitivity_5yr_from180yrPk_visc2x.ipynb`, via the chain 28486 → 30995 → 31039 (fc/adxx bit-identical throughout; 31039's ADJ* seam-corrected). |
| `ensemble_sensitivity_maps.ipynb` | What does each member's accumulated sensitivity look like, side by side across κ? Which members are physically usable? |
| `member_vs_reference_metrics.ipynb` | Quantitatively, how far is each member from the reference — in amplitude vs in spatial structure — per variable, per depth, per lead time? |
| `ensemble_statistics.ipynb` | Ensemble mean/spread: where (horizontally, vertically, per variable) does the ensemble disagree most? |
| `time_evolution_and_animations.ipynb` | How do sensitivities evolve/accumulate over the reverse sweep, and when does each blown-up member depart? Produces the interactive HTML animations. |
| `synthesis_and_interpretation.ipynb` | The answer to Part I's question, the stable-vs-blown-up split, and what it implies for the NN surrogate. |

`ensemble_common.py` holds the run registry, variable metadata, metric
definitions and plotting/animation helpers shared by all notebooks.
`build_cache.py` (run once, ~15–40 min) produces the intermediate products the
notebooks read; its docstring is the cache inventory.

## Outputs

Everything generated lands on scratch, **not** in this repository, under

```
/scratch2/tshahriar/DINO_1deg_outputs/analysis/kappa_v_ensemble/
├── cache/        netCDF/CSV intermediates (build_cache.py docstring = inventory)
├── figures/      one subdirectory per notebook, publication-ready PNGs
├── animations/   self-contained interactive HTML animations (safe to e-mail)
└── stats/        summary tables (CSV)
```

This is the standing rule, not a deviation: output from a notebook that reads
**one** run stays inside that run (`<run>/figures/`, `<run>/animations/`);
output from a notebook that reads **several** goes to `analysis/<campaign>/`.
This suite spans nine runs, so it writes to the campaign's analysis directory —
a sibling of `runs/adjoint/kappa_v_ensemble/`, where its eight adjoints live.

`ckpAll_vs_nocheckpoint_comparison/` beside them holds the raw workspace of the
2026-09-02 `-nocheckpoint` comparison: per-pair file lists, the `%MON` extracts
and the run logs. It is kept because the `-nocheckpoint` half of every pair
(31055, 31060–31067) was deleted on 2026-09-03, so that workspace and the
committed reports in `../tapenade_profiling/` are together the only surviving
evidence of the comparison.

## Conventions

- Methodology follows `../sensitivity_5yr_from180yrPk_visc2x.ipynb`: xmitgcm with
  `delta_t=1800`, `ref_date=2000-01-01`, hFac>0 masking, robust symmetric
  percentile colour limits, RdBu_r for signed fields, and reversed time order
  when animating ADJ* fields (dumps are numbered by forward iteration; the
  adjoint computes them backwards).
- "Lead time" = years before the cost-window end (5.0 = window start = the
  fully accumulated sensitivity, the primary comparison field).
- ADJ* dumps are float32, every 5 days (366 per run); adxx_* control gradients
  are float64, one dump per run. Always read via the `.meta` (the helpers do).
- Raw adxx gradients carry unit control weights and are **not comparable
  across controls** (master plan, "a caution before comparing across
  controls").
