#!/usr/bin/env python3
"""Compare two DINO adjoint run directories field by field.

    python compare_adjoint_runs.py REF_RUN_DIR TEST_RUN_DIR [--md report.md]

Reports, for the cost function value, every adxx_* control gradient and every
ADJ* sensitivity dump present in REF: whether TEST is bitwise identical, and if
not the largest absolute difference, the largest difference relative to the
field's own maximum magnitude, and how many elements differ. Also reads both
run_timing.txt files and prints the speed-up. Precision and shape come from
each file's .meta (adxx_* are float64, ADJ* float32 -- never assume).

Used to validate the Tapenade -nocheckpoint build against the plain build; the
bar it is meant to clear is "fc and adxx_* bitwise identical, ADJ* bitwise
identical", which is what a pure recompute-vs-store change should give.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np

_RX = {
    "dims": re.compile(r"dimList\s*=\s*\[([^\]]*)\]", re.S),
    "prec": re.compile(r"dataprec\s*=\s*\[\s*'(\w+)'"),
    "nrec": re.compile(r"nrecords\s*=\s*\[\s*(\d+)"),
}


def read_meta(metafile: Path):
    txt = metafile.read_text()
    rows = [r for r in _RX["dims"].search(txt).group(1).strip().split("\n") if r.strip(" ,")]
    gdims = [int(r.strip(" ,").split(",")[0]) for r in rows]
    prec = _RX["prec"].search(txt).group(1)
    nrec = int(_RX["nrec"].search(txt).group(1))
    return gdims, prec, nrec


def read_mds(pathbase: Path):
    """Return the raw array in its file precision (no upcast: bitwise checks)."""
    gdims, prec, nrec = read_meta(Path(str(pathbase) + ".meta"))
    dtype = {"float32": ">f4", "float64": ">f8"}[prec]
    a = np.fromfile(str(pathbase) + ".data", dtype=dtype)
    shape = ([nrec] if nrec > 1 else []) + gdims[::-1]
    return a.reshape(shape), prec


def read_fc(run: Path):
    f = run / "costfunction.0000"
    if not f.exists():
        return None
    m = re.search(r"fc\s*=\s*([-+0-9.EeDd]+)", f.read_text())
    return float(m.group(1).replace("D", "E")) if m else None


def read_runtime(run: Path):
    f = run / "run_timing.txt"
    if not f.exists():
        return None
    m = re.search(r"Total runtime:\s*(\d+):(\d+):(\d+)", f.read_text())
    if not m:
        return None
    h, mi, s = (int(x) for x in m.groups())
    return 3600 * h + 60 * mi + s


def compare_field(ref: Path, test: Path):
    a, prec_a = read_mds(ref)
    b, prec_b = read_mds(test)
    if a.shape != b.shape or prec_a != prec_b:
        return {"status": "SHAPE/PREC MISMATCH", "a": (a.shape, prec_a), "b": (b.shape, prec_b)}
    same = np.array_equal(a.view(np.uint8), b.view(np.uint8))  # true bitwise test
    if same:
        return {"status": "bitwise", "n_diff": 0, "max_abs": 0.0, "max_rel": 0.0,
                "ref_max": float(np.nanmax(np.abs(a.astype(np.float64)))) if a.size else 0.0}
    a64 = a.astype(np.float64)
    b64 = b.astype(np.float64)
    d = np.abs(a64 - b64)
    ref_max = float(np.nanmax(np.abs(a64))) if a.size else 0.0
    return {"status": "differs", "n_diff": int(np.count_nonzero(a.view(np.uint8) != b.view(np.uint8)) and np.count_nonzero(d)),
            "max_abs": float(np.nanmax(d)), "max_rel": float(np.nanmax(d) / ref_max) if ref_max > 0 else float("nan"),
            "ref_max": ref_max, "n_total": int(a.size),
            "nan_a": int(np.isnan(a64).sum()), "nan_b": int(np.isnan(b64).sum())}


def fmt_time(s):
    return "n/a" if s is None else f"{s // 3600:02d}:{(s % 3600) // 60:02d}:{s % 60:02d}"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ref", type=Path)
    ap.add_argument("test", type=Path)
    ap.add_argument("--md", type=Path, help="also write the report as Markdown here")
    args = ap.parse_args()
    ref, test = args.ref, args.test
    out = []

    def say(s=""):
        out.append(s)
        print(s)

    say(f"# Adjoint run comparison")
    say(f"- reference: `{ref}`")
    say(f"- test:      `{test}`")
    say()

    # ---- runtime -----------------------------------------------------------
    tr, tt = read_runtime(ref), read_runtime(test)
    say("## Runtime")
    say(f"| run | wall time | seconds |\n|---|---|---|")
    say(f"| reference | {fmt_time(tr)} | {tr} |")
    say(f"| test | {fmt_time(tt)} | {tt} |")
    if tr and tt:
        say(f"\nspeed-up (ref/test) = **{tr / tt:.3f}x**, time saved = {100 * (1 - tt / tr):.1f} %")
    say()

    # ---- fc ----------------------------------------------------------------
    fr, ft = read_fc(ref), read_fc(test)
    say("## Cost function")
    say(f"- reference fc = {fr!r}")
    say(f"- test      fc = {ft!r}")
    if fr is not None and ft is not None:
        say(f"- identical: **{fr == ft}**" + ("" if fr == ft else f"  (rel diff {abs(fr - ft) / abs(fr):.3e})"))
    say()

    # ---- adxx --------------------------------------------------------------
    def compare_group(title, pattern, group_key):
        files = sorted(p for p in ref.glob(pattern) if p.suffix == ".data")
        say(f"## {title} ({len(files)} files in reference)")
        if not files:
            say("_none_\n")
            return
        rows = {}
        missing = []
        for f in files:
            base = f.with_suffix("")
            tbase = test / base.name
            if not Path(str(tbase) + ".data").exists():
                missing.append(base.name)
                continue
            r = compare_field(base, tbase)
            key = group_key(base.name)
            g = rows.setdefault(key, {"n": 0, "bitwise": 0, "max_abs": 0.0, "max_rel": 0.0, "n_diff": 0, "ref_max": 0.0, "status": "bitwise"})
            g["n"] += 1
            if r["status"] == "bitwise":
                g["bitwise"] += 1
            elif r["status"] == "differs":
                g["status"] = "differs"
                g["max_abs"] = max(g["max_abs"], r["max_abs"])
                g["max_rel"] = max(g["max_rel"], r["max_rel"]) if not np.isnan(r["max_rel"]) else g["max_rel"]
                g["n_diff"] += r["n_diff"]
            else:
                g["status"] = r["status"]
            g["ref_max"] = max(g["ref_max"], r.get("ref_max", 0.0))
        say("| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |")
        say("|---|---|---|---|---|---|---|")
        n_bit = n_all = 0
        for key, g in rows.items():
            n_bit += g["bitwise"]
            n_all += g["n"]
            say(f"| {key} | {g['n']} | {g['bitwise']}/{g['n']} | {g['max_abs']:.3e} | {g['max_rel']:.3e} | {g['n_diff']} | {g['ref_max']:.3e} |")
        say(f"\n**{n_bit}/{n_all} files bitwise identical.**")
        if missing:
            say(f"missing in test: {', '.join(missing)}")
        say()

    compare_group("adxx_* control gradients", "adxx_*.data", lambda n: n.split(".")[0] + ("." + n.split(".")[1] if n.split(".")[1] in ("tmp", "effective") else ""))
    compare_group("ADJ* sensitivity dumps", "ADJ*.data", lambda n: n.split(".")[0])

    if args.md:
        args.md.write_text("\n".join(out) + "\n")
        print(f"\nreport written to {args.md}")


if __name__ == "__main__":
    main()
