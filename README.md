# ai-setup

Personal AI tooling setup — Claude Code skills and config, versioned.

## Skills

Skills live in `skills/<name>/SKILL.md` and are wired into Claude Code by symlinking
each skill directory into `~/.claude/skills/`:

```bash
ln -s "$PWD/skills/<name>" ~/.claude/skills/<name>
```

Claude Code follows symlinked skill directories, so edits here are picked up
immediately and the history lives in this repo.

| Skill | What it does |
|---|---|
| [`appops-tech-spec`](skills/appops-tech-spec/SKILL.md) | Write a tech spec / design doc following App Ops's standard template (Background → Goal → Scope → Constraints → Design → Monitoring & Tests → Alternatives), grounded in real code references, then publish it as a Google Doc. |
| [`draft-spec`](skills/draft-spec/SKILL.md) | Draft a concise, architecture-level design spec from a preceding design discussion, in the standard YC design-spec template, pitched at a technically competent reader who already knows the system. |
| [`sprint-demos`](skills/sprint-demos/SKILL.md) | Build the weekly sprint-planning demo package: collect shipped GitLab MRs + GitHub PRs, group into demoable features, check prod status, produce prod/local demo links, screenshots, and a claude.ai artifact deck. Paired with the "Sprint demos draft (Tuesday night)" claude.ai routine. |

## Setup on a new machine

```bash
git clone git@github.com:benguillet/ai-setup.git ~/Work/ai-setup
cd ~/Work/ai-setup
for d in skills/*/; do ln -sfn "$PWD/$d" ~/.claude/skills/$(basename "$d"); done
```
