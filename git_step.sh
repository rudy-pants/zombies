#!/usr/bin/env bash
# git_step.sh -- Step forward/backward through git commits with a 5-commit window
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
MARKER_FILE="$(git rev-parse --git-dir)/git_step_original_head"

# -- Helpers -------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <command> [args]

Commands:
  list                  Show a 5-commit window centered on HEAD
  forward               Step forward  (newer / more recent commit)
  back                  Step backward (older / earlier commit)
  jump <n>              Jump to commit #n  (1 = newest)
  reset                 Return to the original branch/HEAD

Examples:
  $SCRIPT_NAME list
  $SCRIPT_NAME forward
  $SCRIPT_NAME back
  $SCRIPT_NAME jump 3
  $SCRIPT_NAME reset
EOF
  exit 0
}

die() {
  echo "Error: $*" >&2
  exit 1
}

# Save current HEAD so "reset" can restore it.
save_head() {
  git rev-parse HEAD > "$MARKER_FILE"
}

# Build a list of all unique commit hashes (newest first, index 0 = newest).
# Uses awk to deduplicate while preserving chronological order.
all_commits() {
  git rev-list --all | awk '!seen[$0]++'
}

# Check that the working tree is clean (no modified, staged, or untracked files).
# Dies with a helpful message if anything dirty is found.
check_clean_worktree() {
  local has_dirty=false
  local details=""

  # Check for modified or staged files
  if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet HEAD 2>/dev/null; then
    has_dirty=true
    details+=$(git status --short 2>/dev/null)
  fi

  # Check for untracked files
  local untracked
  untracked=$(git ls-files --others --exclude-standard 2>/dev/null)
  if [[ -n "$untracked" ]]; then
    has_dirty=true
    details+="$untracked"
  fi

  if $has_dirty; then
    echo "Error: Working tree is not clean. Cannot move between commits." >&2
    echo "" >&2
    echo "You have uncommitted or untracked files. Please commit or remove them first:" >&2
    echo "" >&2
    git status --short 2>/dev/null | while IFS= read -r line; do
      echo "  $line" >&2
    done
    echo "" >&2
    echo "Tip: Use 'git add -A && git commit' or 'git stash' before stepping." >&2
    exit 1
  fi
}

# Checkout a commit reference.
# Args: <commit_ref>
safe_checkout() {
  local ref="$1"
  git checkout "$ref" >/dev/null 2>&1 || die "Failed to checkout $ref."
}

# Print the 5-commit window, highlighting the current commit.
# Args: <current_commit_hash>
show_window() {
  local current_hash="$1"

  local -a commits
  mapfile -t commits < <(all_commits)
  local total=${#commits[@]}

  (( total == 0 )) && { echo "No commits found."; return; }

  # Find index of current commit (0 = newest)
  local idx=-1
  for i in "${!commits[@]}"; do
    if [[ "${commits[$i]}" == "$current_hash" ]]; then
      idx=$i
      break
    fi
  done
  (( idx == -1 )) && die "Current commit $current_hash not found in history."

  # Center a 5-commit window around idx, clamping at edges.
  local half=$(( 5 / 2 ))          # 2
  local start=$(( idx - half ))
  local end=$(( idx + half ))

  # Clamp to bounds
  if (( start < 0 )); then
    start=0
    end=$(( 5 - 1 ))
  fi
  if (( end >= total )); then
    end=$(( total - 1 ))
    start=$(( end - 5 + 1 ))
    (( start < 0 )) && start=0
  fi

  echo "============================================================"
  printf " 5-Commit Window (newest -> oldest)   [commit %d of %d]\n" "$((idx + 1))" "$total"
  echo "============================================================"

  for (( i = start; i <= end; i++ )); do
    local hash="${commits[$i]}"
    local msg short_hash date

    msg=$(git log -1 --format='%s' "$hash")
    short_hash=$(git log -1 --format='%h' "$hash")
    date=$(git log -1 --format='%cr' "$hash")

    local prefix="  "
    [[ "$hash" == "$current_hash" ]] && prefix=">> "

    printf "%s #%d  %s  %s  (%s)\n" "$prefix" "$((i + 1))" "$short_hash" "$msg" "$date"
  done

  echo "============================================================"
}

# Resolve a commit to its global index (0-based, 0 = newest).
# Args: <commit_hash>
commit_index() {
  local target="$1"
  local -a commits
  mapfile -t commits < <(all_commits)
  for i in "${!commits[@]}"; do
    if [[ "${commits[$i]}" == "$target" ]]; then
      echo "$i"
      return
    fi
  done
  die "Commit $target not found in history."
}

# -- Main ----------------------------------------------------------------------
[[ $# -lt 1 ]] && usage

cmd="$1"
shift

case "$cmd" in
  list)
    [[ -f "$MARKER_FILE" ]] || save_head
    show_window "$(git rev-parse HEAD)"
    ;;

  forward)
    current=$(git rev-parse HEAD)
    idx=$(commit_index "$current")

    if (( idx == 0 )); then
      echo "Already at the newest commit."
      show_window "$current"
      exit 0
    fi

    mapfile -t _commits < <(all_commits)
    target="${_commits[$((idx - 1))]}"
    check_clean_worktree
    safe_checkout "$target"
    echo "Stepped forward to $(git log -1 --format='%h %s' "$target")"
    show_window "$target"
    ;;

  back)
    current=$(git rev-parse HEAD)
    idx=$(commit_index "$current")

    mapfile -t _commits < <(all_commits)

    if (( idx == ${#_commits[@]} - 1 )); then
      echo "Already at the oldest commit."
      show_window "$current"
      exit 0
    fi

    target="${_commits[$((idx + 1))]}"
    check_clean_worktree
    safe_checkout "$target"
    echo "Stepped back to $(git log -1 --format='%h %s' "$target")"
    show_window "$target"
    ;;

  jump)
    [[ $# -lt 1 ]] && die "jump requires a commit number (1 = newest)."
    n="$1"
    [[ "$n" =~ ^[0-9]+$ ]] || die "Commit number must be a positive integer."

    mapfile -t _commits < <(all_commits)
    (( n < 1 || n > ${#_commits[@]} )) && die "Invalid commit number. Range: 1-${#_commits[@]}."

    target="${_commits[$((n - 1))]}"
    check_clean_worktree
    safe_checkout "$target"
    echo "Jumped to commit #$n: $(git log -1 --format='%h %s' "$target")"
    show_window "$target"
    ;;

  reset)
    check_clean_worktree
    if [[ -f "$MARKER_FILE" ]]; then
      original=$(cat "$MARKER_FILE")
      safe_checkout "$original"
      echo "Returned to original HEAD."
      rm -f "$MARKER_FILE"
    else
      safe_checkout @{-1} 2>/dev/null && echo "Returned to previous ref." || {
        safe_checkout main  && echo "Returned to main." ||
        safe_checkout master && echo "Returned to master." ||
        die "Could not determine original branch."
      }
    fi
    show_window "$(git rev-parse HEAD)"
    ;;

  *)
    die "Unknown command: $cmd"
    ;;
esac
