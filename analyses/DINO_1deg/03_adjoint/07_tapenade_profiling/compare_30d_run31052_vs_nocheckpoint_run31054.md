# Adjoint run comparison
- reference: `/scratch2/tshahriar/DINO_1deg_tapAdj_runs/DINO_1deg_tapAdj_ckpAll_30d_from180yrPk_visc2x_run31052`
- test:      `/scratch2/tshahriar/DINO_1deg_tapAdj_runs/DINO_1deg_tapAdj_nocheckpoint_30d_from180yrPk_visc2x_run31054`

## Runtime
| run | wall time | seconds |
|---|---|---|
| reference | 00:13:13 | 793 |
| test | 00:08:47 | 527 |

speed-up (ref/test) = **1.505x**, time saved = 33.5 %

## Cost function
- reference fc = 0.348990284064362
- test      fc = 0.348990284064362
- identical: **True**

## adxx_* control gradients (32 files in reference)
| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |
|---|---|---|---|---|---|---|
| adxx_diffkr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.127e+00 |
| adxx_empmr | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 3.239e+01 |
| adxx_empmr.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_empmr.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 3.379e-02 |
| adxx_fu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 4.596e+01 |
| adxx_fv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_fv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 9.111e-05 |
| adxx_qnet.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qnet.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 2.486e-07 |
| adxx_qsw.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_qsw.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_salt | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 1.773e-01 |
| adxx_tauu | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauu.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_tauv.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_theta | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 3.857e-02 |
| adxx_uvel | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_uwind | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_uwind.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_uwind.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_vvel | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_vwind | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_vwind.effective | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |
| adxx_vwind.tmp | 1 | 1/1 | 0.000e+00 | 0.000e+00 | 0 | 0.000e+00 |

**32/32 files bitwise identical.**

## ADJ* sensitivity dumps (73 files in reference)
| field | files | bitwise identical | max |diff| | max |diff| / max|ref| | differing elements | max|ref| |
|---|---|---|---|---|---|---|
| ADJdiffkr | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 1.127e+00 |
| ADJempmr | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 5.111e-02 |
| ADJetan | 7 | 7/7 | 0.000e+00 | 0.000e+00 | 0 | 2.233e-04 |
| ADJqnet | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 1.417e-07 |
| ADJqsw | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 2.625e-10 |
| ADJsalt | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 1.773e-01 |
| ADJtaux | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 3.202e-05 |
| ADJtauy | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 6.101e-02 |
| ADJtheta | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 3.857e-02 |
| ADJuvel | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 6.818e-03 |
| ADJvvel | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 7.602e-03 |
| ADJwvel | 6 | 6/6 | 0.000e+00 | 0.000e+00 | 0 | 1.013e-02 |

**73/73 files bitwise identical.**

