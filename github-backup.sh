#!/usr/bin/env bash
# Back up every GitHub repo on the account, locally and to Dropbox.
#
#   mirrors/<repo>.git               bare --mirror clones, updated incrementally
#   bundles/<repo>/<YYYY-MM-DD>.bundle
#                                     self-contained snapshot, written only
#                                     when the repo's refs changed since the
#                                     last bundle; newest $KEEP_BUNDLES kept.
#                                     Restore: git clone <file>.bundle <dir>
#
# The bundles dir is rclone-synced to $RCLONE_DEST (direct to the remote, not
# through the ~/Dropbox FUSE mount). Because unchanged repos get no new file,
# a daily run only uploads what actually moved.
#
# Needs: gh (authenticated: gh auth login), git, rclone with a dropbox: remote,
# SSH access to GitHub (clones use the ssh URL).
#
# Usage: github-backup.sh [--no-sync]
# Env overrides: GH_USER BACKUP_DIR RCLONE_DEST KEEP_BUNDLES
#                REPOS="owner/a owner/b"  (skip gh, back up only these)

set -euo pipefail

GH_USER=${GH_USER:-cjnowacek}
BACKUP_DIR=${BACKUP_DIR:-$HOME/backups/github}
RCLONE_DEST=${RCLONE_DEST:-dropbox:99-system/github-backups}
KEEP_BUNDLES=${KEEP_BUNDLES:-5}
SYNC=true
[[ "${1:-}" == "--no-sync" ]] && SYNC=false

log() { echo ":: $1"; }
err() { echo "ERROR: $1" >&2; }

mirrors="$BACKUP_DIR/mirrors"
bundles="$BACKUP_DIR/bundles"
today=$(date +%F)
mkdir -p "$mirrors" "$bundles"

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
failed=() bundled=0 unchanged=0
for full in "${repos[@]}"; do
  name=${full#*/}
  mirror="$mirrors/$name.git"
  out="$bundles/$name"

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
  if ! git -C "$mirror" rev-parse --verify -q HEAD >/dev/null; then
    log "$full (empty, no bundle)"
    continue
  fi

  # Fingerprint of every ref; a bundle is only worth writing when it moved.
  refs=$(git -C "$mirror" for-each-ref | sha256sum | cut -d' ' -f1)
  stamp="$mirror/.last-bundle-refs"
  if [[ -f "$stamp" && "$(<"$stamp")" == "$refs" ]] && compgen -G "$out/*.bundle" >/dev/null; then
    ((unchanged++)) || true
    continue
  fi

  mkdir -p "$out"
  git -C "$mirror" bundle create --quiet "$out/$today.bundle" --all
  echo "$refs" >"$stamp"
  ((bundled++)) || true
  log "$full -> $today.bundle"

  # Keep the newest $KEEP_BUNDLES (names sort by date).
  ls -1 "$out"/*.bundle | sort | head -n -"$KEEP_BUNDLES" | while read -r old; do
    rm -f "$old"; log "  pruned $(basename "$old")"
  done
done

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
log "done: $bundled bundled, $unchanged unchanged, ${#failed[@]} failed of ${#repos[@]}; $(du -sh "$bundles" | cut -f1) in $bundles"
if ((${#failed[@]})); then
  err "failed: ${failed[*]}"
  exit 1
fi
