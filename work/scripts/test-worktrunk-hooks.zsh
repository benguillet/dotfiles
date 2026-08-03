#!/usr/bin/env zsh
set -euo pipefail

script_dir=${0:A:h}
config_path=${script_dir:h}/.config/worktrunk/config.toml
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

export XDG_CONFIG_HOME="$sandbox/config"
export XDG_DATA_HOME="$sandbox/data"

repo="$sandbox/repo"
mkdir -p "$repo"
git -C "$repo" init -b main
print 'tracked' > "$repo/README.md"
print '.env*' > "$repo/.gitignore"
git -C "$repo" add README.md .gitignore
git -C "$repo" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -m init

print 'BASE_ENV=1' > "$repo/.env"
print 'LOCAL_ENV=1' > "$repo/.env.local"
print 'export DIRENV_READY=1' > "$repo/.envrc"

result=$(wt --config "$config_path" -C "$repo" switch --create feature/test --no-cd --format=json)
worktree=$(jq -r '.path' <<< "$result")

cmp "$repo/.env" "$worktree/.env"
cmp "$repo/.env.local" "$worktree/.env.local"
cmp "$repo/.envrc" "$worktree/.envrc"

(
  cd "$worktree"
  direnv export json >/dev/null
)
