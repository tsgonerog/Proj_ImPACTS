# Adjoint run comparison — REF, 31039 vs 31055 (the 2026-09-01 single-run validation, recomputed)
- reference: `/scratch2/tshahriar/DINO_1deg_outputs/runs/adjoint/kappa_v_ensemble/DINO_1deg_tapAdj_ckpAll_5yr_from180yrPk_visc2x_run31039`
- test:      `DINO_1deg_tapAdj_nocheckpoint_5yr_from180yrPk_visc2x_run31055` *(deleted 2026-09-03; it was bitwise identical to the reference, so this report is the record)*

## Runtime
| run | wall time | seconds | forward sweep | reverse sweep |
|---|---|---|---|---|
| reference | 14:05:45 | 50745 | 00:51:36 | 13:14:08 |
| test | 09:35:58 | 34558 | 00:50:38 | 08:45:19 |

speed-up (ref/test) = **1.468x**, time saved = 31.9 %
reverse-sweep speed-up = 1.512x, forward sweep 3096 s vs 3038 s

The forward sweep is measured to the write of `ADJtheta.0003249840`, the first dump of the reverse sweep (the turn plus 240 backward steps).

## Cost function
- reference fc = 0.330992121938681
- test      fc = 0.330992121938681
- identical: **True**

## adxx_* control gradients (32 files in reference)
| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |
|---|---|---|---|---|---|---|
| adxx_diffkr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 3.721e+01 |
| adxx_empmr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 5.287e+04 |
| adxx_empmr.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_empmr.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 2.671e-02 |
| adxx_fu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 5.886e+03 |
| adxx_fv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 6.202e-02 |
| adxx_qnet.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 3.527e-06 |
| adxx_qsw.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_salt | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 3.927e-03 |
| adxx_tauu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_theta | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 8.906e-04 |
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
| ADJdiffkr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 4.021e+01 |
| ADJempmr | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 8.836e-01 |
| ADJetan | 367 | 367/367 | 0.000e+00 | 0.000e+00 | 0 | 2.175e-04 |
| ADJqnet | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 9.097e-07 |
| ADJqsw | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 5.000e-10 |
| ADJsalt | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.864e-01 |
| ADJtaux | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 6.925e-05 |
| ADJtauy | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 9.307e-02 |
| ADJtheta | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 3.598e-02 |
| ADJuvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 6.681e-03 |
| ADJvvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 7.848e-03 |
| ADJwvel | 366 | 366/366 | 0.000e+00 | 0.000e+00 | 0 | 1.097e-02 |

**4393/4393 files bitwise identical.**

## Blow-up reproduction (ADJtheta, adxx_theta)
| run | non-finite in ADJtheta at lead 5 yr | first non-finite ADJtheta dump (adjoint order) | non-finite in adxx_theta | max finite |ADJtheta| at lead 5 yr |
|---|---|---|---|---|
| reference | 0 | none | 0 | 8.906e-04 |
| test | 0 | none | 0 | 8.906e-04 |

