# briefs/

Short, single-topic documents cut from [`../master_plan/`](../master_plan/) for
a reader who is not going to read 31 pages. These are the ones that leave the
repository.

## Four rules

**Three pages maximum, and at most three files in `sections/`.** Both caps are
the point. The page cap forces a choice about what the reader actually needs and
is what makes a brief get read; the file cap keeps a short document from
fragmenting into a dozen scraps that are harder to navigate than the prose they
hold. The header comment in each `main.tex` restates both limits where an editor
will meet them.

The title block rides in `01_`, since it cannot have a file of its own under the
cap. That is the one place briefs differ from the master, which keeps its title
in `sections/01_frontmatter.tex`.

**Derivation runs one way.** The master plan is the only place a claim is
established. A brief restates part of it for a particular reader; it never
asserts anything the master does not support, and it never becomes the place a
number lives. When a correction arrives on a brief it goes into the master
first and reaches the brief on the next pass. A brief that has drifted ahead of
the master is the failure mode this layout exists to prevent.

**No reader is named.** Not in the title block, not in the acknowledgements, not
in a comment. A brief is written to be handed to whoever needs it.

## What is here

Each brief is a directory, not a file — `main.tex` plus `preamble.tex` plus
`sections/`, the same shape as the master and the shape an Overleaf project
takes. They are short enough to be single files; they are split anyway, so that
developing one section means opening one small file and the Overleaf sidebar
reads as a table of contents.

**No file is shared** with the master or between briefs. Each carries its own
preamble and compiles alone. That is what lets one brief go to one reader
without anything else going with it; the cost is that consistency is maintained
by re-reading rather than by `\input`, which is what the table below is for.

| Brief | `sections/` | Derives from | Re-read it when |
| --- | --- | --- | --- |
| [`surrogate_concept_note/`](surrogate_concept_note/) | `01_problem_and_idea`, `02_inputs_outputs_and_loss`, `03_network_and_sketch` | Part II in full, plus **Part I §Objective** for the mixing question and its either-way consequences, plus §Motivation and §Model configuration for the rank count, the adjoint cost and how vertical diffusivity is configured | Part II's inputs, outputs, loss or architecture change; the cost functional moves off 26°N; **§Motivation's measured adjoint cost changes**; **Part I's objective, status, or what the ensemble varies changes** |
| [`perturbation_experiment/`](perturbation_experiment/) | `01_question_and_design`, `02_cost_and_request`, `03_validation_and_decision` | Part I in full, plus §Model configuration | **Anything in Part I moves** — the member table, the cost figures, the sequence, the open questions |
| [`kappa_ensemble_results/`](kappa_ensemble_results/) | `01_question_and_answer`, `02_findings`, `03_surrogate_recommendation` | **Part I §Results** in full (the executed ensemble), plus Part II §Inputs for the κᵥ-as-input recommendation and §Roadmap for the Phase-2 gate | **Anything in Part I §Results moves** — the member/health table, the metric values, the noise floor, the departure leads, the next-steps list; or Part II's input table drops or reshapes the κᵥ channel |

The two are exposed to drift very differently, and it is worth knowing which is
which:

- **The concept note carries almost no measured numbers** — the rank count, the
  five-year adjoint window at roughly a day of wall time, and the cost section's
  latitude. That is deliberate, and it is what keeps it stable: there is very
  little in it that *can* go stale. The grid size used to be here too and was cut
  in an Overleaf round trip, which is the pattern to expect: this list shrinks,
  it does not grow.
- **The perturbation brief is mostly numbers**, because a resource request is
  mostly numbers. It quotes the member table, both cost configurations, the
  storage figure and the request ceiling. It is the brief to re-read first
  whenever Part I is touched.
- **The results brief is a report, and reports mostly stop moving.** It states
  what the executed ensemble measured, so it drifts only if the *analysis* is
  redone (a rerun member, a corrected metric) or if Part II changes what it
  recommends. It is also the one brief allowed **four pages instead of three**
  — set when it was commissioned, because it carries two result figures — and
  the only one with a `figures/` directory: its two PNGs are sources and must
  be committed for the Overleaf zip (`git archive`) to carry them. The four
  interactive HTML animations it cites cannot ride in a PDF and are sent
  alongside it from cluster storage
  (`kappa_v_ensemble_analysis/animations/`).

## Building

```bash
cd notes/nn_surrogate/briefs/<topic>
latexmk -pdf -auxdir=build main.tex          # PDF here, intermediates in build/
```

Each brief has its own `build/`, since they all compile a file called
`main.tex`. Build each in its own folder like this even when the whole direction
is one Overleaf project — compiling from `notes/nn_surrogate/` would write three
different `main.pdf` files over each other at that one level.

A brief goes to Overleaf either on its own or inside the whole-direction upload;
[`../README.md`](../README.md) has the table comparing the two, and
[`../../README.md`](../../README.md) has the pack and bring-back commands. `build/` and the PDFs are gitignored; only the `.tex` is tracked, so
a rendering cannot drift from its source.

The output is `main.pdf` in every brief, which is the cost of the `main.tex`
convention that lets Overleaf pick the root file automatically. Rename it on the
way out — the reader should see the topic, not `main`.

## Adding a brief

Nothing forces the set to stay at two.

1. Copy the shape of an existing brief: `briefs/<topic>/` with `main.tex`,
   `preamble.tex`, and **at most three** files under `sections/`, numbered
   `01_`, `02_`, `03_` and named for what they hold. The title block goes at the
   top of `01_`.
2. `main.tex` holds structure only — `\documentclass`, the `\input@path` block,
   `\input{preamble}`, the `\input` list. **Copy the `\input@path` block**; it is
   what lets the brief build when the project root is `notes/nn_surrogate/`
   rather than the brief's own folder, and a brief without it fails on its first
   `\input` after upload and nowhere before.
3. Open `main.tex` with a header comment giving the scope, the master sections
   it derives from, both caps, and the fact that the master is authoritative.
   Copy the block from either existing brief.
4. Add a row above, including the re-read column. A brief not listed here will
   be missed the next time the master changes.

**Keep `\par` at the front of `\hd`.** A run-in heading at the top of an
`\input` file will otherwise join the previous file's last paragraph — invisible
in the source, obvious in the PDF, and the reason both briefs' preambles carry a
comment about it.

## After the master changes

Read the table, take the briefs whose re-read column matches what moved, and
read them against the master. This is a real step, not a formality: the concept
note has already been corrected once for exactly this reason. Commit `1d125bc`
revised Part II's output heads and label storage, and the note's description of
the loss had to be brought back into line in the same commit — the two documents
were a few hours from disagreeing in front of a reader.

## Sharing, and getting feedback back

**Keep these in LaTeX and send a PDF.** The concept note has a TikZ flowchart,
both are built out of tables, and their compact layout is doing work — that is
precisely the case
[`../../README.md`](../../README.md) reserves LaTeX for. Markdown would cost the
flowchart and gain nothing, since these go to people who read PDFs.

The format and the review channel are separate decisions, and only the second is
worth thinking about:

| Channel | Feedback arrives as | Use it when |
| --- | --- | --- |
| **Overleaf, one project per brief, shared read-and-comment** | anchored comments and tracked changes, in the source | the default, if the institutional licence covers the review features. It is where this field already works |
| **PDF sent directly** | an annotated PDF back, which you transcribe | always works, needs nothing from the reader, no account, no setup. The fallback that never fails |
| **Markdown in the repository** | line-anchored threads, via the repo host | only for a reader already working in this repository, and only for a document with no figure to lose |

Overleaf's comment and track-changes features are not on the free tier, so check
the licence before promising a review loop that depends on them; the PDF route
needs no such check. Either way, say in the covering message what kind of
response is wanted — a judgement on the approach, or line edits — because the
two want different channels and asking for both at once reliably gets neither.

The upload and download mechanics, including the guard that catches a section
deleted in Overleaf, are in [`../../README.md`](../../README.md).
