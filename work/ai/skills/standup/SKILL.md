---
name: standup
description: Prepare a concise, paste-ready daily standup from Ben's verified GitHub PR, GitLab MR, and Conductor AI-session activity. TRIGGER when Ben types "/standup" or "$standup", asks "what did I do yesterday", "prepare my standup", or requests a daily work summary from MRs, PRs, and AI sessions.
---

# Standup

Produce a short, first-person standup for the requested date. Default to the
previous calendar day in `America/Los_Angeles`.

## Rules

- Verify all activity from source data. Do not trust memory or branch names.
- Use the half-open Pacific-time interval `[start, next_day)` and convert it to
  UTC for API and database queries.
- Include authored PRs and MRs that Ben created, changed, or merged in the
  interval. Distinguish these actions. Link each item.
- Include review-only activity when the submission time is in the interval.
- Include Conductor sessions with message activity in the interval, including
  sessions that started earlier.
- Derive session outcomes from user prompts and the last visible assistant text.
  Do not treat tool messages or session titles as proof of completion.
- Group related AI sessions by outcome. Separate completed, research, and
  blocked work. Do not repeat the same shipped work in two sections.
- Do not change code, remote items, credentials, or session state.
- Do not create an HTML report or other artifact.
- If a source stays unavailable, state the missing scope in one short note.
- Write only ASD-STE100 Simplified Technical English.

## Gather

1. Run `ycli --help` for this YC task.
2. Calculate the requested Pacific-time start and end as UTC timestamps. Also
   keep both UTC dates because GitHub search accepts calendar dates.
3. Get the GitHub identity with `GH_HOST=github.com gh api user`. Always set
   `GH_HOST=github.com` because YC workspaces can set it to `gitlab.com`.
4. Find authored PR candidates with `gh search prs --author <login> --updated
   <first-utc-date>..<last-utc-date>`. For each candidate, inspect its PR data,
   commits, and timeline. Include it only when Ben created it, merged it, pushed
   to it, or commented on it inside the exact UTC interval.
5. Find review candidates with `gh search prs --reviewed-by <login>`. Inspect
   review `submitted_at` values and keep only reviews inside the interval.
6. Get a temporary GitLab token without printing it:

   ```zsh
   credentials="$(ycli tool get-gitlab-credentials)"
   gitlab_token="$(jq -r '.token' <<< "$credentials")"
   gitlab_username="$(jq -r '.username' <<< "$credentials")"
   ```

   Query the GitLab API with `Authorization: Bearer`. Find authored merge
   requests with `scope=all`, `author_username`, `updated_after`, and
   `updated_before`. Inspect creation, merge, commit, note, and approval times
   before assigning an action to Ben. Use user events to find review-only work.
7. On a local Conductor workspace, read this database in read-only mode:

   ```text
   ~/Library/Application Support/com.conductor.app/conductor.db
   ```

   Join `sessions`, `session_messages`, and `workspaces`. Filter message times
   with `julianday(created_at)` against the UTC boundaries. Do not compare the
   ISO timestamp strings directly because their formats differ. Count active
   sessions, new sessions, and continued sessions.
8. For each active session, inspect the first user prompt in the interval and
   the last visible assistant text. Visible Codex text is in JSON rows where
   `$.type = "assistant"` and `$.message.content[*].type = "text"`. Use later
   user messages when they change the task or show that the result is blocked.
9. If the local database is unavailable, try authenticated `conductor sql`.
   If neither source works, report that the AI-session section is incomplete.

## Write

Use this small structure:

```markdown
## Standup — <Month D>

Yesterday I:

- <completed or shipped outcome with MR/PR link>
- <other important outcome>

AI-assisted work (<count> sessions; <new> new, <continued> continued):

- <grouped outcome>
- <research or support outcome>

Blocker:

- <only a real unresolved blocker; omit this section when none exists>
```

Keep the result ready to paste. Prefer outcomes over implementation detail.
Keep small lookups in the AI section, not in the main headline. If all AI
sessions map to the main outcomes, give only the count and do not repeat them.
