# 07_tapenade_profiling — where the adjoint recomputes, and what `-nocheckpoint` bought

Scripts and records, no notebook. The question was: which of the routines the
Tapenade adjoint checkpoints inside a time step are worth switching to split
(`_FWD`/`_BWD`) mode, and does doing so change the sensitivities? The
mechanics (what `-profile` measures, what `-nocheckpoint` changes, why the
binomial time loop is untouched) are in `tools/tapenade_profiling/README.md`;
this directory holds the evidence.

## Runs

All 27-rank MPI, `baseline/from180yrPk_visc2x`, `/scratch2/<user>/DINO_1deg_tapAdj_runs/`.

| Run | Build | Length | Node | Wall time | Role |
| --- | --- | --- | --- | --- | --- |
| 31052 | `build_tapAdj` (plain) | 30 d | c2-1 | 0:13:13 | fresh plain reference; bitwise identical to 31032 (0:13:31) |
| 31053 | `build_tapAdj_tapProfile` | 30 d | c2-3 | 0:13:29 | the profile (`tapenade_profile.0000`–`.0026.txt`) |
| 31054 | `build_tapAdj_nocheckpoint` | 30 d | c2-1 | **0:08:47** | validation against 31052 |
| 31039 | `build_tapAdj` (plain) | 5 yr | — | 14:05:45 | production-length reference (2026-09-01) |
| 31055 | `build_tapAdj_nocheckpoint` | 5 yr | c2-1 | _running_ | production-length comparison against 31039 |

## Files

| File | What |
| --- | --- |
| `parse_tapenade_profile.py` | parses a `tapenade_profile.NNNN.txt`, aggregates the per-call-site cost/benefit table by callee, ranks by time gain; `--budget-mb` proposes a list under a peak-memory budget |
| `compare_adjoint_runs.py` | compares two run directories: `fc`, every `adxx_*` (float64) and every `ADJ*` dump (float32) with a true bitwise test plus max abs/relative differences, and the `run_timing.txt` speed-up |
| `tapenade_profile_run31053_rank0000.txt` | rank 0's raw table from run 31053 (the other 26 ranks agree to within 5 % on the total) |
| `profile_run31053_ranked.md` | the parsed, ranked table (116 callees) |
| `compare_30d_run31052_vs_nocheckpoint_run31054.md` | the 30-day validation report |

## What the profile showed (run 31053, rank 0)

- Peak tape **923 MB per process** (27 processes → ~25 GB of a 64 GB node).
- 156 checkpoint locations, 116 distinct callees. Not checkpointing all of
  them would save **363 s of CPU per process out of an 809 s run — 45 %**.
- The gain is concentrated: the top 12 callees carry 308 s. Their split mode is
  memory-neutral or a memory *gain* in 9 of 12 cases:

| callee | gain [s] | Δ peak tape | why |
| --- | --- | --- | --- |
| `timestep` | 75 | −31.1 MB | called per level (36×/step); joint mode snapshots whole 3-D arrays each call |
| `forward_step` | 71 | 0 | the step body: its primal ran once more per step than necessary |
| `grad_sigma` | 37 | 0 | per level |
| `mom_vecinv` | 22 | −0.2 MB | per level |
| `calc_phi_hyd` | 21 | −8.6 MB | per level |
| `thermodynamics` | 18 | 0 | step-level |
| `do_oceanic_phys` | 17 | +28.9 MB | step-level |
| `integrate_for_w` | 13 | 0 | per level |
| `dynamics` | 12 | +9.3 MB | step-level |
| `salt_integrate` | 9 | 0 | step-level |
| `temp_integrate` | 8 | +1.9 MB | step-level |
| `do_fields_blocking_exchanges` | 5 | −1.1 MB | step-level |

- Everything that costs memory sums to ~54 MB per process — irrelevant next to
  the 923 MB peak — so the memory budget never constrained the choice.
- `main_do_loop` appears with a peak-memory cost of 11.3 GB: that is the
  binomial time-loop level, i.e. the whole run's tape, and is exactly what must
  stay checkpointed.
- The profiler truncates gains to whole seconds; 80 callees print 0 s. A
  30-day run (14 min) is the shortest that resolves the ranking.

## The list

`code_tap/tap_nocheckpoint.txt`: every callee with a measured gain ≥ 1 s that is
not a Tapenade external (`cg2d` and `exch2_rl1_cube` are declared in
`tools/TAP_support/flow_tap`, the `TAP_*` hooks in `flow_tap_local`; externals
have no source to split). 33 routines, 357 of the 363 s. Compared with the
c69f-era 64-routine list (`tools/tapenade_profiling/nocheckpoint_routines.txt`):
8 routines in common, none of the top twelve, and that list would have
recovered 21 s under this profile.

## Validation — 30 days, same node (31054 vs 31052)

| | plain | nocheckpoint |
| --- | --- | --- |
| wall time | 0:13:13 | **0:08:47** (1.505×, −33.5 %) |
| `fc` | 0.348990284064362 | identical |
| `adxx_*` (32 files, float64) | — | **32/32 bitwise identical** |
| `ADJ*` (73 files, float32) | — | **73/73 bitwise identical** |

Bitwise identity is the expected outcome, not a happy accident: split mode
stores values the joint mode recomputed with the same statements, so the
adjoint sees the same numbers. (Two plain-build runs, 31032 and 31052, are
also bitwise identical, which is what makes the test meaningful.)

## Validation — 5 years (31055 vs 31039)

_Pending; job 31055 submitted 2026-09-01 19:26 CDT. The relative saving is
expected to be a little smaller than at 30 days because the binomial schedule
re-runs each step up to three times at 87 840 steps (twice at 1 440), and those
re-runs are plain primal steps that `-nocheckpoint` does not touch._

## Re-running

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
./build_tapAdj_tapProfile.sh && ../../../tools/submit.sh submit_tapAdj_tapProfile.sh
python3 analyses/DINO_1deg/03_adjoint/07_tapenade_profiling/parse_tapenade_profile.py \
        /scratch2/$USER/DINO_1deg_tapAdj_runs/<profile run>/tapenade_profile.0000.txt --top 40
# edit code_tap/tap_nocheckpoint.txt, then
./build_tapAdj_nocheckpoint.sh && IMPACTS_DURATION_DAYS=30 ../../../tools/submit.sh submit_tapAdj_nocheckpoint.sh
python3 analyses/DINO_1deg/03_adjoint/07_tapenade_profiling/compare_adjoint_runs.py <plain run dir> <nocheckpoint run dir>
```
