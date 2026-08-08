# Herdr Worktrunk Hooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Copy primary-checkout environment files and approve direnv whenever Worktrunk creates a worktree.

**Architecture:** Store a global Worktrunk `pre-start` pipeline in work dotfiles. The first step copies only top-level environment files; the second conditionally approves `.envrc`, preserving ordering without copying other ignored data. The existing dotfiles symlink task installs the config into `~/.config/worktrunk/config.toml`.

**Tech Stack:** Worktrunk TOML hooks, zsh, direnv, Git, Rake

---

### Task 1: Add an integration test for worktree initialization

**Files:**
- Create: `work/scripts/test-worktrunk-hooks.zsh`

- [ ] **Step 1: Write the failing integration test**

```zsh
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```zsh
zsh work/scripts/test-worktrunk-hooks.zsh
```

Expected: nonzero exit because `work/.config/worktrunk/config.toml` does not exist.

- [ ] **Step 3: Commit the failing test**

```zsh
git add work/scripts/test-worktrunk-hooks.zsh
git commit -m "Test Worktrunk environment setup"
```

### Task 2: Configure global Worktrunk creation hooks

**Files:**
- Create: `work/.config/worktrunk/config.toml`
- Modify: `work/scripts/Rakefile:203`

- [ ] **Step 1: Add the sequential hook pipeline**

Create `work/.config/worktrunk/config.toml`:

```toml
[[pre-start]]
copy_env = """
find {{ primary_worktree_path }} -maxdepth 1 -type f \\( -name '.env' -o -name '.env.*' -o -name '.envrc' \\) -exec cp -p {} . \\;
"""

[[pre-start]]
direnv_allow = "if [ -f .envrc ]; then direnv allow .; fi"
```

- [ ] **Step 2: Add safe symlink installation**

Add this after the existing direnv symlink in `work/scripts/Rakefile`:

```ruby
  worktrunk_config = File.expand_path("~/.config/worktrunk/config.toml")
  if File.exist?(worktrunk_config) && !File.symlink?(worktrunk_config)
    raise "#{worktrunk_config} exists and is not a symlink"
  end

  sh "mkdir -p ~/.config/worktrunk"
  sh "ln -sfn #{__dir__.chomp('/scripts')}/.config/worktrunk/config.toml #{worktrunk_config}"
```

- [ ] **Step 3: Validate syntax before installing**

Run:

```zsh
ruby -c work/scripts/Rakefile
wt --config work/.config/worktrunk/config.toml -C /Users/ben/Work/yc/code hook show
```

Expected: Ruby reports `Syntax OK`; Worktrunk lists `copy_env` and `direnv_allow` as sequential `pre-start` hooks.

- [ ] **Step 4: Run the symlink task**

Run:

```zsh
cd work/scripts && rake symlinks
```

Expected: `~/.config/worktrunk/config.toml` becomes a symlink to the tracked dotfiles config without disturbing the existing Herdr symlinks.

- [ ] **Step 5: Run the integration test to verify it passes**

Run:

```zsh
zsh work/scripts/test-worktrunk-hooks.zsh
```

Expected: exit 0 after both environment files and `.envrc` are copied and direnv accepts the new worktree.

- [ ] **Step 6: Verify the live configuration**

Run:

```zsh
readlink ~/.config/worktrunk/config.toml
wt -C /Users/ben/Work/yc/code hook show
```

Expected: the link targets `/Users/ben/Work/dotfiles/work/.config/worktrunk/config.toml`; Worktrunk shows both ordered hooks from the live user config.

- [ ] **Step 7: Commit the implementation**

```zsh
git add work/.config/worktrunk/config.toml work/scripts/Rakefile
git commit -m "Initialize Worktrunk environments"
```
