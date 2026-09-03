# Adjoint run comparison — M2 (0.5× κ)
- reference: `/scratch2/tshahriar/DINO_1deg_tapAdj_runs/DINO_1deg_tapAdj_ckpAll_5yr_M2_run31041`
- test:      `/scratch2/tshahriar/DINO_1deg_tapAdj_runs/DINO_1deg_tapAdj_nocheckpoint_5yr_M2_run31062`

## Runtime
| run | wall time | seconds | forward sweep | reverse sweep |
|---|---|---|---|---|
| reference | 14:18:39 | 51519 | 00:51:32 | 13:27:06 |
| test | 09:38:14 | 34694 | 00:50:32 | 08:47:41 |

speed-up (ref/test) = **1.485x**, time saved = 32.7 %
reverse-sweep speed-up = 1.530x, forward sweep 3092 s vs 3032 s

The forward sweep is measured to the write of `ADJtheta.0003249840`, the first dump of the reverse sweep (the turn plus 240 backward steps).

## Cost function
- reference fc = 0.259781466212249
- test      fc = 0.259781466212249
- identical: **True**

## adxx_* control gradients (32 files in reference)
| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |
|---|---|---|---|---|---|---|
| adxx_diffkr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 3.802e+02 |
| adxx_empmr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.696e+05 |
| adxx_empmr.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_empmr.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 2.606e-01 |
| adxx_fu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.982e+04 |
| adxx_fv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 4.874e-01 |
| adxx_qnet.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.295e-05 |
| adxx_qsw.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_salt | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 5.225e-03 |
| adxx_tauu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_theta | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.348e-03 |
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
| ADJdiffkr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 3.802e+02 |
| ADJempmr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 2.143e+00 |
| ADJetan | 367 | 367/367 | 0.000e+00 | 0.000e+00 | 0 | 3.126e-04 |
| ADJqnet | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 6.679e-06 |
| ADJqsw | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 4.895e-09 |
| ADJsalt | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 2.146e-01 |
| ADJtaux | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 3.123e-04 |
| ADJtauy | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 3.057e-01 |
| ADJtheta | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 4.816e-02 |
| ADJuvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 6.592e-03 |
| ADJvvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 8.908e-03 |
| ADJwvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 5.085e-02 |

**4393/4393 files bitwise identical.**

## Blow-up reproduction (ADJtheta, adxx_theta)
| run | non-finite in ADJtheta at lead 5 yr | first non-finite ADJtheta dump (adjoint order) | non-finite in adxx_theta | max finite |ADJtheta| at lead 5 yr |
|---|---|---|---|---|
| reference | 0 | none | 0 | 1.348e-03 |
| test | 0 | none | 0 | 1.348e-03 |

## tools/compare_adj_runs.sh
- verdict: **EQUIVALENT**
- %MON stream: 18801 lines, byte-identical

