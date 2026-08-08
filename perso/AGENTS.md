# Personal Agent Instructions

These are user-level instructions that apply across all projects.

## Communication Style

**Always be very concise.** After asking a question or finishing some work,
explain it in simple terms — a short summary, not a detailed writeup. If I want
more details, I will ask for them.

## Shell

I use **zsh**. Adapt shell commands accordingly.

`noclobber` is **unset** in my `~/.zshrc`, so `>` overwrites existing files
without error. You do not need to use `>|` or pre-delete files before
redirecting — just use `>` normally.

## Comments

Default to writing **no comments**. Only add a comment when:

- The **why** is not obvious — from the code itself or from the names of the
  methods/classes being used (a hidden constraint, a workaround for a specific
  bug, a subtle invariant, behavior that would surprise a reader), or
- The code is genuinely **complicated** and a short note materially helps the
  reader follow it.

Do not write comments that restate what the code does — well-named identifiers
already do that. Do not reference the current task, PR, or caller ("used by X",
"added for the Y flow") — those belong in the commit message or PR description,
not the code.

## Prefer Timestamps Over Booleans

When you think you want a boolean (column, attribute, or struct field), what you
really want is usually a **nullable timestamp** (`*_at`): `NULL` == false, set ==
true in the code logic. It costs nothing extra and preserves *when* the thing
became true — invaluable for auditing, debugging, ordering, and reconciliation.
Example: `has_report_at`, not `has_report`.

## Git Branches

Always prefix local branches you create with **`ben/`** (e.g.
`ben/fix-login-redirect`).

## Error Handling

Let exceptions propagate. Do not catch exceptions unless there is a specific,
intentional reason to handle them differently (e.g., translating to a
domain-specific error at a system boundary). Code should fail loudly so
problems are visible immediately, not silently swallowed.
