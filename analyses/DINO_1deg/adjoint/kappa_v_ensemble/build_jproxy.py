#!/usr/bin/env python3
"""Reconstruct the cost-function proxy J(t) over the whole 200-yr spin-up.

The adjoint cost (code_tap/cost_atlantic_heat.F, DOMASS branch) is

    J = 1e-6 * sum_{tiles} sum_{k<KMAX} drF(k)/countV_tile(k)
                            * sum_{i in tile} vbar(i,k)*dxG(i)

at the zonal section j=127 (Fortran; JSEC=126 0-based), upper 25 levels,
where vbar is the mean over the final `lastinterval` = 30 d of the window
(pkg/cost default) and countV is the per-level wet-face count PER MPI TILE
(sNx=17, three tiles across the section) — both verified in this analysis
by matching fc: evaluating this formula on each run's initial pickup
reproduces its fc to within 3-19% (the remaining difference is real
evolution between the initial instant and the terminal-month mean).

The spin-up run 30983 kept a pickup every 1464 steps (30.5 d), so evaluating
the formula on each pickup's instantaneous Vvel gives a ~2,400-point series
of the instantaneous index.  Its variability across 30.5-d samples and
across block means turns the single reference fc into a distribution: the
internal-variability "noise floor" (master plan, "Does the sensitivity
depend on kappa?") against which member fc differences must be judged.

Reads Vvel by memory-mapping only the needed records of each pickup
(record layout from the .meta: Uvel 0:36, Vvel 36:72, ...).

Writes cache/jproxy_series.nc with:
  jproxy            per-tile-normalised index (matches fc's definition)
  jproxy_global     globally-normalised variant (decomposition-invariant,
                    ~1/3 of jproxy; kept for reference)
  jproxy_run_pickup per-tile index on each ensemble run's initial pickup
"""

import sys
import numpy as np

sys.path.insert(0, "/home/tshahriar/Proj_ImPACTS/analyses/DINO_1deg/adjoint/kappa_v_ensemble")
import ensemble_common as ec

import xarray as xr

SPINUP = ec.SPINUP_SCRATCH / "DINO_1deg_frd_200yr_from_rest_visc2x_run30983"

GRID = ec.read_grid()
DXG = np.squeeze(ec.read_mds(SPINUP / "DXG"))          # (j,i)
NR = GRID["hFacC"].shape[0]
VREC0 = NR                                             # Vvel = records 36:72

# section geometry, exactly as compiled into cost_atlantic_heat.F
maskS_sec = GRID["hFacS"][:, ec.JSEC, :] > 0           # (k,i)
dxg_sec = DXG[ec.JSEC, :]                              # (i,)
countV = maskS_sec.sum(axis=1).astype(np.float64)      # wet faces per level
drf = GRID["DRF"]


SNX = 17          # tile width; nPx=3 tiles span the 51-cell section
NTILE = 3


def jproxy_from_v(v_sec, per_tile=True):
    """v_sec: (k,i) instantaneous meridional velocity at the section row.

    per_tile=True reproduces the compiled cost exactly (countV per MPI
    tile); per_tile=False is the decomposition-invariant global variant.
    """
    klim = np.arange(NR) < ec.KMAX
    if not per_tile:
        vbar = (v_sec * dxg_sec[None, :] * maskS_sec).sum(axis=1)
        ok = (countV != 0) & klim
        return 1e-6 * (vbar[ok] * drf[ok] / countV[ok]).sum()
    tot = 0.0
    for tx in range(NTILE):
        sl = slice(SNX * tx, SNX * (tx + 1))
        m = maskS_sec[:, sl]
        cnt = m.sum(axis=1).astype(np.float64)
        vbar = (v_sec[:, sl] * dxg_sec[None, sl] * m).sum(axis=1)
        ok = (cnt != 0) & klim
        tot += (vbar[ok] * drf[ok] / cnt[ok]).sum()
    return 1e-6 * tot


def jproxy_from_pickup(path_data, per_tile=True):
    mm = np.memmap(path_data, dtype=">f8", mode="r",
                   shape=(255, GRID["hFacC"].shape[1], GRID["hFacC"].shape[2]))
    v_sec = np.asarray(mm[VREC0:VREC0 + NR, ec.JSEC, :], np.float64)
    del mm
    return jproxy_from_v(v_sec, per_tile)


if __name__ == "__main__":
    import glob
    import re
    files = sorted(glob.glob(str(SPINUP / "pickup.[0-9]*.data")))
    its, js, jg = [], [], []
    for f in files:
        it = int(re.search(r"pickup\.(\d+)\.data", f).group(1))
        its.append(it)
        mm = np.memmap(f, dtype=">f8", mode="r",
                       shape=(255, GRID["hFacC"].shape[1],
                              GRID["hFacC"].shape[2]))
        v_sec = np.asarray(mm[VREC0:VREC0 + NR, ec.JSEC, :], np.float64)
        del mm
        js.append(jproxy_from_v(v_sec, per_tile=True))
        jg.append(jproxy_from_v(v_sec, per_tile=False))
        if len(its) % 400 == 0:
            print(f"{len(its)}/{len(files)}", flush=True)
    its = np.array(its)
    js = np.array(js)
    jg = np.array(jg)

    # the same index from each ensemble run's own initial (year-2180) pickup
    run_j = [jproxy_from_pickup(str(ec.RUNS[r]["dir"] /
                                    f"pickup.{ec.NITER0:010d}.data"))
             for r in ec.RUN_ORDER]

    ds = xr.Dataset(
        dict(jproxy=("iter", js),
             jproxy_global=("iter", jg),
             jproxy_run_pickup=("run", np.array(run_j))),
        coords=dict(iter=its, model_year=("iter", ec.model_year(its)),
                    run=ec.RUN_ORDER,
                    kappa_factor=("run", [ec.RUNS[r]["factor"]
                                          for r in ec.RUN_ORDER])),
        attrs=dict(description="instantaneous cost-function proxy (section "
                               "transport index) from spin-up 30983 pickups "
                               "every 1464 steps; jproxy_run_pickup = same "
                               "(per-tile) index on each ensemble run's "
                               "initial pickup",
                   formula="1e-6 * sum_tiles sum_k drF/countV_tile * "
                           "sum_i v*dxG*maskS, j=127 (Fortran), k<=25; "
                           "jproxy_global uses a single global countV",
                   caveat="instantaneous snapshots; fc is the mean over the "
                          "final 30 d (lastinterval) of its window"))
    ec.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    ds.to_netcdf(ec.CACHE_DIR / "jproxy_series.nc")
    print("wrote", ec.CACHE_DIR / "jproxy_series.nc")

    # quick sanity summary
    w = (ds.model_year >= 2180) & (ds.model_year < 2185)
    print("mean jproxy 2180-2185:", float(ds.jproxy[w].mean()),
          " (fc of run 31039 = 0.330992)")
