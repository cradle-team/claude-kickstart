#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
basename=$(basename "$file_path")
if [[ "$basename" =~ ^(\.eslintrc|\.eslintrc\.js|\.eslintrc\.json|\.eslintrc\.yml|eslint\.config\.js|eslint\.config\.mjs|eslint\.config\.ts|\.prettierrc|\.prettierrc\.js|\.prettierrc\.json|prettier\.config\.js|prettier\.config\.mjs|biome\.json|biome\.jsonc|\.stylelintrc)$ ]]; then
  echo "[Hook] BLOCKED: Modification of linter/formatter config" >&2
  echo "[Hook] File: $file_path" >&2
  echo "[Hook] Fix the code to comply with existing rules, don't weaken the config" >&2
  exit 1
fi
echo "$input"
