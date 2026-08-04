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
export DIRENV_CONFIG="$XDG_CONFIG_HOME/direnv"
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

primary_env="$sandbox/primary.env"
cp "$repo/.env" "$primary_env"
wt --config "$config_path" -C "$repo" hook pre-start
cmp "$primary_env" "$repo/.env"

dotenv_repo="$sandbox/dotenv-repo"
mkdir -p "$dotenv_repo"
git -C "$dotenv_repo" init -b main
print '.env*' > "$dotenv_repo/.gitignore"
git -C "$dotenv_repo" add .gitignore
git -C "$dotenv_repo" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -m init
print 'BASE_ENV=1' > "$dotenv_repo/.env"
print 'LOCAL_ENV=1' > "$dotenv_repo/.env.local"

dotenv_result=$(wt --config "$config_path" -C "$dotenv_repo" switch --create feature/dotenv --no-cd --format=json)
dotenv_worktree=$(jq -r '.path' <<< "$dotenv_result")
(
  cd "$dotenv_worktree"
  direnv exec . sh -c '[ "$BASE_ENV" = 1 ] && [ "$LOCAL_ENV" = 1 ]'
)
test "$(<"$dotenv_worktree/.envrc")" = $'dotenv_if_exists .env\ndotenv_if_exists .env.local'

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

destination_symlink_repo="$sandbox/destination-symlink-repo"
outside_env="$sandbox/outside.env"
mkdir -p "$destination_symlink_repo"
print 'OUTSIDE_ENV=1' > "$outside_env"
git -C "$destination_symlink_repo" init -b main
print '.env*' > "$destination_symlink_repo/.gitignore"
ln -s "$outside_env" "$destination_symlink_repo/.env"
git -C "$destination_symlink_repo" add .gitignore -f .env
git -C "$destination_symlink_repo" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -m init
rm "$destination_symlink_repo/.env"
print 'BASE_ENV=1' > "$destination_symlink_repo/.env"

wt --config "$config_path" -C "$destination_symlink_repo" switch --create feature/destination-symlink --no-cd
test "$(<"$outside_env")" = 'OUTSIDE_ENV=1'

direnv_failure_repo="$sandbox/direnv-failure-repo"
direnv_stub_dir="$sandbox/direnv-stub"
real_direnv=$(command -v direnv)
mkdir -p "$direnv_failure_repo" "$direnv_stub_dir"
git -C "$direnv_failure_repo" init -b main
git -C "$direnv_failure_repo" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit --allow-empty -m init
print 'export DIRENV_READY=1' > "$direnv_failure_repo/.envrc"
print -rl -- '#!/bin/sh' 'if [ "$1" = allow ] && [ "$2" = . ]; then' '  exit 1' 'fi' "exec \"$real_direnv\" \"\$@\"" > "$direnv_stub_dir/direnv"
chmod +x "$direnv_stub_dir/direnv"

if direnv_failure_output=$(PATH="$direnv_stub_dir:$PATH" wt --config "$config_path" -C "$direnv_failure_repo" switch --create feature/direnv-failure --no-cd 2>&1); then
  print -u2 'expected worktrunk to fail when direnv allow fails'
  exit 1
fi
print -r -- "$direnv_failure_output"
[[ "$direnv_failure_output" == *'pre-start command failed: direnv_allow'* ]]
