#!/usr/bin/env bash
# This hook is implemented as a prompt hook in settings.json, not a shell script.
# See settings.json.base SubagentStop section.
echo "This hook is a prompt hook, not a shell script." >&2
exit 0
