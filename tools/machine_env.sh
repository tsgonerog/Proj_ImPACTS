# shellcheck shell=bash
#
# Per-machine settings for build and submit scripts.  SOURCE THIS, do not run it:
#
#     source "$REPO_ROOT/tools/machine_env.sh"
#
# Everything that differs between clusters lives here, so porting to a new
# machine means adding one case block rather than editing every script.
#
# The sverdrup values are the defaults and reproduce the behaviour these scripts
# had before this file existed. Any variable already set in the environment wins,
# so you can override one value for a single invocation without editing anything:
#
#     SCRATCH_ROOT=/tmp/test ../../../tools/submit.sh submit_tapAdj.sh
#
# Variables exported
#   MACHINE         sverdrup | perlmutter
#   SCRATCH_ROOT    where run directories are staged
#   MPI_LAUNCHER    command + rank flag, e.g. "mpirun -n" or "srun -n"
#   MPI_OPTFILE     genmake2 -of for MPI builds
#   SERIAL_OPTFILE  genmake2 -of for serial builds
#
# The two optfiles are set from the machine, NOT inherited from the environment.
# ~/.bashrc on sverdrup exports MPI_OPTFILE, and letting that win would silently
# build Perlmutter with the Intel sverdrup optfile. To use a different one:
#   export IMPACTS_MPI_OPTFILE=/path/to/optfile
#   SBATCH_EXTRA    extra sbatch flags (account/qos/constraint/walltime)
#   MAIL_USER       notification address
#
# Function
#   impacts_load_modules   loads the compiler/MPI stack for this machine

# --- locate the repo, so MITGCM_ROOT can be defaulted -----------------------
if [ -z "${IMPACTS_ROOT:-}" ]; then
    IMPACTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
: "${MITGCM_ROOT:=$IMPACTS_ROOT/MITgcm_c69m/MITgcm}"

# --- which machine ----------------------------------------------------------
# NERSC sets NERSC_HOST on every login and compute node. sverdrup sets nothing
# reliable (compute nodes are named c1-1 and friends), so it is the default.
# Override with IMPACTS_MACHINE=<name> to force one.
if [ -n "${IMPACTS_MACHINE:-}" ]; then
    MACHINE="$IMPACTS_MACHINE"
elif [ -n "${NERSC_HOST:-}" ]; then
    MACHINE="$NERSC_HOST"
else
    MACHINE="sverdrup"
fi

case "$MACHINE" in

sverdrup)
    : "${SCRATCH_ROOT:=/scratch2/$USER}"
    : "${MPI_LAUNCHER:=mpirun -n}"
    MPI_OPTFILE="${IMPACTS_MPI_OPTFILE:-$HOME/tools_and_software/crios_computing/computing/optfiles/linux_amd64_ifort+mpi_sverdrup}"
    SERIAL_OPTFILE="${IMPACTS_SERIAL_OPTFILE:-$MITGCM_ROOT/tools/build_options/linux_amd64_ifort}"
    : "${SBATCH_EXTRA:=}"
    : "${MAIL_USER:=tanvirshahriar@utexas.edu}"
    impacts_load_modules() {
        # The Intel + MPI + Tapenade stack is loaded from ~/.bashrc here, so
        # there is nothing to do. Kept as a no-op so callers stay identical.
        :
    }
    ;;

perlmutter)
    : "${SCRATCH_ROOT:=${SCRATCH:-/pscratch/sd/${USER:0:1}/$USER}}"
    # NERSC wants srun; mpirun is not supported on Perlmutter.
    : "${MPI_LAUNCHER:=srun -n}"
    # UNTESTED template, deliberately kept out of MITgcm/tools/build_options/ so
    # it is not mistaken for one of the 93 working upstream optfiles. It is used
    # as-is so a first build produces real errors to fix; impacts_check_env warns
    # while it is still the template. Once adapted, point IMPACTS_MPI_OPTFILE at
    # your copy. See tools/optfile_templates/README.md and PORTING.md.
    MPI_OPTFILE="${IMPACTS_MPI_OPTFILE:-$IMPACTS_ROOT/tools/optfile_templates/linux_amd64_gnu+mpi_perlmutter}"
    SERIAL_OPTFILE="${IMPACTS_SERIAL_OPTFILE:-$IMPACTS_ROOT/tools/optfile_templates/linux_amd64_gnu+mpi_perlmutter}"
    # -A and -C are mandatory on Perlmutter; a job without them is rejected.
    # NERSC_ACCOUNT must be set (e.g. in ~/.bashrc): export NERSC_ACCOUNT=mXXXX
    : "${NERSC_ACCOUNT:=}"
    : "${PERLMUTTER_QOS:=regular}"
    : "${PERLMUTTER_WALLTIME:=24:00:00}"
    : "${SBATCH_EXTRA:=${NERSC_ACCOUNT:+-A $NERSC_ACCOUNT} -C cpu -q $PERLMUTTER_QOS -t $PERLMUTTER_WALLTIME}"
    : "${MAIL_USER:=tanvirshahriar@utexas.edu}"
    impacts_load_modules() {
        module load PrgEnv-gnu 2>/dev/null || true
        module load cray-mpich  2>/dev/null || true
        module load cray-hdf5   2>/dev/null || true
        module load cray-netcdf 2>/dev/null || true
        # Tapenade is a Java tool and is not a NERSC module: install it yourself
        # and put its bin/ on PATH (see PORTING.md).
        [ -n "${TAPENADE_HOME:-}" ] && export PATH="$PATH:$TAPENADE_HOME/bin"
    }
    ;;

*)
    echo "machine_env.sh: unknown machine '$MACHINE'." >&2
    echo "  Add a case block for it, or set IMPACTS_MACHINE to one that exists." >&2
    return 1 2>/dev/null || exit 1
    ;;
esac

export MACHINE SCRATCH_ROOT MPI_LAUNCHER MPI_OPTFILE SERIAL_OPTFILE SBATCH_EXTRA MAIL_USER MITGCM_ROOT

# --- warn about things that silently produce a broken build -----------------
impacts_check_env() {
    local bad=0
    if ! command -v tapenade >/dev/null 2>&1; then
        echo "WARNING: 'tapenade' is not on PATH; an adjoint build will fail." >&2
        echo "         Install Tapenade 3.16-v2 and export TAPENADE_HOME. See PORTING.md." >&2
        bad=1
    fi
    if [ ! -f "$MPI_OPTFILE" ]; then
        echo "WARNING: MPI_OPTFILE does not exist: $MPI_OPTFILE" >&2
        bad=1
    fi
    if [ "$MACHINE" = perlmutter ] && [ -z "${NERSC_ACCOUNT:-}" ]; then
        echo "WARNING: NERSC_ACCOUNT is unset; sbatch will reject the job." >&2
        bad=1
    fi
    case "$MPI_OPTFILE$SERIAL_OPTFILE" in
      *"/tools/optfile_templates/"*)
        echo "WARNING: building with an UNTESTED optfile template:" >&2
        echo "         $MPI_OPTFILE" >&2
        echo "         It has never been compile-tested. Expect to adjust FOPTIM" >&2
        echo "         and the netCDF paths. Once it works, copy it somewhere of" >&2
        echo "         your own and export IMPACTS_MPI_OPTFILE to silence this." >&2
        bad=1
        ;;
    esac
    return $bad
}
