# Adjoint run comparison — M6 (16× κ)
- reference: `/scratch2/tshahriar/DINO_1deg_outputs/runs/adjoint/kappa_v_ensemble/DINO_1deg_tapAdj_ckpAll_5yr_M6_run31045`
- test:      `DINO_1deg_tapAdj_nocheckpoint_5yr_M6_run31066` *(deleted 2026-09-03; it was bitwise identical to the reference, so this report is the record)*

## Runtime
| run | wall time | seconds | forward sweep | reverse sweep |
|---|---|---|---|---|
| reference | 14:02:37 | 50557 | 00:51:31 | 13:11:05 |
| test | 09:38:31 | 34711 | 00:50:22 | 08:48:08 |

speed-up (ref/test) = **1.457x**, time saved = 31.3 %
reverse-sweep speed-up = 1.498x, forward sweep 3091 s vs 3022 s

The forward sweep is measured to the write of `ADJtheta.0003249840`, the first dump of the reverse sweep (the turn plus 240 backward steps).

## Cost function
- reference fc = 0.365433572596538
- test      fc = 0.365433572596538
- identical: **True**

## adxx_* control gradients (32 files in reference)
| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |
|---|---|---|---|---|---|---|
| adxx_diffkr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 6.631e+00 |
| adxx_empmr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.850e+05 |
| adxx_empmr.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_empmr.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.416e-02 |
| adxx_fu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 4.102e+03 |
| adxx_fv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 2.816e-01 |
| adxx_qnet.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 3.380e-07 |
| adxx_qsw.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_salt | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 2.630e-03 |
| adxx_tauu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_theta | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 6.399e-04 |
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
| ADJdiffkr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 6.645e+00 |
| ADJempmr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 2.676e+00 |
| ADJetan | 367 | 367/367 | 0.000e+00 | 0.000e+00 | 0 | 2.172e-04 |
| ADJqnet | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 4.078e-06 |
| ADJqsw | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.449e-10 |
| ADJsalt | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.293e-01 |
| ADJtaux | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 3.355e-05 |
| ADJtauy | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 9.632e-02 |
| ADJtheta | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 2.495e-02 |
| ADJuvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 5.923e-03 |
| ADJvvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 6.996e-03 |
| ADJwvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.483e-02 |

**4393/4393 files bitwise identical.**

## Blow-up reproduction (ADJtheta, adxx_theta)
| run | non-finite in ADJtheta at lead 5 yr | first non-finite ADJtheta dump (adjoint order) | non-finite in adxx_theta | max finite |ADJtheta| at lead 5 yr |
|---|---|---|---|---|
| reference | 0 | none | 0 | 6.399e-04 |
| test | 0 | none | 0 | 6.399e-04 |

## tools/compare_adj_runs.sh
- verdict: **EQUIVALENT**
- %MON stream: 18801 lines, byte-identical

