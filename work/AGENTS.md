# Personal Agent Instructions

These are user-level instructions that apply across all projects.

## Shell

I use **zsh**. Adapt shell commands accordingly.

`noclobber` is **unset** in my `~/.zshrc`, so `>` overwrites existing files
without error. You do not need to use `>|` or pre-delete files before
redirecting — just use `>` normally.

## Comments

Default to writing **no comments**. Only add a comment when:

- The **why** is not obvious from the code itself (a hidden constraint, a
  workaround for a specific bug, a subtle invariant, behavior that would
  surprise a reader), or
- The code is genuinely **complicated** and a short note materially helps the
  reader follow it.

Do not write comments that restate what the code does — well-named identifiers
already do that. Do not reference the current task, PR, or caller ("used by X",
"added for the Y flow") — those belong in the commit message or PR description,
not the code.

## Error Handling

Never swallow exceptions silently: Let things break when it's unexpected
behavior, we use Sentry to know when such things happen and be aware of edge
cases. Only rescue errors that are expected.

## Local Links for Frontend Work (YC code monorepo)

When doing any frontend work on the YC code monorepo, **always try to give me
clickable local links with the relevant record IDs** so I can open the page and
try the change immediately.

- Build links against the local dev server. **Don't hardcode the host/port** —
  it varies by stack/workspace. Get the base URL with `yc stacks url`.
- Use **real record IDs** from the data involved (e.g. the app, interview,
  company, or user the change touches), not `:id` placeholders. If you don't
  have a concrete ID, query for one (Rails console / DB) rather than emitting a
  template URL.
- Link to the specific page(s) the change affects so I can verify it end to end.


<!-- ycli:start -->
## Using `ycli`

`ycli` is a command line utility for Y Combinator employees and their agents. It exposes important YC-related skills and tools. Run `ycli --help` for a list of skills, tools, and helpful YC-related context. ALWAYS run this when you are asked to perform a YC-related task.
<!-- ycli:end -->
