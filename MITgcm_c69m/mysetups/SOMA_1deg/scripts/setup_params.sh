#!/bin/bash
# scripts/setup_params.sh -- what makes SOMA_1deg different from the other
# setups, for the shared build and submit bodies (tools/lib/build_body.sh,
# tools/lib/submit_body.sh). Sourced by them, never executed; every build_*.sh
# and submit_*.sh definition beside this file gets these without repeating them.

# ---------- time stepping ----------
DELTA_T=1200              # s
DURATION_KEY=endTime      # SOMA's namelist states the run length as endTime
                          # (seconds), not DINO's nTimeSteps
DAYS_PER_YEAR=360         # SOMA uses a 360-day year: whole years label a run <n>yr

# ---------- generated-hook assertions (adjoint builds) ----------
# SOMA carries only the two dump hooks (ADJ* and ADJetan); it has no
# adjoint-mode viscosity machinery, so no mode-switch hooks. Each hook's
# Tapenade-generated _B call must carry exactly the argument count the
# hand-written routine in code_tap/dummy_tap.F declares (dump hook 11
# value/adjoint pairs + myTime, myIter, myThid = 25; etaN dump 1 pair + 3 = 5).
HOOK_CHECKS=(
    "DUMMY_IN_STEPPING_B 25 forward_step_b.f"
    "DUMMY_FOR_ETAN_B 5 integr_continuity_b.f"
)
# The compiled dummy_tap.f must still carry the ten ADJ* dump calls; they vanish
# silently if the file loses its AD_CONFIG.h include.
DUMP_CALLS=10

# No run_suffix_from_namelist: a run of the live namelist is named by its
# duration alone (SOMA_1deg_<run_token>_<duration>_run<jobid>), as SOMA runs
# always were. Define one here if SOMA ever gains namelist variants worth
# telling apart by name.
