# `viscosity_study/` — how lateral viscosity is specified

Viscosity is the axis most DINO experiments vary, and there are two different
ways to set it. These variants explore both, all from rest.

| Tag | Setting |
| --- | --- |
| `from_rest_viscD2x_Zref` | `viscAhDfile` at 2× but `viscAhZfile` left at the reference field — a **mixed** setting. This is the configuration whose 200-year spin-up crashed at 126.3 years |
| `from_rest_viscGrid1p8e-2_A4Grid1p0e-2` | the scalar `viscAhGrid=1.8E-2` in `PARM01` with biharmonic `viscA4Grid=1.0E-2`, `PARM05` files commented out |
| `..._C4Leith1p5` | as above plus Leith |
| `..._CDscheme` | as above plus the C-D scheme |

Read `p` as the decimal point: `1p8e-2` is `1.8E-2`. The analysis side is
`analyses/DINO_1deg/02_forward/01_viscosity_study/`, and `analyses/README.md`
carries the token vocabulary.
