#!/bin/bash

# Directory to scan (default to ~/git/bash or use first argument)
SCRIPTS_DIR="${1:-$HOME/git/bash}"

# Sanity check
if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "❌ Error: Directory not found: $SCRIPTS_DIR"
  exit 1
fi

# Gather list of executable .sh files
scripts=()
while IFS= read -r -d '' file; do
  [[ "$(basename "$file")" == "run-menu.sh" ]] && continue
  scripts+=("$file")
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh" -executable -print0)

# Check if we found anything
if [ ${#scripts[@]} -eq 0 ]; then
  echo "No executable .sh scripts found in $SCRIPTS_DIR"
  exit 0
fi

# Display the menu
echo "Available scripts in $SCRIPTS_DIR:"
for i in "${!scripts[@]}"; do
  script_name=$(basename "${scripts[$i]}")
  printf " [%d] %s\n" $((i+1)) "$script_name"
done

# Prompt user
read -p "Choose a script to run [1-${#scripts[@]}]: " choice

# Validate choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#scripts[@]} )); then
  echo "❌ Invalid selection."
  exit 1
fi

# Run the chosen script
selected="${scripts[$((choice - 1))]}"
echo "▶️  Running: $selected"
"$selected"

