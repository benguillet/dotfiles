#!/usr/bin/env zsh
set -euo pipefail

script_dir=${0:A:h}
config_path=${script_dir:h}/.config/worktrunk/config.toml
sandbox_root=$(mktemp -d)
sandbox="$sandbox_root/worktrunk hook test"
mkdir -p "$sandbox"
trap 'rm -rf "$sandbox_root"' EXIT

export XDG_CONFIG_HOME="$sandbox/config"
export XDG_DATA_HOME="$sandbox/data"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

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
chmod 640 "$repo/.env.local"
touch -t 202401020304.05 "$repo/.env.local"

result=$(wt --config "$config_path" -C "$repo" switch --create feature/test --no-cd --format=json)
worktree=$(jq -r '.path' <<< "$result")

cmp "$repo/.env" "$worktree/.env"
cmp "$repo/.env.local" "$worktree/.env.local"
cmp "$repo/.envrc" "$worktree/.envrc"
test "$(stat -f '%Lp %m' "$repo/.env.local")" = "$(stat -f '%Lp %m' "$worktree/.env.local")"

(
  cd "$worktree"
  direnv export json >/dev/null
)

failed_copy_repo="$sandbox/failed-copy-repo"
mkdir -p "$failed_copy_repo"
git -C "$failed_copy_repo" init -b main
git -C "$failed_copy_repo" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit --allow-empty -m init
print 'BASE_ENV=1' > "$failed_copy_repo/.env"
chmod 000 "$failed_copy_repo/.env"

if wt --config "$config_path" -C "$failed_copy_repo" switch --create feature/copy-failure --no-cd; then
  print -u2 'expected worktrunk to fail when copying an unreadable environment file'
  exit 1
fi
