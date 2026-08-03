# Herdr Worktrunk hooks design

## Goal

Make every Worktrunk-created worktree immediately usable with the primary checkout's environment files and an approved direnv configuration.

## Behavior

Add a global Worktrunk `pre-start` pipeline with two sequential steps:

1. Copy top-level `.env`, `.env.*`, and `.envrc` files from the primary worktree into the new worktree while preserving file metadata.
2. Run `direnv allow` in the new worktree when `.envrc` exists.

The hook applies to every repository managed through Worktrunk. It does not recursively copy ignored files, dependencies, caches, or build artifacts. Missing environment files and repositories without `.envrc` are valid no-ops. Unexpected copy or direnv failures remain visible and fail the hook.

## Storage

Track the user-level Worktrunk config in work dotfiles and symlink it to `~/.config/worktrunk/config.toml`, following the existing Herdr dotfiles pattern.

## Verification

Validate the TOML through Worktrunk, preview the configured hook, and exercise it against a temporary Git repository to confirm environment files are copied before direnv approval.
