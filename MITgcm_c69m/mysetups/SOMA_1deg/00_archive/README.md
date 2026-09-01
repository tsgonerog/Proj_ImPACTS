# `SOMA_1deg/00_archive/`

Superseded configuration kept for reference. **Nothing here is live** — no build
or submit script reads this directory, and `genmake2` never sees it. A grep hit
in here is history, not current behaviour.

**Layout rule: the archive mirrors the live directory a file came from (or would
go back to)** — the same rule as `../DINO_1deg/00_archive/` and
`MITgcm_c69m/00_archive/`. `scripts/` and `code_tap/` are populated;
`input_tap/` appears if something is ever archived from it.

---

## `code_tap/`

Archived 2026-08-31, when SOMA converted to the Tapenade-native `TAP_*` hook
mechanism (see the DINO README, *"How the Tapenade hooks work"*). Apart from
`the_model_main.F_ForTapProfile` (archived later the same day), all of these
belonged to the old mechanism, in which the `ADJ*` dump call was hand-inserted
into a frozen copy of the generated `forward_step_b.f` and the adjoint state
reached hand-written `_b`-named routines through the `adcommon.h`
common-block mirror.

| File | What it is | Why it is not live |
| --- | --- | --- |
| `adcommon.h` | Hand-mirror of Tapenade's generated adjoint common blocks | The hook's `_B` receives adjoint fields as arguments; no consumer remains |
| `addummy_for_etan.F` | `DUMMY_FOR_ETAN_b`; would dump `ADJetan` | Never called by generated code; needs the archived `adcommon.h`. Superseded by the live `code_tap/addummy_for_etan.F` (`TAP_DUMMY_FOR_ETAN` hook, added later on 2026-08-31) |
| `monitor_ad.F` | `MONITOR_b`, adjoint-state monitor | Same |
| `exf_monitor_ad.F` | `EXF_MONITOR_b` | Same |
| `exf_adjoint_snapshots_ad.F` | `EXF_ADJOINT_SNAPSHOTS_b`, body already defused behind `DONT_DISABLE` | Same; the upstream TAF-named `pkg/exf` copies compile in its place as dead code |
| `the_model_main.F_ForTapProfile` | `the_model_main.F` instrumented for the Tapenade profiling tool | Profiling cannot be run from this repository (no patched `genmake2` here; see `tools/tapenade_profiling/`); archived 2026-08-31 when the workflows were aligned — DINO archived its counterpart the same way |

`forward_step_b.f_modified` (the frozen 7,306-line generated copy) was deleted
rather than archived — git history keeps it, and it is the one file with
negative reference value: **it had gone stale against the evolving tree**
(274 diff lines vs freshly generated code), and splicing it into 2026-08-31
builds misaligned Tapenade's tape enough to crash every adjoint run at the
backward-sweep start (`integer divide by zero` in `pkg/longstep`, runs
31029/31030). The first successful c69m SOMA adjoint is the hook build's run
31031.

## `scripts/`

Two generations of superseded submit scripts.

**Archived 2026-08-31, when the SOMA workflow was aligned with DINO's** — the
five pre-made per-duration scripts, replaced by the single `submit_tapAdj.sh`
with `IMPACTS_DURATION_DAYS`-style overrides (durations are now submissions,
not scripts). They still work, but write DINO-convention-violating
`pd_StP_srl_no-kpp-GM_*` / `test_*` run-directory names and lack the
`ADJetan`-era build pairing:

| File | Simulated days |
| --- | --- |
| `submit_tapAdj_001d_smoketest.sh` | 1 (job name `test`) |
| `submit_tapAdj_005d.sh` | 5 |
| `submit_tapAdj_030d.sh` | 30 |
| `submit_tapAdj_180d.sh` | 180 |
| `submit_tapAdj_360d.sh` | 360 |

**From before the action-first naming** (`submit_tapAdj_<duration>.sh`) was
applied to this setup:

| File | Why it is not live |
| --- | --- |
| `submit_tapAdj_mpi_on_sverdrup.sh` | **SOMA is serial-only.** `code_tap/SIZE.h_mpi` still exists but no script stages it and no submit script expects it. |
| `submit_frd_mpi_on_sverdrup.sh` | Both MPI *and* forward — there is no forward build script in this setup at all |
| `submit_tapAdj_serial_on_sverdrup_150_day.sh` | Superseded by `submit_tapAdj_180d.sh`; the live scripts are zero-padded so they sort |
| `submit_tapAdj_serial_on_sverdrup_5_day_noTpatched.sh` | The `noTpatched` (raw-Tapenade) control, now expressed as `build_tapAdj_rawTapenade.sh` |

These predate `tools/machine_env.sh`, so they carry hardcoded sverdrup paths and
were not ported — see `PORTING.md`. Three of them write into
`/scratch2/<user>/v4_soma_tapAdj_runs/`, the pre-rename scratch tree;
`submit_frd_mpi_on_sverdrup.sh` writes straight into `/scratch2/<user>/` with no
subtree at all.

---

## Removed on 2026-08-20

`code_tap_files/` — 1.7 MB of Tapenade-**generated** Fortran (`.f`, not `.F`):

- `the_main_loop_b.f_for_patched_genmake2`
- `the_main_loop_b.f_for_patched_genmake2_serialPatch` (byte-identical to the above)
- `the_main_loop_b.f_for_patched_genmake2_mpiPatch`
- `forward_step_b.f_modified` (an older revision of the live `code_tap/` copy)

Patch targets from an approach that was abandoned. The genmake2 patch used to
inject a hand-corrected `the_main_loop_b.f`; it now injects
`forward_step_b.f_modified` instead, and `genmake2_override_forward_step_b` merely
`ls -l`s `the_main_loop_b.f` without replacing it. Generated output, regenerable
by re-running Tapenade, and recoverable from git history.
