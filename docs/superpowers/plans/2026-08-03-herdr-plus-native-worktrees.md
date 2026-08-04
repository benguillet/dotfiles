# Herdr Plus Native Worktrees Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Herdr Plus worktree selections initialize through Worktrunk hooks and launch only Codex for Code, Paxel, Infra, and ETL.

**Architecture:** Keep stock Herdr and Herdr Plus. Herdr creates generated-name worktrees through the existing `ctrl+g` project-picker path; repo-specific Herdr Plus layouts run the global Worktrunk `pre-start` hook, load the approved direnv environment, and replace the root pane with Codex.

**Tech Stack:** Herdr TOML, Herdr Plus worktree layouts, Worktrunk hooks, zsh, direnv

---

### Task 1: Add a configuration regression test

**Files:**
- Create: `work/scripts/test-herdr-plus-worktrees.zsh`

- [ ] **Step 1: Write the failing test**

```zsh
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```zsh
zsh work/scripts/test-herdr-plus-worktrees.zsh
```

Expected: nonzero exit because Code and Paxel still include lazygit, Infra and ETL layouts are absent, and `prefix+shift+n` is not committed as a Herdr Plus action.

- [ ] **Step 3: Commit the failing test**

```zsh
git add work/scripts/test-herdr-plus-worktrees.zsh
git commit -m "Test Herdr Plus worktree setup"
```

### Task 2: Configure initialized Codex-only worktrees

**Files:**
- Modify: `work/.config/herdr/config.toml`
- Modify: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/code.toml`
- Modify: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/paxel.toml`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/infra.toml`
- Create: `work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/etl.toml`

- [ ] **Step 1: Bind new-space to Herdr Plus Projects**

Add this command to `work/.config/herdr/config.toml`, keeping the existing `prefix+up` binding:

```toml
[[keys.command]]
key = "prefix+shift+n"
type = "plugin_action"
command = "cloudmanic.herdr-plus.projects"
description = "herdr-plus: projects"
```

Do not add a `prefix+shift+g` custom command; leaving it absent restores Herdr's native worktree shortcut.

- [ ] **Step 2: Replace all four worktree layouts**

`code.toml`:

```toml
repo = "code"

[[tabs]]
name = "codex"
command = "wt hook pre-start && exec direnv exec . codex"
```

`paxel.toml`:

```toml
repo = "paxel"

[[tabs]]
name = "codex"
command = "wt hook pre-start && exec direnv exec . codex"
```

`infra.toml`:

```toml
repo = "infra"

[[tabs]]
name = "codex"
command = "wt hook pre-start && exec direnv exec . codex"
```

`etl.toml`:

```toml
repo = "etl"

[[tabs]]
name = "codex"
command = "wt hook pre-start && exec direnv exec . codex"
```

- [ ] **Step 3: Run the focused test to verify it passes**

Run:

```zsh
zsh work/scripts/test-herdr-plus-worktrees.zsh
```

Expected: exit 0.

- [ ] **Step 4: Validate Herdr and the Worktrunk setup hook**

Run:

```zsh
HERDR_CONFIG_PATH="$PWD/work/.config/herdr/config.toml" herdr config check
zsh work/scripts/test-worktrunk-hooks.zsh
```

Expected: `config: ok`; the Worktrunk integration suite exits 0.

- [ ] **Step 5: Commit the configuration**

```zsh
git add work/.config/herdr/config.toml \
  work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/code.toml \
  work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/paxel.toml \
  work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/infra.toml \
  work/.config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees/etl.toml
git commit -m "Initialize Herdr Plus worktrees"
```

### Task 3: Reconcile and activate the live dotfiles configuration

**Files:**
- Modify in the primary checkout: `work/.config/herdr/config.toml`

- [ ] **Step 1: Preserve unrelated dirty config changes during integration**

The primary checkout currently has uncommitted file-viewer bindings in `work/.config/herdr/config.toml`. Preserve those entries. Its final working-tree form must contain both file-viewer commands plus the committed Herdr Plus `prefix+shift+n` command, and must contain neither `worktrunk.open` nor a custom `prefix+shift+g` block.

The final custom-command tail is:

```toml
[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "herdr-file-viewer.open-file-viewer"
description = "open file viewer in split"

[[keys.command]]
key = "prefix+shift+f"
type = "plugin_action"
command = "herdr-file-viewer.open-file-viewer-tab"
description = "open file viewer in tab"

[[keys.command]]
key = "prefix+shift+n"
type = "plugin_action"
command = "cloudmanic.herdr-plus.projects"
description = "herdr-plus: projects"
```

- [ ] **Step 2: Verify the primary checkout after integration**

Run:

```zsh
zsh work/scripts/test-herdr-plus-worktrees.zsh
zsh work/scripts/test-worktrunk-hooks.zsh
herdr config check
```

Expected: all commands exit 0.

- [ ] **Step 3: Reload the running Herdr server**

Run:

```zsh
herdr server reload-config
```

Expected: JSON reports `status: applied` with no diagnostics.
