#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
if echo "$cmd" | grep -qE '\-\-no-verify' && echo "$cmd" | grep -qE '^git\s+(commit|push|merge)'; then
  echo "[Hook] BLOCKED: --no-verify is not allowed" >&2
  echo "[Hook] Fix the underlying issue instead" >&2
  exit 1
fi
echo "$input"
