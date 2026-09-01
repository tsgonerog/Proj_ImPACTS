# DINO at 1/4°

Moving the adjoint programme from the 1° DINO basin to a 1/4° one — from a
configuration where eddies are parameterised to one where they are partly
resolved.

**Status: placeholder.** Nothing is written, nothing is configured, and no
setup exists. This directory is here so the direction has somewhere to
accumulate, not because any of it has been thought through.

## The question

Everything in this repository is the 1° basin: the 200-year spin-up, the
reference adjoint, the perturbation ensemble in
[`../nn_surrogate/`](../nn_surrogate/). At 1/4° the flow is eddy-permitting, so
the state the adjoint linearises about is a different one — more energetic, and
with variability the coarse configuration cannot produce.

That raises three things, none of them answered here:

- **Does the sensitivity structure survive the resolution change?** If the 1°
  sensitivity maps are a good guide to the 1/4° ones, the coarse configuration
  is a cheap laboratory for the fine one. If they are not, that is its own
  result.
- **Does the adjoint stay usable over a five-year sweep?** A more energetic,
  less dissipative flow is the regime where long adjoints are known to
  misbehave. `adjViscBoost` may go from a variant to a requirement.
- **What does it cost?** See the arithmetic below. This is the constraint that
  shapes everything else.

## Naive scaling

Arithmetic, not measurement — a ×4 refinement in each horizontal direction with
the vertical left alone, which is a guess about how the grid would actually be
built.

| | 1° (`DINO_1deg`) | 1/4°, if scaled ×4 |
| --- | --- | --- |
| Grid | 51 × 198 × 36 = 363,528 | 204 × 792 × 36 ≈ 5.82 M cells (16×) |
| Spacing | 1° zonal; meridional follows cos(lat), ~0.35°–1.0°, mean ~0.71° | a quarter of each |
| Timestep | `dT = 1800 s` | ~450 s if advective CFL sets it (4× the steps) |
| Work per model year | — | **≈ 64×** |
| Decomposition | `sNx=17, sNy=22, nPx=3, nPy=9` → 27 ranks | to be chosen; `-n` and `SIZE.h` move together |

The measured 1° figures the ×64 applies to: the 200-year spin-up took 32 h 21 m
for 3,513,600 forward steps on 27 ranks, and the five-year reference adjoint
23 h 03 m. The ×64 is *work*, not wall time — the point of a bigger grid is that
it also takes many more ranks.

**Do not scale the 23 h figure without reading it first.** `useGrdchk = .TRUE.`
in both setups, so that run also paid for the built-in gradient check's
perturbed forward integrations; the master plan puts the same adjoint at about
9 h with the check off. Scaling 23 h rather than 9 h overstates the 1/4° adjoint
by a factor of about 2.5 on the strength of a one-line namelist setting.

The spin-up is the item to look at first. A 200-year spin-up is what makes the
1° work possible, and at 1/4° it is the dominant cost of the whole direction by
a wide margin. Whether it can be shortened, initialised from the 1° state, or
avoided is the first thing worth deciding.

## What it would inherit

Most of the machinery is resolution-agnostic and would carry over: the Tapenade
build path and the `genmake2` patch, `tools/machine_env.sh`, `tools/submit.sh`,
the `code_tap/` + `input_tap/` split, the namelist-variant convention, and the
DINO analysis notebooks, which take their shape from the run directory through
`xmitgcm.open_mdsdataset(read_grid=True)` rather than hardcoding one. Two things
would need editing by hand: the SOMA notebooks carry `sNx/sNy/OLx/OLy/Nr` as
literals, and `analyses/DINO_1deg/02_forward/01_viscosity_study/00_build_viscAhD_binaries.ipynb`
hardcodes `Nx, Ny, Nr = 51, 198, 36`.

## What has to be worked out

Unordered, and certainly incomplete:

- **Input binaries, and `tile001.mitgrid` above all.** `input_binaries/` is
  untracked and produced outside this repository; nothing here regenerates it,
  and unlike SOMA there is no `gendata.py` to fall back on. The horizontal grid
  is not in the namelist at all — `delX` and `delY` are commented out and
  `usingCurvilinearGrid = .TRUE.` reads `input_binaries/tile001.mitgrid`
  instead — so that one 1.3 MB file *is* the grid, and producing a 1/4° version
  of it is the first practical blocker, in concrete form.
- **Grid generation** — whether the curvilinear grid is regenerated or
  interpolated, and whether the vertical stays at 36 levels.
- **Spin-up strategy**, per above.
- **Decomposition and tile size**, and whether the run fits the queue limits
  `PORTING.md` already flags for the 1° spin-up.
- **Adjoint stability** over the intended window, and what viscosity treatment
  it needs.
- **Storage.** The 1° five-year adjoint writes 8.3 GB and the spin-up retains
  47 GB of retained restarts inside an 85 GB run directory. Both scale with the
  cell count.
- **Cost-section indices.** `code_tap/cost_atlantic_heat.F` carries
  `isecbeg/isecend/jsec/kmaxdepth` as compiled-in `parameter` statements, so a
  new grid means recomputing them and rebuilding. This is a second argument for
  the change [`../nn_surrogate/`](../nn_surrogate/) already asks for: move them
  into `data.cost`.
- **A machine.** Whether sverdrup can carry this at all, or whether it forces
  the Perlmutter port that `PORTING.md` describes and nobody has validated.

## Relation to the other direction

[`../nn_surrogate/`](../nn_surrogate/) is scoped entirely at 1°, and nothing
here changes that. The connection runs one way: a surrogate that generalises
across parameters at 1° is interesting; one that transfers to 1/4° would be the
result worth having, and the plan's own limitations list already names the
idealised configuration as a thing not to assume away — though it says nothing
about resolution, which is this direction's question rather than its. Whether the 1/4°
configuration ever becomes a training target or stays a validation target is not
decided.

## Format, and Overleaf

This file is Markdown and stays that way: it is the repo-internal quick read,
and it is where a fact lands first.

**The direction now has one document**, [`scoping_note/`](scoping_note/) — three
pages restating what is above for a reader who will not open a repository. It
takes the shape [`../nn_surrogate/`](../nn_surrogate/) uses: `main.tex` +
`preamble.tex` + `sections/`, numbered in reading order, with `main.tex`
declaring an `\input@path` of `{scoping_note/}{./}` so it builds whether the
project root is its own folder or this one.

```bash
cd notes/directions/dino_quarter_degree/scoping_note
latexmk -pdf -auxdir=build main.tex          # PDF here, intermediates in build/
```

**Derivation runs one way, as it does in the other direction: this README is
authoritative and the note restates it.** A number is established here and
copied there; a correction that arrives on the note belongs here first. The note
carries no measurement that is not already above, which is what keeps the two
from disagreeing.

**This direction is wired to Overleaf through the git bridge**, so the round trip
is two commands, run from the repository root:

```bash
./tools/overleaf_sync.sh pull dino_quarter_degree   # Overleaf -> here; review, rebuild
./tools/overleaf_sync.sh push dino_quarter_degree   # commit first, push sends HEAD
```

The project is [`6a8f360a0c4433896e31b5c3`](https://www.overleaf.com/project/6a8f360a0c4433896e31b5c3).
It holds this README as well as the note, so it cannot be shared with an outside
reader as it stands — send the PDF, or give the note its own project.
**[`../README.md`](../README.md) carries the full workflow.**
