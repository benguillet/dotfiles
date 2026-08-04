#!/usr/bin/env zsh
set -euo pipefail

repo_url=${WORKSPACE_SMART_RENAME_REPO_URL:-git@github.com:benguillet/herdr-workspace-smart-rename.git}
checkout=${WORKSPACE_SMART_RENAME_CHECKOUT:-$HOME/.config/herdr/local-plugins/workspace-smart-rename}
branch=${WORKSPACE_SMART_RENAME_BRANCH:-main}

if [[ -e "$checkout" && ! -d "$checkout/.git" ]]; then
  print -u2 "Workspace Smart Rename checkout is not a Git repository: $checkout"
  exit 1
fi

if [[ -d "$checkout/.git" ]]; then
  git -C "$checkout" remote set-url origin "$repo_url"
  git -C "$checkout" fetch origin "$branch"
  git -C "$checkout" checkout "$branch"
  git -C "$checkout" merge --ff-only "origin/$branch"
else
  mkdir -p "${checkout:h}"
  git clone --branch "$branch" "$repo_url" "$checkout"
fi

node "$checkout/src/cli.ts" stop
herdr plugin link "$checkout" --enabled
node "$checkout/src/cli.ts" set-local
herdr config check
herdr server reload-config
node "$checkout/src/cli.ts" start
node "$checkout/src/cli.ts" once
