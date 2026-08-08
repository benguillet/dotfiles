---
name: paxel-privacy-policy
description: Refresh, audit, or publish Paxel privacy-policy reference material from current source. Use for Paxel Privacy Policy, data-handling disclosures, pending disclosure PRs, privacy/FAQ Google Docs, Apply Builder Profile privacy messaging and states, or the opted-in applicant reminder email.
---

# Paxel Privacy Policy

Build a source-backed privacy reference packet without allowing published, proposed, and supporting applicant copy to blur together.

## Workflow

1. Run `ycli --help` before YC-related work.
2. Locate the Paxel repo and YC code monorepo from git remotes; do not trust remembered workspace paths.
3. Fetch remotes without changing the user's branches.
4. Record the exact Paxel `origin/main`, YC code `origin/master`, and pending PR SHAs used.
5. Read [references/sources.md](references/sources.md).
6. From a Paxel checkout that renders `origin/main`, run:

   ```zsh
   bin/rails runner /path/to/paxel-privacy-policy/scripts/collect.rb -- \
     --output .context/paxel-privacy-policy \
     --paxel-ref origin/main \
     --proposed-ref origin/pr-1336 \
     --yc-code-root /path/to/yc-code \
     --yc-ref origin/master
   ```

   Omit `--proposed-ref` when there is no pending disclosure PR. Replace the example ref with the actual reviewed PR ref.
7. Review the staged HTML and source extracts. Pull Apply copy from the extracted TypeScript and Slim files, not from screenshots or memory.
8. Publish or update the requested Google Doc. Prefer an applicable Docs API; use the user's requested signed-in browser when UI formatting, tabs, or images are required.
9. Verify every tab visually and leave the finished document open.

## Truth Rules

- Treat `/privacy` as the binding legal policy.
- Treat `/data-handling` as its technical companion.
- Put unmerged wording in a separate **Proposed** tab with its PR link, SHA, merge status, and Legal gate.
- Never silently promote proposed wording into the current policy.
- Keep exact applicant-facing and email copy exact, including dynamic placeholders.
- Use source code as authority when a canonical screenshot contains older punctuation or CTA text.
- Do not embed policy or FAQ text in this skill; always collect it again.

## Recommended Document Tabs

1. Start Here
2. Privacy Policy
3. Data Handling — Current
4. Data Handling — Proposed, when applicable
5. Paxel FAQ
6. Apply Copy & States
7. Reminder Email

## QA Checklist

- Confirm dates and source links.
- Confirm the Privacy Policy is complete, not summarized.
- Diff current and proposed data handling.
- Confirm every website FAQ is present.
- Confirm Apply states include no account, unknown, account found, linked elsewhere, linked without a report, and linked with a report.
- Confirm the reminder trigger and exact subject/body.
- Check images for stale copy and label them when regeneration is not possible.
- Confirm no repository worktree changes were introduced.

## Resources

- `scripts/collect.rb`: render current policy/FAQ HTML and extract YC-code source files.
- `references/sources.md`: canonical paths, discovery commands, and publication guidance.
