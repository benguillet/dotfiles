---
name: save-demo-memo
description: Save useful sprint-demo material into a durable shared folder for later reuse, including exact links and record IDs, screenshots, HTML artifacts, measured results, setup state, and talk tracks. Use when the user says "save this for the demo", "remember this for sprint demos", "add this to demo memory", "save a demo memo", or otherwise wants to preserve work from the current session for the next sprint-planning demo.
---

# Save Demo Memo

Capture what is already useful in the current session so the sprint-demo compiler can
reuse it without repeating research, analytics, setup, or screenshots.

## User's Request

$ARGUMENTS

## Storage

Use this shared root:

```text
/Users/ben/Work/yc/reports/sprints/shared.demos/
└── <sprint-start YYYY-MM-DD>/
    ├── <captured-at UTC>-<slug>.md
    └── <captured-at UTC>-<slug>.assets/
        ├── screenshot.png
        └── artifact.html
```

This root is outside every repository and Conductor worktree. All workspaces share it,
and archiving a workspace cannot remove it.

## Compute the current sprint

Sprint planning ends Wednesday at 11:30 AM Pacific. Use the end of the most recent
planning as the sprint start:

```bash
now_epoch=$(date +%s)
wed_local=$(TZ=America/Los_Angeles date -v-wed -v11H -v30M -v0S '+%Y-%m-%dT%H:%M:%S%z')
wed_epoch=$(TZ=America/Los_Angeles date -j -f '%Y-%m-%dT%H:%M:%S%z' "$wed_local" +%s)
if [ "$wed_epoch" -gt "$now_epoch" ]; then
  wed_local=$(TZ=America/Los_Angeles date -v-wed -v-7d -v11H -v30M -v0S '+%Y-%m-%dT%H:%M:%S%z')
  wed_epoch=$(TZ=America/Los_Angeles date -j -f '%Y-%m-%dT%H:%M:%S%z' "$wed_local" +%s)
fi
SPRINT_START=$(date -u -r "$wed_epoch" '+%Y-%m-%d')
```

Create one memo per capture. Name it with a UTC timestamp through seconds and a short
descriptive slug. Append `-2`, `-3`, and so on if it already exists. Never overwrite or
edit another workspace's memo.

## Capture

1. Preserve the useful material already in context: what changed, why it demos well, a
   concise talk track, exact deep links and record IDs, MR/PR links, measured results with
   their window and source, and any setup needed to reproduce the state.
2. Copy every available local screenshot, HTML artifact, data file, or other reusable
   file into the memo's `.assets` directory. Never move or modify the original. Use
   relative links from the memo.
3. If a browser or attachment tool cannot save its binary output, preserve the source URL
   and state explicitly that the binary was not cached.
4. Do not rerun research, analytics, browser capture, or local setup merely to fill gaps.
   Save what already exists and record missing pieces plainly.
5. Do not store credentials, tokens, cookies, private keys, or raw secret-bearing output.
   Store a safe retrieval note instead.
6. Stop after saving. Do not compile the sprint report.

Use this memo shape, omitting empty sections:

```markdown
---
captured_at: 2026-07-29T22:14:03Z
sprint_start: 2026-07-29
workspace: /absolute/workspace/path
branch: ben/example
---

# Demo title

## Summary

What changed, why it matters, and the concise talk track.

## Links

- [Primary demo](https://example.com/exact/record/123)
- [MR](https://example.com/mr)

## Results

- Metric, value, measurement window, exclusions, and source.

## Reusable assets

- [Screenshot](20260729T221403Z-demo-title.assets/screenshot.png)
- [Artifact](20260729T221403Z-demo-title.assets/artifact.html)

## Setup notes

Any login, record, feature-flag, or local-stack state needed to present it.
```

Return the saved memo path, the assets copied, and any item that could not be cached.
