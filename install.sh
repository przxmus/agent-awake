#!/bin/bash
# Install agent-awake: CLI symlink, passwordless pmset, launchd sweeper, agent hooks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT/bin/awake"
LABEL="local.agent-awake"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SUDOERS="/etc/sudoers.d/pmset-sleep"

chmod +x "$BIN"

echo "==> CLI: ~/.local/bin/awake"
mkdir -p "$HOME/.local/bin"
ln -sf "$BIN" "$HOME/.local/bin/awake"

echo "==> sudoers: passwordless pmset disablesleep"
state=$(pmset -g | awk '/SleepDisabled/ { print $2 }')
if sudo -n /usr/bin/pmset disablesleep "$state" 2>/dev/null; then
  echo "    already allowed"
else
  rule="$(whoami) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1"
  tmp=$(mktemp)
  echo "$rule" >"$tmp"
  sudo visudo -cf "$tmp" >/dev/null
  sudo install -m 0440 -o root -g wheel "$tmp" "$SUDOERS"
  rm -f "$tmp"
  echo "    wrote $SUDOERS"
fi

echo "==> launchd: sweep stale locks every minute"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.agent-awake"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string><string>sweep</string></array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardErrorPath</key><string>$HOME/.agent-awake/launchd.err</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "==> hooks: Claude Code (~/.claude/settings.json)"
osascript -l JavaScript "$ROOT/scripts/hooks.js" add claude "$HOME/.claude/settings.json" "$BIN"

echo "==> hooks: Codex (~/.codex/hooks.json)"
osascript -l JavaScript "$ROOT/scripts/hooks.js" add codex "$HOME/.codex/hooks.json" "$BIN"

cat <<EOF

Done. Restart running Claude Code / Codex sessions so they load the hooks.
Codex asks you to review and trust new hooks: run /hooks in Codex CLI once.
Check state any time with: awake status
EOF
