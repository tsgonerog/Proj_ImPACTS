# `kappa_v_ensemble/` — forward legs

Vertical-mixing perturbation ensemble, Part I of
[`notes/nn_surrogate/`](../../../../../../notes/nn_surrogate/): **do the adjoint
sensitivity patterns depend on the model's vertical mixing?**

These seven namelists are the **forward re-equilibration leg**, year 2170 →
2180, each at its own vertical diffusivity. The adjoint half lives in
[`../../../input_tap/variants/kappa_v_ensemble/`](../../../input_tap/variants/kappa_v_ensemble/).

| Tag | κ_v (m² s⁻¹) | × reference |
| --- | --- | --- |
| `M1` | 3.0e-6 | 0.25 |
| `M2` | 6.0e-6 | 0.5 |
| `M3` | 2.4e-5 | 2 |
| `M4` | 4.8e-5 | 4 |
| `M5` | 9.6e-5 | 8 |
| `M6` | 1.92e-4 | 16 |
| `M7` | 3.84e-4 | 32 |

The reference is 1.2e-5 m² s⁻¹, and the completed 200-year spin-up is the
control — so the design needs seven new runs, not eight.

```bash
cd MITgcm_c69m/mysetups/DINO_1deg
IMPACTS_TEST_CASE=kappa_v_ensemble/M3 ../../../tools/submit.sh submit_frd.sh
```

Each file differs from `../data_from_rest_visc2x` in exactly three lines:

- `nIter0=2986560` — the nearest spin-up checkpoint below year 2170
- `pChkptFreq=316224000.` — raised so only the final pickup is written. The
  spin-up's own 2,400 monthly restarts are the Axis-2 dataset and must **not**
  be thinned this way
- `diffKrFile='dino_diffKr_M<n>.bin'` — the member's κ field

`nTimeSteps=175680` lands exactly on year 2180, whose pickup the matching
adjoint run reads. **`nIter0` and the pickup are coupled by hand** — the pickup
is a hardcoded `ln -s` in `submit_frd.sh`, not an auto-patched parameter.

The κ fields themselves are `input_binaries/dino_diffKr_M<n>.bin`, untracked
like everything else there; Appendix B of the master plan carries the snippet
that regenerates them, and each must be 2,908,224 bytes of big-endian float64.

**Outcome (runs 30996–31002, 2026-08-28/29).** All seven forward legs completed
and are healthy; each wrote its year-2180 pickup and its matching adjoint ran
from it. Results live in `analyses/DINO_1deg/03_adjoint/05_kappa_v_ensemble/`
and `notes/nn_surrogate/` (master Part I §Results) — including the caveat that
four of the seven *adjoint* legs blow up (see the adjoint-side
`input_tap/variants/kappa_v_ensemble/README.md`).
