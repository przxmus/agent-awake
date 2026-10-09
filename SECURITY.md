# Security policy

agent-awake installs a sudoers rule and hooks that run on every agent prompt and tool
call, so security reports are taken seriously.

## Reporting a vulnerability

Please don't open a public issue. Use GitHub's private reporting instead:
**Security** tab, then **Report a vulnerability**.

Include what an attacker can do, the steps to reproduce, and your macOS and
agent versions. Expect a first reply within a week.

## Supported versions

Only the latest release and `main` get fixes. `awake update` brings you to the
latest version.

## What's in scope

- The sudoers rule allowing more than `pmset disablesleep 0` and `pmset disablesleep 1`
- A way to make `awake` run other commands as root, or as you, through crafted
  hook input, lock files or config
- The installer or uninstaller damaging `~/.claude/settings.json`, `~/.codex/hooks.json`
  or other files
- Anything that keeps sleep disabled after all agents have stopped, in a way the
  sweep doesn't fix

## Things to know

- `~/.agent-awake/config` is sourced as a shell file. Anyone who can write it can
  already run code as you, so that's not a vulnerability by itself.
- The curl installer runs code from this repo. If you'd rather review it first,
  clone the repo and run `./install.sh` yourself.
