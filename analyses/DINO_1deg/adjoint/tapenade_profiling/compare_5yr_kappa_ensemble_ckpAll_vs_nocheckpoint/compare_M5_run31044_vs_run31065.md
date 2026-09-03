# Adjoint run comparison — M5 (8× κ)
- reference: `/scratch2/tshahriar/DINO_1deg_outputs/runs/adjoint/kappa_v_ensemble/DINO_1deg_tapAdj_ckpAll_5yr_M5_run31044`
- test:      `DINO_1deg_tapAdj_nocheckpoint_5yr_M5_run31065` *(deleted 2026-09-03; it was bitwise identical to the reference, so this report is the record)*

## Runtime
| run | wall time | seconds | forward sweep | reverse sweep |
|---|---|---|---|---|
| reference | 14:09:52 | 50992 | 00:51:08 | 13:18:43 |
| test | 09:31:20 | 34280 | 00:50:07 | 08:41:12 |

speed-up (ref/test) = **1.488x**, time saved = 32.8 %
reverse-sweep speed-up = 1.532x, forward sweep 3068 s vs 3007 s

The forward sweep is measured to the write of `ADJtheta.0003249840`, the first dump of the reverse sweep (the turn plus 240 backward steps).

## Cost function
- reference fc = 0.302082512248082
- test      fc = 0.302082512248082
- identical: **True**

## adxx_* control gradients (32 files in reference)
| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |
|---|---|---|---|---|---|---|
| adxx_diffkr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 6.643e+15 |
| adxx_empmr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 5.334e+18 |
| adxx_empmr.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_empmr.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.628e+14 |
| adxx_fu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 4.175e+18 |
| adxx_fv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 8.982e+12 |
| adxx_qnet.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 2.482e+08 |
| adxx_qsw.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_salt | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 9.320e+13 |
| adxx_tauu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_theta | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.915e+13 |
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
| ADJdiffkr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 6.643e+15 |
| ADJempmr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.192e+14 |
| ADJetan | 367 | 367/367 | 0.000e+00 | 0.000e+00 | 0 | 1.606e+12 |
| ADJqnet | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 2.609e+08 |
| ADJqsw | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 3.051e+05 |
| ADJsalt | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 2.023e+17 |
| ADJtaux | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.857e+11 |
| ADJtauy | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 8.397e+13 |
| ADJtheta | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.562e+15 |
| ADJuvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 4.129e+14 |
| ADJvvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 3.379e+14 |
| ADJwvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.840e+13 |

**4393/4393 files bitwise identical.**

## Blow-up reproduction (ADJtheta, adxx_theta)
| run | non-finite in ADJtheta at lead 5 yr | first non-finite ADJtheta dump (adjoint order) | non-finite in adxx_theta | max finite |ADJtheta| at lead 5 yr |
|---|---|---|---|---|
| reference | 0 | none | 0 | 1.915e+13 |
| test | 0 | none | 0 | 1.915e+13 |

## tools/compare_adj_runs.sh
- verdict: **EQUIVALENT**
- %MON stream: 18801 lines, byte-identical

