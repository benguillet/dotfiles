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

command_stanzas=$(awk '
  function emit() {
    if (in_command) print key "\t" command
  }

  {
    line = $0
    sub(/[[:space:]]*#.*/, "", line)
  }

  line ~ /^[[:space:]]*\[\[keys\.command\]\][[:space:]]*$/ {
    emit()
    in_command = 1
    key = command = ""
    next
  }

  line ~ /^[[:space:]]*\[/ {
    emit()
    in_command = 0
    key = command = ""
    next
  }

  in_command && line ~ /^[[:space:]]*key[[:space:]]*=/ {
    sub(/^[^\"]*\"/, "", line)
    sub(/\".*$/, "", line)
    key = line
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

for key in prefix+up prefix+shift+n; do
  expected_stanza="$key"$'\tcloudmanic.herdr-plus.projects'
  key_stanza_count=$(print -r -- "$command_stanzas" | rg -F -c -- "$key"$'\t' || true)
  expected_stanza_count=$(print -r -- "$command_stanzas" | rg -F -x -c -- "$expected_stanza" || true)

  if [[ "$key_stanza_count" != 1 || "$expected_stanza_count" != 1 ]]; then
    print -u2 "expected $key to run cloudmanic.herdr-plus.projects"
    exit 1
  fi
done

if print -r -- "$command_stanzas" | rg -Fq -- $'prefix+shift+g\t'; then
  print -u2 'legacy Worktrunk key override remains'
  exit 1
fi

if print -r -- "$command_stanzas" | rg -Fq -- $'\tworktrunk.open'; then
  print -u2 'legacy Worktrunk key override remains'
  exit 1
fi
