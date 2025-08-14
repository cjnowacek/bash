#!/bin/bash

# Use provided directory or default to current
TARGET_DIR="${1:-.}"
TARGET_PATH="$(realpath "$TARGET_DIR")"

# Confirm intent
echo "⚠️  This will rename all files and directories in:"
echo "$TARGET_PATH"
echo "It will replace underscores (_) with hyphens (-) in names."
read -p "Are you sure? Type 'yes' to continue: " confirm
[[ "$confirm" != "yes" ]] && echo "Aborted." && exit 1

# Loop over files and directories (excluding symlinks)
for entry in "$TARGET_DIR"/*; do
  [[ -e "$entry" ]] || continue  # skip nonexistent

  base=$(basename "$entry")

  # Only act if the name contains underscores
  if [[ "$base" == *_* ]]; then
    new_base="${base//_/-}"
    new_path="$TARGET_DIR/$new_base"

    # Avoid overwriting existing entries
    if [[ -e "$new_path" ]]; then
      echo "⚠️  Skipping $base → $new_base (already exists)"
    else
      echo "Renaming: $base → $new_base"
      mv "$entry" "$new_path"
    fi
  fi
done
