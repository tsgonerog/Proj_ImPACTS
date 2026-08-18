# analyses/

Jupyter notebooks that read MITgcm run output from cluster scratch
(`/scratch2/<user>/...`) and produce the diagnostics and figures for this
project. Nothing here reads from the repository itself — the model output lives
outside git.

## Layout

```
analyses/
├── DINO_analyses/                    primary configuration (51 x 198 x 36)
│   ├── exploring_DINO_grids.ipynb        locates cost-function section indices
│   ├── getting_started_visualizing_*     entry point for new readers
│   ├── 01_forward_analysis/              forward runs: MOC, AMOC timeseries
│   │   ├── archive/                        superseded / crashed-run notebooks
│   │   └── experimenting_with_viscosity/   PARM01 vs PARM05 viscosity study
│   └── 02_adjoint_analysis/              adjoint sensitivity (ADJ* fields)
│       ├── archive/                        earlier exploratory runs
│       └── temp/                           short-duration scratch runs (30d, 5yr)
├── SOMA_analyses/                    secondary configuration (62 x 62 x 31)
├── resource_notebooks/               collaborator reference notebooks
└── tools/
    └── strip_animation_outputs.py    keeps notebooks under GitHub's size limit
```

Directory names are referenced by **absolute path** inside several notebooks
(the cells that write animation frames), so renaming a directory here means
editing those cells too.

## Notebook size discipline

`matplotlib`'s `anim.to_jshtml()` embeds *every frame of an animation as a
separate base64 PNG* in a single `text/html` output. Eight such animations were
enough to make one notebook 228 MB — past GitHub's hard 100 MB per-file limit,
which blocks the push outright.

Before committing notebooks that contain animations, run:

```bash
python3 analyses/tools/strip_animation_outputs.py            # whole tree
python3 analyses/tools/strip_animation_outputs.py --dry-run  # report only
```

It removes only oversized animation payloads and leaves static figures in place,
so the plots still render on GitHub. Each stripped output is replaced by a note
saying what was removed and that re-running the cell regenerates it. This took
the tree from 591 MB to 40 MB.

## What is deliberately not in git

Regenerable output is gitignored but kept on disk (see the `analyses/` block in
the root `.gitignore`):

| Ignored | Size | Regenerate by |
| --- | --- | --- |
| `*.html` animation exports | 218 MB | re-running the exporting cell |
| `*.gif` animations | 68 MB | assembling the frame directories |
| `moc_anim*/`, `adj_*_z14/`, `poster_frames/` | 90 MB | re-running the frame-writing cells |
| `.ipynb_checkpoints/` | 420 MB | Jupyter recreates these automatically |
| `.~*` editor autosaves | — | never wanted; one was a corrupt 155 MB file |

Standalone result figures kept directly in `01_forward_analysis/`
(`amoc_adjoint_schematic.png`, `moc_density_space.png`, the AMOC timeseries
PNGs, …) **are** tracked — they are small and are referenced as results rather
than being animation intermediates.
