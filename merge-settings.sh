#!/usr/bin/env bash
set -euo pipefail

# merge-settings.sh — settings.jsonの安全なマージ
# Usage: merge-settings.sh <existing.json> <new.json>

if [ $# -ne 2 ]; then
  echo "Usage: merge-settings.sh <existing.json> <new.json>" >&2
  exit 1
fi

EXISTING="$1"
NEW="$2"

jq -s '
  .[0] as $existing | .[1] as $new |
  $existing |

  # permissions.allow — merge and dedupe
  .permissions.allow = (
    ($existing.permissions.allow // []) +
    ($new.permissions.allow // []) |
    unique
  ) |

  # permissions.deny — merge and dedupe
  .permissions.deny = (
    ($existing.permissions.deny // []) +
    ($new.permissions.deny // []) |
    unique
  ) |

  # hooks — merge each event array, dedupe by description
  .hooks = (
    ($existing.hooks // {}) as $eh |
    ($new.hooks // {}) as $nh |
    (($eh | keys) + ($nh | keys) | unique) |
    map(. as $key |
      {($key): (
        (($eh[$key] // []) + ($nh[$key] // [])) |
        group_by(.description // .matcher // "") |
        map(.[0])
      )}
    ) | add // {}
  )
' "$EXISTING" "$NEW"
