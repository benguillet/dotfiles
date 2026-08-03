# Herdr remote devboxes design

## Goal

Show Herdr sessions from every running YC remote devbox in the local Herdr sidebar without manual host configuration, and safely retire unused devboxes after a 24-hour grace period.

## Scope

This is a personal macOS integration stored in work dotfiles. It mirrors only sessions managed by a Herdr server on the devbox. It does not import arbitrary tmux, Codex, or Claude sessions detected by Productor.

## Components

- Install the upstream `nikok6/herdr-mirror` plugin without maintaining a fork.
- Store all integration code beneath `work/herdr-devboxes/`:
  - `sync.zsh`: discovery, remote-server startup, mirror configuration, and cleanup.
  - `com.benguillet.herdr-devbox-sync.plist`: the macOS LaunchAgent definition.
- Extend `work/scripts/Rakefile` to symlink:
  - `sync.zsh` to `~/.local/bin/herdr-devbox-sync`.
  - the plist to `~/Library/LaunchAgents/com.benguillet.herdr-devbox-sync.plist`.
- Generate `~/.config/herdr-mirror/hosts.toml` at runtime. It is machine state and is not tracked in dotfiles.
- Store cleanup state under `~/.local/state/herdr-devboxes/` and logs under `~/Library/Logs/`.

## Discovery and mirroring

The LaunchAgent runs at login and every 60 seconds. Each run:

1. Invokes `yc devbox sync --quiet` at most once every five minutes so devboxes created on another machine are adopted locally and receive `devbox-<name>` SSH aliases. A `fleet_synced_at` timestamp controls this throttle.
2. Reads remote entries from `~/.yc/stacks.json`, matching Productor's local discovery boundary.
3. For every devbox, checks the remote Herdr server over its SSH alias and starts `herdr server` detached when it is not running.
4. Builds a deterministic `hosts.toml` entry whose target is `devbox-<name>`.
5. Atomically replaces `hosts.toml` only when its content changes.
6. Restarts the `herdr-mirror` daemon only after a changed host set so the new configuration is loaded.

The mirror configuration sets `close_remote_on_local_close = true`. Closing a mirrored local workspace or pane therefore closes the corresponding object on the remote Herdr server. Closing the Herdr client itself only detaches and does not close remote work.

## Devbox cleanup

The script tracks `workspace_seen_at`, `empty_since`, and `cleanup_attempted_at` timestamps per devbox. A devbox becomes cleanup-eligible only after the integration has observed at least one remote Herdr workspace on it. This prevents a newly created or intentionally empty devbox from being stopped.

When an eligible devbox has no remaining Herdr workspaces, the script records `empty_since`. A new workspace clears `empty_since`. If the devbox remains empty for 24 hours, the script runs:

```text
yc stop --remote --name=<name>
```

The cleanup never passes `--force`. YC's existing git safety check must approve the stop; dirty files, unpushed commits, detached HEAD state, or an unverifiable workspace prevent destruction. Launchd supplies no interactive input, so a safety prompt aborts instead of approving itself. A blocked cleanup is logged and retried at most once per hour.

## Failure behavior

- Discovery failure preserves the last generated mirror configuration and cleanup state.
- An unreachable devbox does not block healthy devboxes and is not treated as empty.
- A failed remote Herdr startup is logged; `herdr-mirror` and later LaunchAgent runs retry it.
- Unexpected script failures return nonzero and are captured by launchd; the next scheduled run retries.
- Runtime files are written atomically.
- No AWS credentials, SSH keys, or other secrets are written to dotfiles.

## Installation and lifecycle

The initial setup installs `nikok6/herdr-mirror`, runs the dotfiles symlink task, bootstraps the LaunchAgent with `launchctl`, and kicks off an immediate sync. Updating the dotfiles files requires reloading the LaunchAgent. Removing the integration unloads the LaunchAgent and uninstalls or disables `herdr-mirror`; it does not stop remote devboxes.

## Verification

- Validate the plist and zsh syntax.
- Verify both live devboxes are discovered through their existing SSH aliases.
- Verify a stopped remote Herdr server starts automatically.
- Verify remote Herdr workspaces appear in the local sidebar.
- Verify an unchanged run does not rewrite configuration or restart the mirror.
- Verify discovery and SSH failures preserve existing mirrors.
- Verify closing a local mirror closes the remote Herdr workspace.
- Exercise cleanup with a shortened test grace period and a stubbed `yc stop`, confirming that workspace activity cancels cleanup and no command uses `--force`.
- Reload the real LaunchAgent and confirm its latest run exits successfully.
