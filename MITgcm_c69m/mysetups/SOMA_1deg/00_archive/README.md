# `SOMA_1deg/00_archive/`

Superseded configuration kept for reference. **Nothing here is live** — no build
or submit script reads this directory, and `genmake2` never sees it. A grep hit
in here is history, not current behaviour.

**Layout rule: the archive mirrors the live directory a file came from (or would
go back to)** — the same rule as `../DINO_1deg/00_archive/` and
`MITgcm_c69m/00_archive/`. Only `scripts/` is populated here; `code_tap/` and
`input_tap/` subdirectories appear if something is ever archived from them.

---

## `scripts/`

Four superseded submit scripts, from before the action-first naming
(`submit_tapAdj_<duration>.sh`) was applied to this setup.

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
