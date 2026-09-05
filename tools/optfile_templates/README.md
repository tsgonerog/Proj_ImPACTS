# `tools/optfile_templates/`

`genmake2` optfiles written for this project that are **not part of the vendored
MITgcm tree** and have **not been validated on the machine they target**.

They live here rather than in `MITgcm_c69m/MITgcm/tools/build_options/` on
purpose. That directory holds 93 upstream optfiles that are known to work; an
untested one sitting among them reads as a peer of theirs and invites being
trusted. Keeping them separate also means the vendored tree deviates from stock
MITgcm by as little as possible — see "How the vendored tree deviates" in
`CLAUDE.md`.

## Contents

| File | Target | Status |
| --- | --- | --- |
| `linux_amd64_gnu+mpi_perlmutter` | Perlmutter (NERSC), CPU partition, PrgEnv-gnu | **Never compile-tested.** Written from MITgcm's gfortran and Cray templates plus NERSC's documented compiler wrappers |

## How this one gets used

`tools/machine_env.sh` points `MPI_OPTFILE` and `SERIAL_OPTFILE` here when
`MACHINE=perlmutter`, so a first build runs and produces real compiler errors to
work from rather than failing on a missing file. `impacts_check_env` prints a
warning for as long as the template is what is in use — `tools/submit.sh` shows
it and continues.

Adapting it:

```bash
cp tools/optfile_templates/linux_amd64_gnu+mpi_perlmutter ~/my_perlmutter_optfile
# edit, build, repeat
export IMPACTS_MPI_OPTFILE=~/my_perlmutter_optfile     # silences the warning
```

Alternatively edit the file in place and update its `STATUS:` header once it
builds — but then the warning stays until you also set `IMPACTS_MPI_OPTFILE`,
since the warning keys off the path, not the contents.

Things most likely to need changing, in the order worth trying (from
`PORTING.md`):

1. **`FOPTIM`** — `-march=znver3` assumes the EPYC 7763 CPU nodes. Drop to
   `-march=native`, or remove it, if a build misbehaves.
2. **Optimisation level** — lower `-O2` before suspecting anything else. The
   adjoint is far more sensitive to aggressive optimisation than the forward.
3. **netCDF paths** — the `INCLUDES`/`LIBS` lines are commented out because this
   project uses neither `useSingleCpuIO` nor `pkg/mnc`. Uncomment if that changes.

Note `-fconvert=big-endian` is **not** optional: every pickup, input binary and
`ADJ*`/`adxx*` file in this project was written big-endian on sverdrup, and
removing it makes them unreadable across the two machines.

## When one is validated

Update its `STATUS:` and `Tested on:` header lines with what it was tested
against, and say so in `PORTING.md`. Moving it into the vendored
`build_options/` is not necessary — `genmake2 -of` takes any path, and leaving
it here keeps the vendored tree clean.
