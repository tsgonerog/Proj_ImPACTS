#!/usr/bin/env python3
"""The kappa_v ensemble's 5-year adjoints, ckpAll build vs -nocheckpoint build.

    python compare_ensemble_ckpAll_vs_nocheckpoint.py [--only REF,M3,...] [--out DIR]

The eight adjoints of the vertical-diffusivity ensemble (reference + M1..M7,
analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/) were run on 2026-09-01
with the checkpoint-everything build (jobs 31039-31046) and again on
2026-09-02 with the profile-guided -nocheckpoint build that is the DINO
default since that day (jobs 31060-31067; same namelists, same pickups, same
executable for all eight).  For every pair this script

  * compares fc, every adxx_* control gradient and every ADJ* dump with the
    bitwise test of compare_adjoint_runs.py (same directory) and writes that
    script's report format to <out>/compare_<member>_run<old>_vs_run<new>.md;
  * splits each run's wall time into the forward sweep (job start to the
    write time of the first dump the reverse sweep produces,
    ADJtheta.<nIter0+nTimeSteps-adjDumpFreq>, i.e. the turn plus 240 backward
    steps) and the reverse sweep (that dump to the end), the method used for
    the 31039/31055 report;
  * checks that the blown-up members blow up identically: the number of
    non-finite values in the fully accumulated ADJtheta dump (lead 5 yr) and
    in adxx_theta, and the first dump in adjoint order that is non-finite;
  * picks up the verdict of tools/compare_adj_runs.sh (file inventory, every
    other common file, the %MON monitor stream) when its report is present in
    the new run directory;

and writes the summary table to <out>.md.  Two extra rows put the ensemble
next to the earlier single-run validation (31039 vs 31055) and check that
the executable rebuilt on 2026-09-02 reproduces the 2026-09-01 one (31055 vs
31060).  Precision and shape come from each file's .meta (adxx_* float64,
ADJ* float32).
"""
from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from compare_adjoint_runs import compare_field, fmt_time, read_fc, read_mds  # noqa: E402

SCRATCH = Path("/scratch2/tshahriar/DINO_1deg_tapAdj_runs")

# The adjoint window shared by all runs (nIter0, nTimeSteps, adjDumpFreq/dT).
NITER0, NSTEPS, STRIDE = 3162240, 87840, 240
NITER_END = NITER0 + NSTEPS            # 3250080, not dumped
LAST_DUMP = NITER_END - STRIDE         # 3249840, the first dump the reverse sweep writes
FIRST_DUMP = NITER0                    # 3162240, the fully accumulated dump (lead 5 yr)
STEPS_PER_YEAR = 17568

CKP = "DINO_1deg_tapAdj_ckpAll_5yr_{tag}_run{job}"
NCK = "DINO_1deg_tapAdj_nocheckpoint_5yr_{tag}_run{job}"

# label, kappa factor, ckpAll job (2026-09-01), nocheckpoint job (2026-09-02), node of the new job.
# The 2026-09-01 jobs' nodes are not recorded (accounting is disabled on sverdrup
# and their .out/.err logs were cleaned); the new jobs' nodes come from squeue at
# submission. All ran eight-at-once on separate nodes both times.
PAIRS = [
    ("REF", 1.0,  "from180yrPk_visc2x", 31039, 31060, "c2-4"),
    ("M1",  0.25, "M1", 31040, 31061, "c3-1"),
    ("M2",  0.5,  "M2", 31041, 31062, "c7-4"),
    ("M3",  2.0,  "M3", 31042, 31063, "c8-1"),
    ("M4",  4.0,  "M4", 31043, 31064, "c8-2"),
    ("M5",  8.0,  "M5", 31044, 31065, "c8-3"),
    ("M6",  16.0, "M6", 31045, 31066, "c8-4"),
    ("M7",  32.0, "M7", 31046, 31067, "c9-1"),
]
EXTRA = [
    # label, old run dir, new run dir, node of the new run
    ("REF, 31039 vs 31055 (the 2026-09-01 single-run validation, recomputed)",
     CKP.format(tag="from180yrPk_visc2x", job=31039), NCK.format(tag="from180yrPk_visc2x", job=31055), "c2-1"),
    ("REF, 31055 vs 31060 (nocheckpoint executable rebuilt 2026-09-02 vs the 2026-09-01 one)",
     NCK.format(tag="from180yrPk_visc2x", job=31055), NCK.format(tag="from180yrPk_visc2x", job=31060), "c2-4"),
]


# ---------------------------------------------------------------------------
# timing
# ---------------------------------------------------------------------------

def _when(line):
    """'Run started at: Tue Sep  1 01:05:05 AM CDT 2026' -> naive local datetime."""
    parts = line.split(":", 1)[1].split()
    del parts[5]                                    # the zone name; mtimes are local too
    return datetime.strptime(" ".join(parts), "%a %b %d %I:%M:%S %p %Y")


def phases(run: Path):
    """start, turn (+240 steps), end and the three durations in seconds; None when missing."""
    out = dict(start=None, turn=None, end=None, total=None, fwd=None, rev=None)
    f = run / "run_timing.txt"
    if not f.exists():
        return out
    for line in f.read_text().splitlines():
        if line.startswith("Run started at:"):
            out["start"] = _when(line)
        elif line.startswith("Run ended at:"):
            out["end"] = _when(line)
    turn_file = run / f"ADJtheta.{LAST_DUMP:010d}.data"
    if turn_file.exists():
        out["turn"] = datetime.fromtimestamp(turn_file.stat().st_mtime)
    s, t, e = out["start"], out["turn"], out["end"]
    if s and e:
        out["total"] = int((e - s).total_seconds())
    if s and t:
        out["fwd"] = int((t - s).total_seconds())
    if t and e:
        out["rev"] = int((e - t).total_seconds())
    return out


# ---------------------------------------------------------------------------
# blow-up reproduction
# ---------------------------------------------------------------------------

_NF_CACHE = {}


def nonfinite(run: Path):
    """(non-finite count in ADJtheta at lead 5 yr, first non-finite dump iteration in
    adjoint order or None, non-finite count in adxx_theta, max |finite ADJtheta lead 5|)."""
    if run in _NF_CACHE:
        return _NF_CACHE[run]
    a, _ = read_mds(run / f"ADJtheta.{FIRST_DUMP:010d}")
    fin = np.isfinite(a)
    n_nf = int((~fin).sum())
    amax = float(np.abs(a[fin]).max()) if fin.any() else float("nan")
    first_bad = None
    if n_nf:
        for it in range(LAST_DUMP, FIRST_DUMP - 1, -STRIDE):
            b, _ = read_mds(run / f"ADJtheta.{it:010d}")
            if not np.isfinite(b).all():
                first_bad = it
                break
    x, _ = read_mds(run / "adxx_theta.0000000000")
    res = (n_nf, first_bad, int((~np.isfinite(x)).sum()), amax)
    _NF_CACHE[run] = res
    return res


def lead_years(it):
    return (NITER_END - it) / STEPS_PER_YEAR


# ---------------------------------------------------------------------------
# field-by-field comparison (the compare_adjoint_runs.py report, returned as data)
# ---------------------------------------------------------------------------

def _adxx_key(n):
    p = n.split(".")
    return p[0] + ("." + p[1] if p[1] in ("tmp", "effective") else "")


def compare_group(ref: Path, test: Path, pattern, group_key):
    files = sorted(p for p in ref.glob(pattern) if p.suffix == ".data")
    rows, missing = {}, []
    for f in files:
        base = f.with_suffix("")
        tbase = test / base.name
        if not Path(str(tbase) + ".data").exists():
            missing.append(base.name)
            continue
        r = compare_field(base, tbase)
        g = rows.setdefault(group_key(base.name),
                            {"n": 0, "bitwise": 0, "max_abs": 0.0, "max_rel": 0.0,
                             "n_diff": 0, "ref_max": 0.0, "status": "bitwise"})
        g["n"] += 1
        if r["status"] == "bitwise":
            g["bitwise"] += 1
        elif r["status"] == "differs":
            g["status"] = "differs"
            g["max_abs"] = max(g["max_abs"], r["max_abs"])
            if not np.isnan(r["max_rel"]):
                g["max_rel"] = max(g["max_rel"], r["max_rel"])
            g["n_diff"] += r["n_diff"]
        else:
            g["status"] = r["status"]
        g["ref_max"] = max(g["ref_max"], r.get("ref_max", 0.0))
    n_all = sum(g["n"] for g in rows.values())
    n_bit = sum(g["bitwise"] for g in rows.values())
    return rows, n_bit, n_all, missing


def group_table(title, rows, n_bit, n_all, missing):
    out = [f"## {title} ({n_all} files in reference)"]
    if not rows:
        out += ["_none_", ""]
        return out
    out.append("| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |")
    out.append("|---|---|---|---|---|---|---|")
    for key, g in rows.items():
        out.append(f"| {key} | {g['n']} | {g['bitwise']}/{g['n']} | {g['max_abs']:.3e} | "
                   f"{g['max_rel']:.3e} | {g['n_diff']} | {g['ref_max']:.3e} |")
    out.append(f"\n**{n_bit}/{n_all} files bitwise identical.**")
    if missing:
        out.append(f"missing in test: {', '.join(missing)}")
    out.append("")
    return out


def shell_verdict(ref: Path, test: Path):
    """Verdict and %MON line of tools/compare_adj_runs.sh, if its report is in the test run."""
    rep = test / f"comparison_vs_{ref.name}.txt"
    if not rep.exists():
        return None, None
    txt = rep.read_text()
    verdict = "EQUIVALENT" if "\nEQUIVALENT:" in txt else ("NOT CLEAN" if "NOT CLEAN" in txt else "?")
    m = re.search(r"%MON lines: reference=(\d+)\s+new=(\d+)\n\s*-> (.*)", txt)
    mon = f"{m.group(2)} lines, {'byte-identical' if 'BYTE-IDENTICAL' in m.group(3) else 'DIFFER'}" if m else "n/a"
    return verdict, mon


def compare_pair(label, ref: Path, test: Path, md_path: Path):
    """Write the per-pair report; return the summary numbers."""
    out = [f"# Adjoint run comparison — {label}",
           f"- reference: `{ref}`", f"- test:      `{test}`", ""]
    pr, pt = phases(ref), phases(test)
    out += ["## Runtime", "| run | wall time | seconds | forward sweep | reverse sweep |", "|---|---|---|---|---|"]
    for name, p in (("reference", pr), ("test", pt)):
        out.append(f"| {name} | {fmt_time(p['total'])} | {p['total']} | {fmt_time(p['fwd'])} | {fmt_time(p['rev'])} |")
    if pr["total"] and pt["total"]:
        out.append(f"\nspeed-up (ref/test) = **{pr['total'] / pt['total']:.3f}x**, "
                   f"time saved = {100 * (1 - pt['total'] / pr['total']):.1f} %")
    if pr["rev"] and pt["rev"]:
        out.append(f"reverse-sweep speed-up = {pr['rev'] / pt['rev']:.3f}x, forward sweep {pr['fwd']} s vs {pt['fwd']} s")
    out.append("\nThe forward sweep is measured to the write of `ADJtheta.%010d`, the first dump of the "
               "reverse sweep (the turn plus 240 backward steps)." % LAST_DUMP)
    out.append("")

    fr, ft = read_fc(ref), read_fc(test)
    out += ["## Cost function", f"- reference fc = {fr!r}", f"- test      fc = {ft!r}"]
    fc_same = fr is not None and ft is not None and fr == ft
    if fr is not None and ft is not None:
        out.append(f"- identical: **{fc_same}**" + ("" if fc_same else f"  (rel diff {abs(fr - ft) / abs(fr):.3e})"))
    out.append("")

    ax = compare_group(ref, test, "adxx_*.data", _adxx_key)
    out += group_table("adxx_* control gradients", *ax)
    ad = compare_group(ref, test, "ADJ*.data", lambda n: n.split(".")[0])
    out += group_table("ADJ* sensitivity dumps", *ad)

    nr, nt = nonfinite(ref), nonfinite(test)
    out += ["## Blow-up reproduction (ADJtheta, adxx_theta)",
            "| run | non-finite in ADJtheta at lead 5 yr | first non-finite ADJtheta dump (adjoint order) | non-finite in adxx_theta | max finite |ADJtheta| at lead 5 yr |",
            "|---|---|---|---|---|"]
    for name, n in (("reference", nr), ("test", nt)):
        fb = "none" if n[1] is None else f"iter {n[1]} (lead {lead_years(n[1]):.2f} yr)"
        out.append(f"| {name} | {n[0]} | {fb} | {n[2]} | {n[3]:.3e} |")
    out.append("")

    verdict, mon = shell_verdict(ref, test)
    if verdict:
        out += ["## tools/compare_adj_runs.sh", f"- verdict: **{verdict}**", f"- %MON stream: {mon}", ""]

    md_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.write_text("\n".join(out) + "\n")
    return dict(pr=pr, pt=pt, fc_same=fc_same, fr=fr, ft=ft,
                adxx=(ax[1], ax[2]), adj=(ad[1], ad[2]), missing=ax[3] + ad[3],
                nf_ref=nr, nf_test=nt, verdict=verdict, mon=mon)


# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------

def hours(s):
    return "n/a" if s is None else f"{s / 3600:.2f} h"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="comma-separated labels (REF,M1,..; EXTRA1, EXTRA2)")
    ap.add_argument("--out", type=Path, default=HERE / "compare_5yr_kappa_ensemble_ckpAll_vs_nocheckpoint",
                    help="directory for the per-pair reports; the summary goes to <out>.md")
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None
    out_dir = args.out
    summary = [
        "# kappa_v ensemble, 5-year adjoints: ckpAll (2026-09-01) vs -nocheckpoint (2026-09-02)",
        "",
        "Eight pairs, one per ensemble adjoint. Same namelists, same pickups, same forward legs; only the build differs "
        "(`build_tapAdj_ckpAll` for jobs 31039–31046, `build_tapAdj_nocheckpoint` — the DINO default — for 31060–31067). "
        "Both campaigns ran their eight jobs concurrently on eight separate nodes. Per-pair reports in "
        f"`{out_dir.name}/`; generated by `{Path(__file__).name}`.",
        "",
        "## Numerical identity and runtime",
        "",
        "| member | κ | ckpAll job | wall | nocheckpoint job (node) | wall | speed-up | forward sweep ckpAll → nockp | reverse sweep ckpAll → nockp | fc identical | adxx_* bitwise | ADJ* bitwise | non-finite ADJtheta at lead 5 yr, ckpAll / nockp | compare_adj_runs.sh |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    rows_done = []
    for label, kappa, tag, jold, jnew, node in PAIRS:
        if only and label not in only:
            continue
        ref, test = SCRATCH / CKP.format(tag=tag, job=jold), SCRATCH / NCK.format(tag=tag, job=jnew)
        if not (test / "run_timing.txt").exists() or "Run ended" not in (test / "run_timing.txt").read_text():
            summary.append(f"| {label} | {kappa:g}× | {jold} | {fmt_time(phases(ref)['total'])} | {jnew} ({node}) | _still running_ | | | | | | | | |")
            print(f"{label}: {test.name} not finished, skipped")
            continue
        print(f"{label}: {ref.name} vs {test.name}")
        r = compare_pair(f"{label} ({kappa:g}× κ)", ref, test, out_dir / f"compare_{label}_run{jold}_vs_run{jnew}.md")
        pr, pt = r["pr"], r["pt"]
        sp = f"{pr['total'] / pt['total']:.3f}×" if pr["total"] and pt["total"] else "n/a"
        rsp = f"{fmt_time(pr['rev'])} → {fmt_time(pt['rev'])} ({pr['rev'] / pt['rev']:.2f}×)" if pr["rev"] and pt["rev"] else "n/a"
        fsp = f"{fmt_time(pr['fwd'])} → {fmt_time(pt['fwd'])}" if pr["fwd"] and pt["fwd"] else "n/a"
        nf = f"{r['nf_ref'][0]} / {r['nf_test'][0]}"
        summary.append(f"| {label} | {kappa:g}× | {jold} | {fmt_time(pr['total'])} | {jnew} ({node}) | {fmt_time(pt['total'])} | **{sp}** | {fsp} | {rsp} | "
                       f"{'yes' if r['fc_same'] else '**NO**'} | {r['adxx'][0]}/{r['adxx'][1]} | {r['adj'][0]}/{r['adj'][1]} | {nf} | {r['verdict'] or 'n/a'} |")
        rows_done.append((label, r))

    if rows_done:
        tot_old = sum(r["pr"]["total"] for _, r in rows_done)
        tot_new = sum(r["pt"]["total"] for _, r in rows_done)
        sps = [r["pr"]["total"] / r["pt"]["total"] for _, r in rows_done]
        rsps = [r["pr"]["rev"] / r["pt"]["rev"] for _, r in rows_done if r["pr"]["rev"] and r["pt"]["rev"]]
        all_fc = all(r["fc_same"] for _, r in rows_done)
        all_adxx = all(r["adxx"][0] == r["adxx"][1] for _, r in rows_done)
        all_adj = all(r["adj"][0] == r["adj"][1] for _, r in rows_done)
        n_adxx = sum(r["adxx"][1] for _, r in rows_done)
        n_adj = sum(r["adj"][1] for _, r in rows_done)
        blow = [(l, r) for l, r in rows_done if r["nf_ref"][0] or r["nf_test"][0]]
        summary += [
            "",
            f"**{len(rows_done)} pairs finished.** Wall time {hours(tot_old)} → {hours(tot_new)} in total "
            f"({hours(tot_old - tot_new)} saved, {100 * (1 - tot_new / tot_old):.1f} %); "
            f"speed-up {min(sps):.3f}–{max(sps):.3f}× (mean {np.mean(sps):.3f}×)"
            + (f", reverse sweep {min(rsps):.2f}–{max(rsps):.2f}× (mean {np.mean(rsps):.2f}×)" if rsps else "") + ".",
            f"`fc` identical in {'all' if all_fc else '**NOT ALL**'} pairs; adxx_* {'all' if all_adxx else '**NOT ALL**'} {n_adxx} files bitwise identical; "
            f"ADJ* {'all' if all_adj else '**NOT ALL**'} {n_adj} files bitwise identical.",
        ]
        if blow:
            summary += ["", "Blown-up members (non-finite sensitivities), both builds:", "",
                        "| member | first non-finite ADJtheta dump, ckpAll | nocheckpoint | non-finite in adxx_theta, ckpAll / nockp |", "|---|---|---|---|"]
            for l, r in blow:
                f = lambda n: "none" if n[1] is None else f"iter {n[1]} (lead {lead_years(n[1]):.2f} yr)"
                summary.append(f"| {l} | {f(r['nf_ref'])} | {f(r['nf_test'])} | {r['nf_ref'][2]} / {r['nf_test'][2]} |")

    extra_rows = []
    for i, (label, dold, dnew, node) in enumerate(EXTRA, 1):
        if only and f"EXTRA{i}" not in only:
            continue
        ref, test = SCRATCH / dold, SCRATCH / dnew
        if not (test / "run_timing.txt").exists() or "Run ended" not in (test / "run_timing.txt").read_text():
            print(f"EXTRA{i}: {test.name} not finished, skipped")
            continue
        print(f"EXTRA{i}: {ref.name} vs {test.name}")
        jold, jnew = ref.name.rsplit("run", 1)[1], test.name.rsplit("run", 1)[1]
        r = compare_pair(label, ref, test, out_dir / f"compare_REF_run{jold}_vs_run{jnew}.md")
        pr, pt = r["pr"], r["pt"]
        sp = f"{pr['total'] / pt['total']:.3f}×" if pr["total"] and pt["total"] else "n/a"
        extra_rows.append(f"| {label} | {fmt_time(pr['total'])} | {fmt_time(pt['total'])} ({node}) | {sp} | {'yes' if r['fc_same'] else '**NO**'} | "
                          f"{r['adxx'][0]}/{r['adxx'][1]} | {r['adj'][0]}/{r['adj'][1]} | {r['verdict'] or 'n/a'} |")
    if extra_rows:
        summary += ["", "## Reference cross-checks", "",
                    "| pair | wall (old) | wall (new, node) | speed-up | fc identical | adxx_* bitwise | ADJ* bitwise | compare_adj_runs.sh |",
                    "|---|---|---|---|---|---|---|---|"] + extra_rows

    summary_path = Path(str(out_dir) + ".md")
    summary_path.write_text("\n".join(summary) + "\n")
    print("\n".join(summary))
    print(f"\nsummary written to {summary_path}; per-pair reports in {out_dir}/")


if __name__ == "__main__":
    main()
