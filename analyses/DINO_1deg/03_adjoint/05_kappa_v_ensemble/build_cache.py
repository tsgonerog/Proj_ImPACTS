#!/usr/bin/env python3
"""Build the intermediate-product cache for the kappa_v ensemble analysis.

Reads every ADJ*/adxx_* dump of the nine 5-yr adjoint runs (reference 31039 +
members M1..M7) plus the year-2180 pickups, and writes netCDF/CSV products to
ensemble_common.CACHE_DIR so the notebooks in this directory stay fast and
light.  Metric definitions live in ensemble_common (imported, not duplicated);
the notebooks document the science, this script only mechanises the loops.

Products
--------
run_table.csv            run registry + fc (costfunction.0000) + runtime +
                         internal consistency check (adxx_diffkr vs final
                         ADJdiffkr pattern correlation, expected ~1)
timeseries_stats.nc      (run, var, time): wet-cell RMS, mean, mean|.|,
                         max|.|, positive-sign fraction of every ADJ* dump
member_metrics_time.nc   (member, var, time, weighting): pattern correlation
                         (centered + uncentered), amplitude ratio, regression
                         slope, sign agreement, centered NRMSE — member vs
                         reference at identical dump iterations; weighting =
                         none | volume (area for 2-D fields)
level_metrics_final.nc   (member, var3d, k, weighting): the same metrics per
                         depth level for the fully accumulated (lead 5 yr)
                         snapshot
final_fields_3d.nc/2d.nc (run, var, ...): the fully accumulated snapshot at
                         iteration 3162240 (float32)
annual_fields_3d.nc      (run, var3d, lead, ...): snapshots at dump
                         iterations nearest to leads 4, 3, 2, 1, 0.014 yr
ensemble_stats_final.nc  across the 8 kappa values (7 members + reference):
                         mean, std (ddof=1), min, max, and std normalised by
                         the reference RMS, at the final snapshot
adxx_fields_3d.nc/2d.nc  (run, var, ...): the control gradients (float64)
dJ_decomposition.csv     measured Delta J = fc(member) - fc(ref) against the
                         adjoint prediction, split into the direct kappa term
                         (sum adxx_diffkr * Delta kappa; forward/backward/
                         symmetric variants) and the initial-state term
                         (sum adxx_{theta,salt,uvel,vvel} * Delta state from
                         the year-2180 pickups)
dJ_contrib_maps.nc       (member, term, j, i): vertically summed maps of the
                         pointwise contributions to the predicted Delta J

Usage:  python3 build_cache.py            (~15-40 min, IO-bound; safe to re-run,
                                           overwrites everything)
"""

import sys
import time
import numpy as np
import multiprocessing as mp

sys.path.insert(0, "/home/tshahriar/Proj_ImPACTS/analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble")
import ensemble_common as ec

sys.path.insert(0, ec.MITGCMUTILS_PATH)
from MITgcmutils import mds  # noqa: E402  (pickup reader)

import xarray as xr  # noqa: E402
import pandas as pd  # noqa: E402

CACHE = ec.CACHE_DIR
CACHE.mkdir(parents=True, exist_ok=True)

GRID = ec.read_grid()
ITERS = np.array(ec.ITERS)
NT = len(ITERS)
WEIGHTINGS = ["none", "volume"]
STATS = ["rms", "mean", "mean_abs", "max_abs", "frac_pos", "finite_frac"]
METRICS = ["corr", "corr_uncentered", "amp_ratio", "slope", "sign_agree", "nrmse_c"]

# module-level state shared with fork()ed workers (copy-on-write, read-only)
_SHARED = {}


def wet_stats(a):
    """a: 1-D wet-cell values (float64).  Blown-up dumps can contain inf/NaN,
    so statistics are taken over the finite values and the finite fraction is
    recorded alongside."""
    fin = np.isfinite(a)
    ff = fin.mean()
    a = a[fin]
    if a.size == 0:
        return np.array([np.nan] * 5 + [0.0])
    absa = np.abs(a)
    return np.array([np.sqrt(np.mean(a * a)), a.mean(), absa.mean(),
                     absa.max(), (a > 0).mean(), ff])


def _worker(run):
    """Compute time-series stats (all runs) and metrics vs reference
    (members only) for the variable held in _SHARED."""
    var = _SHARED["var"]
    mask = _SHARED["mask"]
    wts = _SHARED["wts"]          # weights on wet cells (1-D)
    ref = _SHARED["ref"]          # (NT, nwet) float32 or None for REF worker
    st = np.full((NT, len(STATS)), np.nan)
    met = (np.full((NT, len(METRICS), len(WEIGHTINGS)), np.nan)
           if run != "REF" else None)
    np.seterr(over="ignore", invalid="ignore")
    for t, it in enumerate(ITERS):
        a = ec.read_adj(run, var, it)[mask]
        st[t] = wet_stats(a)
        if run != "REF":
            r = ref[t].astype(np.float64)
            both = np.isfinite(a) & np.isfinite(r)
            a2, r2, w2 = a[both], r[both], wts[both]
            if a2.size < 10:
                continue
            for wi, w in enumerate([None, w2]):
                met[t, 0, wi] = ec.pattern_corr(a2, r2, w)
                met[t, 1, wi] = ec.pattern_corr(a2, r2, w, centered=False)
                met[t, 2, wi] = ec.amp_ratio(a2, r2, w)
                met[t, 3, wi] = ec.regression_slope(a2, r2, w)
                met[t, 4, wi] = ec.sign_agreement(a2, r2, w)
                met[t, 5, wi] = ec.nrmse_centered(a2, r2, w)
    return run, st, met


def build_timeseries_and_metrics():
    """One pass over every (var, run, time) dump."""
    all_vars = list(ec.ADJ_VARS)
    ts = np.full((len(ec.RUN_ORDER), len(all_vars), NT, len(STATS)), np.nan)
    mm = np.full((len(ec.MEMBERS), len(all_vars), NT,
                  len(METRICS), len(WEIGHTINGS)), np.nan)
    for vi, var in enumerate(all_vars):
        t0 = time.time()
        mask = ec.var_mask(var, GRID)
        wts = ec.var_weights(var, GRID)[mask]
        # load the reference time series once; forked workers share it
        ref = np.empty((NT, int(mask.sum())), np.float32)
        for t, it in enumerate(ITERS):
            ref[t] = ec.read_adj("REF", var, it)[mask]
        _SHARED.update(var=var, mask=mask, wts=wts, ref=ref)
        ctx = mp.get_context("fork")
        with ctx.Pool(min(6, len(ec.RUN_ORDER))) as pool:
            for run, st, met in pool.map(_worker, ec.RUN_ORDER):
                ts[ec.RUN_ORDER.index(run), vi] = st
                if met is not None:
                    mm[ec.MEMBERS.index(run), vi] = met
        print(f"{var}: {time.time()-t0:.0f} s", flush=True)

    coords_t = dict(time=("time", ITERS),
                    lead_years=("time", ec.lead_years(ITERS)),
                    model_year=("time", ec.model_year(ITERS)))
    xr.Dataset(
        {s: (("run", "var", "time"), ts[..., i]) for i, s in enumerate(STATS)},
        coords=dict(run=ec.RUN_ORDER, var=all_vars, **coords_t,
                    kappa_factor=("run", [ec.RUNS[r]["factor"] for r in ec.RUN_ORDER])),
        attrs=dict(description="wet-cell statistics of every ADJ* dump",
                   note="time = forward-model iteration of the dump; the "
                        "adjoint computes them in reverse order"),
    ).to_netcdf(CACHE / "timeseries_stats.nc")

    xr.Dataset(
        {m: (("member", "var", "time", "weighting"), mm[:, :, :, i, :])
         for i, m in enumerate(METRICS)},
        coords=dict(member=ec.MEMBERS, var=all_vars, weighting=WEIGHTINGS,
                    **coords_t,
                    kappa_factor=("member", [ec.RUNS[r]["factor"] for r in ec.MEMBERS])),
        attrs=dict(description="member-vs-reference metrics at identical dump "
                               "iterations, over wet cells",
                   weighting="none = every wet cell equal; volume = cell "
                             "volume (area for 2-D fields)"),
    ).to_netcdf(CACHE / "member_metrics_time.nc")


def build_field_caches():
    """Final + annual snapshots, adxx gradients, level metrics, ensemble stats."""
    k, j, i = GRID["hFacC"].shape
    coords_map = dict(XC=(("j", "i"), GRID["XC"]), YC=(("j", "i"), GRID["YC"]))
    coords_z = dict(Z=("k", GRID["Z"]), DRF=("k", GRID["DRF"]))
    kf = [ec.RUNS[r]["factor"] for r in ec.RUN_ORDER]

    # ---- final snapshot (lead 5 yr = full accumulation) ---------------------
    f3 = np.full((len(ec.RUN_ORDER), len(ec.ADJ_3D), k, j, i), np.nan, np.float32)
    f2 = np.full((len(ec.RUN_ORDER), len(ec.ADJ_2D), j, i), np.nan, np.float32)
    for ri, run in enumerate(ec.RUN_ORDER):
        for vi, var in enumerate(ec.ADJ_3D):
            f3[ri, vi] = ec.read_adj(run, var, ec.NITER0)
        for vi, var in enumerate(ec.ADJ_2D):
            f2[ri, vi] = ec.read_adj(run, var, ec.NITER0)
    ds3 = xr.Dataset(
        dict(field=(("run", "var", "k", "j", "i"), f3)),
        coords=dict(run=ec.RUN_ORDER, var=list(ec.ADJ_3D),
                    kappa_factor=("run", kf), **coords_z, **coords_map),
        attrs=dict(description="fully accumulated adjoint sensitivity "
                               f"(dump at iteration {ec.NITER0}, lead 5 yr)"))
    ds3.to_netcdf(CACHE / "final_fields_3d.nc")
    xr.Dataset(
        dict(field=(("run", "var", "j", "i"), f2)),
        coords=dict(run=ec.RUN_ORDER, var=list(ec.ADJ_2D),
                    kappa_factor=("run", kf), **coords_map),
        attrs=ds3.attrs).to_netcdf(CACHE / "final_fields_2d.nc")
    print("final fields cached", flush=True)

    # ---- per-level metrics of the final snapshot ---------------------------
    lm = np.full((len(ec.MEMBERS), len(ec.ADJ_3D), k,
                  len(METRICS), len(WEIGHTINGS)), np.nan)
    for vi, var in enumerate(ec.ADJ_3D):
        m3 = ec.var_mask(var, GRID)
        w3 = ec.var_weights(var, GRID)
        rif = f3[ec.RUN_ORDER.index("REF"), vi]
        for mi, mem in enumerate(ec.MEMBERS):
            af = f3[ec.RUN_ORDER.index(mem), vi]
            for kk in range(k):
                mk = m3[kk]
                if mk.sum() < 10:
                    continue
                a = af[kk][mk].astype(np.float64)
                r = rif[kk][mk].astype(np.float64)
                wk = w3[kk][mk]
                both = np.isfinite(a) & np.isfinite(r)
                if both.sum() < 10:
                    continue
                a, r, wk = a[both], r[both], wk[both]
                for wi, w in enumerate([None, wk]):
                    lm[mi, vi, kk, 0, wi] = ec.pattern_corr(a, r, w)
                    lm[mi, vi, kk, 1, wi] = ec.pattern_corr(a, r, w, centered=False)
                    lm[mi, vi, kk, 2, wi] = ec.amp_ratio(a, r, w)
                    lm[mi, vi, kk, 3, wi] = ec.regression_slope(a, r, w)
                    lm[mi, vi, kk, 4, wi] = ec.sign_agreement(a, r, w)
                    lm[mi, vi, kk, 5, wi] = ec.nrmse_centered(a, r, w)
    xr.Dataset(
        {m: (("member", "var", "k", "weighting"), lm[..., i, :])
         for i, m in enumerate(METRICS)},
        coords=dict(member=ec.MEMBERS, var=list(ec.ADJ_3D),
                    weighting=WEIGHTINGS,
                    kappa_factor=("member", [ec.RUNS[r]["factor"] for r in ec.MEMBERS]),
                    **coords_z),
        attrs=dict(description="member-vs-reference metrics per depth level, "
                               "final (lead 5 yr) snapshot"),
    ).to_netcdf(CACHE / "level_metrics_final.nc")
    print("level metrics cached", flush=True)

    # ---- ensemble statistics across the kappa values -----------------------
    # Some members' adjoints blow up (linearisation instability), which makes
    # raw all-member statistics meaningless; stats are therefore computed for
    # two subsets.  "stable" = final ADJtheta everywhere finite AND its
    # wet-cell RMS within a factor 10 of the reference (criterion recorded in
    # the attrs; run_table.csv carries the per-run classification).
    mC = ec.var_mask("ADJtheta", GRID)
    vi_th = list(ec.ADJ_3D).index("ADJtheta")
    ref_rms = np.sqrt(np.mean(f3[ec.RUN_ORDER.index("REF"), vi_th][mC] ** 2))
    stable = []
    for ri, run in enumerate(ec.RUN_ORDER):
        fld = f3[ri, vi_th][mC]
        ok = np.isfinite(fld).all() and \
            0.1 * ref_rms < np.sqrt(np.mean(fld ** 2)) < 10 * ref_rms
        stable.append(bool(ok))
    stable = np.array(stable)
    np.save(CACHE / "stable_runs.npy",
            np.array([r for r, s in zip(ec.RUN_ORDER, stable) if s]))
    subsets = dict(all8=np.ones(len(ec.RUN_ORDER), bool), stable=stable)

    for name, arr, dims in [("3d", f3, ("var", "k", "j", "i")),
                            ("2d", f2, ("var", "j", "i"))]:
        var_list = list(ec.ADJ_3D if name == "3d" else ec.ADJ_2D)
        ref_arr = arr[ec.RUN_ORDER.index("REF")]
        data = {}
        for sub, sel in subsets.items():
            a = np.where(np.isfinite(arr[sel]), arr[sel], np.nan)
            data[sub] = dict(mean=np.nanmean(a, 0), std=np.nanstd(a, 0, ddof=1),
                             emin=np.nanmin(a, 0), emax=np.nanmax(a, 0))
            nspread = np.full_like(data[sub]["std"], np.nan)
            for vi, var in enumerate(var_list):
                m = ec.var_mask(var, GRID)
                rrms = np.sqrt(np.nanmean(ref_arr[vi][m] ** 2))
                nspread[vi] = data[sub]["std"][vi] / rrms if rrms > 0 else np.nan
            data[sub]["std_over_refrms"] = nspread
        stats_names = list(data["all8"])
        ds = xr.Dataset(
            {s: (("subset",) + dims, np.stack([data[sub][s] for sub in subsets]))
             for s in stats_names},
            coords=(dict(subset=list(subsets), var=var_list,
                         **(dict(**coords_z, **coords_map) if name == "3d"
                            else coords_map))),
            attrs=dict(description="statistics across kappa values, final "
                                   "(lead 5 yr) snapshot",
                       subset_all8="all 7 members + reference (blown-up "
                                   "members make these fields meaningless "
                                   "where they dominate; inf treated as NaN)",
                       subset_stable="runs with final ADJtheta finite and "
                                     "wet RMS within 10x of reference: "
                                     + ",".join(r for r, s in
                                                zip(ec.RUN_ORDER, stable) if s),
                       std="sample std, ddof=1",
                       std_over_refrms="std / RMS(reference field over wet cells)"))
        ds.to_netcdf(CACHE / f"ensemble_stats_final_{name}.nc")
    print("ensemble stats cached; stable subset:",
          [r for r, s in zip(ec.RUN_ORDER, stable) if s], flush=True)

    # ---- annual snapshots (3-D vars) ---------------------------------------
    leads = [4.0, 3.0, 2.0, 1.0]
    ann_iters = [ec.nearest_iter(ec.NITER_END - int(y * ec.STEPS_PER_YEAR))
                 for y in leads] + [ec.ITERS[-1]]
    leads = leads + [float(ec.lead_years(ec.ITERS[-1]))]
    a3 = np.full((len(ec.RUN_ORDER), len(ec.ADJ_3D), len(ann_iters), k, j, i),
                 np.nan, np.float32)
    for ri, run in enumerate(ec.RUN_ORDER):
        for vi, var in enumerate(ec.ADJ_3D):
            for li, it in enumerate(ann_iters):
                a3[ri, vi, li] = ec.read_adj(run, var, it)
    xr.Dataset(
        dict(field=(("run", "var", "lead", "k", "j", "i"), a3)),
        coords=dict(run=ec.RUN_ORDER, var=list(ec.ADJ_3D),
                    lead=leads, iter=("lead", ann_iters),
                    kappa_factor=("run", kf), **coords_z, **coords_map),
        attrs=dict(description="snapshots at dump iterations nearest to the "
                               "given sensitivity lead times (years before "
                               "the cost-window end)"),
    ).to_netcdf(CACHE / "annual_fields_3d.nc")
    print("annual fields cached", flush=True)

    # ---- adxx control gradients --------------------------------------------
    g3 = np.full((len(ec.RUN_ORDER), len(ec.ADXX_3D), k, j, i), np.nan)
    for ri, run in enumerate(ec.RUN_ORDER):
        for vi, var in enumerate(ec.ADXX_3D):
            g3[ri, vi] = ec.read_adxx(run, var)
    xr.Dataset(
        dict(field=(("run", "var", "k", "j", "i"), g3)),
        coords=dict(run=ec.RUN_ORDER, var=list(ec.ADXX_3D),
                    kappa_factor=("run", kf), **coords_z, **coords_map),
        attrs=dict(description="pkg/ctrl gradients (float64, unit weights); "
                               "NOT comparable across controls"),
    ).to_netcdf(CACHE / "adxx_fields_3d.nc")
    g2 = np.full((len(ec.RUN_ORDER), len(ec.ADXX_2D), j, i), np.nan)
    for ri, run in enumerate(ec.RUN_ORDER):
        for vi, var in enumerate(ec.ADXX_2D):
            try:
                g2[ri, vi] = ec.read_adxx(run, var)
            except FileNotFoundError:
                pass
    xr.Dataset(
        dict(field=(("run", "var", "j", "i"), g2)),
        coords=dict(run=ec.RUN_ORDER, var=list(ec.ADXX_2D),
                    kappa_factor=("run", kf), **coords_map),
        attrs=dict(description="pkg/ctrl 2-D (gentim2d) gradients"),
    ).to_netcdf(CACHE / "adxx_fields_2d.nc")
    print("adxx fields cached", flush=True)
    return f3


def build_run_table(final3d):
    rows = []
    vi_dkr = list(ec.ADJ_3D).index("ADJdiffkr")
    for run in ec.RUN_ORDER:
        r = ec.RUNS[run]
        fc = np.nan
        cf = r["dir"] / "costfunction.0000"
        if cf.exists():
            for line in cf.read_text().splitlines():
                if line.strip().startswith("fc"):
                    fc = float(line.split("=")[1])
        runtime = ""
        rt = r["dir"] / "run_timing.txt"
        if rt.exists():
            for line in rt.read_text().splitlines():
                if "Total runtime" in line:
                    runtime = line.split(":", 1)[1].strip()
        # consistency: adxx_diffkr should equal the final ADJdiffkr dump
        m = ec.var_mask("ADJdiffkr", GRID)
        adx = ec.read_adxx(run, "adxx_diffkr")[m]
        adj = final3d[ec.RUN_ORDER.index(run), vi_dkr][m].astype(np.float64)
        both = np.isfinite(adx) & np.isfinite(adj)
        chk = ec.pattern_corr(adx[both], adj[both]) if both.any() else np.nan
        # health of the final accumulated ADJtheta (blow-up detection)
        mth = ec.var_mask("ADJtheta", GRID)
        th = final3d[ec.RUN_ORDER.index(run),
                     list(ec.ADJ_3D).index("ADJtheta")][mth].astype(np.float64)
        finite_frac = float(np.isfinite(th).mean())
        rms_th = float(np.sqrt(np.nanmean(np.where(np.isfinite(th), th, np.nan) ** 2)))
        rows.append(dict(run=run, kappa_factor=r["factor"], kappa=r["kappa"],
                         adj_job=r["adj_job"], fwd_job=r["fwd_job"],
                         run_dir=str(r["dir"]), fc=fc, runtime=runtime,
                         n_dumps=NT, adxx_vs_ADJdiffkr_corr=chk,
                         rms_final_ADJtheta=rms_th,
                         finite_frac_final_ADJtheta=finite_frac))
    pd.DataFrame(rows).to_csv(CACHE / "run_table.csv", index=False)
    print("run table cached", flush=True)


def build_dJ_decomposition():
    """Measured Delta J vs the adjoint's linear prediction.

    Forward difference uses the REFERENCE gradients; backward uses each
    MEMBER's own; symmetric is their mean.  The state term uses the
    year-2180 pickup differences (member forward leg minus reference
    spin-up) dotted with the reference initial-condition gradients.
    """
    pk_fields = dict(theta="Theta", salt="Salt", uvel="Uvel", vvel="Vvel")
    fc = pd.read_csv(CACHE / "run_table.csv").set_index("run")["fc"]

    def read_pickup(run):
        arr, its, meta = mds.rdmds(str(ec.RUNS[run]["dir"] / "pickup"),
                                   ec.NITER0, returnmeta=True)
        fl = [f.strip() for f in meta["fldlist"]]
        nr = GRID["hFacC"].shape[0]
        out, rec = {}, 0
        for f in fl:
            n = nr if f not in ("EtaN", "dEtaHdt", "EtaH") else 1
            out[f] = np.asarray(arr[rec:rec + n], np.float64)
            rec += n
        return out

    ref_pk = read_pickup("REF")
    grads = {v: ec.read_adxx("REF", f"adxx_{v}") for v in pk_fields}
    gd_ref = ec.read_adxx("REF", "adxx_diffkr")

    rows, maps, terms = [], [], ["kappa", "theta", "salt", "uvel", "vvel"]
    for mem in ec.MEMBERS:
        dk = (ec.RUNS[mem]["factor"] - 1.0) * ec.KAPPA0
        gd_mem = ec.read_adxx(mem, "adxx_diffkr")
        dJ_k_fwd = gd_ref.sum() * dk          # reference gradient
        dJ_k_bwd = gd_mem.sum() * dk          # member's own gradient
        mem_pk = read_pickup(mem)
        contrib = {"kappa": (gd_ref * dk).sum(axis=0)}
        dJ_state = 0.0
        state_terms = {}
        for v, f in pk_fields.items():
            dfield = mem_pk[f] - ref_pk[f]
            c = grads[v] * dfield
            state_terms[v] = c.sum()
            contrib[v] = c.sum(axis=0)
            dJ_state += state_terms[v]
        rows.append(dict(
            member=mem, kappa_factor=ec.RUNS[mem]["factor"], dkappa=dk,
            dJ_measured=fc[mem] - fc["REF"],
            dJ_kappa_fwd=dJ_k_fwd, dJ_kappa_bwd=dJ_k_bwd,
            dJ_kappa_sym=0.5 * (dJ_k_fwd + dJ_k_bwd),
            dJ_state_theta=state_terms["theta"], dJ_state_salt=state_terms["salt"],
            dJ_state_uvel=state_terms["uvel"], dJ_state_vvel=state_terms["vvel"],
            dJ_state_total=dJ_state,
            dJ_predicted_total=dJ_k_fwd + dJ_state,
            fc=fc[mem], fc_ref=fc["REF"]))
        maps.append(np.stack([contrib[t] for t in terms]))
    pd.DataFrame(rows).to_csv(CACHE / "dJ_decomposition.csv", index=False)
    xr.Dataset(
        dict(contrib=(("member", "term", "j", "i"), np.array(maps))),
        coords=dict(member=ec.MEMBERS, term=terms,
                    XC=(("j", "i"), GRID["XC"]), YC=(("j", "i"), GRID["YC"])),
        attrs=dict(description="vertically summed pointwise contributions to "
                               "the adjoint-predicted Delta J (reference "
                               "gradients dotted with member-minus-reference "
                               "perturbations)"),
    ).to_netcdf(CACHE / "dJ_contrib_maps.nc")
    print("dJ decomposition cached", flush=True)


if __name__ == "__main__":
    t0 = time.time()
    final3d = build_field_caches()
    build_run_table(final3d)
    build_dJ_decomposition()
    build_timeseries_and_metrics()
    print(f"cache complete in {(time.time()-t0)/60:.1f} min", flush=True)
