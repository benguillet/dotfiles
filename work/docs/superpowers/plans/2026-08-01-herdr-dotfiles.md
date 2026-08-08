# Herdr Dotfiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Herdr's durable configuration into work dotfiles, add the requested projects and Quick Actions shortcut, and keep plugin secrets local.

**Architecture:** Dotfiles owns the main Herdr config file and the full plugin-config directory. The live Herdr paths symlink to those locations, while a recursive `*.env` ignore rule keeps credential-bearing plugin files local and untracked.

**Tech Stack:** TOML, Ruby/Rake, Unix symlinks, Git, Herdr CLI

---

### Task 1: Add the Herdr configuration tree

**Files:**
- Create: `work/.config/herdr/config.toml`
- Create: `work/.config/herdr/plugins/config/.gitignore`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/config.toml`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/code.toml`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/paxel.toml`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/infra.toml`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/etl.toml`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/code.toml`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/paxel.toml`

- [ ] **Step 1: Add the main config**

Create the file with the current settings and both keybindings:

```toml
[ui.toast]
delivery = "system"

[ui]
show_agent_labels_on_pane_borders = false

agent_panel_sort = "spaces"
[experimental]
pane_history = false

[theme]
name = "gruvbox"
auto_switch = false

[[keys.command]]
key = "prefix+up"
type = "plugin_action"
command = "cloudmanic.herdr-plus.projects"
description = "herdr-plus: projects"

[[keys.command]]
key = "prefix+down"
type = "plugin_action"
command = "cloudmanic.herdr-plus.quick-actions"
description = "herdr-plus: quick actions"
```

- [ ] **Step 2: Protect local secrets**

Create `work/.config/herdr/plugins/config/.gitignore` with:

```gitignore
*.env
```

- [ ] **Step 3: Add the Plus project templates**

Create `code.toml`:

```toml
name = "Code"
description = "YC code monorepo"
group = "YC"
working_dir = "/Users/ben/Work/yc/code"

[[tabs]]
name = "codex"
command = "codex"
```

Create `paxel.toml`:

```toml
name = "Paxel"
description = "YC Paxel"
group = "YC"
working_dir = "/Users/ben/Work/yc/paxel"

[[tabs]]
name = "codex"
command = "codex"
```

Create `infra.toml`:

```toml
name = "Infra"
description = "YC infrastructure"
group = "YC"
working_dir = "/Users/ben/Work/yc/infra"

[[tabs]]
name = "codex"
command = "codex"
```

Create `etl.toml`:

```toml
name = "ETL"
description = "YC ETL"
group = "YC"
working_dir = "/Users/ben/Work/yc/etl"

[[tabs]]
name = "codex"
command = "codex"
```

- [ ] **Step 4: Preserve Plus worktree behavior**

Create the Plus global config:

```toml
[worktree]
branch_prefix = "ben/"
```

Create `worktrees/code.toml`:

```toml
repo = "code"

[[tabs]]
name = "codex"
command = "codex"

[[tabs]]
name = "lazygit"
command = "lazygit"
```

Create `worktrees/paxel.toml`:

```toml
repo = "paxel"

[[tabs]]
name = "codex"
command = "codex"

[[tabs]]
name = "lazygit"
command = "lazygit"
```

- [ ] **Step 5: Inspect the staged diff**

Run:

```bash
git -C ~/Work/dotfiles diff -- work/.config/herdr
git -C ~/Work/dotfiles status --short
```

Expected: the Herdr tree is new; the user's existing modifications remain unstaged and unchanged.

- [ ] **Step 6: Commit the configuration tree**

```bash
git -C ~/Work/dotfiles add work/.config/herdr
git -C ~/Work/dotfiles commit -m "Track Herdr configuration"
```

### Task 2: Add bootstrap symlinks

**Files:**
- Modify: `work/scripts/Rakefile`

- [ ] **Step 1: Extend the symlinks task**

After the existing direnv symlink, add:

```ruby
  herdr_config_root = "#{__dir__.chomp('/scripts')}/.config/herdr"
  herdr_plugin_config = File.expand_path("~/.config/herdr/plugins/config")
  if File.exist?(herdr_plugin_config) && !File.symlink?(herdr_plugin_config)
    raise "#{herdr_plugin_config} exists and is not a symlink"
  end

  sh "mkdir -p ~/.config/herdr/plugins"
  sh "ln -sfn #{herdr_config_root}/config.toml ~/.config/herdr/config.toml"
  sh "ln -sfn #{herdr_config_root}/plugins/config #{herdr_plugin_config}"
```

- [ ] **Step 2: Check Ruby syntax**

Run:

```bash
ruby -c ~/Work/dotfiles/work/scripts/Rakefile
```

Expected: `Syntax OK`.

- [ ] **Step 3: Inspect and commit only the Rakefile**

```bash
git -C ~/Work/dotfiles diff -- work/scripts/Rakefile
git -C ~/Work/dotfiles add work/scripts/Rakefile
git -C ~/Work/dotfiles commit -m "Link Herdr config from work dotfiles"
```

### Task 3: Migrate the live configuration

**Files:**
- Preserve locally: `~/.config/herdr/plugins/config/tab-smart-rename/provider.env`
- Replace with symlink: `~/.config/herdr/config.toml`
- Replace with symlink: `~/.config/herdr/plugins/config`

- [ ] **Step 1: Copy the ignored provider file into the dotfiles-backed tree**

```bash
mkdir -p ~/Work/dotfiles/work/.config/herdr/plugins/config/tab-smart-rename
install -m 0600 ~/.config/herdr/plugins/config/tab-smart-rename/provider.env ~/Work/dotfiles/work/.config/herdr/plugins/config/tab-smart-rename/provider.env
git -C ~/Work/dotfiles check-ignore work/.config/herdr/plugins/config/tab-smart-rename/provider.env
```

Expected: `git check-ignore` prints the provider file path.

- [ ] **Step 2: Replace the live main config with its symlink**

```bash
ln -sfn ~/Work/dotfiles/work/.config/herdr/config.toml ~/.config/herdr/config.toml
```

- [ ] **Step 3: Replace the live plugin-config directory with its symlink**

Move the original directory to a temporary backup, then link the dotfiles tree:

```bash
mv ~/.config/herdr/plugins/config /tmp/herdr-plugin-config-pre-dotfiles
ln -s ~/Work/dotfiles/work/.config/herdr/plugins/config ~/.config/herdr/plugins/config
```

- [ ] **Step 4: Run the bootstrap task idempotently**

```bash
rake -f ~/Work/dotfiles/work/scripts/Rakefile symlinks
```

Expected: the task completes successfully and both Herdr symlinks remain intact.

### Task 4: Verify and reload Herdr

**Files:**
- Verify: `~/.config/herdr/config.toml`
- Verify: `~/.config/herdr/plugins/config`

- [ ] **Step 1: Verify symlink targets**

```bash
readlink ~/.config/herdr/config.toml
readlink ~/.config/herdr/plugins/config
```

Expected: both targets resolve beneath `/Users/ben/Work/dotfiles/work/.config/herdr/`.

- [ ] **Step 2: Verify shortcuts and projects**

```bash
rg -n 'prefix\+(up|down)|cloudmanic\.herdr-plus\.(projects|quick-actions)' ~/Work/dotfiles/work/.config/herdr/config.toml
rg -n 'name = "(Code|Paxel|Infra|ETL)"' ~/Work/dotfiles/work/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects
rg -n 'lazygit' ~/Work/dotfiles/work/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects
```

Expected: both bindings and all four projects are present; the final command returns no matches.

- [ ] **Step 3: Verify secret isolation**

```bash
git -C ~/Work/dotfiles status --short
git -C ~/Work/dotfiles check-ignore work/.config/herdr/plugins/config/tab-smart-rename/provider.env
```

Expected: `provider.env` is ignored and absent from Git status; only the user's unrelated pre-existing changes remain.

- [ ] **Step 4: Reload Herdr**

```bash
herdr server reload-config
herdr status server
```

Expected: reload succeeds and the server reports healthy.
