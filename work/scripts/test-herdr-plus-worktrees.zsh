#!/usr/bin/env zsh
set -euo pipefail

work_root=${0:A:h:h}
herdr_config="$work_root/.config/herdr/config.toml"
layouts_dir="$work_root/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees"
expected_command='command = "wt hook pre-start && exec direnv exec . codex"'

for repo in code paxel infra etl; do
  layout="$layouts_dir/$repo.toml"
  expected=$'repo = "'"$repo"$'"\n\n[[tabs]]\nname = "codex"\n'"$expected_command"

  if [[ ! -f "$layout" ]] || [[ "$(<"$layout")" != "$expected" ]]; then
    print -u2 "invalid Herdr Plus worktree layout: $repo"
    exit 1
  fi
done

if [[ $(rg -F -c 'command = "cloudmanic.herdr-plus.projects"' "$herdr_config") != 2 ]]; then
  print -u2 'expected Herdr Plus Projects on prefix+up and prefix+shift+n'
  exit 1
fi

if ! rg -Fq 'key = "prefix+shift+n"' "$herdr_config"; then
  print -u2 'missing prefix+shift+n Herdr Plus binding'
  exit 1
fi

if rg -Fq 'command = "worktrunk.open"' "$herdr_config" || rg -Fq 'key = "prefix+shift+g"' "$herdr_config"; then
  print -u2 'legacy Worktrunk key override remains'
  exit 1
fi
