#!/bin/bash

# Use the first argument as the target directory, or default to current directory
TARGET_DIR="${1:-.}"

# Resolve absolute path
TARGET_PATH="$(realpath "$TARGET_DIR")"

# Show the target directory
echo "⚠️  WARNING: This will rename files in:"
echo "$TARGET_PATH"
echo

# Sanity check: does the folder exist?
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: '$TARGET_DIR' is not a directory."
  exit 1
fi

# Ask for confirmation
read -p "Are you sure you want to rename files in this directory? Type 'yes' to proceed: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

# Process each file in the directory (non-recursive)
for file in "$TARGET_DIR"/*; do
  # Skip if it's not a regular file
  [ -f "$file" ] || continue

  # Extract base filename (no path)
  base=$(basename "$file")

  # Get modification date
  mod_date=$(date -r "$file" +"%Y%m%d")

  # Skip if already prefixed
  [[ "$base" =~ ^$mod_date\_ ]] && continue

  # New filename with date prefix
  new_name="${mod_date}_$base"
  new_path="$TARGET_DIR/$new_name"

  # Rename
  echo "Renaming: $base -> $new_name"
  mv "$file" "$new_path"
done
