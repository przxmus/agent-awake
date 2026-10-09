## What and why

<!-- What does this change, and what problem does it solve? Link the issue: Closes #123 -->

## How I tested it

<!-- tests/run.sh output, and what you checked on a real Mac (macOS version, agent and version). -->

## Checklist

- [ ] One change in this PR
- [ ] `tests/run.sh` passes, with a new test for the change
- [ ] `shellcheck bin/awake install.sh uninstall.sh tests/run.sh` passes
- [ ] Works with the bash 3.2 that ships with macOS, no new dependencies
- [ ] Hooks still print nothing and always exit 0
- [ ] README and the `Unreleased` section of CHANGELOG updated if users see the change
- [ ] PR title is a Conventional Commit (`feat: ...`, `fix: ...`)
