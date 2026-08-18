#!/usr/bin/env bash
#
# Configure the notebook `clean` filter for this clone.
#
# Outputs stay in your working copy (so you can show a notebook to someone) but
# are stripped out of anything git records. .gitattributes points *.ipynb at the
# "nbstrip" filter; this script defines what that filter actually runs. Git
# filters are per-clone because they live in .git/config, which is not tracked.
#
#   ./analyses/tools/install_git_filters.sh              # strip >1 MB animations only
#   ./analyses/tools/install_git_filters.sh --all-outputs # strip every output
#   ./analyses/tools/install_git_filters.sh --uninstall
#
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="analyses/tools/strip_animation_outputs.py"
python="${PYTHON:-python3}"

cd "$repo_root"

if [[ "${1:-}" == "--uninstall" ]]; then
    git config --unset filter.nbstrip.clean  2>/dev/null || true
    git config --unset filter.nbstrip.smudge 2>/dev/null || true
    git config --unset diff.ipynb.textconv   2>/dev/null || true
    echo "nbstrip filter removed. Notebooks will now be committed with outputs."
    exit 0
fi

# Default keeps static figures, so plots still render for anyone reading the
# repository on GitHub; only the multi-megabyte to_jshtml payloads come out.
mode_flag=""
mode_desc="animation payloads over 1 MB (static figures kept)"
if [[ "${1:-}" == "--all-outputs" ]]; then
    mode_flag="--all-outputs"
    mode_desc="every output and execution count"
fi

# clean  : working tree -> index. This is where stripping happens.
# smudge : index -> working tree. Identity; there is nothing to restore.
# textconv: makes `git diff` on a notebook readable rather than a JSON wall.
git config filter.nbstrip.clean  "$python $script --filter $mode_flag"
git config filter.nbstrip.smudge "cat"
git config diff.ipynb.textconv   "$python $script --filter $mode_flag"

echo "nbstrip installed for this clone."
echo "  strips: $mode_desc"
echo "  clean : $(git config filter.nbstrip.clean)"
echo
echo "Your working copies keep their outputs. Verify with:"
echo "    git show HEAD:<notebook> | grep -c '\"output_type\"'"
echo
echo "Caveat: the stored copy is the stripped one, so any git operation that"
echo "overwrites a notebook in your working tree (checkout, stash, merge,"
echo "reset --hard) replaces it with the stripped version and whatever was"
echo "stripped is gone locally. Re-run the cell, or keep an exported HTML:"
echo "    jupyter nbconvert --to html --output-dir ~/nb_for_advisor <notebook>"
