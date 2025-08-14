#!/bin/bash

# Loop over files that match the pattern
for file in img_*.png; do
  # Extract the numeric part using parameter expansion
  num=${file#img_}
  num=${num%.png}

  # Remove leading zeros, add 10, then pad to 4 digits
  new_num=$(printf "%04d" $((10#$num + 10)))

  # Form the new file name
  new_name="img_${new_num}.png"

  # Rename the file
  mv -- "$file" "$new_name"
  echo "Renamed: $file → $new_name"
done

