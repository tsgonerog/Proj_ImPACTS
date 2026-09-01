# `MITgcm_c69m/00_archive/`

**Empty since 2026-08-31** — this archive existed to hold files pulled out of
the vendored `MITgcm/` tree, and its one resident has gone home.

`removed_from_MITgcm/pkg/tapenade/dummy_tap.F` (no-op link stubs for the
Tapenade-named hook adjoints) was removed when vendoring because its symbols
collided with the setups' hand-written `code_tap/addummy_*.F` bodies. The
2026-08-31 hook redesign renamed both setups' hooks to `TAP_*`, the collision
disappeared, and the file was restored verbatim to `MITgcm/pkg/tapenade/` —
which, together with the deletion of `tools/genmake2_override_forward_step_b`
in the same change, returned the vendored tree to **byte-for-byte upstream**
(re-verify with the procedure in `CLAUDE.md`, "How the vendored tree
deviates").

The directory is kept so the tree-level archive location stays known; if
something is ever pulled out of `MITgcm/` again, it goes here under the same
layout rule (the archive mirrors the path its contents came from). Full
history of what was archived here: `git log --follow` on this file and on
`MITgcm_c69m/MITgcm/pkg/tapenade/dummy_tap.F`.
