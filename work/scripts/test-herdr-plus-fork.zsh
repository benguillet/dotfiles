#!/usr/bin/env zsh
set -euo pipefail

work_root=${0:A:h:h}
plugin_config="$work_root/.config/herdr/plugins/config/cloudmanic.herdr-plus/config.toml"
installer="$work_root/scripts/install-herdr-plus.zsh"
rakefile="$work_root/scripts/Rakefile"
brewfile="$work_root/scripts/Brewfile.erb"
expected_config=$'[worktree]\nbranch_prefix = "ben/"\ncreate_base = "remote"'

if [[ "$(<"$plugin_config")" != "$expected_config" ]]; then
  print -u2 'invalid Herdr Plus fork config'
  exit 1
fi

if [[ ! -x "$installer" ]]; then
  print -u2 'Herdr Plus fork installer is missing or not executable'
  exit 1
fi

if ! rg -Fq 'git@github.com:benguillet/herdr-plus.git' "$installer"; then
  print -u2 'Herdr Plus fork installer uses the wrong repository'
  exit 1
fi

if ! rg -Fq 'task :herdr_plus do' "$rakefile" || ! rg -Fq 'install-herdr-plus.zsh' "$rakefile"; then
  print -u2 'Rakefile does not expose the Herdr Plus fork installer'
  exit 1
fi

for dependency in herdr go; do
  if ! rg -Fq "brew \"${dependency}\"" "$brewfile"; then
    print -u2 "Brewfile is missing $dependency"
    exit 1
  fi
done

print 'Herdr Plus fork dotfiles tests passed'
