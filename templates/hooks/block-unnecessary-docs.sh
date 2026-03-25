#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
if [[ "$file_path" =~ docs/tickets/ ]] || [[ "$file_path" =~ docs/(requirements|wbs|decisions)\.md$ ]]; then
  echo "$input"
  exit 0
fi
if [[ "$file_path" =~ \.(md|txt)$ ]] && [[ ! "$file_path" =~ (README|CLAUDE|AGENTS|CONTRIBUTING)\.md$ ]]; then
  echo "[Hook] BLOCKED: Unnecessary documentation file creation" >&2
  echo "[Hook] File: $file_path" >&2
  exit 1
fi
echo "$input"
