#!/usr/bin/env bash
#
# fix-copies.sh
#
# Finds files like:
#   "<name> copy.json"
#   "<name>.json copy.backup"
# deletes the corresponding old files:
#   "<name>.json"
#   "<name>.json.backup"
# and renames the "copy" files to take their place.
#
# Usage:
#   ./fix-copies.sh [directory] [--dry-run]
#
# Examples:
#   ./fix-copies.sh                # process current directory
#   ./fix-copies.sh ~/my/folder    # process a specific directory
#   ./fix-copies.sh . --dry-run    # preview what would happen, no changes made

set -euo pipefail

DIR="."
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) DIR="$arg" ;;
  esac
done

if [[ ! -d "$DIR" ]]; then
  echo "Error: '$DIR' is not a directory" >&2
  exit 1
fi

count=0

# Find files whose name contains " copy." somewhere (i.e. a "copy" marker
# right before the final extension). -print0 / read -d '' handles spaces safely.
while IFS= read -r -d '' f; do
  filename="$(basename -- "$f")"
  dirpath="$(dirname -- "$f")"

  ext="${filename##*.}"
  base="${filename%.*}"

  # Only proceed if the base (everything before the last extension) ends in " copy"
  if [[ "$base" == *" copy" ]]; then
    orig_base="${base% copy}"
    orig_name="${orig_base}.${ext}"
    orig_path="${dirpath}/${orig_name}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
      if [[ -f "$orig_path" ]]; then
        echo "[dry-run] would delete: $orig_path"
      fi
      echo "[dry-run] would rename: $f -> $orig_path"
    else
      if [[ -f "$orig_path" ]]; then
        rm -f -- "$orig_path"
      fi
      mv -- "$f" "$orig_path"
      echo "Replaced: $orig_path"
    fi
    ((count++)) || true
  fi
done < <(find "$DIR" -type f -name "* copy.*" -print0)

echo ""
echo "Done. $count file(s) $([[ $DRY_RUN -eq 1 ]] && echo "would be" || echo "were") processed."