#!/bin/bash
# Install agent-awake: CLI symlink, passwordless pmset, launchd sweeper, agent hooks.
# Safe to run again (after an update or after moving the repo).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT/bin/awake"
LABEL="local.agent-awake"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SUDOERS="/etc/sudoers.d/agent-awake"

if [ "$(uname -s)" != Darwin ]; then
  echo "agent-awake only supports macOS." >&2
  exit 1
fi

chmod +x "$BIN"

echo "==> CLI: ~/.local/bin/awake"
mkdir -p "$HOME/.local/bin"
ln -sf "$BIN" "$HOME/.local/bin/awake"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "    note: ~/.local/bin is not on your PATH; add it to use 'awake' directly" ;;
esac

echo "==> sudoers: passwordless 'pmset disablesleep 0|1'"
# Setting the current value again is a no-op, so this is a safe probe.
state=$(/usr/bin/pmset -g | awk '/SleepDisabled/ { print $2 }')
if sudo -n /usr/bin/pmset disablesleep "${state:-0}" 2>/dev/null; then
  echo "    already allowed"
else
  rule="$(whoami) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1"
  tmp=$(mktemp)
  echo "$rule" >"$tmp"
  echo "    sudo will ask for your password once to install $SUDOERS"
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

if [ -d "$HOME/.claude" ] || command -v claude >/dev/null; then
  echo "==> hooks: Claude Code (~/.claude/settings.json)"
  osascript -l JavaScript "$ROOT/scripts/hooks.js" add claude "$HOME/.claude/settings.json" "$BIN"
else
  echo "==> hooks: Claude Code not found, skipped"
fi

if [ -d "$HOME/.codex" ] || command -v codex >/dev/null; then
  echo "==> hooks: Codex (~/.codex/hooks.json)"
  osascript -l JavaScript "$ROOT/scripts/hooks.js" add codex "$HOME/.codex/hooks.json" "$BIN"
else
  echo "==> hooks: Codex not found, skipped"
fi

cat <<EOF

Done. Next steps:
  1. Restart running Claude Code sessions so they load the hooks.
  2. Codex: run /hooks in Codex CLI once and trust the new hooks,
     then quit (Cmd+Q) and reopen the Codex / ChatGPT app.
  3. Check it works: start a prompt and run 'awake status'.
EOF
