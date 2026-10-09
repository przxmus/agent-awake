# agent-awake

Keep your Mac awake while AI coding agents work, even with the lid closed in a
backpack. Once every agent is done and waiting for you, sleep comes back on so the
laptop doesn't cook itself.

It works across several agents at once. Run three Claude Code sessions and two Codex
threads, and sleep stays disabled until the last one finishes.

Supported agents:

- Claude Code (CLI, and the Code tab in the Claude desktop app)
- Codex (CLI, and the Codex / ChatGPT desktop app)

macOS only.

## How it works

Each working agent session holds a lock file in `~/.agent-awake/locks/`. Agent hooks
create and remove the locks:

| Agent | Takes the lock (heartbeat) | Releases the lock |
|---|---|---|
| Claude Code | `UserPromptSubmit`, `PreToolUse` | `Stop`, `SessionEnd` |
| Codex | `UserPromptSubmit`, `PreToolUse` | `Stop`, `Interrupt`, `SessionEnd` |

After every change, `awake` counts the locks:

- One or more locks: it runs `pmset disablesleep 1`.
- No locks left: it runs `pmset disablesleep 0`, but only if awake disabled sleep
  itself. If sleep was already disabled before the first lock (by you or another
  tool), awake leaves it alone.

A launchd job runs `awake sweep` every minute. It drops locks whose agent process
has exited (crash, closed window) and locks with no heartbeat for 45 minutes, so a
crashed session can't keep your laptop awake forever.

### Why `pmset disablesleep` and not `caffeinate`

`caffeinate` keeps the Mac awake while the lid is open. Close the lid and the Mac
sleeps anyway. `pmset disablesleep 1` also prevents lid-close sleep, which is the
whole point here. The catch is that it needs root, so the installer adds a narrow
sudoers rule (see below).

## Requirements

- macOS (tested on macOS 26)
- Claude Code and/or Codex with hooks support (Codex CLI 0.160 or newer)
- An admin account, to install the sudoers rule once

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/przxmus/agent-awake/main/install.sh | bash
```

This clones the repo to `~/.local/share/agent-awake` and runs `install.sh` from
there. Want to read the script first? Clone the repo yourself and run the installer
from your clone. The hooks then point into that clone, so run `./install.sh` again if
you move it.

```bash
git clone https://github.com/przxmus/agent-awake.git
cd agent-awake
./install.sh
```

The installer is safe to run again and does the following:

1. Links `~/.local/bin/awake` to `bin/awake`. Make sure `~/.local/bin` is on your
   `PATH`.
2. Installs `/etc/sudoers.d/agent-awake` if `sudo pmset disablesleep` still asks for
   a password. sudo asks for your password once here.
3. Installs and starts the launchd job `local.agent-awake`.
4. Adds hooks to `~/.claude/settings.json` and `~/.codex/hooks.json`, keeping your
   other settings and hooks. It skips an agent that isn't installed.

Then finish the setup by hand:

1. Restart running Claude Code sessions.
2. In Codex CLI, run `/hooks` once and trust the new hooks. Codex ignores untrusted
   hooks. The Codex desktop app reads the same `~/.codex`, so this covers it too.
3. Quit the Codex / ChatGPT app with Cmd+Q and open it again, so its built-in
   `codex app-server` loads the hooks.
4. Send a prompt to any agent and run `awake status` while it works. You should see
   a `claude-...` or `codex-...` lock.

### The sudoers rule

`pmset disablesleep` needs root, and hooks can't type a password. The installer
writes this rule (with your username):

```
you ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1
```

It allows exactly these two commands without a password. No other `pmset` option and
no other program. The installer checks the file with `visudo -c` before installing
it, so a broken rule can't lock you out of sudo.

To add it by hand instead:

```bash
sudo visudo -f /etc/sudoers.d/agent-awake
```

Paste the line above with your username (`whoami`), save, and quit. Check it with:

```bash
sudo -n /usr/bin/pmset disablesleep 0 && echo ok
```

## Usage

You don't need to do anything day to day. The hooks handle it. A few commands help
when you want to look or step in:

```bash
awake status    # sleep state, whether awake set it, and the current locks
awake on        # take a manual lock (never swept)
awake off       # release the manual lock
awake reset     # drop all locks and restore the previous sleep state
awake help      # all commands
```

`awake on` is handy for a long job you start yourself, like a render or a download.

The log is in `~/.agent-awake/awake.log`.

## Configuration

Settings go in `~/.agent-awake/config`, a shell file:

```bash
# Minutes without a heartbeat before a lock is dropped (default 45).
AWAKE_TTL_MIN=90
```

## Update

```bash
awake update
```

This pulls the latest version with `git pull --ff-only` and runs the installer
again. `awake version` shows what you have.

## Uninstall

```bash
awake uninstall
```

This removes the hooks, the launchd job and the `awake` link, then restores the
sleep state awake changed. It also deletes `~/.local/share/agent-awake` if the curl
installer created it. A clone you made yourself stays. The sudoers rule stays too,
and the command prints how to remove it.

## Limitations

- The plain chat in the Claude desktop app has no hooks or shell, so it isn't
  covered. The Code tab is.
- Interrupting Claude Code with Esc may not fire `Stop`. The lock then stays until
  the session closes or the TTL runs out.
- One tool call that runs longer than the TTL (an hour-long build with no other tool
  calls) loses its lock. Raise `AWAKE_TTL_MIN` if you work like that.
- If an agent ends its turn while a background task still runs, the lock goes away.
  It comes back as soon as the agent uses a tool again.
- If you disable sleep by hand while awake already holds it disabled, awake can't
  tell, and turns sleep back on after the last lock. Run `awake on` instead.

## Troubleshooting

**No locks appear.** Check `~/.agent-awake/awake.log`. With nothing logged, the
hooks aren't running. Restart the agent, and for Codex make sure you trusted the
hooks with `/hooks`.

**`ERROR: sudo pmset disablesleep ... failed` in the log.** The sudoers rule is
missing or doesn't match. Run the `sudo -n` check above.

**Sleep stays disabled.** Run `awake status`. If it lists no locks and says
"Set by awake: no", sleep was disabled outside awake. Run
`sudo pmset disablesleep 0` to turn it back on.

## Development

```bash
tests/run.sh                              # tests, with a fake pmset
shellcheck bin/awake install.sh uninstall.sh tests/run.sh
```

The tests never touch your real sleep setting. See [CONTRIBUTING.md](CONTRIBUTING.md)
before opening a pull request.

## License

[MIT](LICENSE)
