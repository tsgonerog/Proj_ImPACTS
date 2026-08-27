#!/usr/bin/env bash
#
# Sync a notes/<direction>/ folder with its Overleaf project, both ways.
#
#     ./tools/overleaf_sync.sh status <direction>
#     ./tools/overleaf_sync.sh push   <direction>     # repo HEAD -> Overleaf
#     ./tools/overleaf_sync.sh push   <direction> --wip     # working tree -> Overleaf
#     ./tools/overleaf_sync.sh push   <direction> --force   # overwrite Overleaf edits
#     ./tools/overleaf_sync.sh pull   <direction>     # Overleaf -> working tree
#
# <direction> is the folder name under notes/. The forms tab-completion produces
# are all accepted and equivalent:
#
#     nn_surrogate   nn_surrogate/   notes/nn_surrogate/   ./notes/nn_surrogate
#
# tools/overleaf_sync_selftest.sh exercises all of this against a throwaway repo
# standing in for Overleaf -- no credential, no network.
#
# This automates the round trip written out in notes/README.md and keeps its
# three safety properties, which are the whole reason that procedure is spelled
# out by hand there:
#
#   1. Only TRACKED files go up. build/ and the PDFs never leave. By default
#      what goes up is HEAD, so an uncommitted edit never reaches a reader;
#      --wip sends the working tree instead -- see below.
#   2. Coming back, the tracked files are DELETED before the Overleaf copy is
#      laid down. Overwriting in place adds and updates but never removes, so a
#      section deleted in Overleaf would otherwise survive on disk, keep being
#      \input, and appear in no diff at all.
#   3. pull never commits and never rebuilds for you. You review the diff and
#      you rebuild, because Overleaf ships full TeX Live and the local TinyTeX
#      does not -- a package a collaborator adds compiles there and fails here,
#      and a rebuild is the only thing that finds it.
#
# --wip, AND WHEN NOT TO USE IT. Overleaf's git bridge needs a commit, but that
# commit lives in the MIRROR CLONE, which is a separate repository. Nothing
# about the bridge requires a commit here. The default still sends HEAD,
# because when a push IS the delivery -- a reader is about to open the project
# -- what they get should be something this repository can reproduce, and
# `Sync from <sha>` in the Overleaf log is what makes that true.
#
# --wip drops that and sends the tracked files as they stand on disk, for the
# other case: Overleaf is your editor, you are pushing and pulling every few
# minutes, and the commit is something you want to make once the writing is
# settled rather than thirty times on the way there. It commits in the mirror
# alone, HEAD never moves, and the Overleaf log records the sync as WIP so a
# later reader of that history is not told a commit exists that does not.
#
# The cost is that `pull` stops being harmless. Under commit-first, everything
# pull deletes is in a commit and `git checkout` brings it back; once real work
# lives uncommitted in the tree, it is not. So pull snapshots a dirty tree to
# refs/overleaf-prepull/<direction> before touching it, and says so. Commit
# when the writing is settled and that stops mattering.
#
# WHY A MIRROR CLONE AND NOT A REMOTE. Overleaf's project root is
# notes/<direction>/, not this repository's root, so the two trees do not line
# up and `git remote add` cannot work. git-subtree would bridge that, but it is
# not installed with this git and its synthetic history fights the git bridge's
# own. So each direction gets a plain clone of its Overleaf project, kept
# outside this repository, and files are mirrored in and out of it. The clone
# holds Overleaf's history; this repository holds its own; neither is asked to
# understand the other.
#
# AUTHENTICATION. Overleaf's git bridge needs a git token, not your account
# password. Account Settings -> Git Integration -> generate one, then on the
# first prompt:
#
#     Username: git          <- the literal word, NOT your Overleaf email
#     Password: <the token>
#
# THE USERNAME IS THE TRAP. Overleaf appears to key on it, so any other value
# is refused with "Overleaf now only supports Git authentication tokens" and a
# 403 -- the same error you get for using a password, and it fires even when
# the password field holds a perfectly valid token. Verified 2026-08-26: the
# identical token succeeds as `git` and 403s as the account email. If you are
# staring at that message with a token in hand, the username is why.
#
# To be prompted once a day rather than once per command, `credential.helper
# cache --timeout=86400` is already set globally. For something permanent use
# `store`, which writes ~/.git-credentials in the clear -- chmod 600 it. Never
# put the token in this repository.
#
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO=$PWD

red=$'\033[31m'; yel=$'\033[33m'; grn=$'\033[32m'; dim=$'\033[2m'; off=$'\033[0m'
ok()   { printf "  ${grn}ok${off}    %s\n" "$1"; }
warn() { printf "  ${yel}note${off}  %s\n" "$1"; }
bad()  { printf "  ${red}FAIL${off}  %s\n" "$1"; }
die()  { bad "$1"; exit 1; }

MIRROR_ROOT=${OVERLEAF_MIRROR_ROOT:-$HOME/.overleaf_mirrors}

# Direction -> Overleaf project id. Add a line when a direction gets a project.
# OVERLEAF_REMOTE overrides, which is what the self-test uses to run the whole
# round trip against a local bare repo instead of the real project.
project_url() {
    if [[ -n "${OVERLEAF_REMOTE:-}" ]]; then echo "$OVERLEAF_REMOTE"; return; fi
    case "$1" in
        nn_surrogate)        echo "https://git.overleaf.com/6a8f28882435332e2f9da280" ;;
        dino_quarter_degree) echo "https://git.overleaf.com/6a8f360a0c4433896e31b5c3" ;;
        *)                   return 1 ;;
    esac
}

# Spelled out rather than sed'd out of the header by line number: that form
# silently dropped `pull` from the output the first time a line was added above.
usage() {
    cat <<'EOF'
Sync a notes/<direction>/ folder with its Overleaf project, both ways.

    overleaf_sync.sh status <direction>            what differs, in both directions
    overleaf_sync.sh pull   <direction>            Overleaf     -> working tree
    overleaf_sync.sh push   <direction>            repo HEAD    -> Overleaf
    overleaf_sync.sh push   <direction> --wip      working tree -> Overleaf, no commit
    overleaf_sync.sh push   <direction> --force    overwrite un-pulled Overleaf edits

<direction> is the folder name under notes/. These are all equivalent:

    nn_surrogate   nn_surrogate/   notes/nn_surrogate/   ./notes/nn_surrogate
EOF
    exit 1
}

# Flags come after the direction and in any order. An earlier form read only
# $3, so `push <dir> --wip --force` silently ignored the second one.
cmd=${1:-}; dir=${2:-}
[[ -n "$cmd" && -n "$dir" ]] || usage
shift 2
force=no; wip=no
for flag in "$@"; do
    case "$flag" in
        --force)          force=yes ;;
        --wip|--worktree) wip=yes   ;;
        *) die "unknown flag: $flag — expected --wip or --force" ;;
    esac
done

# Accept the direction as a bare name or as the path tab-completion produces:
# nn_surrogate, nn_surrogate/, notes/nn_surrogate/, ./notes/nn_surrogate all
# mean the same thing. Without this, tab-completing from the repository root
# gives "notes/notes/<direction>" and a confusing failure.
dir=${dir#./}; dir=${dir%/}; dir=${dir#notes/}; dir=${dir%/}

[[ -d "notes/$dir" ]] || die "no such direction: notes/$dir"

url=$(project_url "$dir") || die "no Overleaf project mapped for '$dir' — add it to project_url() in this script"
mirror="$MIRROR_ROOT/$dir"

# ---------------------------------------------------------------- mirror setup
# Clone on first use. A failure here is nearly always the premium/token issue
# above, so say so rather than letting a bare git error stand.
ensure_mirror() {
    if [[ -d "$mirror/.git" ]]; then
        git -C "$mirror" remote set-url origin "$url"
        return 0
    fi
    warn "no mirror yet — cloning $url"
    mkdir -p "$MIRROR_ROOT"
    if ! git clone "$url" "$mirror"; then
        rm -rf "$mirror"
        echo
        die "clone failed. Overleaf's git bridge is a paid feature and needs a
        token, not your password — see the header of this script. If you
        authenticated and it still refuses, the project's plan does not
        include git access."
    fi
}

# Overleaf's default branch has been master historically and main on newer
# projects; ask the remote rather than assuming.
mirror_branch() { git -C "$mirror" symbolic-ref --short HEAD; }

# Files tracked in the mirror, i.e. what Overleaf currently holds.
mirror_clear() { ( cd "$mirror" && git ls-files -z | xargs -0 -r rm -f ); }

# The tracked files as they stand on disk, laid into $1. This is what --wip
# sends, and what `status` compares against Overleaf when the tree is dirty.
# TRACKED, so build/ and the PDFs still never leave; ON DISK, so an uncommitted
# edit does. A tracked file deleted in the working tree is skipped rather than
# copied from HEAD, so the deletion reaches Overleaf like any other edit.
copy_worktree() {
    local dest=$1 f rel
    while IFS= read -r -d '' f; do
        [[ -f "$f" ]] || continue
        rel=${f#notes/$dir/}
        mkdir -p "$dest/$(dirname "$rel")"
        cp -p "$f" "$dest/$rel"
    done < <(git ls-files -z "notes/$dir")
}

# ------------------------------------------------------------------ operations

do_status() {
    ensure_mirror
    git -C "$mirror" fetch --quiet origin || die "fetch failed"
    local br; br=$(mirror_branch)
    local behind; behind=$(git -C "$mirror" rev-list --count "HEAD..origin/$br")
    if [[ "$behind" -gt 0 ]]; then
        warn "Overleaf is $behind commit(s) ahead of your mirror — 'pull' to bring them down"
        git -C "$mirror" log --oneline "HEAD..origin/$br" | sed 's/^/        /'
    else
        ok "mirror is level with Overleaf"
    fi

    # Compare repo HEAD against what Overleaf has, file by file.
    local tmp wtd; tmp=$(mktemp -d); wtd=$(mktemp -d)
    trap 'rm -rf "$tmp" "$wtd"' RETURN
    git archive "HEAD:notes/$dir" | tar -x -C "$tmp"
    local ohead="$tmp/.overleaf"; mkdir -p "$ohead"
    git -C "$mirror" archive "origin/$br" | tar -x -C "$ohead"

    local d; d=$(diff -rq "$tmp" "$ohead" 2>/dev/null | grep -v '^Only in .*: \.overleaf$')
    if [[ -z "$d" ]]; then
        ok "repo HEAD and Overleaf hold identical content"
    else
        warn "repo HEAD and Overleaf differ:"
        printf '%s\n' "$d" | sed "s|$tmp|<repo HEAD>|g; s|<repo HEAD>/.overleaf|<overleaf>|g; s/^/        /"
    fi

    # The comparison above is HEAD against Overleaf, because that is what a push
    # would send. An uncommitted edit is therefore invisible to it -- and without
    # this, "identical content" reads as "nothing to do" while your own change
    # sits unsent in the working tree.
    local wt; wt=$(git status --porcelain -- "notes/$dir")
    if [[ -n "$wt" ]]; then
        warn "uncommitted here, and NOT part of the comparison above:"
        printf '%s\n' "$wt" | sed 's/^/        /'

        # The comparison above answers "what would a plain push send?". After a
        # --wip push it is the wrong question and reads as alarming: HEAD is
        # meant to differ, and what matters is whether the TREE matches. So
        # answer that one too whenever there is a difference between them.
        copy_worktree "$wtd"
        local wd; wd=$(diff -rq "$wtd" "$ohead" 2>/dev/null)
        if [[ -z "$wd" ]]; then
            ok "your working tree, though, matches Overleaf — a --wip push is up to date"
        else
            warn "your working tree also differs from Overleaf:"
            printf '%s\n' "$wd" | sed "s|$wtd|<worktree>|g; s|$ohead|<overleaf>|g; s/^/        /"
        fi
        printf "        ${dim}%s${off}\n" "commit, then: ./tools/overleaf_sync.sh push $dir"
        printf "        ${dim}%s${off}\n" "or send the tree as it stands:  ./tools/overleaf_sync.sh push $dir --wip"
    fi
}

# The Overleaf commit this machine last saw, in either direction. Kept beside
# the mirror rather than inside it, so it is never committed up to Overleaf.
# Both push and pull write it; the guard below reads it.
SEEN="$MIRROR_ROOT/$dir.last_synced"
mark_seen() { git -C "$mirror" rev-parse "origin/$1" > "$SEEN"; }

# Anything in Overleaf after the last-seen commit was written there and has not
# been pulled -- pushing over it reverts someone's edit. Recoverable from the
# git bridge's history, but silent, so refuse instead. Prints the count, or the
# whole history the first time, when nothing has ever been synced from here.
# The revision range holding that work -- the whole branch when nothing has ever
# been synced from here, otherwise everything after the last-seen commit.
unpulled_range() {
    local br=$1 seen
    if [[ -s "$SEEN" ]]; then
        seen=$(<"$SEEN")
        # A rewritten or squashed history leaves the marker dangling; treat that
        # as unseen rather than crashing, so the guard fails closed.
        if git -C "$mirror" cat-file -e "$seen^{commit}" 2>/dev/null; then
            echo "$seen..origin/$br"; return
        fi
    fi
    echo "origin/$br"
}

unpulled_overleaf_work() {
    git -C "$mirror" rev-list --count "$(unpulled_range "$1")"
}

do_push() {
    # HEAD, not the working tree -- so refuse when they disagree, rather than
    # silently shipping something other than what the user is looking at.
    # --wip is the deliberate opt-out; see the header.
    if [[ "$wip" != yes ]] && ! git diff --quiet HEAD -- "notes/$dir"; then
        echo
        die "notes/$dir has uncommitted changes. push sends HEAD, so commit
        first or your reader gets the previous text:
            git status --short notes/$dir
        Or send the tree as it stands and commit once the writing is settled:
            ./tools/overleaf_sync.sh push $dir --wip"
    fi
    local untracked; untracked=$(git ls-files --others --exclude-standard "notes/$dir")
    [[ -n "$untracked" ]] && warn "untracked, will NOT be sent: $(echo "$untracked" | tr '\n' ' ')"

    ensure_mirror
    local br; br=$(mirror_branch)
    git -C "$mirror" fetch --quiet origin || die "fetch failed"

    local unpulled; unpulled=$(unpulled_overleaf_work "$br")
    if [[ "$unpulled" -gt 0 && "$force" != yes ]]; then
        warn "$unpulled commit(s) in Overleaf have not been pulled here:"
        git -C "$mirror" log --oneline -n 10 "$(unpulled_range "$br")" | sed 's/^/        /'
        echo
        die "pushing would revert that work. Pull it, reconcile, commit, then
        push:
            ./tools/overleaf_sync.sh pull $dir
        Or, if you are certain Overleaf holds nothing worth keeping:
            ./tools/overleaf_sync.sh push $dir --force"
    fi
    [[ "$unpulled" -gt 0 ]] && warn "--force: overwriting $unpulled un-pulled Overleaf commit(s)"

    git -C "$mirror" pull --quiet --ff-only origin "$br" || die "mirror is behind and cannot fast-forward — run 'pull' first and reconcile"

    mirror_clear
    local msg source
    if [[ "$wip" == yes ]]; then
        copy_worktree "$mirror"
        source="your working tree"
        # Say WIP in the Overleaf log rather than naming a commit this content
        # cannot be reproduced from. The sha is where the tree was standing.
        msg="WIP from $(git rev-parse --short HEAD)+ — uncommitted working tree"
    else
        git archive "HEAD:notes/$dir" | tar -x -C "$mirror"
        source="repo HEAD"
        msg="Sync from $(git rev-parse --short HEAD) — $(git log -1 --format=%s)"
    fi

    ( cd "$mirror" && git add -A )
    if git -C "$mirror" diff --cached --quiet; then
        mark_seen "$br"
        ok "Overleaf already matches $source — nothing to push"
        return 0
    fi
    git -C "$mirror" --no-pager diff --cached --stat | sed 's/^/        /'
    git -C "$mirror" commit --quiet -m "$msg"
    git -C "$mirror" push --quiet origin "$br" || die "push rejected — someone edited in Overleaf since your last sync; run 'pull' first"
    git -C "$mirror" fetch --quiet origin && mark_seen "$br"
    ok "pushed to Overleaf"
    [[ "$wip" == yes ]] && warn "sent from the working tree — nothing was committed here"
    printf "        ${dim}%s${off}\n" "$url"
}

do_pull() {
    ensure_mirror
    local br; br=$(mirror_branch)
    git -C "$mirror" pull --quiet --ff-only origin "$br" || die "mirror has diverged from Overleaf"
    mark_seen "$br"

    # Under commit-first, everything the clear below deletes is in a commit and
    # `git checkout` brings it back. --wip breaks that: real work now lives
    # uncommitted in the tree, and this would take it with nothing to recover
    # from. `stash create` writes a commit object and touches neither the index
    # nor the working tree; the ref is what keeps it out of reach of gc.
    local snap=""
    if ! git diff --quiet HEAD -- "notes/$dir"; then
        snap=$(git stash create "overleaf pull: notes/$dir as it stood before" 2>/dev/null)
        [[ -n "$snap" ]] && git update-ref "refs/overleaf-prepull/$dir" "$snap"
    fi

    # Property 2: clear first, so a file deleted in Overleaf reports as ' D'.
    git ls-files -z "notes/$dir" | xargs -0 -r rm -f
    git -C "$mirror" archive "$br" | tar -x -C "notes/$dir"
    find "notes/$dir" -type d -empty -delete

    echo
    local st; st=$(git status --short "notes/$dir")
    if [[ -z "$st" ]]; then
        ok "no changes — the working tree already matches Overleaf"
        return 0
    fi
    warn "changes brought back, staged nothing — review them:"
    printf '%s\n' "$st" | sed 's/^/        /'
    if [[ -n "$snap" ]]; then
        echo
        warn "your tree was dirty; it is saved as refs/overleaf-prepull/$dir"
        printf "        ${dim}%s${off}\n" "git diff refs/overleaf-prepull/$dir -- notes/$dir      # what this pull changed"
        printf "        ${dim}%s${off}\n" "git checkout refs/overleaf-prepull/$dir -- notes/$dir  # to put it back"
    fi
    echo
    printf "  ${dim}%s${off}\n" "git diff notes/$dir                      # read every change"
    printf "  ${dim}%s${off}\n" "cd notes/$dir/<doc> && latexmk -pdf -auxdir=build main.tex"
    printf "  ${dim}%s${off}\n" "                                          # REBUILD before committing"
    printf "  ${dim}%s${off}\n" "git checkout -- notes/$dir && git clean -fd notes/$dir   # to abort (never -x)"
}

case "$cmd" in
    status) do_status ;;
    push)   do_push   ;;
    pull)   do_pull   ;;
    *)      usage     ;;
esac
