#!/usr/bin/env zsh
set -euo pipefail

repo_url=${HERDR_PLUS_REPO_URL:-git@github.com:benguillet/herdr-plus.git}
checkout=${HERDR_PLUS_CHECKOUT:-$HOME/.config/herdr/local-plugins/herdr-plus}
branch=${HERDR_PLUS_BRANCH:-main}

if [[ -e "$checkout" && ! -d "$checkout/.git" ]]; then
  print -u2 "Herdr Plus checkout is not a Git repository: $checkout"
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

mkdir -p "$checkout/bin"
go -C "$checkout" build -o bin/herdr-plus .
herdr plugin link "$checkout" --enabled
