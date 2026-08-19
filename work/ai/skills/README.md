# Shared skills

Personal Claude Code / Codex skills, versioned in the dotfiles repo
(formerly the separate `ai-setup` repo).

## Wiring

`rake symlinks` (from `work/scripts/`) links every `work/ai/skills/<name>` into both
`~/.claude/skills/<name>` and `~/.codex/skills/<name>`. Both tools follow
symlinked skill directories, so edits here are picked up immediately and the
history lives in this repo. For a single new skill:

```bash
ln -sfn "$PWD/work/ai/skills/<name>" ~/.claude/skills/<name>
ln -sfn "$PWD/work/ai/skills/<name>" ~/.codex/skills/<name>
```

| Skill | What it does |
|---|---|
| [`ai-setup`](ai-setup/SKILL.md) | Meta-skill: how this setup is organized, wired into `~/.claude` and `~/.codex`, and committed — so Claude can "save this to my repo" without rediscovering the conventions. |
| [`draft-spec`](draft-spec/SKILL.md) | Draft a concise, architecture-level design spec from a preceding design discussion, in the standard YC design-spec template. |
| [`factory`](factory/SKILL.md) | Ship a prompt, spec, or approved plan as a fleet of small stacked MRs/PRs through a workflow-native pipeline with adversarial review and browser verification. |
| [`feature-pipeline`](feature-pipeline/SKILL.md) | Run a task folder through the full feature pipeline: triage → sharpen → research → dual plans → critique → implement → review → verify → ship. |
| [`gdoc`](gdoc/SKILL.md) | Publish the latest on-disk version of a spec/plan markdown file to Google Docs and return the link; updates the same Doc in place on republish. |
| [`mockup`](mockup/SKILL.md) | High-fidelity UI mockups matched to the target app's real design tokens, published to a claude.ai/design project and screenshotted. |
| [`paxel-privacy-policy`](paxel-privacy-policy/SKILL.md) | Refresh, audit, or publish Paxel privacy-policy reference material from current source. |
| [`pier70-lunch`](pier70-lunch/SKILL.md) | Weekday office lunch: pick Ben's most likely item, confirm, add it to the shared DoorDash group cart. Has an "arm" mode for the 7:40am cron. |
| [`polling-ticker`](polling-ticker/SKILL.md) | When Ben asks to monitor/poll every `<frequency>`: run a visible ticker — one status line per tick, even unchanged, ending with a loud DONE line. Never a silent background watch. |
| [`review-panel`](review-panel/SKILL.md) | Adversarial review panel over diffs or plan documents: finders per target×axis plus red-teams, then independent refuters verify every finding. |
| [`save-demo-memo`](save-demo-memo/SKILL.md) | Save links, screenshots, artifacts, results, setup state, and talk tracks from the current session into the shared sprint-demo folder. |
| [`sprint-demos`](sprint-demos/SKILL.md) | Build the weekly sprint-planning demo package: collect shipped MRs/PRs, group into features, check prod status, compile adoption analytics, produce demo links, screenshots, and an artifact deck. |
| [`standup`](standup/SKILL.md) | Prepare a concise daily standup from verified GitHub PR, GitLab MR, and Conductor AI-session activity. |
| [`test-apply-locally`](test-apply-locally/SKILL.md) | Start, repair, sign into, and browser-test Apply and its YC Agent chat in the local YC stack. |
| [`work-summary`](work-summary/SKILL.md) | Concise, verified end-of-work handoff report: what shipped, manual steps left, risks, rollback plan, and MR/PR links in safe merge order. |

## Claude config (`work/ai/claude/`)

- `work/ai/claude/statusline.sh` — the status line script. `~/.claude/statusline.sh` is a
  symlink to it, so edits here go live on the next Claude Code interaction.
- `work/ai/claude/settings.json` — a snapshot **copy** of `~/.claude/settings.json`, not a
  symlink: Claude Code rewrites the live file at runtime (`/fast`, `/config`), which
  would keep the repo dirty and its atomic writes could silently replace a symlink.
  Re-sync after meaningful changes:

```bash
cp ~/.claude/settings.json work/ai/claude/settings.json
```

## Setup on a new machine

```bash
git clone git@github.com:benguillet/dotfiles.git ~/Work/dotfiles
cd ~/Work/dotfiles/work/scripts && rake symlinks
cp -n ../ai/claude/settings.json ~/.claude/settings.json  # seed once; Claude Code owns it after
```
