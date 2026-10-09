#!/bin/bash
# Test suite. Uses a fake pmset, so it never touches the real sleep setting.
# usage: tests/run.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AWAKE="$ROOT/bin/awake"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

# Fake pmset: keeps SleepDisabled in a file, prints it like the real `pmset -g`.
cat >"$WORK/pmset" <<'EOF'
#!/bin/bash
state_file="$(dirname "$0")/state"
case "$1" in
  -g) printf ' SleepDisabled\t\t%s\n' "$(cat "$state_file")" ;;
  disablesleep) echo "$2" >"$state_file" ;;
esac
EOF
chmod +x "$WORK/pmset"

export AWAKE_PMSET="$WORK/pmset"
export AWAKE_SUDO=""

setup() {
  export AWAKE_HOME="$WORK/home-$1"
  rm -rf "$AWAKE_HOME"
  echo "$2" >"$WORK/state"
}

sleep_state() { cat "$WORK/state"; }
lock_count() { find "$AWAKE_HOME/locks" -type f | wc -l | tr -d ' '; }

check() {
  local name=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $name (want '$want', got '$got')"
  fi
}

# --- tests ----------------------------------------------------------------

setup on-off 0
"$AWAKE" on a
check "on disables sleep" 1 "$(sleep_state)"
"$AWAKE" off a
check "last off re-enables sleep" 0 "$(sleep_state)"

setup pause 0
"$AWAKE" on a
"$AWAKE" pause >/dev/null
check "pause restores sleep" 0 "$(sleep_state)"
"$AWAKE" on b
check "lock while paused keeps sleep enabled" 0 "$(sleep_state)"
check "locks tracked while paused" 2 "$(lock_count)"
"$AWAKE" resume >/dev/null
check "resume disables sleep again" 1 "$(sleep_state)"
"$AWAKE" pause 1m >/dev/null
echo $(($(date +%s) - 1)) >"$AWAKE_HOME/paused"
"$AWAKE" sweep
check "expired pause ends on sweep" 1 "$(sleep_state)"
"$AWAKE" pause bogus 2>/dev/null
check "bad duration rejected" 1 "$(sleep_state)"

setup multi 0
"$AWAKE" on a
"$AWAKE" on b
"$AWAKE" off a
check "sleep stays disabled while a lock remains" 1 "$(sleep_state)"
"$AWAKE" off b
check "sleep re-enabled after the last lock" 0 "$(sleep_state)"

setup preexisting 1
"$AWAKE" on a
"$AWAKE" off a
check "pre-existing disablesleep 1 is kept" 1 "$(sleep_state)"

setup user-reenabled 0
"$AWAKE" on a
echo 0 >"$WORK/state"
"$AWAKE" off a
check "sleep re-enabled by the user stays enabled" 0 "$(sleep_state)"
"$AWAKE" on b
"$AWAKE" off b
check "ownership is tracked again on the next lock" 0 "$(sleep_state)"

setup sweep-dead 0
"$AWAKE" on gone 99999999
"$AWAKE" sweep
check "sweep drops locks of dead processes" 0 "$(lock_count)"
check "sweep restores sleep" 0 "$(sleep_state)"

setup sweep-alive 0
"$AWAKE" on alive $$
"$AWAKE" sweep
check "sweep keeps locks of live processes" 1 "$(lock_count)"

setup sweep-ttl 0
"$AWAKE" on old $$
"$AWAKE" on
touch -t 202001010000 "$AWAKE_HOME/locks/old" "$AWAKE_HOME/locks/manual"
"$AWAKE" sweep
check "sweep drops locks without a heartbeat" 0 "$([ -f "$AWAKE_HOME/locks/old" ] && echo 1 || echo 0)"
check "sweep never drops the manual lock" 1 "$([ -f "$AWAKE_HOME/locks/manual" ] && echo 1 || echo 0)"

# Codex session log line, like ~/.codex/sessions/.../rollout-*.jsonl.
rollout_event() {
  printf '{"timestamp":"%s","ordinal":1,"type":"event_msg","payload":{"type":"%s","turn_id":"t"}}\n' \
    "$(date -u -r "$1" '+%Y-%m-%dT%H:%M:%S.123Z')" "$2"
}

setup sweep-turn-ended 0
log="$WORK/rollout.jsonl"
now=$(date +%s)
rollout_event $((now - 60)) task_complete >"$log"
rollout_event "$now" task_started >>"$log"
printf '{"session_id":"s-2","transcript_path":"%s"}' "$log" | "$AWAKE" hook codex on
"$AWAKE" sweep
check "sweep keeps the lock of a running turn" 1 "$(lock_count)"
: >"$log"
rollout_event $((now - 60)) task_complete >"$log"
"$AWAKE" sweep
check "sweep ignores a turn that ended before the heartbeat" 1 "$(lock_count)"
rollout_event $((now + 1)) task_complete >>"$log"
"$AWAKE" sweep
check "sweep drops the lock of a turn that ended with an error" 0 "$(lock_count)"
check "sweep restores sleep after a failed turn" 0 "$(sleep_state)"

setup sweep-turn-aborted 0
rollout_event $(($(date +%s) + 1)) turn_aborted >"$log"
printf '{"session_id":"s-3","transcript_path":"%s"}' "$log" | "$AWAKE" hook codex on
"$AWAKE" sweep
check "sweep drops the lock of an aborted turn" 0 "$(lock_count)"

setup hook 0
out=$(echo '{"session_id": "s-1", "hook_event_name": "UserPromptSubmit"}' | "$AWAKE" hook claude on)
check "hook prints nothing" "" "$out"
check "hook creates a lock per session" 1 "$([ -f "$AWAKE_HOME/locks/claude-s-1" ] && echo 1 || echo 0)"
echo '{"session_id":"s-1"}' | "$AWAKE" hook claude off
check "hook off removes the lock" 0 "$(lock_count)"

setup hook-garbage 0
echo 'not json' | "$AWAKE" hook codex on
check "hook exits 0 on bad input" 0 "$?"
check "hook falls back to an 'unknown' session" 1 "$([ -f "$AWAKE_HOME/locks/codex-unknown" ] && echo 1 || echo 0)"

setup sanitize 0
"$AWAKE" on '../../evil id'
check "lock ids cannot escape the locks dir" 1 "$(lock_count)"

setup concurrent 0
for i in $(seq 1 20); do "$AWAKE" on "c$i" & done
wait
check "concurrent on keeps every lock" 20 "$(lock_count)"
for i in $(seq 1 20); do "$AWAKE" off "c$i" & done
wait
check "concurrent off releases every lock" 0 "$(lock_count)"
check "concurrent off restores sleep" 0 "$(sleep_state)"

setup reset 0
"$AWAKE" on a
"$AWAKE" on b
"$AWAKE" reset
check "reset drops all locks" 0 "$(lock_count)"
check "reset restores sleep" 0 "$(sleep_state)"

# hooks.js: merging into agent configs (needs macOS osascript).
cfg="$WORK/settings.json"
echo '{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo keep"}]}]}}' >"$cfg"
osascript -l JavaScript "$ROOT/scripts/hooks.js" add claude "$cfg" "$AWAKE"
osascript -l JavaScript "$ROOT/scripts/hooks.js" add claude "$cfg" "$AWAKE"
check "hooks add is idempotent" 5 "$(grep -c 'hook claude' "$cfg")"
check "hooks add keeps foreign hooks" 1 "$(grep -c 'echo keep' "$cfg")"
osascript -l JavaScript "$ROOT/scripts/hooks.js" remove claude "$cfg" ""
check "hooks remove drops only ours" 0 "$(grep -c 'hook claude' "$cfg")"
check "hooks remove keeps other settings" 1 "$(grep -c '"theme"' "$cfg")"

echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
