#!/usr/bin/env zsh
set -euo pipefail

work_root=${0:A:h:h}
herdr_config="$work_root/.config/herdr/config.toml"
layouts_dir="$work_root/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees"
expected_command='command = "wt hook pre-start && exec direnv exec . codex"'
expected_layouts=(code.toml etl.toml infra.toml paxel.toml)
actual_layouts=("$layouts_dir"/*.toml(N:t))

if [[ "${(j:\n:)actual_layouts}" != "${(j:\n:)expected_layouts}" ]]; then
  print -u2 'invalid Herdr Plus worktree layout set'
  exit 1
fi

for repo in code paxel infra etl; do
  layout="$layouts_dir/$repo.toml"
  expected=$'repo = "'"$repo"$'"\n\n[[tabs]]\nname = "codex"\n'"$expected_command"

  if [[ ! -f "$layout" ]] || [[ "$(<"$layout")" != "$expected" ]]; then
    print -u2 "invalid Herdr Plus worktree layout: $repo"
    exit 1
  fi
done

command_stanzas=$(awk '
  function emit() {
    if (in_command) print key "\t" type "\t" command
  }

  {
    line = $0
    sub(/[[:space:]]*#.*/, "", line)
  }

  line ~ /^[[:space:]]*\[\[keys\.command\]\][[:space:]]*$/ {
    emit()
    in_command = 1
    key = type = command = ""
    next
  }

  line ~ /^[[:space:]]*\[/ {
    emit()
    in_command = 0
    key = type = command = ""
    next
  }

  in_command && line ~ /^[[:space:]]*key[[:space:]]*=/ {
    sub(/^[^\"]*\"/, "", line)
    sub(/\".*$/, "", line)
    key = line
    next
  }

  in_command && line ~ /^[[:space:]]*type[[:space:]]*=/ {
    sub(/^[^\"]*\"/, "", line)
    sub(/\".*$/, "", line)
    type = line
    next
  }

  in_command && line ~ /^[[:space:]]*command[[:space:]]*=/ {
    sub(/^[^\"]*\"/, "", line)
    sub(/\".*$/, "", line)
    command = line
  }

  END {
    emit()
  }
' "$herdr_config")

projects_stanzas=$(
  print -r -- "$command_stanzas" |
    awk -F '\t' '$3 == "cloudmanic.herdr-plus.projects" { print $1 "\t" $2 }' |
    LC_ALL=C sort
)
expected_projects_stanzas=$'prefix+shift+n\tplugin_action\nprefix+up\tplugin_action'

if [[ "$projects_stanzas" != "$expected_projects_stanzas" ]]; then
  print -u2 'expected only prefix+up and prefix+shift+n to run Herdr Plus Projects as plugin_action'
  exit 1
fi

if print -r -- "$command_stanzas" | rg -q -- $'^prefix\\+shift\\+g\t'; then
  print -u2 'legacy Worktrunk key override remains'
  exit 1
fi

if print -r -- "$command_stanzas" | rg -q -- $'\tworktrunk\\.open$'; then
  print -u2 'legacy Worktrunk key override remains'
  exit 1
fi
