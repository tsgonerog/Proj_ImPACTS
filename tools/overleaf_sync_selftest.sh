#!/usr/bin/env bash
#
# Self-test for tools/overleaf_sync.sh.
#
#     ./tools/overleaf_sync_selftest.sh [direction]      # default: nn_surrogate
#
# Runs the whole round trip against a throwaway bare repository standing in for
# Overleaf, via the OVERLEAF_REMOTE override. It never contacts overleaf.com,
# never touches ~/.overleaf_mirrors, and never needs a credential.
#
# WHY THIS EXISTS. overleaf_sync.sh deletes tracked files as a normal part of
# `pull` -- that is the step that makes a deletion in Overleaf show up as ' D'
# instead of silently surviving on disk. A tool that does that deserves a test
# that proves it also puts everything back.
#
# WHAT IT WILL NOT DO. It never commits to this repository and never moves HEAD.
# It edits the working tree under notes/<direction> and restores it with
# `git checkout` + `git clean -fd`, so a failure mid-run costs you nothing that
# was committed. It refuses to start on a dirty tree, because it cannot tell
# your uncommitted work from its own and would restore over both. An earlier
# draft of this file used `git reset --hard` and destroyed uncommitted edits;
# that is why the guard is here and why nothing below is repository-wide.
#
# Exit status is 0 only if every check passes.
#
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO=$PWD
SYNC="$REPO/tools/overleaf_sync.sh"
DIR=${1:-nn_surrogate}

red=$'\033[31m'; grn=$'\033[32m'; dim=$'\033[2m'; off=$'\033[0m'
pass=0; fail=0
ok()   { printf "  ${grn}pass${off}  %s\n" "$1"; pass=$((pass+1)); }
bad()  { printf "  ${red}FAIL${off}  %s\n" "$1"; fail=$((fail+1)); }
chk()  { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 ${dim}(want '$3', got '$2')${off}"; fi; }

DIR=${DIR#./}; DIR=${DIR%/}; DIR=${DIR#notes/}; DIR=${DIR#directions/}; DIR=${DIR%/}
if [[ -d "notes/directions/$DIR" ]]; then NDIR="notes/directions/$DIR"
elif [[ -d "notes/$DIR" ]]; then NDIR="notes/$DIR"
else echo "no such direction: notes/directions/$DIR"; exit 1; fi

dirty=$(git status --porcelain --untracked-files=no -- "$NDIR")
if [[ -n "$dirty" ]]; then
    echo "REFUSING: $NDIR has uncommitted changes. This test edits and then"
    echo "restores that tree, which would take your work with it. Commit or stash:"
    printf '%s\n' "$dirty" | sed 's/^/    /'
    exit 1
fi

HEAD_AT_START=$(git rev-parse HEAD)
TMP=$(mktemp -d) || exit 1
FAKE="$TMP/overleaf.git"
SEED="$TMP/seed"
export OVERLEAF_MIRROR_ROOT="$TMP/mirrors"
export OVERLEAF_REMOTE="$FAKE"
export GIT_TERMINAL_PROMPT=0

restore() {
    git reset -q -- "$NDIR" 2>/dev/null          # in case a test staged something
    git checkout -q -- "$NDIR" 2>/dev/null
    git clean -qfd "$NDIR" 2>/dev/null
}
cleanup() { restore; rm -rf "$TMP"; }
trap cleanup EXIT

# A bare repo seeded from HEAD, standing in for the Overleaf project.
git init -q --bare "$FAKE"
git init -q "$SEED"
git -C "$SEED" config user.email selftest@localhost
git -C "$SEED" config user.name  selftest
git archive "HEAD:$NDIR" | tar -x -C "$SEED"
git -C "$SEED" add -A
git -C "$SEED" commit -q -m "seed: matches repo HEAD"
git -C "$SEED" branch -M master
git -C "$SEED" push -q "$FAKE" master
seed_push() { git -C "$SEED" add -A; git -C "$SEED" commit -q -m "$1"; git -C "$SEED" push -q "$FAKE" master; }

# Pick a section file and a whole document that exist in any direction here.
victim=$(git ls-files "$NDIR" | grep '/sections/.*\.tex$' | head -1)
victim=${victim#$NDIR/}
[[ -n "$victim" ]] || { echo "no sections/*.tex in $NDIR to test with"; exit 1; }

echo "── argument handling ────────────────────────────────────────────────"
for form in "$DIR" "$DIR/" "$NDIR/" "./$NDIR"; do
    out=$("$SYNC" status "$form" 2>&1)
    if grep -q 'no such direction' <<<"$out"; then bad "form '$form' rejected"; else ok "form '$form' resolves"; fi
done
out=$("$SYNC" status notes/definitely_not_a_direction 2>&1); rc=$?
chk "a bad name still fails" "$rc" "1"
grep -q 'no such direction' <<<"$out" && ok "and says why" || bad "message unclear"
out=$("$SYNC" push "$DIR" --nonsense 2>&1); rc=$?
chk "an unknown flag is rejected" "$rc" "1"

echo
echo "── pull ─────────────────────────────────────────────────────────────"
"$SYNC" status "$DIR" >/dev/null 2>&1
out=$("$SYNC" status "$DIR" 2>&1)
grep -q 'identical content' <<<"$out" && ok "seeded project reports identical" || bad "should report identical"

# status compares HEAD, so it must SAY when the working tree has more than HEAD;
# otherwise "identical content" reads as "nothing to do".
echo "x" >> "$NDIR/$victim"
out=$("$SYNC" status "$DIR" 2>&1)
grep -q 'uncommitted here' <<<"$out" && ok "status flags an uncommitted edit" || bad "status silent about uncommitted work"
restore
out=$("$SYNC" status "$DIR" 2>&1)
grep -q 'uncommitted here' <<<"$out" && bad "status cries wolf on a clean tree" || ok "status quiet when the tree is clean"

# Overleaf-side: edit one file, delete another.
git -C "$SEED" pull -q "$FAKE" master
printf '\n%%%% edited in overleaf\n' >> "$SEED/$victim"
doomed=$(cd "$SEED" && git ls-files | grep '/sections/.*\.tex$' | tail -1)
git -C "$SEED" rm -q "$SEED/$doomed"
seed_push "overleaf: edit one file, delete another"

"$SYNC" pull "$DIR" >/dev/null 2>&1
st=$(git status --porcelain -- "$NDIR")
grep -q "^ M $NDIR/$victim" <<<"$st" && ok "edit arrives as ' M'" || bad "edit not reported as modified"
grep -q "^ D $NDIR/$doomed" <<<"$st" && ok "deletion arrives as ' D'" || bad "deletion not reported — THE bug this tool exists to prevent"
[[ -e "$NDIR/$doomed" ]] && bad "deleted file still on disk" || ok "deleted file gone from disk"

# Untracked build products must survive a pull.
built=$(find "$NDIR" -maxdepth 2 -name main.pdf | head -1)
if [[ -n "$built" ]]; then ok "main.pdf survived the pull"; else
    printf "  ${dim}skip  no built PDF present to check${off}\n"; fi
[[ -z "$(git status --porcelain --untracked-files=all -- "$NDIR" | grep '^??')" ]] \
    && ok "pull added no untracked files" || bad "pull left untracked files behind"

restore
chk "abort restores the tree" "$(git status --porcelain -- "$NDIR")" ""

echo
echo "── push ─────────────────────────────────────────────────────────────"
# The pull above already marked Overleaf as seen, so make a change here that has
# deliberately NOT been pulled -- otherwise there is nothing for the guard to
# catch and a passing test would prove nothing.
git -C "$SEED" pull -q "$FAKE" master
printf '\n%%%% written in overleaf, never pulled\n' >> "$SEED/$victim"
seed_push "overleaf: a change the repo has not seen"

out=$("$SYNC" push "$DIR" 2>&1); rc=$?
chk "refuses while Overleaf has unpulled work" "$rc" "1"
grep -q 'have not been pulled' <<<"$out" && ok "and names the reason" || bad "message unclear"
n=$(grep -c '^        [0-9a-f]\{7\} ' <<<"$out")
chk "lists only the unpulled commit(s)" "$n" "1"

echo "x" >> "$NDIR/$victim"
out=$("$SYNC" push "$DIR" --force 2>&1); rc=$?
chk "refuses a dirty tree even with --force" "$rc" "1"
grep -q 'uncommitted changes' <<<"$out" && ok "and names the reason" || bad "message unclear"
restore

out=$("$SYNC" push "$DIR" --force 2>&1); rc=$?
chk "--force pushes over unpulled work" "$rc" "0"
out=$("$SYNC" status "$DIR" 2>&1)
grep -q 'identical content' <<<"$out" && ok "Overleaf now matches HEAD" || bad "content still differs after push"

# What landed must be exactly HEAD's tracked files — no build/, no PDFs.
mapfile -t sent < <(git -C "$TMP/mirrors/$DIR" ls-tree -r --name-only HEAD | sort)
mapfile -t want < <(git ls-files "$NDIR" | sed "s|^$NDIR/||" | sort)
chk "pushed exactly HEAD's tracked files" "${sent[*]}" "${want[*]}"

echo
echo "── after a pull, push is unblocked ──────────────────────────────────"
git -C "$SEED" pull -q "$FAKE" master
printf '\n%%%% another overleaf edit\n' >> "$SEED/$victim"
seed_push "overleaf: one more edit"
out=$("$SYNC" push "$DIR" 2>&1); rc=$?
chk "blocked before pulling" "$rc" "1"
"$SYNC" pull "$DIR" >/dev/null 2>&1
restore                       # discard it; we only need the sync marker moved
out=$("$SYNC" push "$DIR" 2>&1); rc=$?
chk "allowed after pulling, no --force" "$rc" "0"

echo
echo "── push --wip: the working tree, without a commit ────────────────────"
printf '\n%%%% wip edit, never committed\n' >> "$NDIR/$victim"
out=$("$SYNC" push "$DIR" --wip 2>&1); rc=$?
chk "--wip pushes a dirty tree" "$rc" "0"
grep -q 'nothing was committed here' <<<"$out" && ok "and says nothing was committed" || bad "silent about not committing"
chk "HEAD still has not moved" "$(git rev-parse HEAD)" "$HEAD_AT_START"
chk "the edit is still uncommitted here" "$(git status --porcelain -- "$NDIR/$victim")" " M $NDIR/$victim"

# The whole point: Overleaf must hold the working tree's text, not HEAD's.
git -C "$TMP/mirrors/$DIR" show "HEAD:$victim" 2>/dev/null | grep -q 'wip edit, never committed' \
    && ok "Overleaf got the uncommitted text" || bad "Overleaf got HEAD's text instead"
git -C "$TMP/mirrors/$DIR" log -1 --format=%s | grep -q '^WIP from' \
    && ok "the Overleaf log records it as WIP" || bad "log claims a commit the content is not in"

# --wip must not widen what leaves the repository.
mapfile -t sent < <(git -C "$TMP/mirrors/$DIR" ls-tree -r --name-only HEAD | sort)
mapfile -t want < <(git ls-files "$NDIR" | sed "s|^$NDIR/||" | sort)
chk "--wip sent exactly the tracked files" "${sent[*]}" "${want[*]}"

out=$("$SYNC" status "$DIR" 2>&1)
grep -q 'working tree, though, matches Overleaf' <<<"$out" \
    && ok "status answers for the tree, not just HEAD" || bad "status only compares HEAD"

# The guard protecting someone else's work is not relaxed by --wip.
git -C "$SEED" pull -q "$FAKE" master
printf '\n%%%% overleaf edit, unpulled, against --wip\n' >> "$SEED/$victim"
seed_push "overleaf: unpulled, against --wip"
out=$("$SYNC" push "$DIR" --wip 2>&1); rc=$?
chk "--wip still refuses over unpulled work" "$rc" "1"

echo
echo "── pull protects an uncommitted tree ────────────────────────────────"
git update-ref -d "refs/overleaf-prepull/$DIR" 2>/dev/null
# The edit has to be one Overleaf has never seen. The --wip text above is no use
# here: it went up, so the pull brings it straight back and the snapshot is
# never exercised -- which is exactly what an earlier version of this test did.
printf '\n%%%% local only, never pushed anywhere\n' >> "$NDIR/$victim"
"$SYNC" pull "$DIR" >/dev/null 2>&1
grep -q 'local only, never pushed anywhere' "$NDIR/$victim" \
    && bad "pull did not overwrite — the snapshot is untested" || ok "pull overwrote the dirty tree"
if git rev-parse --verify -q "refs/overleaf-prepull/$DIR" >/dev/null; then
    ok "and snapshotted it first"
    git checkout -q "refs/overleaf-prepull/$DIR" -- "$NDIR"
    grep -q 'local only, never pushed anywhere' "$NDIR/$victim" \
        && ok "the snapshot restores the uncommitted work" || bad "snapshot does not restore it"
    git update-ref -d "refs/overleaf-prepull/$DIR"
else
    bad "uncommitted work overwritten with nothing to recover from"
fi

echo
restore
chk "tree restored at end" "$(git status --porcelain -- "$NDIR")" ""
chk "HEAD never moved" "$(git rev-parse HEAD)" "$HEAD_AT_START"

echo
if [[ "$fail" -eq 0 ]]; then
    printf "${grn}%d passed, 0 failed.${off}\n" "$pass"; exit 0
else
    printf "${red}%d passed, %d FAILED.${off}\n" "$pass" "$fail"; exit 1
fi
