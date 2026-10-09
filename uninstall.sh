#!/bin/bash
# Remove agent-awake hooks, launchd sweeper and CLI symlink, then re-enable sleep.
# The sudoers entry is left in place; remove /etc/sudoers.d/pmset-sleep by hand if unused.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
LABEL="local.agent-awake"

osascript -l JavaScript "$ROOT/scripts/hooks.js" remove claude "$HOME/.claude/settings.json" ""
[ -f "$HOME/.codex/hooks.json" ] && osascript -l JavaScript "$ROOT/scripts/hooks.js" remove codex "$HOME/.codex/hooks.json" ""

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"

"$ROOT/bin/awake" reset
rm -f "$HOME/.local/bin/awake"

echo "Uninstalled. Sleep is enabled again."
