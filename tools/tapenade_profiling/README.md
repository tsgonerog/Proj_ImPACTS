# Tapenade profiling and checkpoint tuning

Two capabilities that were carried in checkpoint69f as patched `genmake2` copies
and are **not currently wired into any build script here**. This directory holds
what you need to use them on c69m, plus the c69f originals for reference.

Neither is needed for a normal adjoint build. Reach for them when the adjoint is
too slow or uses too much memory.

> **Untested on c69m.** The recipes below were derived by reading c69m's
> `genmake2` and the c69f patches they replace — no profiling build has been run
> against c69m. The `-tap_extra` option and the `adProfile.c` gap are verified by
> inspection; the exact quoting of a `-nocheckpoint` list through `genmake2` into
> the make rule is not. Expect to iterate on first use.

---

## The short version

On c69m you do **not** need a patched `genmake2` for either of these. c69m's
`genmake2` accepts `-tap_extra`, whose contents are passed straight through to
the Tapenade command line (`MITgcm/tools/genmake2:1568`, and the rule at `:3751`
that expands `$(TAP_EXTRA)`). That option did not exist in c69f, which is why
the capability had to be patched in back then.

| Want | c69m | c69f did |
| --- | --- | --- |
| profile the adjoint | `genmake2 … -tap_extra "-profile"` (+ see the `adProfile.c` gap below) | `patched_ForTapProfile_genmake2` |
| skip checkpointing on chosen routines | `genmake2 … -tap_extra '-nocheckpoint "…"'` | `patched_AfterTapProfile_genmake2` |

---

## 1. Profiling — what costs what

Tapenade's `-profile` instruments the generated adjoint so that at run time it
reports, per routine, how much tape/stack it pushes and how often it is called.
That tells you where the adjoint's memory actually goes, which is the input to
step 2.

Adapt the build script's `genmake2` line by hand:

```bash
"$MITGCM_ROOT/tools/genmake2_override_forward_step_b" -mpi -tap \
    -tap_extra "-profile" \
    -rd="$MITGCM_ROOT" \
    -of="$MPI_OPTFILE" \
    -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_tap"
```

### The one real gap: `adProfile.c`

`-profile` makes Tapenade emit calls to `profileline_`, `printprofile_` and
`halt_`. Those live in `tools/TAP_support/ADFirstAidKit/adProfile.c`, which c69m
ships but **does not expose to the build**: `pkg/tapenade/` symlinks
`adBinomial.c`, `adFixedPoint.c` and `adStack.c`, and not `adProfile.c`. Without
it the link fails on undefined references to those symbols.

Fix it the same way the other three are done:

```bash
cd MITgcm_c69m/MITgcm/pkg/tapenade
ln -s ../../tools/TAP_support/ADFirstAidKit/adProfile.c adProfile.c
```

This is a change to the vendored tree — see "How the vendored tree deviates" in
`CLAUDE.md`, and add it there if you make it permanent.

### What the c69f patch did that you should NOT copy

It also compiled the ADFirstAidKit with `-D_ADSTACKPROFILE -D_ADSTACKPREFETCH`.
**Those macros appear nowhere in the ADFirstAidKit — not in c69m and not in c69f
either.** They were inert then and are inert now. Ignore them.

---

## 2. `-nocheckpoint` — trading recomputation for memory

Tapenade checkpoints by default: it stores intermediate state on the tape so the
reverse sweep can read it back. For routines that are cheap to recompute but
store a lot, that is the wrong trade. `-nocheckpoint` names those routines so
Tapenade recomputes them instead.

This is what you do *after* reading a profile — hence the old `AfterTapProfile`
name. Applying it blind is guesswork.

`nocheckpoint_routines.txt` in this directory holds the **64 routines** the c69f
work settled on, one per line. To use it:

```bash
NOCP=$(tr '\n' ' ' < ../../tools/tapenade_profiling/nocheckpoint_routines.txt)
"$MITGCM_ROOT/tools/genmake2_override_forward_step_b" -mpi -tap \
    -tap_extra "-nocheckpoint \"$NOCP\"" \
    -rd="$MITGCM_ROOT" -of="$MPI_OPTFILE" -mods=../code_tap \
    -adof="$MITGCM_ROOT/tools/adjoint_options/adjoint_tap"
```

**Treat that list as a starting point, not an answer.** It was derived from a
profiling run of a *c69f* configuration — a different checkpoint, and not
necessarily this grid or this control set. Re-profile before trusting it.

The original embedded the list inline in the genmake2 copy and repeated three
entries (`calc_3d_diffusivity` three times, `exch_xy_rl` and `gad_calc_rhs`
twice); the file here is deduplicated and sorted, 68 entries down to 64.
Duplicates were harmless, just noise.

---

## `c69f_originals/`

`patched_ForTapProfile_genmake2` and `patched_AfterTapProfile_genmake2`, copied
verbatim from `Proj_ImPACTS_old/MITgcm_c69f/MITgcm/tools/` on 2026-08-20.

**They do not work on c69m and must not be dropped into `MITgcm/tools/`.** They
are full copies of the *c69f* `genmake2`, which differs from c69m's by ~200
lines, so installing one silently regresses the build tool by a checkpoint. Two
of their three patch sites no longer exist in c69m: the Tapenade command was
hardcoded in c69f and is parameterised via `$(TAP_EXTRA)`/`$(TAPENADE_FLAGS)`
now, and the explicit `${TAPTOOLS}/ADFirstAidKit/*.c` source list is gone.

They are kept because they are the record of what was actually tried — in
particular the `-nocheckpoint` list, which is extracted above. Each differs from
its c69f `genmake2` by only a handful of lines; to see exactly what a variant
did:

```bash
OLD=/home/tshahriar/backups_and_resources/Proj_ImPACTS/02_20260817_Proj_ImPACTS_old_c69f_tree/MITgcm_c69f/MITgcm/tools
diff "$OLD/genmake2" tools/tapenade_profiling/c69f_originals/patched_ForTapProfile_genmake2
```

`Proj_ImPACTS_old` also holds `patched_AfterTapProfile_genmake2_old`, an earlier
revision, not copied here.

## Reviving the build-script path

`build_tapAdj.sh` and friends still carry a `use_TapProfile` switch with `NO` /
`YES` / `AFTER` branches, where `YES` and `AFTER` name the two c69f files by
their original names and fail. If you make profiling routine, that block is
better replaced by a single `TAP_EXTRA` variable passed through to `genmake2`
than by recreating the old three-way file selection. The `YES` branch also stages
`code_tap/the_model_main.F_ForTapProfile`, which lives in
`../../MITgcm_c69m/mysetups/DINO_1deg/00_archive/code_tap/` and would need
copying back into `code_tap/` first.
