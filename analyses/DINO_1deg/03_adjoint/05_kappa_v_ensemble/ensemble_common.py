"""Shared helpers for the kappa_v (vertical-diffusivity) perturbation-ensemble
adjoint analysis.

Every notebook in this directory imports this module, so the run registry, the
variable metadata, the metric definitions and the plotting conventions live in
exactly one place.  The heavy intermediate products are produced once by
``build_cache.py`` (same directory) and read back here from
``CACHE_DIR`` — see that script's docstring for what each cache file holds.

Experiment (notes/directions/nn_surrogate master plan, Part I; submitted
2026-08-28, adjoints rerun 2026-09-01 with the Tapenade-native hook build):
    seven members perturb the uniform background vertical diffusivity
    kappa_v = 1.2e-5 m^2/s by factors 0.25x .. 32x.  Each member ran a 10-yr
    forward leg from the year-2170 pickup of spin-up run 30983 with the
    perturbed kappa, then a 5-yr adjoint (years 2180-2185) from its own
    year-2180 pickup.  The reference adjoint (run 31039) uses the spin-up's
    own year-2180 pickup and the unperturbed kappa.  All nine adjoint runs
    share the same window: nIter0=3162240, nTimeSteps=87840, dT=1800 s.
    The rerun reproduces the original adjoints (30995, 31003-31009) bitwise
    in fc and adxx_*; its ADJ* dumps are seam-clean (the originals carried
    the pre-31022 tile-seam artifact) and ADJetan is new with the rerun.

Cost function (code_tap/cost_atlantic_heat.F, DOMASS branch, mult_atl=1):
    J = 1e-6 * sum_{tiles} sum_{k<=25} drF(k)/countV_tile(k)
                            * sum_{i in tile} vbar(i,k)*dxG(i)
    at the zonal section j=127 (26.05N), upper 982.4 m.  Two verified
    subtleties (2026-08-30, this analysis):
    - vbar is NOT the 5-yr mean: pkg/cost accumulates cMean* only over the
      final `lastinterval` = 2,592,000 s = 30 d of the window
      (cost_readparms.F default; data.cost does not override it).  J is the
      TERMINAL-MONTH mean transport index, so direct cost forcing enters the
      adjoint only during the last 30 days; everything earlier is pure
      adjoint dynamics.
    - countV is computed PER MPI TILE (the bi,bj loop with i=1..sNx), and
      the 51-cell section spans 3 tiles, so J is a sum of three per-tile
      wet-count-normalised transports (~3x a globally normalised index).
      J therefore depends on the domain decomposition — fine within this
      ensemble (all runs share nPx=3), but not decomposition-invariant.

Conventions carried over from 03_adjoint/01_5yr_from_180yr_pickup_visc2x.ipynb:
    xmitgcm.open_mdsdataset(delta_t=1800, ref_date='2000-01-01'), hFac>0
    masking, robust symmetric percentile colour limits, RdBu_r for signed
    sensitivity fields, and reversed time order when animating ADJ* fields
    (files are numbered by forward-model iteration; the adjoint runs
    backwards, so the LAST dump in forward time is the FIRST computed).
"""

from __future__ import annotations

import base64
import io
import os
import re
from pathlib import Path

import numpy as np

# ----------------------------------------------------------------------------
# Locations
# ----------------------------------------------------------------------------

SCRATCH = Path("/scratch2/tshahriar/DINO_1deg_tapAdj_runs")
ANALYSIS_ROOT = SCRATCH / "kappa_v_ensemble_analysis"
CACHE_DIR = ANALYSIS_ROOT / "cache"
FIG_ROOT = ANALYSIS_ROOT / "figures"
ANIM_ROOT = ANALYSIS_ROOT / "animations"
STATS_ROOT = ANALYSIS_ROOT / "stats"

# MITgcmutils (vendored with the model source) is used to read pickup files.
MITGCMUTILS_PATH = ("/home/tshahriar/Proj_ImPACTS/MITgcm_c69m/MITgcm/"
                    "utils/python/MITgcmutils")

# ----------------------------------------------------------------------------
# Run registry — ordered by kappa factor; REF sits between M2 (0.5x) and M3 (2x)
#
# adj_job/dir point at the 2026-09-01 RERUN with the Tapenade-native hook build
# (jobs 31039-31046).  Validated 2026-09-01 against the 2026-08-28 originals
# (REF 30995, members 31003-31009): fc and all 32 adxx_* files bitwise
# identical per run, ADJ* differing ONLY within the pre-31022 tile-seam dump
# artifact the rerun removes, ADJetan newly present (367 dumps incl. the
# window-end iteration, non-finite only in M4 beyond its documented overflow
# lead).  The 10-yr forward legs (fwd_job) are unchanged.
# ----------------------------------------------------------------------------

KAPPA0 = 1.2e-5  # m^2/s, the unperturbed uniform background diffusivity

RUNS = {
    "M1":  dict(factor=0.25, adj_job=31040, fwd_job=30996,
                dir=SCRATCH / "DINO_1deg_tapAdj_5yr_M1_run31040"),
    "M2":  dict(factor=0.5,  adj_job=31041, fwd_job=30997,
                dir=SCRATCH / "DINO_1deg_tapAdj_5yr_M2_run31041"),
    "REF": dict(factor=1.0,  adj_job=31039, fwd_job=30983,
                dir=SCRATCH / "DINO_1deg_tapAdj_5yr_from180yrPk_visc2x_run31039"),
    "M3":  dict(factor=2.0,  adj_job=31042, fwd_job=30998,
                dir=SCRATCH / "DINO_1deg_tapAdj_5yr_M3_run31042"),
    "M4":  dict(factor=4.0,  adj_job=31043, fwd_job=30999,
                dir=SCRATCH / "DINO_1deg_tapAdj_5yr_M4_run31043"),
    "M5":  dict(factor=8.0,  adj_job=31044, fwd_job=31000,
                dir=SCRATCH / "DINO_1deg_tapAdj_5yr_M5_run31044"),
    "M6":  dict(factor=16.0, adj_job=31045, fwd_job=31001,
                dir=SCRATCH / "DINO_1deg_tapAdj_5yr_M6_run31045"),
    "M7":  dict(factor=32.0, adj_job=31046, fwd_job=31002,
                dir=SCRATCH / "DINO_1deg_tapAdj_5yr_M7_run31046"),
}
for k, r in RUNS.items():
    r["kappa"] = KAPPA0 * r["factor"]
    r["label"] = ("reference (1×)" if k == "REF"
                  else f"{k} ({r['factor']:g}×)")

RUN_ORDER = ["M1", "M2", "REF", "M3", "M4", "M5", "M6", "M7"]   # by kappa
MEMBERS = [k for k in RUN_ORDER if k != "REF"]                  # the 7 members

# ----------------------------------------------------------------------------
# Time axis of the adjoint window
# ----------------------------------------------------------------------------

DT = 1800.0                      # s
NITER0 = 3162240                 # window start  (model year 180 = calendar 2180)
NSTEPS = 87840                   # 5 model years of 366 days at 48 steps/day
NITER_END = NITER0 + NSTEPS      # 3250080, the cost-window end
DUMP_STRIDE = 240                # adjDumpFreq = 5 days
ITERS = list(range(NITER0, NITER_END, DUMP_STRIDE))  # 366 dumps; NITER_END itself
                                                     # is not dumped
STEPS_PER_YEAR = 17568           # 366-day model year
REF_YEAR0 = 2000                 # ref_date year used by the earlier notebooks


def model_year(it):
    """Iteration -> calendar-style model year (2180.0 at window start)."""
    return REF_YEAR0 + np.asarray(it) / STEPS_PER_YEAR


def lead_years(it):
    """Years remaining before the cost-window end (5.0 at window start).

    In adjoint terms this is the sensitivity lead time: the dump at lead L
    answers "how does J respond to a perturbation applied L years before the
    end of the cost window".  The dump at NITER0 (lead 5.0) holds the fully
    accumulated 5-yr sensitivity and is the primary comparison field.
    """
    return (NITER_END - np.asarray(it)) / STEPS_PER_YEAR


def nearest_iter(target_it):
    """The dump iteration closest to an arbitrary iteration number."""
    arr = np.asarray(ITERS)
    return int(arr[np.abs(arr - target_it).argmin()])


# ----------------------------------------------------------------------------
# Variable metadata
# ----------------------------------------------------------------------------
# grid: which hFac masks the variable ('C' tracer point, 'W' u-point,
# 'S' v-point).  ADJwvel lives on the vertical interface below the tracer
# point; masking it with hFacC is the standard approximation.
# ADJ* dumps are float32 snapshots every 5 days; adxx_* are single float64
# dumps at iteration 0 (always read the .meta rather than assuming).

ADJ_3D = {
    "ADJtheta":  dict(grid="C", units="dJ/degC",
                      long_name="sensitivity of J to potential temperature"),
    "ADJsalt":   dict(grid="C", units="dJ/(g/kg)",
                      long_name="sensitivity of J to salinity"),
    "ADJdiffkr": dict(grid="C", units="dJ/(m$^2$ s$^{-1}$)",
                      long_name="sensitivity of J to vertical diffusivity"),
    "ADJuvel":   dict(grid="W", units="dJ/(m/s)",
                      long_name="sensitivity of J to zonal velocity"),
    "ADJvvel":   dict(grid="S", units="dJ/(m/s)",
                      long_name="sensitivity of J to meridional velocity"),
    "ADJwvel":   dict(grid="C", units="dJ/(m/s)",
                      long_name="sensitivity of J to vertical velocity"),
}

ADJ_2D = {
    "ADJtaux":  dict(grid="W", units="dJ/(N m$^{-2}$)",
                     long_name="sensitivity of J to zonal wind stress"),
    "ADJtauy":  dict(grid="S", units="dJ/(N m$^{-2}$)",
                     long_name="sensitivity of J to meridional wind stress"),
    "ADJqnet":  dict(grid="C", units="dJ/(W m$^{-2}$)",
                     long_name="sensitivity of J to net surface heat flux"),
    "ADJqsw":   dict(grid="C", units="dJ/(W m$^{-2}$)",
                     long_name="sensitivity of J to shortwave radiation"),
    "ADJempmr": dict(grid="C", units="dJ/(kg m$^{-2}$ s$^{-1}$)",
                     long_name="sensitivity of J to freshwater flux (E-P-R)"),
}

ADJ_VARS = {**ADJ_3D, **ADJ_2D}

# Control-gradient files (pkg/ctrl).  One dump each, float64, unit weights —
# raw gradients are in each control's own units and are NOT comparable across
# controls (master plan, "a caution before comparing across controls").
ADXX_3D = {
    "adxx_theta":  dict(grid="C", units="dJ/degC",
                        long_name="gradient of J w.r.t. initial temperature"),
    "adxx_salt":   dict(grid="C", units="dJ/(g/kg)",
                        long_name="gradient of J w.r.t. initial salinity"),
    "adxx_uvel":   dict(grid="W", units="dJ/(m/s)",
                        long_name="gradient of J w.r.t. initial zonal velocity"),
    "adxx_vvel":   dict(grid="S", units="dJ/(m/s)",
                        long_name="gradient of J w.r.t. initial meridional velocity"),
    "adxx_diffkr": dict(grid="C", units="dJ/(m$^2$ s$^{-1}$)",
                        long_name="gradient of J w.r.t. vertical diffusivity"),
}

ADXX_2D = {
    "adxx_tauu":  dict(grid="W", units="dJ/(N m$^{-2}$)",
                       long_name="gradient of J w.r.t. zonal wind stress"),
    "adxx_tauv":  dict(grid="S", units="dJ/(N m$^{-2}$)",
                       long_name="gradient of J w.r.t. meridional wind stress"),
    "adxx_qnet":  dict(grid="C", units="dJ/(W m$^{-2}$)",
                       long_name="gradient of J w.r.t. net surface heat flux"),
    "adxx_qsw":   dict(grid="C", units="dJ/(W m$^{-2}$)",
                       long_name="gradient of J w.r.t. shortwave radiation"),
    "adxx_empmr": dict(grid="C", units="dJ/(kg m$^{-2}$ s$^{-1}$)",
                       long_name="gradient of J w.r.t. freshwater flux"),
    "adxx_uwind": dict(grid="W", units="dJ/(m/s)",
                       long_name="gradient of J w.r.t. zonal 10-m wind"),
    "adxx_vwind": dict(grid="S", units="dJ/(m/s)",
                       long_name="gradient of J w.r.t. meridional 10-m wind"),
    "adxx_fu":    dict(grid="W", units="dJ/(N m$^{-2}$)",
                       long_name="gradient of J w.r.t. zonal surface stress"),
    "adxx_fv":    dict(grid="S", units="dJ/(N m$^{-2}$)",
                       long_name="gradient of J w.r.t. meridional surface stress"),
}

ADXX_VARS = {**ADXX_3D, **ADXX_2D}

# ----------------------------------------------------------------------------
# Cost-section geometry (compiled into code_tap/cost_atlantic_heat.F)
# ----------------------------------------------------------------------------
# Fortran indices: zonal section isecbeg=1..isecend=51 at jsec=127,
# kmaxdepth=25 (DOMASS branch).  Python 0-based:
JSEC = 126          # j index of the cost section row (26.05 N)
KMAX = 25           # number of levels in the cost integral (upper 982.4 m)
ISEC = 29           # meridional section i index (declared but not the active
                    # cost term; kept for completeness)

# ----------------------------------------------------------------------------
# Raw MDS readers (per-file; parse the .meta rather than assuming precision)
# ----------------------------------------------------------------------------

_META_RX = {
    "dims": re.compile(r"dimList\s*=\s*\[(.*?)\]", re.S),
    "prec": re.compile(r"dataprec\s*=\s*\[\s*'(\w+)'"),
    "nrec": re.compile(r"nrecords\s*=\s*\[\s*(\d+)"),
}


def read_meta(metafile):
    txt = Path(metafile).read_text()
    dims_txt = _META_RX["dims"].search(txt).group(1)
    rows = [r for r in dims_txt.strip().split("\n") if r.strip(" ,")]
    # each row: "  gdim, first, last," — global dim is the first number
    gdims = [int(r.strip(" ,").split(",")[0]) for r in rows]
    prec = _META_RX["prec"].search(txt).group(1)
    nrec = int(_META_RX["nrec"].search(txt).group(1))
    return gdims, prec, nrec


def read_mds(pathbase):
    """Read one global MDS file pair <pathbase>.data/.meta -> ndarray.

    Returns float64 regardless of file precision (reductions downstream want
    full precision).  Axis order is (k, j, i) for 3-D, (j, i) for 2-D.
    """
    gdims, prec, nrec = read_meta(str(pathbase) + ".meta")
    dtype = {"float32": ">f4", "float64": ">f8"}[prec]
    a = np.fromfile(str(pathbase) + ".data", dtype=dtype)
    shape = [nrec] if nrec > 1 else []
    shape += gdims[::-1]          # meta lists x,y[,z]; file is z,y,x C-order
    return a.reshape(shape).astype(np.float64)


def adj_file(run, var, it):
    return RUNS[run]["dir"] / f"{var}.{it:010d}"


def read_adj(run, var, it):
    """One ADJ* dump of one run as float64 (k,j,i) or (j,i)."""
    return read_mds(adj_file(run, var, it))


def read_adxx(run, var):
    """The (single) adxx_* control-gradient dump of one run."""
    return read_mds(RUNS[run]["dir"] / f"{var}.{0:010d}")


# ----------------------------------------------------------------------------
# Grid, masks and weights
# ----------------------------------------------------------------------------

_GRID_CACHE = {}


def read_grid():
    """Grid arrays from the reference run directory (all runs share the grid).

    Returns a dict with XC,YC (j,i), Z,DRF (k), RAC/RAW/RAS (j,i),
    hFacC/W/S (k,j,i), Depth (j,i) plus boolean wet masks and the RF
    interface depths.
    """
    if _GRID_CACHE:
        return _GRID_CACHE
    d = RUNS["REF"]["dir"]
    g = {}
    for name in ["XC", "YC", "RAC", "RAW", "RAS", "Depth",
                 "hFacC", "hFacW", "hFacS", "DRF", "RC", "RF"]:
        g[name] = np.squeeze(read_mds(d / name))
    g["Z"] = g.pop("RC")                     # cell-centre depths, negative down
    g["DRF"] = np.atleast_1d(g["DRF"])
    for hf in ["hFacC", "hFacW", "hFacS"]:
        g["wet" + hf[-1]] = g[hf] > 0
    _GRID_CACHE.update(g)
    return g


def var_mask(var, grid=None):
    """Boolean wet mask for a variable (3-D (k,j,i) or surface (j,i))."""
    g = grid or read_grid()
    info = {**ADJ_VARS, **ADXX_VARS}[var]
    wet = g["wet" + info["grid"]]
    return wet if var in {**ADJ_3D, **ADXX_3D} else wet[0]


def var_weights(var, grid=None):
    """Volume (3-D) or area (2-D) weights on wet cells, else 0."""
    g = grid or read_grid()
    info = {**ADJ_VARS, **ADXX_VARS}[var]
    ra = g[{"C": "RAC", "W": "RAW", "S": "RAS"}[info["grid"]]]
    hf = g["hFac" + info["grid"]]
    if var in {**ADJ_3D, **ADXX_3D}:
        return ra[None] * hf * g["DRF"][:, None, None]
    return ra * (hf[0] > 0)


# ----------------------------------------------------------------------------
# Comparison metrics
# ----------------------------------------------------------------------------
# a = member field, r = reference field, both already restricted to wet cells
# (1-D arrays), w = optional weights (None = unweighted).  All metrics are
# computed in float64.


def _w(x, w):
    return x if w is None else x * w


def pattern_corr(a, r, w=None, centered=True):
    """(Weighted) Pearson pattern correlation.  centered=False gives the
    uncentered (cosine) similarity, which also feels the mean offset."""
    a = np.asarray(a, np.float64)
    r = np.asarray(r, np.float64)
    if w is None:
        w = np.ones_like(a)
    sw = w.sum()
    if centered:
        a = a - (w * a).sum() / sw
        r = r - (w * r).sum() / sw
    num = (w * a * r).sum()
    den = np.sqrt((w * a * a).sum() * (w * r * r).sum())
    return num / den if den > 0 else np.nan


def rms(a, w=None):
    a = np.asarray(a, np.float64)
    if w is None:
        return np.sqrt(np.mean(a * a))
    return np.sqrt((w * a * a).sum() / w.sum())


def amp_ratio(a, r, w=None):
    """Amplitude ratio: RMS(member)/RMS(reference)."""
    rr = rms(r, w)
    return rms(a, w) / rr if rr > 0 else np.nan


def regression_slope(a, r, w=None):
    """Least-squares slope of member on reference through the origin.
    Unlike the RMS ratio it is signed and penalises decorrelation."""
    a = np.asarray(a, np.float64)
    r = np.asarray(r, np.float64)
    if w is None:
        w = np.ones_like(a)
    den = (w * r * r).sum()
    return (w * a * r).sum() / den if den > 0 else np.nan


def sign_agreement(a, r, w=None):
    """(Weighted) fraction of wet cells where member and reference agree in
    sign.  Cells where either field is exactly zero are excluded."""
    a = np.asarray(a, np.float64)
    r = np.asarray(r, np.float64)
    valid = (a != 0) & (r != 0)
    if not valid.any():
        return np.nan
    agree = (np.sign(a) == np.sign(r))[valid]
    if w is None:
        return agree.mean()
    wv = np.asarray(w, np.float64)[valid]
    return (wv * agree).sum() / wv.sum()


def nrmse_centered(a, r, w=None):
    """Centered RMS difference normalised by the reference standard
    deviation — the 'structure only' error (Taylor 2001), insensitive to a
    pure amplitude offset of the means."""
    a = np.asarray(a, np.float64)
    r = np.asarray(r, np.float64)
    if w is None:
        w = np.ones_like(a)
    sw = w.sum()
    ac = a - (w * a).sum() / sw
    rc = r - (w * r).sum() / sw
    sr = np.sqrt((w * rc * rc).sum() / sw)
    d = ac - rc
    return np.sqrt((w * d * d).sum() / sw) / sr if sr > 0 else np.nan


METRIC_FUNCS = dict(corr=pattern_corr,
                    corr_uncentered=lambda a, r, w=None: pattern_corr(a, r, w, centered=False),
                    amp_ratio=amp_ratio,
                    slope=regression_slope,
                    sign_agree=sign_agreement,
                    nrmse_c=nrmse_centered)

METRIC_LABELS = dict(
    corr="pattern correlation (centered)",
    corr_uncentered="pattern correlation (uncentered)",
    amp_ratio="amplitude ratio  RMS(member)/RMS(ref)",
    slope="regression slope on reference",
    sign_agree="sign-agreement fraction",
    nrmse_c="centered NRMSE (structure error)",
)

# ----------------------------------------------------------------------------
# xmitgcm loaders (same conventions as the earlier adjoint notebooks)
# ----------------------------------------------------------------------------

_XDIMS = {"C": ["j", "i"], "W": ["j", "i_g"], "S": ["j_g", "i"]}


def _extra_vars(table, three_d):
    out = {}
    for v, info in table.items():
        dims = (["k"] if three_d else []) + _XDIMS[info["grid"]]
        if v == "ADJwvel":
            dims = ["k_l", "j", "i"]
        out[v] = dict(dims=dims,
                      attrs=dict(standard_name=v,
                                 long_name=info["long_name"],
                                 units=info["units"]))
    return out


def open_adj(run, prefixes=None):
    """xmitgcm dataset of the ADJ* dumps of one run (time = forward order;
    remember the adjoint fills these in reverse)."""
    import xmitgcm
    prefixes = prefixes or list(ADJ_VARS)
    extra = {**_extra_vars({k: v for k, v in ADJ_3D.items() if k in prefixes}, True),
             **_extra_vars({k: v for k, v in ADJ_2D.items() if k in prefixes}, False)}
    return xmitgcm.open_mdsdataset(
        str(RUNS[run]["dir"]), grid_dir=str(RUNS[run]["dir"]),
        prefix=prefixes, ref_date=np.datetime64("2000-01-01T00:00:00"),
        delta_t=DT, extra_variables=extra)


def open_adxx(run, prefixes=None):
    """xmitgcm dataset of the adxx_* control gradients of one run."""
    import xmitgcm
    prefixes = prefixes or list(ADXX_VARS)
    extra = {**_extra_vars({k: v for k, v in ADXX_3D.items() if k in prefixes}, True),
             **_extra_vars({k: v for k, v in ADXX_2D.items() if k in prefixes}, False)}
    return xmitgcm.open_mdsdataset(
        str(RUNS[run]["dir"]), grid_dir=str(RUNS[run]["dir"]),
        prefix=prefixes, ref_date=np.datetime64("2000-01-01T00:00:00"),
        delta_t=DT, extra_variables=extra)


def open_cache(name):
    """Open one cache netCDF (see build_cache.py for the inventory)."""
    import xarray as xr
    p = CACHE_DIR / name
    if not p.exists():
        raise FileNotFoundError(
            f"{p} missing — run build_cache.py first (see its docstring)")
    return xr.open_dataset(p)


# ----------------------------------------------------------------------------
# Plotting conventions
# ----------------------------------------------------------------------------
# Signed sensitivity fields: RdBu_r, symmetric robust limits, light-grey land.
# Magnitude/spread fields: viridis (or magma), zero-anchored.
# Members are an ORDERED set (by kappa), so they take graded colours from
# viridis; the reference is always black and dashed in line plots.


def setup_style():
    import matplotlib as mpl
    mpl.rcParams.update({
        "figure.dpi": 110,
        "savefig.dpi": 200,
        "savefig.bbox": "tight",
        "font.size": 10,
        "axes.titlesize": 11,
        "axes.labelsize": 10,
        "axes.grid": True,
        "grid.alpha": 0.25,
        "grid.linewidth": 0.6,
        "axes.axisbelow": True,
        "image.interpolation": "nearest",
        "legend.framealpha": 0.9,
        "legend.fontsize": 9,
    })


def member_color(run):
    """Graded viridis colour by log2(kappa factor); REF is black."""
    import matplotlib.cm as cm
    if run == "REF":
        return "black"
    f = RUNS[run]["factor"]
    x = (np.log2(f) - np.log2(0.25)) / (np.log2(32) - np.log2(0.25))
    return cm.viridis(0.05 + 0.9 * x)


def line_kwargs(run):
    kw = dict(color=member_color(run), label=RUNS[run]["label"], lw=1.6)
    if run == "REF":
        kw.update(ls="--", lw=2.2, zorder=5)
    return kw


def robust_sym(field, p=99.0):
    """Symmetric colour limit at the p-th percentile of |finite values|."""
    a = np.asarray(field)
    a = np.abs(a[np.isfinite(a)])
    if a.size == 0:
        return 1.0
    v = np.percentile(a, p)
    if not np.isfinite(v) or v == 0:
        v = a.max() if a.max() > 0 else 1.0
    return float(v)


def masked(field, var, grid=None):
    """NaN out land for plotting.  field is (k,j,i) or (j,i) or a level."""
    m = var_mask(var, grid)
    f = np.array(field, np.float64)
    if f.ndim == 2 and m.ndim == 3:
        raise ValueError("pass the matching level of the 3-D mask yourself, "
                         "or the full 3-D field")
    return np.where(m, f, np.nan)


def plot_map(ax, field2d, grid=None, vmax=None, p=99.0, cmap="RdBu_r",
             title="", cbar_label="", diverging=True, vmin=None):
    """Publication-style map on the model's lon/lat mesh.

    field2d must already be masked (NaN on land).  Returns the mesh handle;
    adds its own colourbar.
    """
    import matplotlib.pyplot as plt
    g = grid or read_grid()
    if vmax is None:
        vmax = robust_sym(field2d, p)
    if diverging:
        vmin = -vmax
    elif vmin is None:
        vmin = 0.0
    cm_obj = plt.get_cmap(cmap).copy()
    cm_obj.set_bad("0.82")
    pm = ax.pcolormesh(g["XC"], g["YC"], field2d, cmap=cm_obj,
                       vmin=vmin, vmax=vmax, shading="auto", rasterized=True)
    ax.set_xlabel("longitude [°]")
    ax.set_ylabel("latitude [°]")
    ax.set_title(title)
    ax.grid(False)
    cb = ax.figure.colorbar(pm, ax=ax, pad=0.02, shrink=0.9)
    cb.set_label(cbar_label)
    return pm


def mark_cost_section(ax, grid=None, **kw):
    """Overlay the 26°N cost section on a map axis."""
    g = grid or read_grid()
    kw.setdefault("color", "limegreen")
    kw.setdefault("lw", 1.8)
    ax.plot(g["XC"][JSEC], g["YC"][JSEC], **kw)


def fig_dir(nb_stem):
    d = FIG_ROOT / nb_stem
    d.mkdir(parents=True, exist_ok=True)
    return d


def save_fig(fig, nb_stem, name):
    """Save a figure under figures/<notebook>/<name>.png and report the path."""
    p = fig_dir(nb_stem) / f"{name}.png"
    fig.savefig(p)
    print(f"saved {p}")
    return p


# ----------------------------------------------------------------------------
# Self-contained interactive HTML animations
# ----------------------------------------------------------------------------
# Rationale: a single .html file with base64-embedded JPEG frames plays
# anywhere (email/Slack/browser, no server, no JS libraries, no internet),
# and gives a real slider over time plus a second selector over depth —
# which matplotlib's to_jshtml() (time only, much larger payload) and
# plotly (needs its runtime, slow at hundreds of frames) do not match.


def fig_to_jpeg(fig, dpi=100, quality=82):
    """Render a matplotlib figure to JPEG bytes (falls back to PNG)."""
    buf = io.BytesIO()
    try:
        fig.savefig(buf, format="jpg", dpi=dpi,
                    pil_kwargs={"quality": quality})
        mime = "jpeg"
    except Exception:
        buf = io.BytesIO()
        fig.savefig(buf, format="png", dpi=dpi)
        mime = "png"
    return buf.getvalue(), mime


def write_html_animation(path, title, groups, subtitle="", footer="",
                         group_name="Depth", fps=6):
    """Write a self-contained interactive animation.

    Parameters
    ----------
    path : output .html file
    groups : dict {group_label: [(frame_label, jpeg_bytes, mime), ...]}
        one entry per depth level (or any second dimension); a single-entry
        dict hides the group selector.  Frames must be in DISPLAY order —
        the suite convention (all notebooks, since 2026-09-01) is ADJOINT
        COMPUTATION order for ADJ* fields: lead increasing, i.e. iterate
        the forward-numbered dumps reversed, and label every frame.
    """
    path = Path(path)
    payload = {}
    for gl, frames in groups.items():
        payload[gl] = [
            dict(l=lab, m=mime, d=base64.b64encode(b).decode("ascii"))
            for (lab, b, mime) in frames
        ]
    import json
    data_js = json.dumps(payload)
    group_labels = list(groups)
    sel_html = ""
    if len(group_labels) > 1:
        opts = "".join(f'<option value="{g}">{g}</option>' for g in group_labels)
        sel_html = (f'<label>{group_name}: <select id="grp">{opts}</select>'
                    f'</label>')
    html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>{title}</title>
<style>
 body {{ font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
        margin: 0; background: #fafaf7; color: #1a1a1a; }}
 .wrap {{ max-width: 1060px; margin: 0 auto; padding: 18px 22px 30px; }}
 h1 {{ font-size: 19px; margin: 4px 0 2px; }}
 .sub {{ color: #555; font-size: 13px; margin-bottom: 10px; }}
 .frame {{ text-align: center; background: #fff; border: 1px solid #ddd;
          border-radius: 8px; padding: 8px; }}
 .frame img {{ max-width: 100%; height: auto; }}
 .controls {{ display: flex; gap: 14px; align-items: center; flex-wrap: wrap;
             margin: 12px 0; font-size: 14px; }}
 .controls button {{ font-size: 15px; padding: 3px 14px; cursor: pointer; }}
 #slider {{ flex: 1 1 320px; }}
 #lab {{ font-variant-numeric: tabular-nums; color: #333; min-width: 21em; }}
 .foot {{ color: #777; font-size: 12px; margin-top: 10px; }}
</style></head><body><div class="wrap">
<h1>{title}</h1>
<div class="sub">{subtitle}</div>
<div class="controls">
 <button id="play">&#9658;</button>
 <button id="prev">&#9664;&#9664;</button>
 <button id="next">&#9654;&#9654;</button>
 <input type="range" id="slider" min="0" value="0">
 <label>fps <select id="fps">
   <option>2</option><option>4</option><option selected>{fps}</option>
   <option>10</option><option>15</option></select></label>
 {sel_html}
 <span id="lab"></span>
</div>
<div class="frame"><img id="im" alt="animation frame"></div>
<div class="foot">{footer}<br>
Drag the slider or use &larr;/&rarr; keys; space toggles play.
Self-contained file — safe to forward.</div>
</div>
<script>
const DATA = {data_js};
const groups = Object.keys(DATA);
let grp = groups[0], idx = 0, playing = false, timer = null;
const im = document.getElementById('im'), sl = document.getElementById('slider'),
      lab = document.getElementById('lab'), play = document.getElementById('play'),
      fpsSel = document.getElementById('fps'), grpSel = document.getElementById('grp');
function frames() {{ return DATA[grp]; }}
function show(i) {{
  const f = frames(); idx = Math.max(0, Math.min(i, f.length - 1));
  im.src = 'data:image/' + f[idx].m + ';base64,' + f[idx].d;
  sl.value = idx; lab.textContent = (idx+1) + '/' + f.length + '  ' + f[idx].l;
}}
function setGroup(g) {{ grp = g; sl.max = frames().length - 1; show(Math.min(idx, frames().length-1)); }}
function tick() {{ show(idx + 1 >= frames().length ? 0 : idx + 1); }}
function setPlay(p) {{
  playing = p; play.innerHTML = p ? '&#10074;&#10074;' : '&#9658;';
  if (timer) clearInterval(timer);
  if (p) timer = setInterval(tick, 1000 / parseFloat(fpsSel.value));
}}
play.onclick = () => setPlay(!playing);
document.getElementById('prev').onclick = () => {{ setPlay(false); show(idx-1); }};
document.getElementById('next').onclick = () => {{ setPlay(false); show(idx+1); }};
sl.oninput = e => {{ setPlay(false); show(parseInt(e.target.value)); }};
fpsSel.onchange = () => {{ if (playing) setPlay(true); }};
if (grpSel) grpSel.onchange = e => setGroup(e.target.value);
document.addEventListener('keydown', e => {{
  if (e.key === 'ArrowRight') {{ setPlay(false); show(idx+1); }}
  if (e.key === 'ArrowLeft')  {{ setPlay(false); show(idx-1); }}
  if (e.key === ' ') {{ e.preventDefault(); setPlay(!playing); }}
}});
setGroup(grp);
</script></body></html>
"""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html)
    mb = path.stat().st_size / 1e6
    print(f"wrote {path}  ({mb:.1f} MB)")
    if mb > 80:
        print("WARNING: file large for e-mail; consider a bigger frame stride")
    return path
