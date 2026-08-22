---
name: linear-ticket
description: >
  Create a Linear ticket in Ben's workspace via Chrome browser automation,
  defaulting to his private "Ben Personal" team, optionally cross-linking a
  GitLab MR / GitHub PR both ways. TRIGGER when Ben says "make a linear
  ticket", "create a ticket on my ben team", "add this to linear", "file a
  linear issue", "ticket this", or any variation of wanting work captured as
  a Linear issue — including "and link the MR to it".
---

# linear-ticket — file a Linear issue on Ben's board

Creates a Linear issue through the browser (Linear's UI, not an API key), in
the **Ben Personal** private team by default, and cross-links any related
MR/PR in both directions.

## Inputs to infer from the conversation

- **Title**: short, imperative, specific. If the session just shipped
  something, describe the work item, not the session.
- **Description**: 3 parts, keep it scannable:
  1. one-line *why/context*,
  2. what already happened (link MRs/PRs/docs inline — Linear auto-links raw
     URLs),
  3. what's left / follow-ups as bullets.
- **Team**: `Ben Personal` (key `BEN`, has a lock icon) unless Ben names
  another team (e.g. "App Ops").
- **MR/PR to link**: whatever this session created or Ben points at.

## Procedure

1. Invoke the `claude-in-chrome` skill, then load the browser tools in ONE
   ToolSearch call (`tabs_context_mcp, navigate, computer, read_page,
   tabs_create_mcp, tabs_close_mcp, find, form_input`).
2. `tabs_context_mcp {createIfEmpty: true}`, then navigate the session tab to
   `https://linear.app` — Ben is already signed into the `ycm` workspace. Do
   NOT reuse his existing Linear tabs.
3. In the left sidebar under "Your teams", click **Ben Personal → Issues**
   (this sets the composer's default team), then press **`c`** to open the
   new-issue composer.
4. Screenshot and confirm the composer header shows `BEN 🔒`. If it shows a
   different team, click the team chip and pick Ben Personal before typing.
5. Type the title, press **Tab**, type the description. Type plain text with
   raw URLs — Linear auto-links them; don't attempt markdown link syntax.
   Note: leading `- ` inside typed lines becomes nested bullets; just start
   lines with the text or use `•`-free plain lines if nesting looks wrong.
6. Click **Create issue**. Screenshot; the confirmation toast bottom-right
   gives the issue ID (e.g. `BEN-217`). The canonical URL is
   `https://linear.app/ycm/issue/<ID>`.
7. Cross-link back from the code side (no browser needed):
   - GitLab MR: `glab mr note create <MR_IID> -m "Linear: <issue URL>"`
   - GitHub PR: `GH_HOST=github.com gh pr comment <N> --body "Linear: <url>"`
8. Close the tab you created (`tabs_close_mcp`).
9. Report: issue ID + URL, team, and what was cross-linked.

## Gotchas

- **Do not press `c` from the Agent/chat page** — make sure a team view is
  focused first, otherwise the composer may default to the wrong team.
- The composer's fade-out animation lingers after Create; verify creation by
  the toast / the new row in the list, and never click Create twice.
- One toast = one issue. If the backlog count moves by more than one, check
  the list for a duplicate before assuming.
- Keyboard shortcut `cmd+enter` also submits the composer; the Create issue
  button is fine too.
- Ben's Linear workspace slug is `ycm`; teams seen there: Ben Personal
  (private), App Ops, Y Combinator.
