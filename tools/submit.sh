#!/usr/bin/env bash
#
# Submit a job with the sbatch flags this machine needs.
#
#     ./tools/submit.sh MITgcm_c69m/mysetups/DINO_1deg/submit_tapAdj.sh
#     ./tools/submit.sh <script> --test-only          # extra flags are passed through
#
# The submit scripts carry the #SBATCH directives that are the same everywhere
# (job name, node/rank counts, output files). Account, QOS, constraint and
# walltime differ per machine and cannot be written as directives without
# breaking the other machine, so they come from tools/machine_env.sh and are
# passed on the command line, where sbatch lets them override the script.
#
# On sverdrup SBATCH_EXTRA is empty, so this is exactly `sbatch <script>`.
#
set -euo pipefail

if [ $# -lt 1 ]; then
    sed -n '2,15p' "$0" | sed 's/^# \?//'
    exit 2
fi

script="$1"; shift
[ -f "$script" ] || { echo "submit.sh: no such script: $script" >&2; exit 1; }

script_abs="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "$repo_root/tools/machine_env.sh"
impacts_check_env || echo "submit.sh: continuing despite warnings above." >&2

# The submit scripts resolve input_tap/, input_binaries/ and the build directory
# through $SLURM_SUBMIT_DIR, which sbatch sets to the current directory. Submit
# from the setup directory so those stay correct however this was invoked.
cd "$(dirname "$script_abs")"

# The submit scripts write their SLURM log to logs/%x.%j.out. sbatch does not
# create that directory: if it is missing the job is accepted and then fails at
# launch, usually with no log to say why. Creating it here rather than in a
# README is what makes a fresh clone able to submit.
mkdir -p logs

echo "machine : $MACHINE"
echo "extra   : ${SBATCH_EXTRA:-<none>}"
echo "submit  : sbatch ${SBATCH_EXTRA} --export=ALL $* $(basename "$script_abs")"
echo
# Extra arguments go BEFORE the script name. sbatch's usage is
#     sbatch [OPTIONS...] script [args...]
# so anything after the script name is handed to the script as an argument
# rather than consumed as an sbatch option. That is why the --test-only example
# above used to submit a real job instead of dry-running it.
#
# --export=ALL is already sbatch's default; it is stated explicitly because the
# jobs genuinely depend on it. impacts_load_modules is a no-op on sverdrup, so
# the compiler/MPI stack and the IMPACTS_* per-run overrides both reach the
# compute node only through the inherited environment. A user-supplied
# --export= still wins, coming later on the command line.
# shellcheck disable=SC2086
exec sbatch ${SBATCH_EXTRA} --export=ALL "$@" "$(basename "$script_abs")"
