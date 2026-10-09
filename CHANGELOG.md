# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[semver](https://semver.org/).

## Unreleased

- `awake pause [duration]` and `awake resume` to temporarily stop keeping the Mac awake

## 0.1.0

First release.

- Lock-based `pmset disablesleep` control shared by all agent sessions
- Hooks for Claude Code (CLI and desktop Code tab) and Codex (CLI and desktop app)
- launchd sweep that drops locks of dead sessions and sessions without a heartbeat
- Keeps sleep disabled if it was already disabled before awake
- One-line installer, `awake update`, `awake uninstall`, `awake status`
