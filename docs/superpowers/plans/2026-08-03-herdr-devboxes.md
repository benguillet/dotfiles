# Herdr Remote Devboxes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically mirror Herdr sessions from YC remote devboxes and safely stop devboxes that remain without Herdr workspaces for 24 hours.

**Architecture:** A zsh reconciler discovers boxes through YC's existing registry and SSH aliases, starts their Herdr servers, maintains `herdr-mirror`'s generated host configuration, and tracks cleanup timestamps in JSON state. A macOS LaunchAgent invokes the reconciler every minute; dotfiles owns and symlinks both executable and plist.

**Tech Stack:** zsh, jq, launchd, Herdr CLI, herdr-mirror, YC CLI, SSH, Rake

---

### Task 1: Build the reconciler discovery and mirror lifecycle

**Files:**
- Create: `work/herdr-devboxes/sync.zsh`
- Create: `work/herdr-devboxes/test.zsh`

- [ ] **Step 1: Write a failing hermetic discovery test**

Create a zsh test harness that builds a temporary `HOME`, fake `yc`, `ssh`, `herdr`, and `herdr-mirror` executables, then writes this registry:

```json
{
  "alpha": {"remote": true},
  "beta": {"remote": true},
  "local": {"remote": false}
}
```

Have fake SSH return marker-delimited Herdr workspace JSON for `devbox-alpha` and `devbox-beta`. Run `sync.zsh` with command/path overrides and assert that `hosts.toml` contains exactly the two remote hosts, `close_remote_on_local_close = true`, and one mirror `start` invocation. Run it again unchanged and assert that no second mirror lifecycle command occurs.

```zsh
run_sync 1000
grep -q '^close_remote_on_local_close = true$' "$config"
grep -q '^\[hosts\."alpha"\]$' "$config"
grep -q '^\[hosts\."beta"\]$' "$config"
! grep -q '^\[hosts\."local"\]$' "$config"
[[ "$(grep -c '^start$' "$mirror_log")" == 1 ]]
run_sync 1060
[[ "$(grep -c '^start$' "$mirror_log")" == 1 ]]
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```zsh
zsh work/herdr-devboxes/test.zsh
```

Expected: FAIL because `sync.zsh` does not exist.

- [ ] **Step 3: Implement discovery, remote startup, and atomic mirror config**

Implement `sync.zsh` with `set -euo pipefail` and injectable defaults:

```zsh
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
```

The remote probe must first call `herdr workspace list`; if unavailable, start `herdr server` with redirected stdin/stdout/stderr, wait up to ten seconds, and print only marker-delimited workspace JSON. Use Productor's resilient SSH shape:

```zsh
ssh_args=(-S none -o ControlMaster=no -o BatchMode=yes -o ConnectTimeout=10 \
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3)
```

Generate deterministic TOML in sorted devbox-name order:

```toml
poll_seconds = 60
close_remote_on_local_close = true
always_control = true

[hosts."alpha"]
target = "devbox-alpha"
prefix = "alpha"
```

Resolve the installed mirror executable from `herdr plugin list --json`, with `HERDR_DEVBOX_MIRROR_BIN` as a test override. When the host config changes, synchronously run the mirror binary's `teardown` against the old config, atomically replace the config, and run `start` for a nonempty host set. Do not invoke asynchronous Herdr plugin actions for this transition.

- [ ] **Step 4: Run discovery tests**

Run:

```zsh
zsh work/herdr-devboxes/test.zsh
zsh -n work/herdr-devboxes/sync.zsh work/herdr-devboxes/test.zsh
```

Expected: all assertions pass and both files parse successfully.

- [ ] **Step 5: Commit discovery and mirror lifecycle**

```zsh
git add work/herdr-devboxes/sync.zsh work/herdr-devboxes/test.zsh
git commit -m "Add Herdr devbox reconciler"
```

### Task 2: Add timestamp-based safe cleanup

**Files:**
- Modify: `work/herdr-devboxes/sync.zsh`
- Modify: `work/herdr-devboxes/test.zsh`

- [ ] **Step 1: Add failing cleanup tests**

Extend the harness with these exact state transitions:

```zsh
set_workspace_count alpha 1
run_sync 1000
set_workspace_count alpha 0
run_sync 2000
assert_json "$state" '.devboxes.alpha.empty_since == 2000'
run_sync 88399
assert_yc_not_called 'stop --remote --name=alpha'
run_sync 88400
assert_yc_called 'stop --remote --name=alpha'
assert_yc_not_called '--force'
```

Also make fake `yc stop` fail and assert that the host remains configured, `cleanup_attempted_at` is recorded, no retry occurs at 3,599 seconds, a retry occurs at 3,600 seconds, and an unreachable SSH probe never starts or advances `empty_since`.

- [ ] **Step 2: Run the cleanup tests and verify they fail**

Run:

```zsh
zsh work/herdr-devboxes/test.zsh
```

Expected: FAIL because cleanup state and `yc stop` are not implemented.

- [ ] **Step 3: Implement timestamp state transitions**

Persist this atomic JSON shape:

```json
{
  "fleet_synced_at": 1000,
  "devboxes": {
    "alpha": {
      "workspace_seen_at": 1000,
      "empty_since": null,
      "cleanup_attempted_at": null
    }
  }
}
```

For reachable boxes, a positive workspace count updates `workspace_seen_at` and clears both cleanup timestamps. Zero workspaces sets `empty_since` only when `workspace_seen_at` already exists. Once the 24-hour deadline passes, run this exact safe command with no stdin:

```zsh
"$YC_BIN" stop --remote "--name=$name" </dev/null
```

Never add `--force`. Record every attempt before invocation. Remove a successfully stopped box from the desired mirror host set for the current run. Preserve timestamps for unreachable boxes, and prune state only for names absent from a successfully parsed registry.

- [ ] **Step 4: Run all reconciler tests**

```zsh
zsh work/herdr-devboxes/test.zsh
zsh -n work/herdr-devboxes/sync.zsh work/herdr-devboxes/test.zsh
```

Expected: all discovery, retry, unreachable-host, and cleanup assertions pass.

- [ ] **Step 5: Commit cleanup behavior**

```zsh
git add work/herdr-devboxes/sync.zsh work/herdr-devboxes/test.zsh
git commit -m "Safely retire idle Herdr devboxes"
```

### Task 3: Add and link the LaunchAgent

**Files:**
- Create: `work/herdr-devboxes/com.benguillet.herdr-devbox-sync.plist`
- Modify: `work/scripts/Rakefile`

- [ ] **Step 1: Add a failing symlink expectation**

Extend `test.zsh` to read `work/scripts/Rakefile` and assert it names both live destinations:

```zsh
grep -q '~/.local/bin/herdr-devbox-sync' work/scripts/Rakefile
grep -q '~/Library/LaunchAgents/com.benguillet.herdr-devbox-sync.plist' work/scripts/Rakefile
```

Run `zsh work/herdr-devboxes/test.zsh`; expect failure because the links do not exist in the Rake task.

- [ ] **Step 2: Create the LaunchAgent plist**

Create a plist with label `com.benguillet.herdr-devbox-sync`, `RunAtLoad` enabled, `StartInterval` set to `60`, and this executable:

```xml
<array>
  <string>/Users/ben/.local/bin/herdr-devbox-sync</string>
</array>
```

Set `PATH` to `/Users/ben/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`, and send stdout/stderr to `/Users/ben/Library/Logs/herdr-devbox-sync.log`.

- [ ] **Step 3: Extend the Rake symlink task**

Add idempotent directory creation and links rooted at `work/herdr-devboxes`:

```ruby
herdr_devboxes_root = "#{__dir__.chomp('/scripts')}/herdr-devboxes"
sh "mkdir -p ~/.local/bin ~/Library/LaunchAgents"
sh "ln -sfn #{herdr_devboxes_root}/sync.zsh ~/.local/bin/herdr-devbox-sync"
sh "ln -sfn #{herdr_devboxes_root}/com.benguillet.herdr-devbox-sync.plist ~/Library/LaunchAgents/com.benguillet.herdr-devbox-sync.plist"
```

- [ ] **Step 4: Validate tests and configuration syntax**

Run:

```zsh
zsh work/herdr-devboxes/test.zsh
zsh -n work/herdr-devboxes/sync.zsh work/herdr-devboxes/test.zsh
ruby -c work/scripts/Rakefile
plutil -lint work/herdr-devboxes/com.benguillet.herdr-devbox-sync.plist
```

Expected: tests pass, Ruby reports `Syntax OK`, and `plutil` reports `OK`.

- [ ] **Step 5: Commit the LaunchAgent integration**

```zsh
git add work/herdr-devboxes/com.benguillet.herdr-devbox-sync.plist work/scripts/Rakefile work/herdr-devboxes/test.zsh
git commit -m "Run Herdr devbox sync with launchd"
```

### Task 4: Install and verify the live integration

**Files:**
- Runtime: `~/.config/herdr-mirror/hosts.toml`
- Runtime: `~/.local/state/herdr-devboxes/state.json`
- Runtime: `~/Library/LaunchAgents/com.benguillet.herdr-devbox-sync.plist`

- [ ] **Step 1: Install upstream herdr-mirror**

```zsh
herdr plugin install nikok6/herdr-mirror -y
herdr server reload-config
```

Expected: plugin list shows enabled plugin id `mirror` and no warnings.

- [ ] **Step 2: Create live symlinks**

```zsh
rake -f work/scripts/Rakefile symlinks
readlink ~/.local/bin/herdr-devbox-sync
readlink ~/Library/LaunchAgents/com.benguillet.herdr-devbox-sync.plist
```

Expected: both targets resolve beneath `/Users/ben/Work/dotfiles/work/herdr-devboxes/`.

- [ ] **Step 3: Load and kick the LaunchAgent**

```zsh
launchctl bootout "gui/$(id -u)/com.benguillet.herdr-devbox-sync" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.benguillet.herdr-devbox-sync.plist
launchctl kickstart -k "gui/$(id -u)/com.benguillet.herdr-devbox-sync"
```

Expected: `launchctl print` reports the job and its latest exit status is zero.

- [ ] **Step 4: Verify current devboxes and idempotence**

Run the reconciler once directly, inspect `hosts.toml`, verify `devbox-herdr` and `devbox-paxel-revamp`, and run it a second time:

```zsh
~/.local/bin/herdr-devbox-sync
~/.local/bin/herdr-devbox-sync
herdr plugin list --json
```

Expected: both hosts are configured, the stopped Paxel Herdr server is started, the mirror plugin stays enabled, and the second run does not teardown/restart mirrors.

- [ ] **Step 5: Run final verification**

```zsh
zsh work/herdr-devboxes/test.zsh
zsh -n work/herdr-devboxes/sync.zsh work/herdr-devboxes/test.zsh
ruby -c work/scripts/Rakefile
plutil -lint work/herdr-devboxes/com.benguillet.herdr-devbox-sync.plist
git diff --check
git status --short
```

Expected: all checks pass; only the user's pre-existing unrelated changes remain outside this feature's commits.
