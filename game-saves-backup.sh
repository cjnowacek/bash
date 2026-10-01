#!/usr/bin/env bash
# Back up RetroArch saves, savestates and BIOS files to Dropbox.
#
#   ~/Games/{saves,states,bios}  ->  $RCLONE_DEST/{saves,states,bios}
#
# Goes direct to the remote, not through the ~/Dropbox FUSE mount. Anything
# the sync would overwrite or delete on the remote is moved to
# $RCLONE_DEST/.versions/<timestamp>/ first, so a corrupted or wiped save
# can't destroy the good copy; versions older than $KEEP_DAYS are pruned.
#
# Restore: rclone copy $RCLONE_DEST/saves ~/Games/saves
#          (or pick an older file out of .versions/)
#
# Env overrides: GAMES_DIR RCLONE_DEST KEEP_DAYS

set -euo pipefail

GAMES_DIR=${GAMES_DIR:-$HOME/Games}
RCLONE_DEST=${RCLONE_DEST:-dropbox:5-personal/Games/GameSaves/RetroArch}
KEEP_DAYS=${KEEP_DAYS:-90}
STAMP=$(date +%Y-%m-%d_%H%M%S)

for d in saves states bios; do
  # A missing dir means something is wrong locally; never mirror that.
  [[ -d "$GAMES_DIR/$d" ]] || { echo "missing $GAMES_DIR/$d, aborting" >&2; exit 1; }
  rclone sync "$GAMES_DIR/$d" "$RCLONE_DEST/$d" \
    --backup-dir "$RCLONE_DEST/.versions/$STAMP/$d"
done

rclone delete "$RCLONE_DEST/.versions" --min-age "${KEEP_DAYS}d" 2>/dev/null || true
rclone rmdirs "$RCLONE_DEST/.versions" --leave-root 2>/dev/null || true
