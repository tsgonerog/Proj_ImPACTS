# `viscosity_study/` — adjoint runs at the study's viscosity settings

The adjoint half of [`../../../input/variants/viscosity_study/`](../../../input/variants/viscosity_study/):
adjoint runs using the scalar `viscAhGrid` formulation rather than the `PARM05`
files, from two different starting points.

| Tag | Start |
| --- | --- |
| `from_rest_viscGrid1p8e-2` | from rest |
| `from50yrPk_viscGrid1p8e-2` | from the 50-year pickup (`nIter0=878400`) |

A long adjoint at these settings may need `adjointViscosity/` to stay stable — see
that group.
