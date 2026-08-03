#!/bin/zsh
set -euo pipefail

ROOT=${0:A:h}
SYNC="$ROOT/sync.zsh"
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

HOME_DIR="$TMP_ROOT/home"
FAKE_BIN="$TMP_ROOT/bin"
FIXTURES="$TMP_ROOT/fixtures"
COMMAND_LOG="$TMP_ROOT/commands.log"
MIRROR_LOG="$TMP_ROOT/mirror.log"
CONFIG="$HOME_DIR/.config/herdr-mirror/hosts.toml"
STATE="$HOME_DIR/.local/state/herdr-devboxes/state.json"
STACKS="$HOME_DIR/.yc/stacks.json"

mkdir -p "$HOME_DIR/.yc" "$FAKE_BIN" "$FIXTURES"
: > "$COMMAND_LOG"
: > "$MIRROR_LOG"

cat > "$FAKE_BIN/yc" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$HERDR_DEVBOX_TEST_COMMAND_LOG"
if [[ "${1:-} ${2:-}" == "stop --remote" ]]; then
  exit "${HERDR_DEVBOX_TEST_STOP_EXIT:-0}"
fi
exit "${HERDR_DEVBOX_TEST_SYNC_EXIT:-0}"
EOF

cat > "$FAKE_BIN/ssh" <<'EOF'
#!/bin/zsh
host=''
for arg in "$@"; do
  if [[ "$arg" == devbox-* ]]; then
    host=$arg
  fi
done
name=${host#devbox-}
fixture="$HERDR_DEVBOX_TEST_FIXTURES/$name"
[[ -f "$fixture" ]] || exit 255
value=$(<"$fixture")
[[ "$value" != unreachable ]] || exit 255
json=$(/usr/bin/jq -cn --argjson count "$value" '{id:"cli:workspace:list",result:{type:"workspace_list",workspaces:[range(0;$count)|{workspace_id:("w"+(.|tostring))}]}}')
print -r -- '@@HERDR_DEVBOX_WORKSPACES@@'
print -r -- "$json"
print -r -- '@@HERDR_DEVBOX_WORKSPACES_END@@'
EOF

cat > "$FAKE_BIN/herdr" <<'EOF'
#!/bin/zsh
if [[ "${1:-} ${2:-}" == "status --json" ]]; then
  print -r -- '{"server":{"status":"running","socket":"/tmp/herdr.sock"}}'
  exit 0
fi
exit 1
EOF

cat > "$FAKE_BIN/herdr-mirror" <<'EOF'
#!/bin/zsh
print -r -- "${1:-}" >> "$HERDR_DEVBOX_TEST_MIRROR_LOG"
EOF

chmod +x "$FAKE_BIN"/*

cat > "$STACKS" <<'EOF'
{
  "alpha": {"remote": true},
  "beta": {"remote": true},
  "local": {"remote": false}
}
EOF
print -r -- 1 > "$FIXTURES/alpha"
print -r -- 0 > "$FIXTURES/beta"

fail() {
  print -u2 -r -- "FAIL: $*"
  exit 1
}

assert_contains() {
  local pattern=$1 file=$2
  grep -q -- "$pattern" "$file" || fail "$file does not contain $pattern"
}

assert_not_contains() {
  local pattern=$1 file=$2
  if grep -q -- "$pattern" "$file"; then
    fail "$file unexpectedly contains $pattern"
  fi
}

run_sync() {
  local now=$1
  env \
    HOME="$HOME_DIR" \
    PATH="$FAKE_BIN:/usr/bin:/bin" \
    HERDR_DEVBOX_NOW="$now" \
    HERDR_DEVBOX_YC_BIN="$FAKE_BIN/yc" \
    HERDR_DEVBOX_SSH_BIN="$FAKE_BIN/ssh" \
    HERDR_DEVBOX_HERDR_BIN="$FAKE_BIN/herdr" \
    HERDR_DEVBOX_MIRROR_BIN="$FAKE_BIN/herdr-mirror" \
    HERDR_DEVBOX_STACKS_PATH="$STACKS" \
    HERDR_DEVBOX_CONFIG_PATH="$CONFIG" \
    HERDR_DEVBOX_STATE_PATH="$STATE" \
    HERDR_DEVBOX_TEST_COMMAND_LOG="$COMMAND_LOG" \
    HERDR_DEVBOX_TEST_MIRROR_LOG="$MIRROR_LOG" \
    HERDR_DEVBOX_TEST_FIXTURES="$FIXTURES" \
    zsh "$SYNC"
}

run_sync 1000
assert_contains '^close_remote_on_local_close = true$' "$CONFIG"
assert_contains '^\[hosts\."alpha"\]$' "$CONFIG"
assert_contains '^\[hosts\."beta"\]$' "$CONFIG"
assert_not_contains '^\[hosts\."local"\]$' "$CONFIG"
[[ "$(grep -c '^start$' "$MIRROR_LOG")" == 1 ]] || fail 'mirror did not start exactly once'

run_sync 1060
[[ "$(grep -c '^start$' "$MIRROR_LOG")" == 1 ]] || fail 'unchanged config restarted mirror'
[[ "$(grep -c '^devbox sync --quiet$' "$COMMAND_LOG")" == 1 ]] || fail 'fleet sync throttle failed'

print -r -- 'PASS: discovery and unchanged reconciliation'
