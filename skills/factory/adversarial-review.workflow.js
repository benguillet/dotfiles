// /factory phase-6 review fleet: fan out read-only finders per diff × lens
// (plus cross-diff contract checks), dedup, then attack every finding with N
// independent refuters. Read-only over PUSHED refs — safe to run while other
// agents build. Crash-safe via the Workflow journal (resumeFromRunId).
//
// args contract:
// {
//   diffs: [{ key: 'ycinternal',            // short id used in labels
//             dir: '/abs/path/to/repo',     // git -C target
//             base: 'origin/master',        // diff base ref
//             head: 'origin/ben/branch',    // diff head ref (PUSHED)
//             context: 'what this diff is', // one line for the prompt
//             lenses: [{key, focus}] }],    // optional; defaults below
//   crosschecks: [{ key, prompt }],         // optional cross-diff finders;
//                                           // prompt must name its own diffs
//   settled: ['decision …'],                // do-not-relitigate list
//   context_files: ['/abs/spec.md'],        // read-first files (spec/plan)
//   refuters: 2                             // verifiers per finding
// }
export const meta = {
  name: 'factory-adversarial-review',
  description: 'Find -> refute-verify review fleet over pushed factory diffs',
  phases: [
    { title: 'Find', detail: 'finders per diff x lens + cross-checks' },
    { title: 'Verify', detail: 'independent refuters per deduped finding' },
  ],
}

const DEFAULT_LENSES = [
  { key: 'correctness', focus: 'CORRECTNESS + CONCURRENCY. Hunt: races (locking, check-then-act, cache-vs-store ordering), idempotency and retry holes, staleness/ordering guards, invalidation gaps, error paths that break documented contracts, off-by-one state machines.' },
  { key: 'security', focus: 'SECURITY. Hunt: auth/authz bypass, secret handling and leakage into logs/error trackers, injection via externally-supplied fields, PII exposure, unsafe mass assignment, DoS via pathological batch inputs.' },
  { key: 'conventions', focus: 'HOUSE RULES + TEST HONESTY. Check the repo CLAUDE.md/AGENTS.md rules (error handling, typing, logging, lint policy). Audit the diff’s tests: do they assert what they claim, or pass vacuously? Any check that was skipped or substituted without saying so?' },
]

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          repo: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'integer' },
          title: { type: 'string' },
          detail: { type: 'string', description: 'Concrete failure scenario: state + trigger -> observable wrong behavior' },
          severity: { type: 'string', enum: ['critical', 'major', 'minor'] },
          fix: { type: 'string' },
        },
        required: ['repo', 'file', 'title', 'detail', 'severity'],
        additionalProperties: false,
      },
    },
  },
  required: ['findings'],
  additionalProperties: false,
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean' },
    reasoning: { type: 'string' },
  },
  required: ['refuted', 'reasoning'],
  additionalProperties: false,
}

const diffs = args.diffs || []
if (!diffs.length) throw new Error('args.diffs is required')
const refuterCount = args.refuters || 2

const settled = (args.settled || []).map(s => `- ${s}`).join('\n')
const contextFiles = (args.context_files || []).join(', ')
const diffCatalog = diffs
  .map(d => `- ${d.key}: \`git -C ${d.dir} diff ${d.base}...${d.head}\` (${d.context || ''})`)
  .join('\n')

const COMMON = `
You are reviewing shipped-but-unmerged factory work. ${contextFiles ? `Read these context files FIRST: ${contextFiles}.` : ''}

STRICT RULES:
- READ-ONLY: git diff/show/log against the named refs and plain file reads only. NEVER checkout, commit, or modify anything — other processes own the working trees.
- Report only findings with a CONCRETE failure scenario (state + trigger -> observable wrong behavior). No style nits a linter enforces, no speculative "consider".
- severity: critical = data loss/security/broken feature in prod; major = wrong behavior in a real edge case; minor = worth fixing, low blast radius.
${settled ? `- Do NOT relitigate settled decisions:\n${settled}` : ''}

All diffs in this review (for cross-referencing):
${diffCatalog}
`

const finders = []
for (const d of diffs) {
  for (const lens of (d.lenses || DEFAULT_LENSES)) {
    finders.push({
      key: `${d.key}:${lens.key}`,
      prompt: `${COMMON}\nYour diff: \`git -C ${d.dir} diff ${d.base}...${d.head}\`${d.context ? ` — ${d.context}` : ''}. Read surrounding committed code via git show where the diff needs context.\nLens: ${lens.focus}`,
    })
  }
}
for (const c of (args.crosschecks || [])) {
  finders.push({ key: `xcheck:${c.key}`, prompt: `${COMMON}\n${c.prompt}` })
}

phase('Find')
const results = await parallel(finders.map(f => () =>
  agent(`${f.prompt}\nReturn findings via the structured schema. Empty array if genuinely nothing.`,
    { label: `find:${f.key}`, phase: 'Find', schema: FINDINGS_SCHEMA, effort: 'high' })
))

const all = results.filter(Boolean).flatMap((r, i) => r.findings.map(fd => ({ ...fd, finder: finders[i].key })))
log(`${all.length} raw findings across ${finders.length} finders`)

const seen = new Set()
const deduped = all.filter(f => {
  const k = `${f.file}|${(f.title || '').toLowerCase().slice(0, 40)}`
  if (seen.has(k)) return false
  seen.add(k)
  return true
})
log(`${deduped.length} after exact dedup (same bug via different lenses still consolidates during fixing)`)

phase('Verify')
const verified = await parallel(deduped.map(f => () =>
  parallel(Array.from({ length: refuterCount }, (_, n) => () =>
    agent(`You are adversarial refuter #${n + 1} trying to REFUTE a code-review finding. Default to refuted=true unless the evidence is solid.

FINDING (lens ${f.finder}, severity ${f.severity}):
${f.repo} ${f.file}${f.line ? ':' + f.line : ''} — ${f.title}
${f.detail}
Proposed fix: ${f.fix || 'n/a'}

Verify against the REAL code (read-only; never checkout/modify):
${diffCatalog}
${contextFiles ? `Settled-decision context: ${contextFiles}` : ''}
Refute if: the scenario is impossible given the real code, already mitigated elsewhere (specs, guards, backstops, TTLs), relitigates a settled decision, or is purely speculative.`,
      { label: `refute${n + 1}:${(f.title || '').slice(0, 30)}`, phase: 'Verify', schema: VERDICT_SCHEMA, effort: 'high' })
  )).then(vs => {
    const votes = vs.filter(Boolean)
    const refutes = votes.filter(v => v.refuted).length
    return {
      ...f, refutes, votes: votes.length,
      verdict: refutes === 0 ? 'CONFIRMED' : refutes < votes.length ? 'PLAUSIBLE' : 'REFUTED',
      refutations: votes.map(v => v.reasoning),
    }
  })
))

const survivors = verified.filter(Boolean).filter(v => v.verdict !== 'REFUTED')
log(`${survivors.length} findings survived of ${deduped.length}`)
return {
  confirmed: survivors.filter(s => s.verdict === 'CONFIRMED'),
  plausible: survivors.filter(s => s.verdict === 'PLAUSIBLE'),
  refuted_count: verified.filter(Boolean).length - survivors.length,
}
