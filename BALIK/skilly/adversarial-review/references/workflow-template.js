// adversarial-review — Workflow skeleton. READ AND ADAPT, DO NOT RUN THIS FILE.
// Copy this into a Workflow tool call, then tailor FILES, INTENT, and DIMENSIONS to the project.
// Pattern: fan out finders (one per lens) → pipeline each finding through a refute-by-default
// verifier → return only confirmed findings + the raw count (the gap proves the verifier worked).

export const meta = {
  name: 'adversarial-review-run',
  description: 'Multi-dimension adversarial review of <project/scope>',
  phases: [{ title: 'Review' }, { title: 'Verify' }],
}

const FILES = [ /* absolute paths in scope */ ]

// One paragraph: what the app is, the stack, the core invariants, the user's locked decisions, and:
// "tsc/build/tests are GREEN — hunt RUNTIME/LOGIC bugs, data-loss, regressions, intent violations,
//  NOT compile errors." Ground the finders so they judge against real intent.
const INTENT = `...`

const FINDINGS_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { findings: { type: 'array', items: {
    type: 'object', additionalProperties: false,
    properties: {
      title: { type: 'string' },
      severity: { type: 'string', description: 'blocker | major | minor | nit' },
      file: { type: 'string', description: 'path:line' },
      detail: { type: 'string', description: 'what is wrong + how it manifests at runtime' },
      suggestedFix: { type: 'string' },
    },
    required: ['title', 'severity', 'file', 'detail', 'suggestedFix'] } } },
  required: ['findings'],
}

const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    isReal: { type: 'boolean' },
    severity: { type: 'string', description: 'blocker | major | minor | nit' },
    confidence: { type: 'string', description: 'high | med | low' },
    reasoning: { type: 'string' },
  },
  required: ['isReal', 'severity', 'confidence', 'reasoning'],
}

// Tailor: pick 3–6 from references/review-dimensions.md, each a DISTINCT lens.
const DIMENSIONS = [ /* { key, prompt } */ ]

// The 4 refute gates — a finding SURVIVES only if the verifier can do all four.
const REFUTE = `Adversarial verifier. REFUTE BY DEFAULT: isReal=false unless ALL FOUR hold —
(1) quote the actual code at the cited file:line;
(2) trace a reachable runtime path to the defect;
(3) rule out existing guards/mitigations already in the code;
(4) give a concrete triggering input or call sequence.
"Could be null" is refuted; "returns null when x=[], dereferenced at line N" survives.
Compile errors are NOT valid (the static gate is green). Set confidence low/med/high accordingly.`

phase('Review')
const perDim = await pipeline(
  DIMENSIONS,
  (d) => agent(`Review ONLY along your dimension. Read the files.\n\nDIMENSION: ${d.prompt}\n\nFILES:\n${FILES.join('\n')}\n\n${INTENT}\n\nReport only real defects (file:line + concrete fix). Empty findings array if clean. Do not invent issues to seem thorough.`,
    { label: `review:${d.key}`, phase: 'Review', schema: FINDINGS_SCHEMA }
  ).then((r) => ({ dim: d.key, findings: (r && r.findings) || [] })),
  (r) => parallel((r.findings).map((f) => () =>
    agent(`${REFUTE}\n\nCLAIM (${r.dim}):\n${JSON.stringify(f)}\n\nFILES:\n${FILES.join('\n')}\n\n${INTENT}`,
      { label: `verify:${f.file}`, phase: 'Verify', schema: VERDICT_SCHEMA }
    ).then((v) => ({ ...f, dim: r.dim, verdict: v })))),
)

const all = perDim.flat().filter(Boolean)
const confirmed = all.filter((f) => f.verdict && f.verdict.isReal)
log(`${confirmed.length} confirmed of ${all.length} raw`)
return { confirmed, rawCount: all.length }

// THOROUGH mode: for a low-confidence "isReal=true", escalate to 3 verifiers with DISTINCT lenses
// (correctness / security / does-it-reproduce) and keep the finding only if >=2 agree.
