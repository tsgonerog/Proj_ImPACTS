# Adjoint run comparison — M4 (4× κ)
- reference: `/scratch2/tshahriar/DINO_1deg_outputs/runs/adjoint/kappa_v_ensemble/DINO_1deg_tapAdj_ckpAll_5yr_M4_run31043`
- test:      `DINO_1deg_tapAdj_nocheckpoint_5yr_M4_run31064` *(deleted 2026-09-03; it was bitwise identical to the reference, so this report is the record)*

## Runtime
| run | wall time | seconds | forward sweep | reverse sweep |
|---|---|---|---|---|
| reference | 14:04:21 | 50661 | 00:51:02 | 13:13:18 |
| test | 09:30:47 | 34247 | 00:50:12 | 08:40:34 |

speed-up (ref/test) = **1.479x**, time saved = 32.4 %
reverse-sweep speed-up = 1.524x, forward sweep 3062 s vs 3012 s

The forward sweep is measured to the write of `ADJtheta.0003249840`, the first dump of the reverse sweep (the turn plus 240 backward steps).

## Cost function
- reference fc = 0.273085893331951
- test      fc = 0.273085893331951
- identical: **True**

## adxx_* control gradients (32 files in reference)
| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |
|---|---|---|---|---|---|---|
| adxx_diffkr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 6.455e+48 |
| adxx_empmr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.442e+53 |
| adxx_empmr.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_empmr.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.640e+46 |
| adxx_fu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 6.864e+50 |
| adxx_fv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.993e+46 |
| adxx_qnet.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 2.138e+41 |
| adxx_qsw.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_salt | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 7.904e+43 |
| adxx_tauu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_theta | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 9.890e+42 |
| adxx_uvel | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_uwind | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_uwind.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_uwind.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_vvel | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_vwind | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_vwind.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_vwind.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |

**32/32 files bitwise identical.**

## ADJ* sensitivity dumps (4393 files in reference)
| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |
|---|---|---|---|---|---|---|
| ADJdiffkr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJempmr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJetan | 367 | 367/367 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJqnet | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJqsw | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJsalt | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJtaux | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJtauy | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJtheta | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJuvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJvvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |
| ADJwvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | inf |

**4393/4393 files bitwise identical.**

## Blow-up reproduction (ADJtheta, adxx_theta)
| run | non-finite in ADJtheta at lead 5 yr | first non-finite ADJtheta dump (adjoint order) | non-finite in adxx_theta | max finite |ADJtheta| at lead 5 yr |
|---|---|---|---|---|
| reference | 123660 | iter 3198240 (lead 2.95 yr) | 0 | 3.402e+38 |
| test | 123660 | iter 3198240 (lead 2.95 yr) | 0 | 3.402e+38 |

## tools/compare_adj_runs.sh
- verdict: **EQUIVALENT**
- %MON stream: 18801 lines, byte-identical

