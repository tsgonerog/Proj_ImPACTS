# Neural-network surrogate for DINO adjoint sensitivities

Planning and proposal material for a project with two parts: a perturbation
ensemble that has to run first to establish whether adjoint sensitivities depend
on vertical mixing at all, and a neural-network surrogate that would predict
those sensitivity fields instead of computing them.

Nothing here is code and nothing builds or runs. These are documents written to
be read, argued with and revised.

## Layout

```
nn_surrogate/
├── master_plan/                     the master -- everything is established here
└── briefs/                          short documents cut from it (3 pages; the
    │                                results brief is allowed 4, for its figures)
    ├── surrogate_concept_note/      Part II, for a first reader
    ├── perturbation_experiment/     Part I, for a reader deciding whether to run it
    └── kappa_ensemble_results/      Part I's results + the kappa_v-as-input recommendation
```

**[`master_plan/`](master_plan/) is authoritative.** Every claim, every measured
number and every design decision lives there. It is the working reference: kept
open while the work is implemented, extended section by section as material is
developed.

**[`briefs/`](briefs/) is derived.** Each brief restates one part of the master
for one audience, asserts nothing the master does not support, and never becomes
the place a number lives. Derivation runs one way, and
[`briefs/README.md`](briefs/README.md) carries the table saying which brief has
to be re-read when which part of the master moves. **A brief is three pages at
most** (the results brief alone is allowed four, for its figures), and **no reader is named** in anything here.

Every document is its own Overleaf project and shares no file with any other —
not a preamble, not a macro file. That is what lets one brief go to someone
without the plan going with it, and it is why consistency is maintained by
re-reading rather than by `\input`. All four are laid out the same way,
`main.tex` plus `preamble.tex` plus `sections/`, so moving between them costs
nothing.

## The master document

**33 pages, two parts plus a results section, laid out as an Overleaf project.** It is a directory, not
a file: `main.tex` holds structure and the prose sits in child files — bar the
short paragraph introducing the appendices, which stays in `main.tex` —
so the Overleaf sidebar doubles as a table of contents and an edit touches one
small file rather than a 2,000-line one.

| File | Contents |
| --- | --- |
| `main.tex` | **The document.** `\documentclass`, the `\input` list, the appendix heading. Compile this one |
| `preamble.tex` | Packages, colours, macros (`\code`, `\kv`, `\ck`), the `callout` environment |
| `sections/01_frontmatter.tex` | Title block and abstract |
| `sections/02_summary_request.tex` | Summary and resource request |
| `sections/03_motivation.tex` | Motivation |
| `sections/04_model_config.tex` | Model configuration — common to both parts |
| **`sections/10_part1_ensemble.tex`** | **Part I, the perturbation ensemble.** Objective, experiment design, measured compute and storage, analysis plan, further ensemble axes, open questions, sequence and decision points |
| `sections/11_part1_results.tex` | **Part I, results of the executed ensemble** (run 2026-08-28/29, analysed 2026-08-30): the member/health table, the noise floor, the adjoint-stability finding, the finite-difference verdict, consequences for Part II, revised next steps |
| `sections/20_part2_surrogate.tex` | Part II, the surrogate design: inputs and outputs channel by channel, normalisation, loss, architecture, training ensemble, validation, risks, roadmap |
| `sections/90_app_reference_values.tex` | Appendix A — reference values |
| **`sections/91_app_running.tex`** | **Appendix B — running the experiment.** Environment, generating the diffusivity files, namelists, submission, the pilot, remaining members, porting. The operational how-to |
| `sections/92_app_verification.tex` | Appendix C — verification before production |
| `sections/93_app_checklist_risks.tex` | Appendices D and E — checklist, risks |

The two bold files are the ones open most while implementing. A reviewer of the
resource request needs Part I and the appendices only — comment out the Part II
`\input` in `main.tex` and the document still compiles without it.

### Numbering

The number is the file's position in the document, so the Overleaf sidebar —
which sorts alphabetically and cannot be reordered — reads in PDF order. Decades
are blocks with deliberate gaps: `0x` front matter (00 and 05–09 free), `1x`
Part I (12–19 free), `2x` Part II (21–29), `9x` appendices (94–99), and 30–89 unused.
Adding a file means a free number in its own block plus one `\input`; removing
one means leaving the hole. Only an insertion between two consecutive numbers
forces a renumber, and it stays inside that decade.

`preamble.tex` sits outside `sections/` and outside the numbering: it is not part
of the document sequence, it is what the document is set in. The rule is restated
at the top of `main.tex`, which is where an editor will meet it.

### Developing a section in detail

The expected way this document grows: a section that has been treated in a
paragraph gets worked out properly, and outgrows the file it is in.

**Split it into its own file in the same decade** rather than letting one child
grow without bound. Part II is currently a single 839-line
`20_part2_surrogate.tex`; if the loss function is developed at length it becomes
`21_part2_loss.tex`, with `20_` keeping what remains and one more `\input` added
to `main.tex`. Nothing outside that decade moves, no cross-reference breaks, and
the Overleaf sidebar still reads in order. Nine free numbers per part is room
for a long time.

Two things to keep true while doing it:

- **`\label`s stay put.** Cross-references are by label, not by file, so moving
  prose between children costs nothing as long as the label travels with the
  text it names.
- **Anything newly measured gets a row** in the provenance table below, saying
  what it was read from. The document's credibility rests on that table.

## Building and editing

```bash
cd notes/directions/nn_surrogate/master_plan          # or any brief
latexmk -pdf -auxdir=build main.tex        # PDF here, intermediates in build/
```

### Two ways to put this on Overleaf

Overleaf compiles from the **project root**, not from the folder the main file
sits in. Every `main.tex` here therefore declares its own `\input@path`, listing
its own folder first and the compilation directory second, which makes the same
source build under either arrangement. **Do not remove that block** — without it
the whole-folder upload fails on the very first `\input`.

| | Upload | Then |
| --- | --- | --- |
| **One project per document** | `master_plan/`, or one brief's folder | Overleaf picks `main.tex` automatically. The project can be shared with a reader, so comments and track-changes work per document |
| **One project for the direction** | all of `nn_surrogate/` | Four documents in one project. Switch between them with the **gear icon, bottom-left → Compiler → main document** and compile each; download and rename each PDF |

The second is one upload instead of four and is the usual arrangement here. Its
cost is that the project itself can never be shared — it carries the master plan
and the internal `README.md` files — so a review loop that depends on Overleaf
comments needs the first arrangement, or a separate project for the brief being
reviewed.

**This direction is wired to Overleaf through the git bridge**, so the round trip
is two commands, run from the repository root:

```bash
./tools/overleaf_sync.sh pull nn_surrogate        # Overleaf -> here; then review and rebuild
./tools/overleaf_sync.sh push nn_surrogate        # commit first, push sends HEAD
./tools/overleaf_sync.sh push nn_surrogate --wip  # or the working tree, committing nothing
```

`--wip` is the one to use while the writing is still moving: it sends the
tracked files as they stand on disk and leaves `HEAD` where it is, so the commit
can wait until the text is settled. Use the plain form once it is, so the
Overleaf log names a commit this repository can be rebuilt from.

The project is [`6a8f28882435332e2f9da280`](https://www.overleaf.com/project/6a8f28882435332e2f9da280).
Authenticating asks for a username: it is the literal word `git`, never your
Overleaf email. **[`../README.md`](../README.md) carries the full workflow**, the
manual zip route it automates, and why that username is the thing that bites.

Either way no file is shared between documents: each carries its own preamble,
and its own `\input@path`, which is what lets any one of them be lifted out and
sent on its own.

`-auxdir=build` is not optional housekeeping — without it every compile drops
`.aux`, `.log`, `.fls`, `.fdb_latexmk`, `.out` and `.toc` beside the sources and
buries them. With it the only thing that appears next to `main.tex` is
`main.pdf`. `build/` is already gitignored by the repository's `**/build*/` rule,
and it does not reach Overleaf, because `git archive --format=zip` packs only
tracked files. Do not pack the folder with `python3 -m zipfile -c` instead,
which would sweep `build/` straight in.

If intermediates do accumulate, `latexmk -c` removes them.

**Three passes, not two, from cold.** The table of contents runs to two pages, so
populating it shifts every page number and needs one more pass to converge. A
warm build with an up-to-date `.toc` settles in one. `latexmk` handles this on
its own and is the safer habit.

## How the two parts of the plan relate

They are sequential, not parallel.

**Part I** is a scoping study. Its primary output is a design answer — whether
adjoint sensitivity patterns depend on vertical mixing — and the training pairs
it produces are a by-product. Its result determines what Part II should be:

- a **flat** response means sensitivities are robust to mixing, which is a
  publishable result on its own and redirects the surrogate towards ocean state
  and cost functional as its varying inputs;
- a **strong** response makes mixing a required network input and justifies the
  larger parameter ensemble that Part II describes.

**This question is now answered: the response is strong** (ensemble executed
2026-08-28/29, analysed 2026-08-30 — the master's Part I Results section,
`sections/11_part1_results.tex`, and the results brief). Two findings the plan
did not anticipate came with it: the adjoint computation itself goes unstable
at four of the seven κ settings, non-monotonically in κ, which bounds how
training data can be generated at strongly perturbed mixing; and the adjoint's
linear ΔJ prediction fails already at the factor-2 members, so the response is
nonlinear from the smallest step tested. The full evidence lives in the
analysis suite at `analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/`.

Eight κ values, the seven members plus the reference, are ample for the first
question and thin for the second. Part II therefore calls for a 200–400 member
ensemble later; Part I does not propose one now.

Part I also produces a second result worth having on its own: a finite-difference
check taken where the sensitivity is large, which would be the first meaningful
validation this adjoint has had.

Three questions bear on both parts and should be settled once for both: the
spatial structure of the perturbation, the surrogate framing (global
field-to-field map against local operator), and the scope of the cost function.

### Three numbering schemes, kept apart

The two documents merged into the plan each used "Phase" for a different thing.
The merged document separates them, and they should not be conflated:

| Term | Means |
| --- | --- |
| **Part I / Part II** | the two halves of `master_plan/main.tex` |
| **Axis 1 / 2 / 3** | the ensemble's parameter axes — vertical diffusivity, ocean state, surface forcing |
| **Phase 0–4** | the project roadmap in Part II's final section. Part I runs inside Phase 1 |

## Numbers in these documents, and where they came from

Every quantitative claim was measured from the DINO tree and from cluster
scratch rather than estimated. The planning numbers, measured 2026-08-21:

| Claim | Source |
| --- | --- |
| 332,274 of 363,528 cells wet (91.4 %) | `hFacC.data` of run 28486 |
| `adxx_diffkr` equals `ADJdiffkr` at the final reverse-sweep dump | correlation 1.000000, median pointwise ratio 1.0000, run 28486 |
| `ADJdiffkr` RMS grows 656× across a 5-year sweep — accumulation, not instability | `ADJdiffkr.*.data`, iterations 3249840 → 3162240 |
| `ADJtheta` *decays* ~5× and `ADJtaux` ~40× over the same sweep; the three classes differ in magnitude by ~10⁵ | `ADJ{theta,taux,diffkr}.*.data`, run 28486 |
| \|∂J/∂κ\| spans ~15 decades; sign split 48.6 / 48.5 % | `adxx_diffkr.0000000000.data`, wet points only |
| Forward 0.0332 s/step; adjoint 0.945 s/step on 27 ranks | `run_timing.txt` of runs 28463 and 28486 |
| 5-year adjoint = 23 h ≈ 622 core-hours, 8.3 GB | run 28486 |
| `useGrdchk` costs 18,622 `FORWARD_STEP` calls for 1,440 timesteps | `STDOUT.0000` timer section, run 30948 |
| All 2,400 spin-up restarts retained, 47 GB (the whole run directory is 85 GB) | run 28463, `du -ch pickup*` |
| Reference κ uniform at 1.2 × 10⁻⁵ m² s⁻¹ | `input_binaries/dino_diffKr.bin`, single unique value |
| Cost section at 26.05 °N, upper 982.4 m | `YC.data` row 127 and `DRF.data`, run 28486 |

The results numbers (master Part I §Results, and the results brief) were
measured on 2026-08-30 by the executed analysis suite at
`analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/` — its notebooks are the
per-number source, and its `stats/*.csv` tables on scratch are the
machine-readable copies:

| Claim | Source |
| --- | --- |
| Member fc values 0.214–0.510, monotonic; REF 0.3310 | `costfunction.0000` of runs 31039–31046 (2026-09-01 hook-build rerun; fc bitwise identical to the original 30995, 31003–31009); `stats/01_*.csv`; notebook 01 |
| Reference chain 28486 ≡ 30995 ≡ 31039 (fc/adxx bitwise; the rerun's ADJ* seam-corrected, ADJetan new); `useGrdchk` off saves 8.2 h/run | md5 comparisons + `run_timing.txt`, notebooks 01/02 |
| Noise floor σ = 0.007 (annual) / 0.012 (instantaneous) | J-proxy over 2,402 spin-up-30983 pickups (`build_jproxy.py`), notebook 01 |
| Stable-member metrics (corr 0.82/0.85, amp ×1.37/×0.77; ADJdiffkr corr 0.21 at 2×; ∂J/∂κ sums −251/−436/−78/+673) | `cache/member_metrics_time.nc`, `cache/adxx_fields_3d.nc`; notebooks 04/07 |
| Blow-up departure leads 0.36/0.70/1.28/2.55 yr; burst e-folds 1–3 d; Southern Ocean seeds; 62 % usable dumps | `stats/06_blowup_departure_table.csv`, `stats/07_training_data_budget.csv`; notebook 06 |
| Linear ΔJ prediction: wrong sign 4/7, none within 30 % | `cache/dJ_decomposition.csv`; notebook 01 |
| fc is a terminal-30-day mean; per-MPI-tile normalisation (decomposition-dependent) | `pkg/cost` source + proxy validation (fc reproduced within 3–19 %), notebook 01 |
| Six control gradients identically zero (`xx_uvel/vvel`, four wind controls) | `cache/adxx_fields_*.nc`, notebook 02 |

## Prerequisites the plan identifies

Worth doing whether or not the surrogate is ever built:

- **repair the gradient check** — move it to `iGloPos=2, jGloPos=127, kGloPos=26`
  with `grdchk_eps` around `1e-3`. At its current point it cannot pass and never
  has, which means the adjoint underlying all of this is not currently verified by
  anything in the repository;
- **set `useGrdchk = .FALSE.`** for ensemble members and measure the saving. It is
  the largest single cost lever available;
- **promote the cost-section indices** (`isecbeg`, `isecend`, `jsec`, `kmaxdepth`)
  out of `parameter` statements in `code_tap/cost_atlantic_heat.F` and into
  `data.cost`, so the cost functional becomes a namelist setting rather than a
  rebuild;
- **pin a Python environment** — the repository has no dependency manifest.

## Not stored here

- **Model configuration and source** — this repository, at
  `MITgcm_c69m/mysetups/DINO_1deg/`
- **Model output** — cluster scratch, `/scratch2/<user>/DINO_1deg_{frd,tapAdj}_runs/`
- **Input binaries** — `input_binaries/` is untracked and produced outside this
  repository; see the root `README.md`
