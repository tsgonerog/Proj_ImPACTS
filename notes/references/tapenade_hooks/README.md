# Replacing TAF hook directives with Tapenade-native active-argument hooks

*Change note for MITgcm review — Proj_ImPACTS `main` (initial commits
`27e4ee5`, `e789533`; developed on the since-merged branch
`tapenade-active-dump-hook`, whose pre-hook base survives as the tag
`archive/20260831_pre-tapenade-hooks`), MITgcm checkpoint69m, Tapenade 3.16,
2026-08-31. A styled copy of this note lives beside it as
`tapenade_hook_note.html`.*

How the DINO adjoint's `ADJ*` dumps and adjoint-mode parameter switching were
moved off hand-patched generated code and onto a mechanism Tapenade itself
honors — and what an upstream version would look like.

## 1 · The gap: TAF has a directive Tapenade doesn't

MITgcm's `ADJ*` sensitivity dumps and its adjoint-mode parameter switching both
hang off deliberately empty forward hooks — `DUMMY_IN_STEPPING`
(`forward_step.F:577`) and `AUTODIFF_INADMODE_UNSET/SET` (`:433`/`:1207`).
Under TAF, a `.flow` directive forces a *hand-written* adjoint routine into the
reverse sweep even though no active data crosses the hook's
three-passive-scalar interface; the adjoint state reaches that routine through
TAF-generated common blocks mirrored in `adcommon.h`:

```
cadj SUBROUTINE dummy_in_stepping REQUIRED
cadj SUBROUTINE dummy_in_stepping ADNAME = addummy_in_stepping
```

Tapenade's external-library mechanism (`-ext tools/TAP_support/flow_tap`) is
purely data-flow driven. It has no `ADNAME`/`REQUIRED` equivalent: an external
whose declared interface carries no active data contributes nothing to any
derivative, so Tapenade drops it from the backward sweep entirely
(`flow_tap:835` declares `dummy_in_stepping` with all parameters
`ReadNotWritten` — no reverse-sweep call is ever generated).

Upstream is aware of the gap in effect if not in framing:
`pkg/tapenade/dummy_tap.F` ships *empty* `DUMMY_IN_STEPPING_B/_D` and
`DUMMY_FOR_ETAN_B/_D` bodies — link stubs, not functionality. The Tapenade
path simply does not produce `ADJ*` output as distributed.

### The previous workaround, and what it cost

This project originally bridged the gap by hand: a patched `genmake2` copy
(`genmake2_override_forward_step_b`) injected one line into the `adj_tap_all`
rule, overwriting the generated `forward_step_b.f` with a frozen 5,547-line
copy whose only difference from raw Tapenade output was **a single inserted**
`CALL DUMMY_IN_STEPPING_B(...)`. The hand-written dump routine then read the
adjoint state from `adcommon.h`, a manually maintained mirror of Tapenade's
generated common blocks whose member *ordering* had to silently track the
generated code — a mismatch would mislabel every dumped field with no error.
Both the frozen file (per decomposition variant) and the mirror had to be
redone after any re-differentiation.

Worse, the same gap had silently disabled a second mechanism:
`ADAUTODIFF_INADMODE_SET/UNSET` — the *only* routines that apply `viscFacInAd`
and the ASTE `inAd*` viscosity overrides (consumed in
`pkg/mom_common/mom_calc_visc.F:511ff`) — are TAF-named and were never called
by anything Tapenade generated. **The "adjViscBoost" configuration had
therefore never boosted anything**: the namelist loaded `viscFacInAd = 10.`
and no code path applied it.

## 2 · The mechanism: activity through the argument list

The one thing Tapenade honors is data flow, so the redesign routes the hooks'
relevance through their interfaces. Each hook receives model state as
arguments; a setup-local external library declares those arguments active
(read-then-written); Tapenade then generates `CALL <hook>_B(x, xb, …)` at the
exact reverse-sweep mirror of the forward call site, by construction. The
hand-written `_B` body receives the adjoint fields as explicit arguments — no
generated file is post-edited, and no common-block mirror exists.

```fortran
C  code_tap/forward_step.F (shadow), in the ALLOW_AUTODIFF_MONITOR block:
# ifdef ALLOW_TAPENADE
      CALL TAP_DUMMY_IN_STEPPING(
     &     theta, salt, uVel, vVel, wVel,
     &     fu, fv, Qnet, Qsw, EmPmR, diffKr,
     &     myTime, myIter, myThid )
# else
      CALL DUMMY_IN_STEPPING( myTime, myIter, myThid )
# endif
```

```
! code_tap/flow_tap_local — second -ext file, injected via genmake2's
! existing -tap_extra passthrough (no genmake2 patch needed):
subroutine tap_dummy_in_stepping:
  external:
  shape: (param 1, ..., param 14)
  ReadNotWritten:     (0,0,0,0,0,0,0,0,0,0,0,1,1,1)
  ReadThenWritten:    (1,1,1,1,1,1,1,1,1,1,1,0,0,0)
```

```fortran
C  What Tapenade 3.16 then generates in forward_step_b.f, unprompted,
C  at the reverse-sweep mirror of the forward call site:
      CALL TAP_DUMMY_IN_STEPPING_B(theta, thetab, salt, saltb, uvel,
     +                             uvelb, vvel, vvelb, wvel, wvelb, fu,
     +                             fub, fv, fvb, qnet, qnetb, qsw, qswb
     +                             , empmr, empmrb, diffkr, diffkrb,
     +                             mytime, myiter, mythid)
```

The same pattern drives the mode switches. `TAP_INADMODE_SET(uVel, …)`
replaces the step-end hook and `TAP_INADMODE_UNSET(uVel, …)` the step-start
hook (one field suffices as the activity vehicle); their generated `_B`s land
at each backward step's *start* (apply `inAd*` parameters, before
`DYNAMICS_B`) and *end* (restore forward parameters, after
`RESET_NLFS_VARS_B`) — exactly the TAF semantics, including forward parameters
during every checkpoint re-forward. The `_B` bodies are thin wrappers that
call the existing TAF-named routines, so the parameter-switching logic is not
duplicated.

**Cost.** Declaring the fields read-then-written makes Tapenade push/pop them
around each hook call: +22 array push/pops per timestep in `forward_step_b.f`
for the dump hook (~1.3 MB/rank/step for DINO) plus two 3-D fields for the
mode switches. Measured wall-time impact was below run-to-run noise (13:51 vs
14:22 on a 30-day adjoint).

**Fragility guard.** F77 checks no interfaces, so a drift between the
generated call and the hand-written signature would silently misalign
arguments. Both build scripts therefore parse the generated calls after
`make` (`check_gen_call`) and fail the build unless the dump hook has exactly
25 arguments and each mode switch 5.

## 3 · Change inventory

All paths relative to `MITgcm_c69m/mysetups/DINO_1deg/` unless noted. The
vendored `MITgcm/` tree remains byte-identical to upstream apart from two
pre-existing deviations (the — now SOMA-only — `genmake2` override, and the
removal of colliding `pkg/tapenade/dummy_tap.F`); everything new lives in the
setup's `-mods` directory.

| File | Previous | Current | Reason | Scope |
| --- | --- | --- | --- | --- |
| **added** `code_tap/forward_step.F` | Not shadowed; upstream file called the passive TAF hooks | `-mods` shadow; only change is the three `TAP_*` hook calls under `#ifdef ALLOW_TAPENADE` (TAF calls kept in `#else`) | The hooks need active arguments; the call sites live here | **upstream-ready** — would be an edit to `model/src/forward_step.F` |
| **added** `code_tap/tap_dummy_in_stepping.F`, `code_tap/tap_inadmode.F` | — | No-op forward bodies of the three hooks (never in any `*_ad_diff.list`, so compiled as plain sources, not differentiated) | Primal calls in forward runs and checkpoint re-forwards must resolve and do nothing | **upstream-ready** — `pkg/autodiff` (or `pkg/tapenade`) |
| **added** `code_tap/flow_tap_local` | — | Supplementary Tapenade external library declaring the hooks' field arguments active; passed as `-tap_extra "-ext ../code_tap/flow_tap_local"` alongside the stock `flow_tap` | This declaration is what makes Tapenade emit the `_B` calls | DINO-specific arity — upstream analog appends generic stanzas to `TAP_support/flow_tap` |
| **reworked** `code_tap/addummy_in_stepping.F` | Renamed TAF routine `DUMMY_IN_STEPPING_b` reading Tapenade's adjoint commons via `adcommon.h` | `TAP_DUMMY_IN_STEPPING_B`: halo-folds and dumps its adjoint *arguments*; TAF's `ADDUMMY_IN_STEPPING` body kept in `#else`, plus a no-op `_D` for TLM linking | Adjoint state now arrives through the interface; one file serves both toolchains by CPP | **upstream-ready** — dual-tool shape for `pkg/autodiff` |
| **reworked** `code_tap/autodiff_inadmode_set_ad.F` (+ `_OG`, `_aste` variants) | Defined `ADAUTODIFF_INADMODE_SET` — TAF-named, **never called** under Tapenade (dead code) | Same bodies, now reached via a thin `TAP_INADMODE_SET_B` wrapper (+ `_D` no-op) under `#ifdef ALLOW_TAPENADE` | Makes the `inAd*` parameter application actually execute at each backward step's start | **upstream-ready** — wrapper belongs beside the body in `pkg/autodiff` |
| **added** `code_tap/autodiff_inadmode_unset_ad.F` (+ `_OG`, `_aste` variants) | No local copy; upstream's `ADAUTODIFF_INADMODE_UNSET` compiled but unreachable; ASTE's `outAd*` restore side never ported | Shadow with the upstream body + `TAP_INADMODE_UNSET_B` wrapper; the `_aste` variant newly implements the `outAd*` restore (parameters existed in the header/readparms, nothing applied them) | Forward-mode parameters must be restored at each backward step's end, before re-forwards | **upstream-ready** (restore body itself is ASTE-config-specific) |
| **removed** `code_tap/forward_step_b.f_modified` (+ `_mpi`, `_serial`) | Frozen 5,547-line copies of generated code; sole content = one inserted call; overwritten into the build by the patched `genmake2` | Deleted — the call is generated | Eliminates hand-editing of generated code and per-variant regeneration burden | n/a |
| **archived** `code_tap/adcommon.h` | Hand-mirror of Tapenade's generated adjoint commons; member order had to silently match or dumps were mislabeled | Archived (`00_archive/code_tap/`) — no consumer remains | Adjoint fields are explicit arguments now | n/a — TAF path keeps its own `pkg/autodiff/adcommon.h` |
| **archived** `code_tap/addummy_for_etan.F`, `code_tap/monitor_ad.F` | Present but dead: no generated code ever called `DUMMY_FOR_ETAN_B` / `MONITOR_b`; no run ever produced `ADJetan` | Archived with notes; an `ADJetan` hook at the `integr_continuity.F` call site is a documented follow-up — **landed, see §7** | Could not compile without the retired `adcommon.h`; were inert regardless | done (§7) |
| **retired** `build_tapAdj_rawTapenade.sh` | Control build demonstrating uncorrected raw Tapenade output | Deleted for DINO — raw output *is* the working configuration | The patched/raw axis no longer exists here | n/a |
| **modified** `build_tapAdj.sh`, `build_tapAdj_adjViscBoost.sh` | Invoked the patched `genmake2_override_forward_step_b`; staged the frozen file | Invoke **stock** `genmake2` + `-tap_extra "-ext …"`; stage the new `unset` variant; run `check_gen_call` argument-count assertions on all three generated calls | No vendored-tree patch needed; loud failure instead of silent F77 misalignment | pattern **upstream-ready** (the assertion could live in a genmake2 rule) |
| **unchanged → deleted** `MITgcm/tools/genmake2_override_forward_step_b` | Load-bearing for all adjoint builds | Kept for the not-yet-converted SOMA setup at the time of writing; **deleted later the same day (2026-08-31) when SOMA adopted the same hooks** — the vendored tree has deviated from upstream in zero files since | Done | superseded the same day |

Project-local housekeeping (not review-relevant): `tools/pre_push_check.sh`
gained the new staged-variant path; `CLAUDE.md` and the READMEs document the
mechanism.

## 4 · Validation

All runs: DINO 1°, 51×198×36, 27 MPI ranks, 30-day adjoints (1,440 steps),
identical staged namelists within each pair; comparisons are `cmp`-level
bitwise on `fc`, all `adxx_*` and all `ADJ*` files.

| Check | Run pair | Result |
| --- | --- | --- |
| Dump hook reproduces the hand-patched build | 31023 (hooks) vs 31022 (patched, from 180-yr pickup) | `fc`, 32 `adxx_*`, 66 `ADJ*` all bitwise identical; 13:51 vs 14:22 wall time |
| Mode-switch hooks are exact no-ops at default parameters (`viscFacInAd = viscFacInFw = 1`) | 31024 (all three hooks) vs 31023 | Bitwise identical throughout |
| adjViscBoost engages — and only in the backward sweep | 31025 (boost) vs 31026 (plain, same from-rest config) | `fc` bit-identical (0.399075406661494, forward trajectory untouched); all 66 `ADJ*` and all 8 nonzero `adxx_*` differ (24 identical files are all-zero inactive controls); peak \|adxx_theta\| damped 3.96e-2 → 3.35e-2 |

The last row is the first functioning adjViscBoost run in this project's
history. The `fc`-identical / adjoint-different signature is precisely the
TAF-equivalent "modified adjoint" semantics: boosted dissipation in the
reverse sweep, untouched forward physics.

## 5 · Toward an upstream version

The mechanism maps onto stock MITgcm cleanly: hook calls with state arguments
in `model/src/forward_step.F` under `#ifdef ALLOW_TAPENADE`; no-op forward
bodies and dual-guard adjoint bodies in `pkg/autodiff` (replacing the
`dummy_tap.F` link stubs); external-library stanzas appended to
`tools/TAP_support/flow_tap`. Points an upstream design should settle:

- **Signature vs configuration.** The dump hook's 14-argument list encodes
  this setup's field set (`diffKr` exists only under
  `ALLOW_3D_DIFFKR`/`ALLOW_DIFFKR_CONTROL`). Upstream needs either
  CPP-conditional argument lists with matching per-config stanzas, or a fixed
  superset signature.
- **Activity is config-dependent.** Tapenade omits the `xb` slot of any
  argument that is passive *at the call site* (e.g. no `xx_qsw` control → no
  `qswb`), changing the generated arity. A build-time assertion like
  `check_gen_call` — or moving the hooks behind explicit interfaces — is
  essential, since F77 gives no protection.
- **Tape cost** of read-then-written declarations is real but modest here; a
  superset signature on a large configuration would want measurement.
- **Small toolchain facts** worth knowing: Tapenade 3.16 accepts repeated
  `-ext`; genmake2's `-tap_extra` *overwrites* on repeat, so profiling flags
  and the `-ext` must share one instance; Tapenade may emit `_B0`-suffixed
  names when it specializes (cf. `CG2D_B0`) — verify the emitted name once per
  hook.
- **Adjacent gaps**, same root cause: `DUMMY_FOR_ETAN`/`ADJetan` (unwired
  when this was written; since closed by the same pattern — see §7),
  and the `ADEXCH_*` adjoint halo exchanges that upstream
  `pkg/tapenade/stubs_tap_adj.F` ships as no-ops (implemented in this repo via
  `EXCH2_*_CUBE_AD` in an earlier commit, `7378086`; without them multi-tile
  `ADJ*` dumps carry seam artifacts). TLM counterparts (`_D`) are currently
  link-safe no-ops and would need real bodies for tangent-mode dumps.

## 6 · Addendum — SOMA converted; deviation set now empty (same day, later)

The follow-up anticipated in §5 landed the same day, and it produced the
strongest evidence for this note's thesis. Converting SOMA to the same
mechanism (dump hook only — SOMA has no adjViscBoost machinery to switch)
required a baseline run of the *old* patched mechanism first, and that
baseline **crashed at the backward-sweep start** (`integer divide by zero` in
`pkg/longstep`, runs 31029/31030) — at every duration. The cause: SOMA's
frozen `forward_step_b.f_modified` had silently gone stale against the
evolving tree (274 diff lines vs freshly generated code), and splicing it into
current builds misaligned Tapenade's tape. **The c69m SOMA adjoint had never
actually run.** The hook build completed on the first attempt: run 31031,
`fc` bitwise-identical to the crashed baseline's forward value, full finite
`ADJ*`/`adxx_*` output — the failure mode hand-frozen generated code invites,
and the one this redesign eliminates, demonstrated in one experiment.

With both setups on generated hook calls, the two remaining tree deviations
dissolved: `tools/genmake2_override_forward_step_b` is deleted (nothing uses
it), and `pkg/tapenade/dummy_tap.F` is restored verbatim (the `TAP_*` renaming
removed the symbol collision that had forced it out at vendoring time; its
stubs compile as dead code). **The vendored MITgcm tree is now byte-for-byte
upstream in every file** — everything this project adds lives in the setups'
`-mods` directories and one `-tap_extra` flag, which is exactly the shape an
upstream patch would formalize.

## 7 · Addendum — ADJetan wired; shadows re-laid out additively (later still)

Two follow-ups, same day, after the SOMA conversion (first in DINO, then
SOMA — see the closing paragraph):

**The fourth hook: `ADJetan`.** Upstream dumps the free-surface adjoint from
its own hook — `DUMMY_FOR_ETAN`, called inside `INTEGR_CONTINUITY`
(`model/src/integr_continuity.F:313`), not from `FORWARD_STEP` — because
`adEtaN` is half a time step out of phase with the other adjoint variables
(the comment block in `pkg/autodiff/addummy_for_etan.F` explains). The stock
`flow_tap` declares it all-passive (three scalars), so Tapenade dropped it
exactly as it dropped `DUMMY_IN_STEPPING`: the generated
`integr_continuity_b.f` kept an `EXTERNAL DUMMY_FOR_ETAN` and no call, the
`dummy_tap.F` `DUMMY_FOR_ETAN_B` stub sat unreferenced, and no Tapenade run
here had ever produced `ADJetan`. Wired with the identical recipe: an
`integr_continuity.F` shadow whose one change is
`TAP_DUMMY_FOR_ETAN(etaN, myTime, myIter, myThid)` under
`#ifdef ALLOW_TAPENADE`; a `tap_dummy_for_etan.F` no-op forward body; an
`etaN` read-then-written stanza in `flow_tap_local`; the hand-written
`TAP_DUMMY_FOR_ETAN_B` (dumps `etaNb` via `DUMP_ADJ_XY` on the separate
`dumpAdRecEt` counter; like upstream, no ADEXCH fold) appended to an
`addummy_for_etan.F` shadow; and a fourth `check_gen_call` assertion
(5 arguments, in `integr_continuity_b.f`). Tape cost: one 2-D
`PUSH`/`POP` of `etaN` per call.

**Additive re-layout of the shadows.** In the same pass every DINO shadow was
rebuilt to be *upstream file byte-for-byte + guarded additions only*:
`addummy_in_stepping.F` now carries the complete upstream TAF/OpenAD body
unmodified (it compiles as dead code under Tapenade, exactly as in an
upstream Tapenade verification build — no more condensed `#else` copy) with
the `TAP_*` block appended; `addummy_for_etan.F` follows the same shape; and
the six option headers that had drifted from older MITgcm versions
(`CPP_OPTIONS.h`, `COST_OPTIONS.h`, `CTRL_OPTIONS.h`, `CTRL_SIZE.h`,
`GMREDI_OPTIONS.h`, `MOM_COMMON_OPTIONS.h`) were rebased onto the c69m text
with only `#define`/`#undef` toggles changed, the effective macro set
verified identical. Every `code_tap/` file is now one `vimdiff` hunk-set away
from its upstream counterpart — the shape an upstream contribution needs.

**Validation (run 31032 vs baseline 31022, 30-day adjoint from the 180-yr
pickup, identical namelists).** Rebuilding both variants after the re-layout
changed the generated `.f` code lines *only* by the new hook (11 lines in
`integr_continuity_b.f`; everything else comment/case-identical). The run:
`fc` = 3.48990284064362E-01 bitwise identical, all 32 `adxx_*` and all 66
`ADJ*` files bitwise identical, wall time 13:31 vs 14:22 — plus 7 new
`ADJetan` records (one per 5-day dump plus the `nIter0` initialization call,
mirroring TAF's `initialise_varia -> integr_continuity` path), all finite,
zero at the reverse-sweep start and growing with lead as the cost information
propagates backward.

**SOMA received the identical treatment** (validated by run 31033 vs baseline
31031: `fc` = -9.21812947379697E-03, all 32 `adxx_*` and all 55 `ADJ*`
bitwise identical, 6 finite `ADJetan` records). The shared-content files —
`addummy_in_stepping.F`, `addummy_for_etan.F`, `integr_continuity.F`, the
`tap_dummy_*` no-op bodies, `the_main_loop.F` and the rebased option headers —
are byte-identical between the two setups on purpose. Two SOMA-specific
findings from the pass: its `the_main_loop.F` was still a c69f-era copy whose
rebase restored upstream's `COST_DRIVER` call (a runtime no-op in this
configuration — it drives only OBCS/ECCO cost terms — but it pulls
`cost_driver`/`ctrl_cost_*` into Tapenade's differentiated call graph, where
DINO always had them; the bitwise result above shows the numbers are
untouched), and its forward `code/packages.conf` still listed `timeave`,
removed upstream in c69m, so the forward model could not even configure. The
SOMA workflow was aligned with DINO's in the same pass: one submit script per
mode with `IMPACTS_*` overrides, DINO-convention job and run-directory names
(`SOMA_1deg_<mode>_<duration>_run<jobid>`), and a restored forward
build/submit pair (30-day 4-rank smoke run 31034 completes normally).

**Gradient-check coda (2026-09-01).** The repaired DINO finite-difference
check (perturbation moved onto the sensitivity peak, `grdchk_eps=1e-3`;
`input_tap/variants/grdchk_repair/`) **passes at 0.9 %** at the peak point on
the hook build (run 31037), and a control build of the pre-hook (`main`-tip)
mechanism reproduces the entire `grdchk` table digit for digit and all
`adxx_*`/`ADJ*` files bitwise (run 31038) — the hook-generated adjoint and
the hand-patched one are the same object down to the finite-difference
level. SOMA's always-on check passes at 0.07–1.8 % on all five points,
identically on both builds. Details in the root `README.md`, *Verifying
correctness*.

---

*Prepared on branch `tapenade-active-dump-hook` of `tsgonerog/Proj_ImPACTS`
(initial commits `27e4ee5`, `e789533`; merged to `main` 2026-09-01, the
pre-hook base kept as tag `archive/20260831_pre-tapenade-hooks`); validation
runs 31022–31026 on sverdrup, 2026-08-31; §7 validated by runs 31032 (DINO),
31033/31034 (SOMA) and the gradient-check pair 31037/31038. Line references
are to MITgcm checkpoint69m.*
