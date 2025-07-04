#!/bin/bash

# Use the first argument as the target directory, or default to current directory
TARGET_DIR="${1:-.}"

# Show the target directory
echo "Targeting directory: $(realpath "$TARGET_DIR")"
echo

# Sanity check: does the folder exist?
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: '$TARGET_DIR' is not a directory."
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

