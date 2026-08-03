#!/bin/zsh
set -euo pipefail

export PATH="${PATH:-/usr/bin:/bin}:/Users/ben/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

YC_BIN=${HERDR_DEVBOX_YC_BIN:-yc}
SSH_BIN=${HERDR_DEVBOX_SSH_BIN:-ssh}
HERDR_BIN=${HERDR_DEVBOX_HERDR_BIN:-herdr}
STACKS_PATH=${HERDR_DEVBOX_STACKS_PATH:-$HOME/.yc/stacks.json}
CONFIG_PATH=${HERDR_DEVBOX_CONFIG_PATH:-$HOME/.config/herdr-mirror/hosts.toml}
STATE_PATH=${HERDR_DEVBOX_STATE_PATH:-$HOME/.local/state/herdr-devboxes/state.json}
NOW=${HERDR_DEVBOX_NOW:-$(date +%s)}
FLEET_SYNC_SECONDS=${HERDR_DEVBOX_FLEET_SYNC_SECONDS:-300}
CLEANUP_GRACE_SECONDS=${HERDR_DEVBOX_CLEANUP_GRACE_SECONDS:-86400}
CLEANUP_RETRY_SECONDS=${HERDR_DEVBOX_CLEANUP_RETRY_SECONDS:-3600}

log() {
  print -u2 -r -- "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"
}

atomic_write() {
  local target=$1 content=$2 tmp
  mkdir -p "${target:h}"
  tmp="${target}.tmp.$$"
  print -r -- "$content" > "$tmp"
  mv "$tmp" "$target"
}

load_state() {
  if [[ ! -e "$STATE_PATH" ]]; then
    print -r -- '{"fleet_synced_at":null,"devboxes":{}}'
    return
  fi
  /usr/bin/jq -ce '
    if type == "object" and (.devboxes | type) == "object" then
      . + {fleet_synced_at: (.fleet_synced_at // null)}
    else
      error("invalid state")
    end
  ' "$STATE_PATH"
}

resolve_mirror_bin() {
  if [[ -n "${HERDR_DEVBOX_MIRROR_BIN:-}" ]]; then
    print -r -- "$HERDR_DEVBOX_MIRROR_BIN"
    return
  fi
  local root
  root=$("$HERDR_BIN" plugin list --json | /usr/bin/jq -er \
    '.result.plugins[] | select(.plugin_id == "mirror") | .plugin_root')
  print -r -- "$root/target/release/herdr-mirror"
}

local_herdr_running() {
  "$HERDR_BIN" status --json 2>/dev/null | /usr/bin/jq -e '.server.status == "running"' >/dev/null
}

render_config() {
  local name quoted
  print -r -- 'poll_seconds = 60'
  print -r -- 'close_remote_on_local_close = true'
  print -r -- 'always_control = true'
  for name in "$@"; do
    quoted=$(/usr/bin/jq -Rn --arg value "$name" '$value')
    print
    print -r -- "[hosts.$quoted]"
    print -r -- "target = \"devbox-$name\""
    print -r -- "prefix = $quoted"
  done
}

probe_workspaces() {
  local name=$1 output json
  local -a ssh_args
  ssh_args=(
    -S none
    -o ControlMaster=no
    -o BatchMode=yes
    -o ConnectTimeout=10
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=3
  )
  local remote_script='workspaces=$(herdr workspace list 2>/dev/null)
if [ $? -ne 0 ]; then
  nohup herdr server >/tmp/herdr-server-stdio.log 2>&1 </dev/null &
  attempt=0
  while [ "$attempt" -lt 50 ]; do
    sleep 0.2
    workspaces=$(herdr workspace list 2>/dev/null) && break
    attempt=$((attempt + 1))
  done
fi
if [ -z "${workspaces:-}" ]; then
  echo "remote Herdr server did not become ready" >&2
  exit 1
fi
printf "%s\n%s\n%s\n" "@@HERDR_DEVBOX_WORKSPACES@@" "$workspaces" "@@HERDR_DEVBOX_WORKSPACES_END@@"'

  if ! output=$("$SSH_BIN" "${ssh_args[@]}" "devbox-$name" "$remote_script" 2>&1); then
    log "$name: remote Herdr probe failed: $output"
    return 1
  fi
  json=$(print -r -- "$output" | awk '
    /^@@HERDR_DEVBOX_WORKSPACES@@$/ { capture = 1; next }
    /^@@HERDR_DEVBOX_WORKSPACES_END@@$/ { capture = 0 }
    capture { print }
  ')
  if ! print -r -- "$json" | /usr/bin/jq -e \
    '.result.type == "workspace_list" and (.result.workspaces | type) == "array"' >/dev/null 2>&1; then
    log "$name: remote Herdr returned invalid workspace data"
    return 1
  fi
  print -r -- "$json"
}

state=$(load_state)
last_fleet_sync=$(print -r -- "$state" | /usr/bin/jq -r '.fleet_synced_at // 0')
if (( NOW - last_fleet_sync >= FLEET_SYNC_SECONDS )); then
  if "$YC_BIN" devbox sync --quiet; then
    state=$(print -r -- "$state" | /usr/bin/jq -c --argjson now "$NOW" '.fleet_synced_at = $now')
  else
    log 'yc devbox sync failed; using the existing local registry'
  fi
fi

if [[ ! -e "$STACKS_PATH" ]]; then
  registry='{}'
elif ! registry=$(/usr/bin/jq -ce 'if type == "object" then . else error("invalid registry") end' "$STACKS_PATH"); then
  log 'could not parse the YC stack registry; preserving mirror configuration'
  exit 1
fi

names=()
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  if [[ ! "$name" =~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$' ]]; then
    log "ignoring unsafe devbox name: $name"
    continue
  fi
  names+=("$name")
done < <(print -r -- "$registry" | /usr/bin/jq -r \
  'to_entries[] | select(.value.remote == true) | .key' | sort)

stopped_names=()
for name in "${names[@]}"; do
  if ! workspaces=$(probe_workspaces "$name"); then
    continue
  fi
  workspace_count=$(print -r -- "$workspaces" | /usr/bin/jq -r '.result.workspaces | length')
  if (( workspace_count > 0 )); then
    state=$(print -r -- "$state" | /usr/bin/jq -c \
      --arg name "$name" --argjson now "$NOW" '
        .devboxes[$name] = (
          (.devboxes[$name] // {
            workspace_seen_at: null,
            empty_since: null,
            cleanup_attempted_at: null
          })
          | .workspace_seen_at = $now
          | .empty_since = null
          | .cleanup_attempted_at = null
        )
      ')
  else
    state=$(print -r -- "$state" | /usr/bin/jq -c \
      --arg name "$name" --argjson now "$NOW" '
        .devboxes[$name] = (
          (.devboxes[$name] // {
            workspace_seen_at: null,
            empty_since: null,
            cleanup_attempted_at: null
          })
          | if .workspace_seen_at != null and .empty_since == null then
              .empty_since = $now
            else
              .
            end
        )
      ')
    workspace_seen_at=$(print -r -- "$state" | /usr/bin/jq -r --arg name "$name" \
      '.devboxes[$name].workspace_seen_at // 0')
    empty_since=$(print -r -- "$state" | /usr/bin/jq -r --arg name "$name" \
      '.devboxes[$name].empty_since // 0')
    cleanup_attempted_at=$(print -r -- "$state" | /usr/bin/jq -r --arg name "$name" \
      '.devboxes[$name].cleanup_attempted_at // 0')
    if (( workspace_seen_at > 0 && NOW - empty_since >= CLEANUP_GRACE_SECONDS &&
          NOW - cleanup_attempted_at >= CLEANUP_RETRY_SECONDS )); then
      state=$(print -r -- "$state" | /usr/bin/jq -c \
        --arg name "$name" --argjson now "$NOW" \
        '.devboxes[$name].cleanup_attempted_at = $now')
      atomic_write "$STATE_PATH" "$state"
      if "$YC_BIN" stop --remote "--name=$name" </dev/null; then
        stopped_names+=("$name")
        state=$(print -r -- "$state" | /usr/bin/jq -c --arg name "$name" \
          'del(.devboxes[$name])')
      else
        log "$name: safe cleanup was blocked or failed"
      fi
    fi
  fi
done

remaining_names=()
for name in "${names[@]}"; do
  if (( ${stopped_names[(Ie)$name]} == 0 )); then
    remaining_names+=("$name")
  fi
done

registry_names=$(
  print -rl -- "${names[@]}" | /usr/bin/jq -Rsc 'split("\n") | map(select(length > 0))'
)
state=$(print -r -- "$state" | /usr/bin/jq -c --argjson names "$registry_names" '
  .devboxes |= with_entries(select(.key as $name | $names | index($name)))
')

desired=$(render_config "${remaining_names[@]}")
current=''
[[ -e "$CONFIG_PATH" ]] && current=$(<"$CONFIG_PATH")

if [[ "$desired" != "$current" ]]; then
  mirror_bin=$(resolve_mirror_bin)
  if [[ -n "$current" && -x "$mirror_bin" ]] && local_herdr_running; then
    "$mirror_bin" teardown
  fi
  if (( ${#remaining_names[@]} == 0 )); then
    rm -f "$CONFIG_PATH"
  else
    atomic_write "$CONFIG_PATH" "$desired"
    if local_herdr_running; then
      "$mirror_bin" start
    fi
  fi
fi

atomic_write "$STATE_PATH" "$state"
