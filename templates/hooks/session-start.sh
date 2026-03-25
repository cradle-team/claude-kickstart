#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
if git rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo 'unknown')
  echo "[Session] Branch: $branch" >&2
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "[Session] WARNING: Uncommitted changes detected" >&2
    git status --short 2>/dev/null | head -5 >&2
  fi
fi
echo "$input"
