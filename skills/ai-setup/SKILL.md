---
name: ai-setup
description: Save skills, Claude config, or knowledge docs to Ben's personal ai-setup repo and keep everything wired into ~/.claude. TRIGGER when Ben says "save this to my repo", "add this to ai-setup", "save to my skills repo", "version this", mentions "ai setup" / "ai-setup" in any form, or wants a personal skill, statusline/settings change, or knowledge doc persisted across machines and sessions.
---

# ai-setup — Ben's personal AI tooling repo

**Where:** local checkout `/Users/ben/Work/ai-setup` ↔ private `github.com/benguillet/ai-setup`, default branch `main`. Work directly on `main` — no branches, no PRs.

## Layout

| Path | Contents |
|---|---|
| `skills/<name>/SKILL.md` | Personal Claude Code skills, each symlinked into `~/.claude/skills/<name>` |
| `claude/statusline.sh` | Status line script — the REAL file; `~/.claude/statusline.sh` is a symlink to it |
| `claude/settings.json` | Snapshot copy of `~/.claude/settings.json` (copy, NOT symlink — see below) |
| `brain/` | Durable knowledge docs (architecture/system notes, e.g. `yc-architecture.md`) |
| `docs/` | Misc documentation |
| `tools/` | Helper scripts |

## Wiring rules

- **Skills are symlinked**: `ln -sfn /Users/ben/Work/ai-setup/skills/<name> ~/.claude/skills/<name>`. Always edit the repo copy (the symlink target); never create a sibling real directory in `~/.claude/skills`.
- **`claude/statusline.sh`**: edit the repo file directly — the `~/.claude` symlink picks it up and Claude Code re-reads it on the next interaction. Keep it `/bin/bash` 3.2 compatible (macOS system bash: no `$'\u…'`, use `$'\xHH'` byte escapes).
- **`claude/settings.json` is a copy, not a symlink**, on purpose: Claude Code rewrites `~/.claude/settings.json` at runtime (`/fast` toggles `fastMode`, `/config` changes, etc.), which would constantly dirty the repo, and an atomic-rename write could silently replace a symlink with a plain file. After meaningful settings changes, re-sync with:

  ```bash
  cp ~/.claude/settings.json /Users/ben/Work/ai-setup/claude/settings.json
  ```

## Adding a new skill

1. Create `skills/<name>/SKILL.md` with `name` + `description` frontmatter. The description MUST spell out trigger phrases ("TRIGGER when Ben says …") — that's what makes Claude invoke it.
2. Symlink it: `ln -sfn /Users/ben/Work/ai-setup/skills/<name> ~/.claude/skills/<name>`
3. Add a row to the skills table in `README.md`.
4. Commit + push.

## Saving "this" to the repo

When Ben says "save this to my repo", infer the destination from what "this" is — a skill → `skills/`, Claude config → `claude/`, an architecture/system note → `brain/`, a helper script → `tools/` — place it, wire the symlink if applicable, update the README when adding a skill, then commit and push in one go. Don't ask which directory unless it's genuinely ambiguous.

## Committing and pushing

- The repo has local `user.email = 766416+benguillet@users.noreply.github.com`. GitHub email-privacy protection rejects pushes that embed the real email (GH007) — never override this config.
- Other sessions may leave uncommitted files behind: run `git status` first and stage only the files you touched, by path.
- End commit messages with the standard `Co-Authored-By: Claude …` footer per global instructions.
- Push to `main` immediately after committing.
- If using `gh` from a YC monorepo workspace, prefix with `GH_HOST=github.com` (the workspace default host is GitLab).

## New machine bootstrap

See "Setup on a new machine" in `README.md` — clone, symlink all skills, symlink `claude/statusline.sh`, and seed `~/.claude/settings.json` from the snapshot with `cp -n`.
