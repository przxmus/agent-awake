# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[semver](https://semver.org/).

## Unreleased

## 0.1.2

- Release the Claude Code lock when an API error (lost connection, rate limit) ends the turn
- `awake sweep` drops the Codex lock when the session log shows the turn ended without a `Stop` hook

## 0.1.1

- `awake pause [duration]` and `awake resume` to temporarily stop keeping the Mac awake

## 0.1.0

First release.

- Lock-based `pmset disablesleep` control shared by all agent sessions
- Hooks for Claude Code (CLI and desktop Code tab) and Codex (CLI and desktop app)
- launchd sweep that drops locks of dead sessions and sessions without a heartbeat
- Keeps sleep disabled if it was already disabled before awake
- One-line installer, `awake update`, `awake uninstall`, `awake status`
