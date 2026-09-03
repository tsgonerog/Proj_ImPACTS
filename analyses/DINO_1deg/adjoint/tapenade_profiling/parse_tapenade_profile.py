#!/usr/bin/env python3
"""Turn a Tapenade -profile table into a ranked -nocheckpoint candidate list.

    python parse_tapenade_profile.py tapenade_profile.0000.txt [--top 40]
           [--budget-mb 500] [--min-gain-s 1] [--list-out tap_nocheckpoint.txt]

adProfile.c (Tapenade 3.16 develop) writes, per static checkpoint location,
the run time that NOT checkpointing it would spare (DeltaT, summed over all its
dynamic occurrences) and the change in the adjoint's PEAK tape size that the
decision would cause (DeltaPk). A location is a (callee, file, line) triple;
`-nocheckpoint "name ..."` acts per callee, so this script aggregates the
locations by callee: time gains add up, and the memory cost is summed too --
an upper bound, since two locations' peaks need not coincide.

Three caveats the table itself does not state:

* `showOneCostBenefit` integer-divides DeltaT by CLOCKS_PER_SEC before
  printing, so every time gain is truncated to whole seconds. Gains below 1 s
  print as 0.000 s, which is why the profiling run has to be long enough.
* DeltaT is the profiled process's CPU time (clock()), for one MPI rank.
* Memory-gain and memory-neutral entries (DeltaPk <= 0) are free wins; the
  "peak memory cost" entries are the trade-offs.
"""
from __future__ import annotations

import argparse
import re
from collections import defaultdict
from pathlib import Path

LINE = re.compile(
    r"^\s*-\s*Time gain\s+-\s*(\d+)\.(\d+)\s*s\."
    r"(?:\s*and peak memory gain\s+(-?\d+)b|\s*at peak memory cost zero|\s*at peak memory cost\s+(\d+)\.(\d+)\s*Mb)"
    r"\s*for (?:call (\S+) \((\d+) times\), at|checkpoint \((\d+) times\) starting at)"
    r"\s*location#(\d+): line (\d+) of file (\S+)\s*$"
)


def parse(path: Path):
    peak = None
    rows = []
    section = None
    for ln in path.read_text().splitlines():
        if ln.startswith("PEAK STACK:"):
            peak = int(ln.split(":")[1].split()[0])
            continue
        if ln.strip().startswith("* Peak memory"):
            section = ln.strip().lstrip("* ").rstrip(":")
            continue
        m = LINE.match(ln)
        if not m:
            continue
        sec, ms, gain_b, cost_mb, cost_b, callee, occ, occ_manual, loc, line, fname = m.groups()
        t = int(sec) + int(ms) / 1000.0
        if gain_b is not None:
            dpk = int(gain_b)  # negative (a gain), bytes
        elif cost_mb is not None:
            dpk = int(cost_mb) * 1_000_000 + int(cost_b)
        else:
            dpk = 0
        rows.append({
            "callee": callee if callee else "<manual checkpoint>",
            "occurrences": int(occ if occ else occ_manual),
            "time_gain_s": t,
            "delta_peak_bytes": dpk,
            "location": int(loc), "line": int(line), "file": fname, "section": section,
        })
    return peak, rows


def aggregate(rows):
    agg = defaultdict(lambda: {"time_gain_s": 0.0, "delta_peak_bytes": 0, "occurrences": 0, "sites": 0, "files": set()})
    for r in rows:
        a = agg[r["callee"]]
        a["time_gain_s"] += r["time_gain_s"]
        a["delta_peak_bytes"] += r["delta_peak_bytes"]
        a["occurrences"] += r["occurrences"]
        a["sites"] += 1
        a["files"].add(r["file"])
    return agg


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("profile", type=Path)
    ap.add_argument("--top", type=int, default=40, help="rows to print (default 40)")
    ap.add_argument("--budget-mb", type=float, default=None,
                    help="propose a -nocheckpoint list whose summed peak-memory cost stays under this (MB per rank)")
    ap.add_argument("--min-gain-s", type=float, default=1.0, help="ignore callees below this total time gain (s)")
    ap.add_argument("--list-out", type=Path, help="write the proposed list (one name per line) here")
    ap.add_argument("--md", type=Path, help="write the ranked table as Markdown here")
    args = ap.parse_args()

    peak, rows = parse(args.profile)
    agg = aggregate(rows)
    ranked = sorted(agg.items(), key=lambda kv: -kv[1]["time_gain_s"])
    total_gain = sum(a["time_gain_s"] for _, a in ranked)
    out = []

    def say(s=""):
        out.append(s)
        print(s)

    say(f"# Tapenade checkpointing profile: `{args.profile}`")
    say(f"- peak tape (this rank): **{peak / 1e9:.3f} GB**" if peak else "- peak tape: n/a")
    say(f"- {len(rows)} checkpoint locations, {len(agg)} distinct callees")
    say(f"- summed time gain if none were checkpointed: {total_gain:.0f} s CPU on this rank")
    say()
    say("| rank | callee | time gain [s] | cum. gain [s] | peak-mem cost [MB] | gain/cost [s/MB] | call sites | occurrences |")
    say("|---|---|---|---|---|---|---|---|")
    cum = 0.0
    for i, (name, a) in enumerate(ranked[: args.top], 1):
        cum += a["time_gain_s"]
        mb = a["delta_peak_bytes"] / 1e6
        ratio = (a["time_gain_s"] / mb) if mb > 0 else float("inf")
        say(f"| {i} | `{name}` | {a['time_gain_s']:.0f} | {cum:.0f} | {mb:.1f} | {ratio if ratio != float('inf') else 'free':>} | {a['sites']} | {a['occurrences']} |")
    say()

    if args.budget_mb is not None:
        # greedy: free/negative-cost callees first, then best gain per MB, until the budget is spent
        cands = [(n, a) for n, a in ranked if a["time_gain_s"] >= args.min_gain_s]
        free = [(n, a) for n, a in cands if a["delta_peak_bytes"] <= 0]
        paid = sorted([(n, a) for n, a in cands if a["delta_peak_bytes"] > 0],
                      key=lambda kv: -(kv[1]["time_gain_s"] / kv[1]["delta_peak_bytes"]))
        chosen, spent, gain = [], 0.0, 0.0
        for n, a in free:
            chosen.append(n); gain += a["time_gain_s"]
        for n, a in paid:
            mb = a["delta_peak_bytes"] / 1e6
            if spent + mb <= args.budget_mb:
                chosen.append(n); spent += mb; gain += a["time_gain_s"]
        say(f"## Proposed -nocheckpoint list (budget {args.budget_mb:.0f} MB/rank, min gain {args.min_gain_s} s)")
        say(f"- {len(chosen)} callees, summed peak-memory cost bound {spent:.1f} MB, summed time gain {gain:.0f} s "
            f"({100 * gain / total_gain:.1f} % of all recorded gain)")
        say()
        say("```")
        say(" ".join(sorted(chosen)))
        say("```")
        if args.list_out:
            args.list_out.write_text("\n".join(sorted(chosen)) + "\n")
            say(f"\nlist written to {args.list_out}")
    if args.md:
        args.md.write_text("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
