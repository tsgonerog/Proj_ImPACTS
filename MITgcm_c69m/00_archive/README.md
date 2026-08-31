# `MITgcm_c69m/00_archive/`

Files that were once **inside the vendored `MITgcm/` tree** and have since been
taken back out. Nothing here is live: no build or submit script reads this
directory, and `genmake2` never sees it. A grep hit in here is history.

**Layout rule: the archive mirrors the path the file came from.** A file under
`removed_from_MITgcm/pkg/tapenade/` was, at some point, sitting in
`MITgcm/pkg/tapenade/`. The `removed_from_` prefix is deliberate — it is the part
that says *do not put this back without reading below*.

The setup-level archives (`mysetups/DINO_1deg/00_archive/`,
`mysetups/SOMA_1deg/00_archive/`) follow the same rule against their own
directory names.

---

## `removed_from_MITgcm/pkg/tapenade/dummy_tap.F`

| | |
| --- | --- |
| **What it is** | No-op link stubs: empty bodies for `DUMMY_IN_STEPPING_D/_B` and `DUMMY_FOR_ETAN_D/_B` |
| **Where it came from** | `MITgcm/pkg/tapenade/` — the c69m tree **as obtained** ships it; it was removed when vendoring |
| **Why it is not live** | It defines the same symbols as the setups' `code_tap/addummy_*.F`, which have real bodies. Compiling both is a duplicate-symbol link error. |

### Background

MITgcm keeps two deliberately-empty hook routines in `pkg/autodiff`:
`DUMMY_IN_STEPPING` and `DUMMY_FOR_ETAN`. They do nothing in the forward model.
They exist so an AD tool has somewhere to hang code — `model/src/forward_step.F`
calls the first, `model/src/integr_continuity.F` calls the second — and when
those are differentiated, the reverse-mode body runs inside the adjoint sweep at
exactly the right instant. That body is where MITgcm writes its `ADJ*` files.

The toolchains name the differentiated result differently:

| Tool | Reverse mode | Tangent mode |
| --- | --- | --- |
| TAF | `ADDUMMY_IN_STEPPING` | `G_DUMMY_IN_STEPPING` |
| Tapenade | `DUMMY_IN_STEPPING_B` | `DUMMY_IN_STEPPING_D` |

`dummy_tap.F` supplies empty bodies for all four Tapenade-named variants, in
the idiom of its former neighbour `pkg/tapenade/stubs_tap_adj.F`: link stubs
for hand-supplied derivatives. **A caveat established on 2026-08-31: raw
Tapenade output does not actually call any of these.** The hooks are declared
passive in `tools/TAP_support/flow_tap`, so Tapenade drops them from the
backward sweep entirely — the calls only exist where something inserts them
(SOMA's hand-patched `forward_step_b.f_modified` inserts the
`DUMMY_IN_STEPPING_B` one). The stubs therefore satisfy a link demand that
arises from patching, not from Tapenade itself; the `DUMMY_FOR_ETAN_B/_D`
signatures (with `myTimeb/d`) suggest they were built against an earlier
configuration where the hooks were undeclared and Tapenade conservatively
activated `myTime`.

### Why it was removed, and why it must stay removed

It is the **opposite choice** from what the live setups make — though the two
setups have since diverged (2026-08-31 dump-hook redesign):

- **SOMA** still carries `code_tap/addummy_in_stepping.F` and
  `code_tap/addummy_for_etan.F` defining the same symbols —
  `DUMMY_IN_STEPPING_b`, `DUMMY_FOR_ETAN_b` — with real bodies. Putting
  `dummy_tap.F` back breaks SOMA's build at the link step.
- **DINO** no longer defines those symbols at all: its hooks are the renamed
  `TAP_DUMMY_IN_STEPPING_B` etc., generated-call-driven, and its old
  `addummy_for_etan.F` is archived in `DINO_1deg/00_archive/code_tap/`.
  Reinstalling `dummy_tap.F` would not break DINO's link — but it would
  reintroduce dead code that the redesign exists to remove, and it still
  breaks SOMA.

It is not a drop-in swap in any case: its `DUMMY_FOR_ETAN_D/_B` take four
arguments (`myTime, myTimed/b, myIter, myThid` — Tapenade treating `myTime` as
active) against the setups' three.

`dummy_tap.F` is the *"make it link, dump nothing"* path. That was the right
choice for the `tutorial_global_oce_biogeo` cross-check in the old c69f tree,
where the point was verifying a gradient rather than producing sensitivity maps.
Evidence that it really was installed in the package survives there as a build
symlink:

```
tutorial_global_oce_biogeo/build_tapAdj_serial/dummy_tap.F
    -> .../MITgcm/pkg/tapenade/dummy_tap.F
```

(see `Proj_ImPACTS_old`).

**Verified 2026-08-20.** Diffing the vendored tree against the reference copy at
`~/tools_and_software/MITgcm_collections/MITgcm_c69m/MITgcm/` shows
`pkg/tapenade/dummy_tap.F` present there and absent here — it is the *only* file
this repository removes from the tree it was given. This repository's history
confirms the removal happened before the initial commit: `dummy_tap.F` was never
tracked at `MITgcm/pkg/tapenade/`, only ever as this archived copy.

Whether that reference tree is stock upstream checkpoint69m or already carried a
local addition is **not established** — it is a plain source tree, not a git
checkout, so it cannot be compared against an upstream tag. Nothing in MITgcm's
own build machinery references `dummy_tap.F` by name (`genmake2` globs
`pkg/*/[a-z]*.F` rather than listing files), and the c69f tree in
`Proj_ImPACTS_old` does not carry it either. Treat the provenance above as "came
with the c69m tree we started from", not as "is upstream MITgcm".
