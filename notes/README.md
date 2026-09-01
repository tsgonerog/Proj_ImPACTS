# notes/

Prose only — nothing here builds or runs. Two kinds of material live here, kept
apart because they answer to different standards:

- **Directions** — proposals for work this project might take on. Nothing in one
  is a commitment to do it.
- **Practical references** — how a workflow that *has* run actually works, so it
  can be reproduced. These describe fact, so a claim in one is either true of the
  repository today or marked as superseded.

## Directions

One subdirectory per direction, each carrying its own `README.md` that says what
the direction is and how its documents relate.

| Direction | The question | Status |
| --- | --- | --- |
| [`nn_surrogate/`](nn_surrogate/) | Can a neural network predict DINO adjoint sensitivity fields instead of computing them? Includes the vertical-mixing ensemble that has to run first to decide what the surrogate should be | Part I complete and analysed (2026-08-30): strong κ_v response — mixing is a required surrogate input, and four of seven member adjoints blow up. Results in the master's Part I §Results and the `kappa_ensemble_results` brief; evidence in `analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/`. The surrogate itself is proposed, nothing built |
| [`dino_quarter_degree/`](dino_quarter_degree/) | What does moving DINO from 1° to 1/4° — from parameterised eddies to partly resolved ones — change about the adjoint, and what would it cost? | Placeholder — a three-page scoping note, nothing configured |

## Adding a direction

Make `notes/<direction>/`, put a `README.md` in it, add a row above. Name the
directory after the question rather than the method, so it survives a change of
approach. Keep each direction's material inside its own directory; a note that
bears on two of them lives with whichever direction owns the decision and is
cited from the other.

## Practical references

Workflow how-tos, written after the fact from a run that happened. Same
one-subdirectory-plus-`README.md` shape as a direction; the difference is that
these document what was done rather than what might be.

| Reference | Covers |
| --- | --- |
| [`slurm_job_chaining/`](slurm_job_chaining/) | Making one job wait for another with `--dependency`, and running a follow-on step automatically when a job finishes. Worked from the κ_v ensemble submitted 2026-08-28 |
| [`tapenade_hooks/`](tapenade_hooks/) | Change note on replacing the TAF hook directives with Tapenade-native active-argument hooks (`ADJ*` + `ADJetan` dumps, adjViscBoost mode switching): the gap, the mechanism, a file-by-file comparison, bitwise validation, and upstream-MITgcm considerations; §6–7 add the SOMA conversion, the additive upstream+append file re-layout of both setups' `code_tap/`, and the DINO/SOMA workflow alignment. Written 2026-08-31 for advisor/MITgcm review; a styled HTML copy sits beside the README |
| [`adxx_vs_adj/`](adxx_vs_adj/) | What the two sensitivity outputs of a Tapenade adjoint run mean: `adxx_*` control gradients vs `ADJ*` adjoint-state dumps — who writes each (call path), when, how the iteration numbers read, the measured `adxx` ≈ final-`ADJ`-dump equivalence, and which output to use for gradients vs animations. DINO 5-yr window as the worked example. Written 2026-09-01; a styled HTML copy sits beside the README |

Keep these honest about their own scope: name the machine and the scheduler
version they were verified on, and say plainly when something documented is the
weaker of two approaches rather than the recommended one.

## Master and briefs

A direction that produces more than one document splits them by authority, not
by topic: **`master_plan/`** holds the one document where every claim and every
number is established, and **`briefs/`** holds short single-topic documents cut
from it for readers who get one part rather than all of it.
`nn_surrogate/` does this and its
[`briefs/README.md`](nn_surrogate/briefs/README.md) carries the mechanism —
a table saying which brief must be re-read when which part of the master moves.

**A brief is three pages at most, in at most three section files.** Both caps
are the point: the first forces a choice about what the reader needs, and the
second keeps a short document from fragmenting into scraps. Past three pages it
is not a brief, and the material belongs in the master.

Derivation runs one way. A correction that arrives on a brief goes into the
master first and reaches the brief on the next pass; a brief that has drifted
ahead of the master is how two documents end up quoting different numbers to
different people. **No reader is named in a document that leaves the
repository** — not in the title block, not in a comment.

## Which format

**Markdown by default; LaTeX only for a document that leaves the repository as a
PDF.** The dividing line is audience, not length. A note renders on GitHub, diffs
a sentence at a time and needs no build; LaTeX earns its cost when something
needs equations, cross-references, a table of contents or a drawn figure and goes
to a reader as a PDF. Do not write a note in `.tex` merely because this folder
already contains some — that puts a compile loop in front of a scratchpad.

A note that grows into something to send out converts once, `pandoc note.md -o
doc.tex`, and the `.tex` is the source from then on. Never maintain one document
in both formats.

## LaTeX conventions

These apply to the documents only; a Markdown note needs none of them.

- **One Overleaf project per document, and no file shared between documents.**
  A document is a directory rather than a file — `main.tex` plus `preamble.tex`
  plus `sections/`, the shape an Overleaf project takes, so the directory maps
  one to one onto the project tree. It is still one document. Length is not the
  test: `nn_surrogate/master_plan/` is 31 pages and each brief beside it is two,
  and all of them are split, because developing one section should mean opening
  one small file and because the Overleaf sidebar then reads as a table of
  contents. Two documents sharing a preamble or a macro file cannot be shared
  with different readers, and that is the property worth protecting.
- **`main.tex` is the only file with `\documentclass` in its own document**,
  which is how Overleaf picks it when that document is a project on its own.
  Children carry a comment saying they are `\input`, not compiled alone.
- **Every `main.tex` declares an `\input@path`**, listing its own folder and
  then `./`:

  ```latex
  \makeatletter
  \expandafter\edef\csname input@path\endcsname{{<doc-folder>/}{./}}
  \makeatother
  ```

  Overleaf compiles from the **project root**, not from the folder the main
  file sits in, so without this a document only builds when its own folder is
  the root. With it the same source builds both ways — as its own project, and
  as one of several in a whole-direction project. **Do not remove it**; the
  failure it prevents appears only after upload, at the first `\input`.
- **Only the `.tex` files are tracked.** `.pdf` and the LaTeX intermediates under
  `notes/` are gitignored, so a rendering cannot drift from its source.
- **Compile with `latexmk`**, which runs as many passes as it takes. Two is not
  always enough: a table of contents that spans a page boundary shifts every page
  number when it appears, and needs a third pass to converge. TinyTeX is on
  `PATH` via `~/.bashrc`; see `~/tools_and_software/TinyTeX/INSTALL_NOTES.md`.

  ```bash
  latexmk -pdf -auxdir=build <doc>.tex
  ```

  **Always pass `-auxdir=build`.** LaTeX writes four to six intermediate files
  per document — six for the master, which has a table of contents and
  bookmarks; four for a brief, which has neither — and they otherwise land
  beside the sources. `build/` is already
  ignored by the repository's `**/build*/` rule, so nothing further is needed —
  and putting the setting in a `latexmkrc` instead is deliberately avoided,
  because that file would upload to Overleaf and interfere with its own build.
  `latexmk -c` cleans up if intermediates ever accumulate.

### Overleaf round trip

**The unit of upload is a direction, not a document.** `notes/<direction>/` goes
up as one Overleaf project holding every document in it; you switch between them
with the **gear icon at the bottom-left corner** — the bottommost icon in that
narrow rail — then **Compiler**, where *the primary file for compiling your
project* is chosen. Compile each in turn. **Not** Menu → Settings, which is the
obvious place to look and the wrong one. That is one upload instead of three and
it is the arrangement these documents are set up for.

It works only because **Overleaf compiles from the project root, not from the
folder the main file sits in**, and every `main.tex` here declares an
`\input@path` listing its own folder and then `./`. That block is load-bearing:
without it the upload fails on the very first `\input`. See the LaTeX
conventions above.

The cost is that the project cannot be shared — it carries the master and the
repo-internal `README.md` files. **Sharing PDFs is fine; sharing the project is
not.** If a reader needs to comment in Overleaf, give that one document its own
project instead: the `{./}` half of every `\input@path` means a single document
folder still uploads and builds on its own, unchanged.

A direction with no `.tex` in it has nothing to upload — it stays on GitHub
until it grows a document. Both directions now have one, so this is a rule for
whatever comes next rather than a description of anything here.

#### Automated, through Overleaf's git bridge

Every Overleaf project is also a git remote, which turns this whole round trip
into two commands. `tools/overleaf_sync.sh` wraps it, and works for **any**
`notes/<direction>/` once the direction is mapped to a project id:

```bash
./tools/overleaf_sync.sh status <direction>       # what differs, in both directions
./tools/overleaf_sync.sh pull   <direction>       # Overleaf     -> working tree
./tools/overleaf_sync.sh push   <direction>       # repo HEAD    -> Overleaf
./tools/overleaf_sync.sh push   <direction> --wip # working tree -> Overleaf, no commit
```

**`status` compares `HEAD`, not your working tree**, because `HEAD` is what a
push would send. So an edit you have made but not committed does not count as a
difference, and the headline line can read *identical content* while your own
change sits unsent. It says so underneath when that is the case:

```
  ok    repo HEAD and Overleaf hold identical content
  note  uncommitted here, and NOT part of the comparison above:
         M notes/<direction>/<file>
```

Commit, then push. The same rule is why `push` refuses outright on a dirty tree.

**`--wip` is the way out of that when you are still drafting.** Overleaf's git
bridge does need a commit, but that commit lives in the mirror clone, which is a
separate repository — nothing about the bridge requires one here. `push --wip`
sends the tracked files as they stand on disk, commits in the mirror alone, and
leaves `HEAD` where it was, so the commit here can wait until the writing is
settled instead of being made thirty times on the way there. `status` notices:
when the tree is dirty it reports the tree against Overleaf as well as `HEAD`,
since after a `--wip` push `HEAD` is *meant* to differ.

Use the plain form when the push is the delivery — a reader is about to open the
project — so that what they see is something this repository can reproduce.
`Sync from <sha>` in the Overleaf log is what makes that true, and `--wip` says
`WIP from <sha>+` precisely so it cannot claim a commit the content is not in.

The cost is that `pull` stops being harmless. Under commit-first, everything a
pull deletes is in a commit and `git checkout` brings it back; once real work
lives uncommitted in the tree, it does not. So a pull that finds a dirty tree
snapshots it to `refs/overleaf-prepull/<direction>` first and says so:

```bash
git diff refs/overleaf-prepull/<direction> -- notes/<direction>      # what the pull changed
git checkout refs/overleaf-prepull/<direction> -- notes/<direction>  # to put it back
```

The ref is overwritten by the next pull of that direction, so it is a safety net
for the pull you just ran, not an archive.

`<direction>` is the folder name, and the four forms tab-completion is likely to
produce all mean the same thing:

```bash
nn_surrogate     nn_surrogate/     notes/nn_surrogate/     ./notes/nn_surrogate
```

Currently mapped: **`nn_surrogate`** and **`dino_quarter_degree`**. A name that
is wrong in either of the two possible ways says which:

```
FAIL  no such direction: notes/nn_surrogat            <- no such folder
FAIL  no Overleaf project mapped for 'x' — add it to project_url() in this script
```

so a typo cannot sync the wrong project, and a real direction that nobody has
mapped yet says exactly what to do about it.

It automates the manual procedure below step for step and keeps its safety
properties, so read that at least once — what the script does is not magic, and
the failure it exists to prevent is described there.
`./tools/overleaf_sync_selftest.sh [direction]` checks that it still does, in 25
assertions against a throwaway repository standing in for Overleaf; it needs no
credential and never contacts overleaf.com.

##### First time on a machine: authenticate

The git bridge needs a **git token**, not your account password. Generate one at
Account Settings → **Git Integration**. The first sync then prompts once:

```
Username for 'https://git.overleaf.com': git
Password for 'https://git@git.overleaf.com': <paste the token>
```

**The username is the literal word `git`, not your Overleaf email.** This is the
one thing worth remembering on this page. Overleaf keys on that field, so any
other value is refused with

```
remote: Overleaf now only supports Git authentication tokens to access git.
fatal: ... The requested URL returned error: 403
```

— which is *the same error you get for using a password*, and it fires even when
the password field holds a valid token. Verified 2026-08-26: one identical token
succeeded as `git` and 403'd as the account email. If you are looking at that
message with a token in hand, the username is why, and regenerating the token
will not help.

**On sverdrup this is already set up, host-scoped:**

```bash
git config --global credential.https://git.overleaf.com.helper store
```

Scoping it to `git.overleaf.com` rather than setting `store` globally means the
Overleaf token is the *only* credential that lands in plaintext; everything else
keeps the global `cache --timeout=86400`. The file is `~/.git-credentials`,
mode `600`. The token never belongs in this repository.

The plain `cache` helper was tried first and proved unreliable here — the daemon
survives but its entry does not, and a prompt reappears mid-session. More to the
point, **a stored credential is what lets the sync run without a terminal at
all**: from a script, a batch job, or an agent session, where there is no TTY to
answer a prompt and git fails with `could not read Username ... No such device or
address` before it ever reaches the network.

**After rotating the token**, clear the stored one and re-authenticate:

```bash
printf 'protocol=https\nhost=git.overleaf.com\n\n' | git credential reject
./tools/overleaf_sync.sh status <direction>   # prompts once; username is still `git`
```

##### Day to day

Bringing Overleaf's edits down. **Run these from the repository root** — the
script resolves the root from its own location, so it works from anywhere, but
the `./tools/` prefix is a relative path and only resolves at the top. From a
subdirectory, give the full path instead:

```bash
./tools/overleaf_sync.sh status <direction>   # see what differs before deciding
./tools/overleaf_sync.sh pull   <direction>   # Overleaf -> working tree, unstaged
git diff notes/<direction>                    # read every change
cd notes/<direction>/<doc> && latexmk -pdf -auxdir=build main.tex   # REBUILD
cd -                                          # back to the repository root
git add notes/<direction> && git commit       # then, and only then, commit
```

Sending yours up is one command, because `push` sends `HEAD`:

```bash
git commit -am "..."                          # commit first — push sends HEAD
./tools/overleaf_sync.sh push <direction>
```

While the writing is still moving, `--wip` sends the working tree instead and
commits nothing here:

```bash
./tools/overleaf_sync.sh push <direction> --wip   # edit in Overleaf, pull, repeat
git commit -am "..."                              # once, when it is settled
./tools/overleaf_sync.sh push <direction>         # and the log records the sha
```

To abandon a pull and put everything back:

```bash
git checkout -- notes/<direction> && git clean -fd notes/<direction>
```

From somewhere else in the tree, the script still works — only the prefix
changes:

```bash
cd notes/<direction>/<doc>
/home/tshahriar/Proj_ImPACTS/tools/overleaf_sync.sh status <direction>
```

The rhythm that avoids every conflict: **pull before you edit in Overleaf, push
after you commit here.** Overleaf is the working copy; the repository is the
record.

##### Adding a direction

**The bridge cannot create an Overleaf project.** It attaches to one that already
exists, by id, and Overleaf exposes no public API for creating projects — so the
first step happens in a browser and nothing here can do it for you. Everything
after it is two commands.

1. **Create the project.** Pack the direction with the `git archive` command
   under **Out** below, then Overleaf → **New Project → Upload Project**. A
   direction with no `.tex` in it has nothing worth uploading yet: a project
   holding only Markdown has no `\documentclass` for Overleaf to find and will
   not compile.
2. **Copy the id out of the URL** —
   `https://www.overleaf.com/project/`**`6a8f28882435332e2f9da280`** — into
   `project_url()` in `tools/overleaf_sync.sh`:

   ```bash
   case "$1" in
       nn_surrogate)        echo "https://git.overleaf.com/6a8f28882435332e2f9da280" ;;
       dino_quarter_degree) echo "https://git.overleaf.com/6a8f360a0c4433896e31b5c3" ;;
       <new_direction>)     echo "https://git.overleaf.com/<its id>" ;;
       *)                   return 1 ;;
   esac
   ```
3. **`pull` first, before any push.** The script refuses the first push against
   a project it has never synced, because that is exactly when a push would
   flatten whatever the project already held. Pulling establishes what Overleaf
   has; after that pushes run freely.
4. **Check it compiles the way Overleaf will** — from the project root, not the
   document folder:

   ```bash
   ./tools/overleaf_sync.sh status <direction>     # confirms the upload was faithful
   ```

   then build once from the direction root to prove the `\input@path` resolves.
   A missing `\input@path` fails only after upload, at the first `\input`.

##### What it will not do

- **Push over Overleaf edits you have not pulled.** The script records which
  Overleaf commit this machine last saw, in either direction; a push that would
  revert work written in Overleaf stops with the count and the log. `--force`
  overrides, and is right only when Overleaf holds nothing worth keeping.
- **Push a dirty tree without being asked to.** `push` sends `HEAD`, so it
  refuses when `notes/<direction>/` has uncommitted changes rather than shipping
  something other than what you are looking at. `--wip` is how you ask, and it
  sends the working tree rather than `HEAD`.
- **Send anything untracked, in either mode.** `build/` and the PDFs stay here.
  `--wip` changes which *version* of the tracked files goes up, never which
  files.
- **Commit or rebuild for you** after a pull. Both are yours, and the rebuild is
  not optional — see the warning under **Back**.
- **Send anything untracked.** `build/`, the PDFs and any stray file stay here.

The mirror clones live in `~/.overleaf_mirrors/<direction>/`, outside this
repository on purpose. Deleting one costs nothing; the next command re-clones it.

**Why a mirror clone and not a git remote.** Overleaf's project root is
`notes/<direction>/`, not this repository's root, so the two trees do not line up
and `git remote add` cannot work. `git subtree` would bridge that but is not
installed with this git, and its synthetic history fights the bridge's own. A
plain clone per direction sidesteps both: it holds Overleaf's history, this
repository holds its own, and neither has to understand the other.

**Overleaf's history is a single commit**, labelled `Update on Overleaf.` — the
bridge presents project state, not per-edit history. It can tell you *what*
differs, never who changed which line when. The repository's own history is the
only record of that, which is the argument for pulling and committing often
rather than letting Overleaf drift ahead.

The manual route below does the same thing by hand. It needs nothing from
Overleaf beyond a download, so it is the fallback whenever the bridge is not
available — and it is what the script automates.

#### Out

**sverdrup has no `zip` binary.** Use `git archive`, which is better anyway: it
packs the committed state, only tracked files, and roots the archive wherever
you point it.

```bash
git archive --format=zip -o ~/<direction>.zip HEAD:notes/<direction>
```

Then Overleaf → **New Project → Upload Project**.

Three things that command gets right, each of which is a real failure if you do
it by hand:

- **`HEAD:notes/<direction>` strips the prefix**, so the zip's top level is
  `master_plan/`, `briefs/`, `README.md`. Writing `HEAD notes/<direction>`
  instead — a space, not a colon — leaves every entry under a
  `notes/<direction>/` wrapper, and then the project root is two levels too high
  and every `\input@path` misses. The symptom is exactly the error the
  `\input@path` exists to prevent: `File 'preamble.tex' not found`.
- **Only tracked files are packed**, so `build/` and the PDFs stay behind
  without needing an exclude list.
- **It packs `HEAD`, not your working tree.** Uncommitted edits do not reach
  Overleaf. Commit first, or your reader reviews stale text and the diff on the
  way back makes no sense.

#### Back

**Menu → Download → Source.** There is no `unzip` on sverdrup either; use
Python's. Run from the repository root:

```bash
git status --short notes/<direction>                                # must be empty before you start
git ls-files -z notes/<direction> | xargs -0 rm -f                  # delete the tracked files first
python3 -m zipfile -e ~/Downloads/<project>.zip notes/<direction>   # unpack the download in their place
git status --short notes/<direction>                                # M / D / ?? — the review
git diff notes/<direction>                                          # read it before you commit
```

**Line 2 is the whole point and it is the step everyone skips.** Unpacking over
a directory overwrites and adds but never deletes, so a section removed in
Overleaf silently survives on disk, keeps being `\input`, and shows up in no
diff at all. Deleting the tracked files first makes git report the removal as
` D`. Nothing is at risk: git has every one of them.

Then **rebuild before you commit** — this is not optional:

```bash
cd notes/<direction>/<doc> && latexmk -pdf -auxdir=build main.tex
```

Overleaf ships full TeX Live; the local TinyTeX is a minimal install of about
125 packages. `siunitx`, `cleveref`, `biblatex` and `subcaption` are among those
**not** present here. A collaborator who adds one gets a clean compile in
Overleaf and hands you source that will not build on sverdrup until
`$TEXLIVE_HOME/bin/x86_64-linux/tlmgr install <pkg>`. The risk runs one way,
Overleaf → local, and a rebuild is how you find it.

To abort and put everything back:

```bash
git checkout -- notes/<direction> && git clean -fd notes/<direction>
```

**Never add `-x`.** `git clean -fd` deliberately spares ignored files, so your
`build/` directories and built PDFs survive; `-fdx` would delete every one of
them.

#### Four things that will bite

- **A `.pdf` figure added in Overleaf vanishes silently.** `notes/**/*.pdf` is
  gitignored, so it does not even appear as `??` in `git status` — it is never
  committed, the next `git archive` omits it, and the re-uploaded project loses
  the figure and stops compiling. Use `.png` or `.jpg` for figures under
  `notes/`. Latent today, since no document here loads `graphicx`.
- **Building from the direction root collides.** All three documents are called
  `main.tex`, so compiling them with the direction folder as the working
  directory writes `main.pdf` there three times over. Build each in its own
  folder — `cd <doc> && latexmk -pdf -auxdir=build main.tex` — which is the
  habit anyway.
- **`rm -f` leaves empty directories** where a whole document was deleted in
  Overleaf. Git does not track directories so the status is still correct; clear
  the skeletons with `find notes/<direction> -type d -empty -delete`.
- **`git checkout --` only reverts unstaged changes.** The sequence above stages
  nothing, so it works as written — but if you have already run `git add`, you
  need `git checkout HEAD -- notes/<direction>` and an unstage.
