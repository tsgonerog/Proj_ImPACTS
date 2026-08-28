# Chaining SLURM jobs

How to make one job wait for another, and how to make something run
automatically once a job finishes. Written from the vertical-mixing (κ_v)
ensemble submitted on 2026-08-28, which is the worked example throughout.

Unlike the rest of `notes/`, this is not a proposal — it documents a workflow
that ran. Commands here are the ones actually used, on **sverdrup, SLURM
23.11.6**.

---

## 1. The problem

Each ensemble member is two jobs that must run in order:

```
forward leg 2170 -> 2180   writes pickup.0003162240
        |
        v
5-yr adjoint 2180 -> 2185  reads that pickup
```

The adjoint cannot start until the forward leg has written its pickup. Three
ways to arrange that:

| Approach | Verdict |
| --- | --- |
| Submit the forward legs, wait, submit the adjoints by hand | Works, but needs you present ~1 h 40 m later, ×7 |
| One job that runs both | Wastes the adjoint's walltime request on the forward leg, and a forward crash burns the whole allocation |
| **Submit both now, tell SLURM the second waits for the first** | What was done |

The third is `--dependency`. Both jobs enter the queue immediately; the
scheduler holds the second in `PD` (pending) until its condition is met, then
runs it on its own. Nothing has to stay connected — the scheduler is the thing
that remembers.

---

## 2. What was actually done

### 2.1 The forward legs

Seven independent jobs, no dependencies:

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
for n in 1 2 3 4 5 6 7; do
  out=$(IMPACTS_TEST_CASE=kappa_v_ensemble/M$n ../../../tools/submit.sh submit_frd.sh 2>&1 | tail -1)
  id=$(echo "$out" | grep -oE '[0-9]+$')
  echo "M$n forward: job $id"
done
# -> 30996 30997 30998 30999 31000 31001 31002
```

`IMPACTS_TEST_CASE=kappa_v_ensemble/M$n` selects
`input/variants/kappa_v_ensemble/data_M<n>` without editing a tracked file. A
tag containing `/` names one member of an experiment directory; a bare tag names
a flat `variants/data_<tag>`. See the setup README.

(These runs were submitted before the variants were grouped, when the tag was a
bare `M$n`. The job ids and results are unchanged; only the tag spelling moved.)

### 2.2 The adjoints, each waiting on its own forward leg

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
declare -A FWD=( [1]=30996 [2]=30997 [3]=30998 [4]=30999 [5]=31000 [6]=31001 [7]=31002 )
REFDIR='DINO_1deg_frd_200yr_from_rest_visc2x_run30983'
cur="$REFDIR"
for n in 1 2 3 4 5 6 7; do
  mdir="DINO_1deg_frd_10yr_M${n}_run${FWD[$n]}"

  # point the hardcoded pickup symlink at THIS member's forward run
  sed -i "s|DINO_1deg_frd_runs/${cur}/pickup.0003162240|DINO_1deg_frd_runs/${mdir}/pickup.0003162240|g" \
      submit_tapAdj.sh
  grep -c "DINO_1deg_frd_runs/${mdir}/pickup.0003162240" submit_tapAdj.sh | grep -qx 2 \
      || { echo "EDIT FAILED for M$n"; exit 1; }

  out=$(IMPACTS_TEST_CASE=kappa_v_ensemble/M$n ../../../tools/submit.sh submit_tapAdj.sh \
          --dependency=afterok:${FWD[$n]} 2>&1 | tail -1)
  echo "M$n adjoint: job $(echo "$out" | grep -oE '[0-9]+$')  (afterok:${FWD[$n]})"
  cur="$mdir"
done

# restore the committed default: reference adjoint reads the spin-up pickup
sed -i "s|DINO_1deg_frd_runs/${cur}/pickup.0003162240|DINO_1deg_frd_runs/${REFDIR}/pickup.0003162240|g" \
    submit_tapAdj.sh
# -> 31003 31004 31005 31006 31007 31008 31009
```

Three things in there are worth separating out.

**`--dependency=afterok:<jobid>` is the whole mechanism.** Everything else is
this setup's own bookkeeping.

**Why the `sed` loop exists.** `submit_tapAdj.sh` carries the pickup as a
hardcoded `ln -s`, and `nIter0` lives in the namelist variant — the two are
coupled by hand and neither is auto-patched (see `CLAUDE.md`). Each member's
adjoint must read *its own* forward leg's pickup, so the line is rewritten
before each submission. The `cur` variable chains because each `sed` replaces
the path the previous iteration wrote, and the final `sed` puts the committed
default back so the working tree is left as it was found. The `grep -qx 2`
asserts the edit landed — `sed` exits 0 when it matches nothing, which would
otherwise submit seven jobs all reading the same wrong pickup.

**The submission is read at submission time, but the script body runs at start
time.** `sbatch` spools a copy of the script when you submit, so the rewritten
`ln -s` is captured then and later edits cannot disturb a queued job. That is
what makes rewrite-submit-rewrite-submit safe. (It is also why the duration
`sed` inside the submit scripts patches the *staged* namelist in the run
directory rather than the tracked one — same hazard, opposite direction.)

### 2.3 It worked

All seven forward legs finished in ~1 h 40 m each with 27 `NORMAL END`, the
dependencies cleared, and all seven adjoints started on their own and staged
the correct member pickup and κ file:

```
M1 adj=31003  pickup<-DINO_1deg_frd_10yr_M1_run30996 [resolves]  dino_diffKr_M1.bin
...
M7 adj=31009  pickup<-DINO_1deg_frd_10yr_M7_run31002 [resolves]  dino_diffKr_M7.bin
```

---

## 3. The reusable pattern

Strip away this setup's specifics and job chaining is three lines. Use
`--parsable`, which makes `sbatch` print **only** the job id instead of
`Submitted batch job 12345` — verified to pass through `tools/submit.sh`:

```bash
# A then B then C
A=$(sbatch --parsable stage_a.sh)
B=$(sbatch --parsable --dependency=afterok:$A stage_b.sh)
C=$(sbatch --parsable --dependency=afterok:$B stage_c.sh)
echo "chain: $A -> $B -> $C"
```

Fan-out, one pair per member — the ensemble's shape:

```bash
for n in 1 2 3 4 5 6 7; do
  fwd=$(IMPACTS_TEST_CASE=kappa_v_ensemble/M$n ../../../tools/submit.sh submit_frd.sh --parsable)
  adj=$(IMPACTS_TEST_CASE=kappa_v_ensemble/M$n ../../../tools/submit.sh submit_tapAdj.sh \
          --parsable --dependency=afterok:$fwd)
  echo "M$n: forward $fwd -> adjoint $adj"
done
```

Fan-in — one job that waits for *all* of several (colon-separated):

```bash
ALL=$(IFS=:; echo "${JOBIDS[*]}")          # "31003:31004:31005:..."
sbatch --dependency=afterok:$ALL analyse_ensemble.sh
```

**In this repository, always submit through `tools/submit.sh`, not bare
`sbatch`.** It adds the per-machine account/QOS/constraint flags from
`tools/machine_env.sh`. Extra arguments are placed **before** the script name,
which is what makes `--dependency` and `--parsable` work through it; anything
after the script name would be passed to the script instead. Confirmed:

```
submit  : sbatch  --export=ALL --test-only --parsable submit_frd.sh
```

---

## 4. The dependency types

`--dependency=<type>:<jobid>[:<jobid>...]`

| Type | Runs when the dependency… |
| --- | --- |
| `afterok:A` | finished **successfully** (exit 0). **The default choice for a data chain** |
| `afterany:A` | finished, success or failure. Use for cleanup/reporting that should run regardless |
| `afternotok:A` | **failed**. Use for a salvage or notification step |
| `after:A` | merely **started**. Rarely what you want |
| `after:A+30` | started at least 30 minutes ago |
| `singleton` | no other job of yours with the same `--job-name` is running |

Combining: `afterok:A:B` waits for **both**. Separating with `?` instead of `:`
makes it **any** — `afterok:A?afterok:B`.

`afterok` was right for the ensemble: if a forward leg crashes, its pickup is
missing or truncated, and an adjoint reading it would fail confusingly or —
worse — silently read a stale pickup left from another run.

---

## 5. Running something automatically after a job finishes

### 5.1 What is running tonight, and what it is not

The comparison of the new reference adjoint (job 30995) against the pre-cleanup
reference (28486) is **not** a SLURM job and uses **no** `--dependency`. It is a
plain background shell process that polls `squeue` and runs when the job leaves
the queue:

```bash
tools/compare_adj_runs.sh --wait 30995 <reference-run-dir> <new-run-dir> &
```

with a wait loop of, in essence:

```bash
gone=0
while [ "$gone" -lt 2 ]; do
    if squeue -h -j "$JOB" 2>/dev/null | grep -q .; then gone=0; sleep 120
    else gone=$((gone+1)); sleep 60; fi
done
# ... comparison ...
```

The doubled check is deliberate: a transient `squeue` failure would otherwise
look like "the job finished" and compare a half-written run.

**This approach is the weaker one and is worth understanding as a
counter-example.** The poller is an ordinary process living inside whichever
interactive allocation launched it, so it dies with that allocation — it does
not appear in `squeue`, the scheduler knows nothing about it, and if the login
session's job ends the comparison silently never happens. It was used only
because the job was already running when the comparison was wanted.

### 5.2 The robust way: make it a job with a dependency

If you know in advance that you want a follow-on step, submit it as a job at the
same time. Then the scheduler owns it and your terminal is irrelevant.

Write a thin batch wrapper, e.g. `run_comparison.sh`:

```bash
#!/bin/bash
#SBATCH -J adj_compare
#SBATCH -o %x.%j.out
#SBATCH -e %x.%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 00:30:00
set -x
    /home/tshahriar/Proj_ImPACTS/tools/compare_adj_runs.sh \
        /scratch2/$USER/DINO_1deg_tapAdj_runs/<reference-run> \
        /scratch2/$USER/DINO_1deg_tapAdj_runs/<new-run>
```

No `--wait` here: the dependency already guarantees the job has finished, so
polling would be redundant. `--wait` is for the case in §5.1, where the job was
already running by the time the comparison was wanted.

and submit it against the run it should follow:

```bash
ADJ=$(../../../tools/submit.sh submit_tapAdj.sh --parsable)
CMP=$(sbatch --parsable --dependency=afterany:$ADJ run_comparison.sh)
echo "adjoint $ADJ -> comparison $CMP"
```

**`afterany`, not `afterok`, for a comparison or report step.** You want the
report even when the run failed — the script's own "did it end normally?" check
is what should tell you, rather than the step silently never running. Keep
`afterok` for steps that would be meaningless on bad data.

Note the wrapper asks for `-n 1` and 30 minutes: a comparison is serial I/O, so
do not inherit the model's 27-rank, 240-hour request.

---

### 5.3 The comparison tool itself

`tools/compare_adj_runs.sh` is what both arrangements above invoke.

```bash
tools/compare_adj_runs.sh [options] <reference-run-dir> <new-run-dir>

  --wait <jobid>    poll until that job leaves the queue, then compare
  --report <file>   default: <new-run-dir>/comparison_vs_<ref basename>.txt
  --no-report       print the report, write no file
  --work <dir>      keep the intermediate listings (default: a mktemp dir)
```

It exits **0 when the two runs are equivalent and 1 when they are not**, so it
composes into a larger script. Seven sections: job completion, file inventory,
every `ADJ*`/`adxx*` sensitivity field bit-compared, every other common file,
the cost function, the `%MON` stream, then a verdict.

Two behaviours are worth knowing before reading its output, because both would
otherwise look like failures:

**Three files always differ between a `useGrdchk=.TRUE.` run and a `.FALSE.`
one**, and are classified as expected rather than reported as problems:

| File | Why |
| --- | --- |
| `data.pkg` | the flag itself |
| `output_tap_adj.txt` | grdchk's `ph-test` / `ph-grd` chatter |
| `xx_theta.effective.*.data` | grdchk leaves its last probe's perturbation behind — **exactly one element of 363,528, differing by exactly `grdchk_eps`**, which the script verifies numerically rather than reporting "binary files differ" |

**The monitor stream is compared against a leading block, not wholesale.** A
grdchk run's perturbed forward integrations emit extra `%MON` lines *after* the
main run, so the new run's lines are matched against the reference run's first
*n* of them. A raw count comparison would misfire on every such pair.

Verified in both directions before being trusted: on runs 30948 (grdchk on) and
30994 (grdchk off), which differ only in that flag, it reports EQUIVALENT across
196 sensitivity fields with an identical cost function and exits 0; on two runs
with genuinely different windows it reports 74 differing sensitivities, a
different cost, and exits 1.

## 6. Checking on a chain

**`sacct` does not work here — "Slurm accounting storage is disabled".** The
usual advice to use it is a dead end on sverdrup. Use these instead.

Live view, with the dependency and the reason it is waiting:

```bash
squeue -u $USER -o '%.7i %.20j %.2t %.10M %.24E %R'
```

`%E` is the dependency, `%R` the reason. A waiting job looks like

```
  31009     DINO_1deg_tapAdj PD       0:00 afterok:31002(unfulf   (Dependency)
```

and once satisfied the dependency clears to `(null)` and the state goes `R`.

One job in detail:

```bash
scontrol show job 31009 | tr ' ' '\n' | grep -iE 'JobState|Dependency|Reason'
```

`scontrol` only knows about live and very recently finished jobs. Once a job has
aged out, the run's own files are the record — which is why the submit scripts
write `run_timing.txt`:

```bash
cat <run_dir>/run_timing.txt                       # start, end, elapsed
grep -c 'NORMAL END' <run_dir>/output_tap_adj.txt  # expect 27 (one per rank)
```

Changing your mind about a queued job:

```bash
scontrol update jobid=31009 dependency=afterok:31002   # change the condition
scontrol update jobid=31009 dependency=                # release it to run now
scancel 31009                                          # drop it
```

---

## 7. Gotchas

- **A dependency that can never be satisfied leaves the job pending forever.**
  If the parent fails under `afterok`, the child's reason becomes
  `DependencyNeverSatisfied`. `DependencyParameters` is unset on this cluster,
  so SLURM will **not** auto-cancel it — it sits in `PD` indefinitely and you
  must `scancel` it yourself. After any failure in a chain, check `squeue` for
  orphaned dependents.
- **A cancelled parent counts as "not ok".** `scancel` on the forward leg
  strands its adjoint exactly as a crash would.
- **`sbatch` spools the script at submit time.** Editing the submit script
  afterwards does not affect queued jobs — which is what makes the rewrite loop
  in §2.2 safe, and equally means fixing a bug in the script does *not* fix jobs
  already queued. Cancel and resubmit those.
- **The environment is captured at submit time too**, via `--export=ALL`. So
  `IMPACTS_TEST_CASE=kappa_v_ensemble/M3 ... submit.sh` is fixed into that job; exporting a
  different value later changes nothing for it.
- **Job ids are the durable key.** Run directory names carry the tags, but if a
  name and a namelist ever disagree, the staged namelist in the run directory
  wins.
- **`--parsable` is worth the habit.** Parsing `Submitted batch job N` with
  `grep -oE '[0-9]+$'` works but breaks the moment a warning is printed after
  the id.

---

## See also

- `tools/compare_adj_runs.sh` — the comparison tool of §5.3; `--help` prints its
  own reference
- `MITgcm_c69m/mysetups/DINO_1deg/README.md` — the `IMPACTS_*` overrides and the
  variant vocabulary
- `CLAUDE.md` — why `nIter0` and the pickup symlink are coupled by hand, and why
  the duration `sed` targets the staged namelist
- `notes/nn_surrogate/master_plan/sections/91_app_running.tex` — the ensemble's
  own operational appendix
