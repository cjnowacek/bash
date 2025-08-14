#!/bin/bash

# Go through each file in the current directory
for file in *; do
  # Skip directories
  [ -f "$file" ] || continue

  # Get the first character lowercased, and the rest of the filename
  first_char=$(echo "${file:0:1}" | tr '[:upper:]' '[:lower:]')
  rest="${file:1}"

  new_name="$first_char$rest"

  # Only rename if the name actually changes
  if [[ "$file" != "$new_name" ]]; then
    mv -- "$file" "$new_name"
    echo "Renamed: $file → $new_name"
  fi
done

