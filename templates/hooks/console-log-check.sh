#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
if [ -n "$file_path" ] && [ -f "$file_path" ]; then
  console_logs=$(grep -n "console\.log" "$file_path" 2>/dev/null || true)
  if [ -n "$console_logs" ]; then
    echo "[Hook] WARNING: console.log found in $file_path" >&2
    echo "$console_logs" | head -5 >&2
    echo "[Hook] Remove console.log before committing" >&2
  fi
fi
echo "$input"
