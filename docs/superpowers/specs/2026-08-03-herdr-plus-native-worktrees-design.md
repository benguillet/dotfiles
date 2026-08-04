# Herdr Plus native worktrees design

## Goal

Use the stock Herdr Plus project picker to create initialized worktree workspaces without maintaining a plugin fork.

## Workflow

`prefix+shift+n` and `prefix+up` open Herdr Plus Projects. The user selects Code, Paxel, Infra, or ETL, presses `ctrl+g`, leaves the branch prompt empty, and presses Enter. Herdr creates the worktree with its native generated branch name and opens its workspace.

This config-only approach delegates naming to Herdr. It does not guarantee an animal-only name pool or use Worktrunk as the worktree-creation backend.

## Initialization

Add Herdr Plus worktree layouts for all four repositories. Each layout contains only one `codex` tab whose command runs:

```sh
wt hook pre-start && exec direnv exec . codex
```

The existing global Worktrunk hook copies top-level `.env`, `.env.*`, and `.envrc` files from the primary checkout and runs `direnv allow`. `direnv exec` then loads the approved environment for Codex. A setup failure prevents Codex from starting and remains visible in the pane.

Remove every lazygit tab from these worktree layouts.

## Keybindings

Replace the custom Worktrunk bindings on `prefix+shift+n` and `prefix+shift+g`. Bind `prefix+shift+n` to Herdr Plus Projects; leave `prefix+shift+g` uncustomized so Herdr's native worktree shortcut is available. Keep the existing `prefix+up` Herdr Plus Projects binding.

The Worktrunk plugin may remain installed, but this workflow uses the `wt` CLI only for lifecycle hooks.

## Verification

Validate the Herdr configuration and reload it, verify all four layout files contain only the initialized Codex tab, and exercise the existing Worktrunk integration test to confirm environment copying, direnv approval, and failure handling.
