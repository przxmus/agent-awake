#!/bin/bash
# Remove agent-awake hooks, launchd sweeper and CLI symlink, and restore the sleep
# state from before awake disabled it. The sudoers entry is kept; the script prints
# how to remove it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
LABEL="local.agent-awake"

[ -f "$HOME/.claude/settings.json" ] &&
  osascript -l JavaScript "$ROOT/scripts/hooks.js" remove claude "$HOME/.claude/settings.json" ""
[ -f "$HOME/.codex/hooks.json" ] &&
  osascript -l JavaScript "$ROOT/scripts/hooks.js" remove codex "$HOME/.codex/hooks.json" ""

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"

"$ROOT/bin/awake" reset
rm -f "$HOME/.local/bin/awake"

cat <<EOF
Uninstalled. State and logs are kept in ~/.agent-awake (safe to delete).
To also remove the passwordless pmset rule:
  sudo rm /etc/sudoers.d/agent-awake
EOF

# Drop the checkout only if the curl installer created it; a clone you made is yours.
if [ "$ROOT" = "${AGENT_AWAKE_DIR:-$HOME/.local/share/agent-awake}" ]; then
  rm -rf "$ROOT"
fi
