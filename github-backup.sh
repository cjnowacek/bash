#!/usr/bin/env bash
# Back up every GitHub repo on the account, locally and to Dropbox.
#
#   mirrors/<repo>.git         bare --mirror clones, updated incrementally
#   bundles/<YYYY-MM-DD>/<repo>.bundle
#                               one self-contained file per repo per day;
#                               restore with: git clone <file>.bundle <dir>
#
# The bundles dir is rclone-synced to $RCLONE_DEST (direct to the remote, not
# through the ~/Dropbox FUSE mount). Days older than $KEEP_DAYS are pruned
# locally and the sync propagates the deletion.
#
# Needs: gh (authenticated: gh auth login), git, rclone with a dropbox: remote,
# SSH access to GitHub (clones use the ssh URL).
#
# Usage: github-backup.sh [--no-sync]
# Env overrides: GH_USER BACKUP_DIR RCLONE_DEST KEEP_DAYS
#                REPOS="owner/a owner/b"  (skip gh, back up only these)

set -euo pipefail

GH_USER=${GH_USER:-cjnowacek}
BACKUP_DIR=${BACKUP_DIR:-$HOME/backups/github}
RCLONE_DEST=${RCLONE_DEST:-dropbox:99-system/github-backups}
KEEP_DAYS=${KEEP_DAYS:-7}
SYNC=true
[[ "${1:-}" == "--no-sync" ]] && SYNC=false

log() { echo ":: $1"; }
err() { echo "ERROR: $1" >&2; }

mirrors="$BACKUP_DIR/mirrors"
bundles="$BACKUP_DIR/bundles"
today="$bundles/$(date +%F)"
mkdir -p "$mirrors" "$today"

# One run at a time (the timer and a manual run could overlap).
exec 9>"$BACKUP_DIR/.lock"
if ! flock -n 9; then
  err "another github-backup is running"
  exit 1
fi

# --- enumerate repos ---------------------------------------------------------
if [[ -n "${REPOS:-}" ]]; then
  read -ra repos <<<"$REPOS"
else
  command -v gh >/dev/null || { err "gh not installed (pacman -S github-cli)"; exit 1; }
  gh auth status >/dev/null 2>&1 || { err "gh not logged in (run: gh auth login)"; exit 1; }
  mapfile -t repos < <(gh repo list "$GH_USER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
fi
((${#repos[@]})) || { err "no repos found"; exit 1; }
log "${#repos[@]} repos"

# --- mirror + bundle ---------------------------------------------------------
failed=()
for full in "${repos[@]}"; do
  name=${full#*/}
  mirror="$mirrors/$name.git"

  if [[ -d "$mirror" ]]; then
    if ! git -C "$mirror" remote update --prune >/dev/null 2>&1; then
      err "$full: fetch failed"; failed+=("$full"); continue
    fi
  else
    if ! git clone --quiet --mirror "git@github.com:$full.git" "$mirror" 2>/dev/null; then
      err "$full: clone failed"; failed+=("$full"); continue
    fi
  fi

  # An empty repo has no refs and bundle refuses; that's fine to skip.
  if git -C "$mirror" rev-parse --verify -q HEAD >/dev/null; then
    git -C "$mirror" bundle create --quiet "$today/$name.bundle" --all
    log "$full"
  else
    log "$full (empty, no bundle)"
  fi
done

# --- prune old bundle days ---------------------------------------------------
find "$bundles" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -print -exec rm -rf {} + \
  | sed 's/^/:: pruned /' || true

# --- sync to dropbox ---------------------------------------------------------
if $SYNC; then
  if ! command -v rclone >/dev/null; then
    err "rclone not installed, bundles are local only"
  elif ! rclone listremotes 2>/dev/null | grep -qx "${RCLONE_DEST%%:*}:"; then
    err "rclone remote '${RCLONE_DEST%%:*}:' not configured, bundles are local only"
  else
    rclone sync "$bundles" "$RCLONE_DEST" --transfers 4 --stats-one-line --stats 0 -q
    log "synced bundles -> $RCLONE_DEST"
  fi
fi

# --- summary -----------------------------------------------------------------
log "done: $((${#repos[@]} - ${#failed[@]}))/${#repos[@]} ok, $(du -sh "$today" | cut -f1) today, bundles in $bundles"
if ((${#failed[@]})); then
  err "failed: ${failed[*]}"
  exit 1
fi
