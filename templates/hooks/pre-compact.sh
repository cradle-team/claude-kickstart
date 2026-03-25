#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "[PreCompact] Current branch: $(git branch --show-current 2>/dev/null)" >&2
  echo "[PreCompact] Recent commits:" >&2
  git log --oneline -3 2>/dev/null >&2
fi
echo "$input"
