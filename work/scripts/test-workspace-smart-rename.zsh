#!/usr/bin/env zsh
set -euo pipefail

work_root=${0:A:h:h}
installer="$work_root/scripts/install-workspace-smart-rename.zsh"
rakefile="$work_root/scripts/Rakefile"
herdr_config="$work_root/.config/herdr/config.toml"
tool_versions="$work_root/.tool-versions"

if [[ ! -x "$installer" ]]; then
  print -u2 'Workspace Smart Rename installer is missing or not executable'
  exit 1
fi

for expected in \
  'git@github.com:benguillet/herdr-workspace-smart-rename.git' \
  '.config/herdr/local-plugins/workspace-smart-rename' \
  'herdr plugin link "$checkout" --enabled' \
  'node "$checkout/src/cli.ts" set-local' \
  'herdr server reload-config' \
  'node "$checkout/src/cli.ts" start' \
  'node "$checkout/src/cli.ts" once'; do
  if ! rg -Fq "$expected" "$installer"; then
    print -u2 "Workspace Smart Rename installer is missing: $expected"
    exit 1
  fi
done

if rg -Fq 'install-layout' "$installer"; then
  print -u2 'Installer must preserve the dotfiles-backed Herdr config symlink'
  exit 1
fi

if ! rg -Fq 'task :workspace_smart_rename do' "$rakefile" \
  || ! rg -Fq 'install-workspace-smart-rename.zsh' "$rakefile"; then
  print -u2 'Rakefile does not expose the Workspace Smart Rename installer'
  exit 1
fi

if ! rg -Fq '["branch", "git_status"]' "$herdr_config" \
  || ! rg -Fq '["$worktree"]' "$herdr_config" \
  || rg -Fq '["$repo", "branch", "git_status"]' "$herdr_config"; then
  print -u2 'Tracked Herdr sidebar layout is stale'
  exit 1
fi

node_version=$(awk '$1 == "nodejs" { print $2 }' "$tool_versions")
node_major=${node_version%%.*}
if [[ -z "$node_version" || "$node_major" -lt 24 ]]; then
  print -u2 'Workspace Smart Rename requires Node 24 or newer'
  exit 1
fi

print 'Workspace Smart Rename dotfiles tests passed'
