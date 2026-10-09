# Contributing

Thanks for helping. agent-awake is small on purpose, so the rules below are mostly
about keeping it small, safe and easy to install.

## Before you start

- For a bug, open an issue with the bug report form. Include `awake status`,
  `awake version` and the relevant lines of `~/.agent-awake/awake.log`.
- For a new feature or a new agent integration, open an issue first and describe
  the use case. A short discussion saves you from writing a PR that won't be merged.
- Typos and small doc fixes can go straight to a PR.
- Security problems go through [SECURITY.md](SECURITY.md), not public issues.

## Ground rules for the code

- **Plain bash 3.2.** That's what ships with macOS. No bash 4+ features (associative
  arrays, `${var,,}`, `mapfile`) and no zsh.
- **No new dependencies.** Users shouldn't need Homebrew, jq, Python or Node. Use
  what macOS ships with (`osascript -l JavaScript` handles JSON).
- **Hooks must never break an agent.** `awake hook` prints nothing, exits 0 and
  finishes in well under a second, whatever the input.
- **Only undo what awake did.** Never change a sleep setting awake didn't set itself.
- **Keep sudo narrow.** The sudoers rule covers `pmset disablesleep 0` and
  `pmset disablesleep 1` and nothing else. A PR that needs more root access needs a
  very good reason.
- **Don't break user configs.** Changes to `~/.claude/settings.json` or
  `~/.codex/hooks.json` must keep every setting and hook that isn't ours.
- **Tests never touch the real Mac.** Use the fake pmset in `tests/run.sh`.

## Development

```bash
git clone https://github.com/przxmus/agent-awake.git
cd agent-awake
./install.sh          # optional: installs hooks pointing at your clone
tests/run.sh
shellcheck bin/awake install.sh uninstall.sh tests/run.sh
```

Add a test to `tests/run.sh` for every behavior change and every bug fix.

## Pull requests

1. Fork the repo and create a branch from `main`, e.g. `fix/sweep-ttl` or
   `feat/cursor-hooks`.
2. Keep one change per PR. Two unrelated fixes means two PRs.
3. Make sure `tests/run.sh` and `shellcheck` pass. CI runs both on macOS.
4. Update `README.md` if users see the change, and add a line under `Unreleased`
   in `CHANGELOG.md`.
5. Fill in the PR template, including how you tested it on a real Mac.

PRs are squash-merged, so the PR title becomes the commit message. Write it as a
[Conventional Commit](https://www.conventionalcommits.org/):

```
feat: add hooks for Cursor
fix: keep the lock when Codex resumes a thread
docs: explain the TTL in the README
```

Use `feat!:` or a `BREAKING CHANGE:` footer when users have to do something after
updating (for example, reinstall or re-trust hooks).

## Releases (maintainers)

`main` only accepts pull requests, so a release has two steps.

1. Actions → Release → Run workflow on `main`. Pick `patch`, `minor` or `major` to bump the latest `vX.Y.Z` tag, or `custom` and fill in `custom_version`. The workflow opens a `chore: release vX.Y.Z` PR that bumps `VERSION` and moves the `Unreleased` entries in `CHANGELOG.md` under the new version, and runs CI on it.
2. Merge that PR. The merge tags `vX.Y.Z` and publishes the GitHub release, with notes generated from the commits since the previous tag, grouped by conventional commit type.

In Settings → Actions → General, enable "Allow GitHub Actions to create and approve pull requests".

Users get the release through `awake update`, which pulls `main`.

## Code of conduct

Everyone taking part follows the [code of conduct](CODE_OF_CONDUCT.md).
