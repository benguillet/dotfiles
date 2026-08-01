# Herdr dotfiles design

## Goal

Keep Herdr and plugin configuration in work dotfiles so changes are tracked automatically, while keeping secrets local.

## Layout

- Store Herdr's main config at `work/.config/herdr/config.toml`.
- Store the complete plugin config tree at `work/.config/herdr/plugins/config/`.
- Symlink both locations from `~/.config/herdr/`.
- Add both symlinks to the existing work `rake symlinks` task.
- Ignore `*.env` beneath the plugin config tree so provider credentials remain local.

## Herdr behavior

- Keep Projects bound to `prefix+up`.
- Bind Quick Actions to `prefix+down`.
- Define Code, Paxel, Infra, and ETL project templates using their paths under `~/Work/yc`.
- Open only a Codex tab for each project.
- Leave worktree layouts unchanged.

## Migration

Copy the current config into dotfiles, preserve the existing local `provider.env`, replace the live config paths with symlinks, and reload Herdr.

## Verification

Confirm the symlink targets, verify the four project templates contain no lazygit tab, validate both keybindings, ensure the provider file is ignored by Git, and reload the running Herdr server successfully.
