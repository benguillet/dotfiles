---
name: draft-spec
description: >-
  Draft a design spec / design doc from a preceding design discussion. Use this whenever
  the user asks to "draft the spec", "write up a spec", "write the design doc", "put together
  a spec", "turn this into a spec", or otherwise wants a design conversation written up as a
  document — even if they don't say the word "spec". Produces a concise, architecture-level
  design doc in the standard YC design-spec template, pitched at a technically competent
  reader who already knows the system. Trigger it after a back-and-forth about what to build
  and how; do not write specs freehand when this skill applies.
---

# Draft a Design Spec

Turn a design discussion into a written spec. This is almost always invoked **after** a
conversation (and often after one or more design docs) has already worked out what to build
and how. Your job is to distill that into a clean, standalone document — not to re-derive the
design.

## Source the content from the conversation

Pull the substance from the preceding discussion and any design artifacts already produced.
Don't invent new design decisions here. If a **material** decision is genuinely unresolved
(not a trivial detail), ask one quick question rather than silently guessing — a spec that
bakes in a wrong assumption is worse than a short pause.

## Audience and altitude — get this right first

Write for a **technically competent reader who already knows the existing system**. They know
the codebase, the domain, and the standard concepts. This determines everything below:

- **Don't explain basics.** No defining common concepts, no quote-wrapped term introductions,
  no contrasting two familiar things at length. Assume fluency.
- **Architecture, not implementation.** Describe *what each piece does, how the pieces fit
  together, and why* — at the level of components and data flow. Do **not** name specific
  classes, methods, functions, columns, or services you intend to create, and don't sketch
  code. That's too low; it belongs in an implementation plan, not the spec.
- **Explain everything; handwave nothing.** Staying high-level is not license to be vague.
  Every mechanism in the design should be explained clearly enough that a reader understands
  how it works and why it's there. "We handle X safely" is not enough — say *how*, in plain
  architectural terms.

## Tone and length — concise and dense

The reader is busy and competent. Cut anything that isn't carrying weight.

- **Front matter is short.** Background, Goal, Why we need this, Scope, and Constraints are a
  few sentences or a tight bullet list each. Background should assume the reader knows the
  current system — reference it in a sentence, don't recap it.
- **Design is the core** and gets the most room — but written as short, focused subsections,
  each on one part of the architecture.
- **No puff.** No throat-clearing, no restating the obvious, no motivational filler, no
  "it's worth noting that." Prefer plain declarative sentences over hedged ones.
- **Plain language over jargon.** When a concept genuinely needs a name, name it once in
  plain words and move on; don't belabor it.
- **Go easy on em dashes.** They're fine occasionally, but don't lean on them as a default
  connector or pepper them through the prose. Reach for a comma, period, colon, or
  parentheses first, and keep em dashes rare enough that each one still feels deliberate.

Tone calibration:

- Too verbose / puffy: *An agent's "system prompt" (its base set of written instructions
  that define how it behaves) and a skill's "instructions" are both, in essence, text that
  can be tested and improved — so we treat them as the same kind of thing.*
- Right: *An agent's system prompt and a skill's instructions are both tunable text; the
  loop is generalized to operate on either.*

## The template

Use this structure (it's the standard YC design-spec template). **Remove any section that
isn't relevant** to the doc rather than padding it.

```
# [Title]

[Author]
[Date]

## Background
## Goal
## Why we need this
## Scope of this doc
## Constraints
## Design
## Monitoring & Tests
## Alternatives considered
    #### Alternative 1
    #### Alternative 2
## Comments
    #### Person 1
    #### Person 2
```

## What goes in each section

- **Background** — the minimum context to orient a reader who knows the system: what exists
  today and the gap. A few sentences. Don't teach the system.
- **Goal** — what we're building, in one or two sentences. The end state, not the steps.
- **Why we need this** — the problem/motivation and the cost of not doing it. Short and
  concrete.
- **Scope of this doc** — what's in scope and, just as importantly, what's explicitly out of
  scope (and why it's separate). Prevents reviewers from re-litigating boundaries.
- **Constraints** — the realities the design must respect (technical, product, operational).
  A tight bullet list. These should justify the non-obvious design choices that follow.
- **Design** — the heart. Break it into short subsections, each covering one component or
  mechanism: what it does, how it connects to the rest, and why it's designed that way.
  Cover the data/decision flow end to end. This is where "explain everything, handwave
  nothing" matters most — but still no class/method/column detail.
- **Monitoring & Tests** — how we'll know it works and stays working: what's monitored, how
  it's validated, regression vs. new-capability coverage, and any scale/safety checks the
  constraints imply.
- **Alternatives considered** — the real forks you weighed. For each: the alternative in a
  sentence, then why it was rejected in a sentence or two. Don't strawman; include the
  genuinely plausible options that were turned down.
- **Comments** — leave the headers as empty placeholders for reviewers (or a one-line note
  inviting comments). Don't fill them in.

Fill in the **Author** from context (default to the user) and **Date** to today.

## UI mockups (when the spec covers user-facing UI)

If the design includes new or changed user-facing UI/UX, invoke the **`/mockup` skill** to
build mockups, publish them to claude.ai/design, and screenshot them. Embed its output
**minimally**: each screenshot inline where that state is described, plus the single
design-project link — no meta-verbiage around them (no canvas/file names, no mockup source
paths, no visual-language notes).

## Process

1. Identify the source material (this conversation + any design docs already written).
2. Resolve any genuinely open material decision with a quick question; otherwise proceed.
3. Draft the spec in the template, applying the audience/altitude/tone rules above.
4. If the spec covers user-facing UI, invoke the `/mockup` skill and embed its output per
   the section above.
5. Re-read it once with fresh eyes and cut: any sentence that explains something the reader
   knows, any handwave that should be a real explanation, any implementation detail that
   crept in, and any padding. Tighten.
6. Save it as a markdown file with a descriptive name. If the repo has a convention for where
   design/plan docs live, follow it; otherwise put it somewhere sensible and tell the user
   the path.
7. When the user wants it in Google Docs (or asks to publish/share it), invoke the `/gdoc`
   skill — it publishes the latest saved version and returns the link. Note: Drive's
   markdown import fails on local image references — see the gdoc-image-splice memory for
   the placeholder + Docs-API procedure that preserves embedded screenshots.

## What good looks like

A reader who knows the system can read it top to bottom in a few minutes, comes away
understanding the full architecture and the reasoning behind each part, and is never made to
sit through an explanation of something they already know or a vague "we'll handle it"
where a real mechanism should be.
