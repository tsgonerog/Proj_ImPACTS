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

echo "machine : $MACHINE"
echo "extra   : ${SBATCH_EXTRA:-<none>}"
echo "submit  : sbatch ${SBATCH_EXTRA} $(basename "$script_abs") $*"
echo
# shellcheck disable=SC2086
exec sbatch ${SBATCH_EXTRA} "$(basename "$script_abs")" "$@"
