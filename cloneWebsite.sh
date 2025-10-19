#!/usr/bin/env bash
set -euo pipefail

# SOURCE (Linux) and TARGET (Windows via WSL)
SRC="/var/www/html/"
TARGET="/mnt/c/Users/cjnow/website-clone"

# Make sure target exists (and imgs/ is there to preserve)
mkdir -p "$TARGET/imgs"

# Sync everything from SRC -> TARGET
# --delete removes files in TARGET that aren't in SRC,
# but the --exclude 'imgs/' protects that folder (and its contents)
# from both deletion and being overwritten.
rsync -av --delete --exclude 'static/' "$SRC" "$TARGET/"
