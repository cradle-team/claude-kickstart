#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
if [ -n "$file_path" ] && [ -f "$file_path" ]; then
  dir=$(dirname "$file_path")
  tsconfig=""
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/tsconfig.json" ]; then
      tsconfig="$dir/tsconfig.json"
      break
    fi
    dir=$(dirname "$dir")
  done
  if [ -n "$tsconfig" ]; then
    project_dir=$(dirname "$tsconfig")
    errors=$(cd "$project_dir" && npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
    if [ "$errors" -gt 0 ]; then
      echo "[Hook] WARNING: TypeScript errors detected ($errors errors)" >&2
      (cd "$project_dir" && npx tsc --noEmit 2>&1 | grep "error TS" | head -5) >&2
    fi
  fi
fi
echo "$input"
