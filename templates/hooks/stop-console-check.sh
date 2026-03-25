#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
if git rev-parse --git-dir > /dev/null 2>&1; then
  modified_files=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx|js|jsx)$' || true)
  if [ -n "$modified_files" ]; then
    has_console=false
    while IFS= read -r file; do
      if [ -f "$file" ] && grep -q "console\.log" "$file" 2>/dev/null; then
        echo "[Hook] WARNING: console.log found in $file" >&2
        has_console=true
      fi
    done <<< "$modified_files"
    if [ "$has_console" = true ]; then
      echo "[Hook] Remove console.log statements before committing" >&2
    fi
  fi
fi
echo "$input"
