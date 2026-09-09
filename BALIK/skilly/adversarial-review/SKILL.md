---
name: adversarial-review
description: >-
  Use when the user asks to "adversarially review", "review my changes",
  "double-check the code", "did we make a mistake", "review before shipping
  or merging", or "check our work" — even if they don't say "adversarial".
  Runs a high-signal, low-noise local code review: a static gate (typecheck +
  build + tests) first, then a parallel find → refute-by-default verify → fix
  pass that discards plausible-but-unproven findings so only real defects
  surface. Distinct from the built-in cloud /code-review; this runs locally
  and never pushes. Scope is ONE change — a diff, a feature, a working tree.
  For an ACCUMULATED range of many commits, where the defect sits in the seam
  BETWEEN separately-correct commits, use seam-review instead, or first.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Workflow
  - AskUserQuestion
---

# Adversarial review

Catch real defects before they ship, with high signal and low noise: static checks first, then a
parallel **find → refute-by-default verify → fix confirmed** pass. The verify stage is the point —
it kills plausible-but-wrong findings so effort goes only to real bugs.

## When to use

Before merging/shipping, after a big batch of changes, or whenever the user asks to double-check
work / "did we break something". Scale the fleet to the size of the change: a targeted diff review
is 3 dimensions; a full audit is 5–6 with 3-verifier voting.

## Inputs

The skill accepts (in priority order):
- explicit file paths or globs → review exactly those;
- a base branch/ref → review `git diff --name-only <base>...HEAD` plus close dependents;
- nothing → review the changed files vs the default branch, else the `src/` tree.

## Steps

### 1. Static gate (fast, local — first)
Resolve the repo's REAL commands, then run them; report failures FIRST (a red build makes the agent
review moot). `cd` into the project dir in EACH Bash call — cwd can reset between calls.
- Typecheck: prefer `node_modules/.bin/tsc --noEmit`, else the repo's `typecheck` script. Avoid bare
  `npx tsc` — it can fetch a wrong/squatting `tsc` package.
- Build: the repo's `build` script (catches what `tsc --noEmit` misses — bundler/asset issues).
- Tests: the repo's test script (e.g. `node_modules/.bin/vitest run`).
Proceed only once the gate is green (or the user says review anyway).

### 2. Scope
Resolve scope from Inputs. Skip generated/vendored files. Don't chunk a huge diff into one review —
cap scope and `log()` what you dropped (no silent truncation).

### 3. Launch the Workflow (find → adversarial verify)
Author a Workflow by adapting `references/workflow-template.js` — the reusable find→verify→report
skeleton (schemas, the `pipeline()` finder→verifier wiring, the 4 refute gates, the `confirmed`/
`rawCount` return). **Read** it, copy it inline into your Workflow, then tailor `FILES`, `INTENT`,
and `DIMENSIONS`. Do not execute the file directly.

Pick 3–6 dimensions from `references/review-dimensions.md` (a bounded checklist per lens —
correctness, security/OWASP, concurrency, error-handling, API-contract, persistence, performance,
domain-core). Choose what actually matters here; give each finder a DISTINCT lens so they don't
converge on the same easy bug. Compile errors are NOT valid findings (the static gate covers those).

### 4. Report + fix
- Dedupe confirmed findings (several dimensions often report the same bug); sort by severity ×
  confidence (see below).
- Fix `blocker`+`major` directly — **EXCEPT on money / payroll / pricing / billing / auth / migration
  files, where an LLM verifier passing a wrong `blocker` would mean an autonomous edit to exactly the
  code that must not be touched on derived evidence: there, surface the finding + proposed fix, never
  auto-apply.** Batch `minor`; never auto-apply a `nit` or a large refactor without asking. Add a
  regression test for each real logic bug where practical.
- Re-run the static gate after fixing. Report honestly: X confirmed of Y raw (the gap shows the
  verifier did its job).
- Append refuted findings + their one-line refutation to a LOCAL, gitignored ledger (e.g.
  `.adversarial-review/refuted.md`) so the same false positive isn't re-raised next run.

## Severity & confidence

Report each confirmed finding as: `<severity> [confidence] file:line — <subject>`, then a 1–2 line
discussion + concrete fix.
- **Severity:** `blocker` (fix before merge) · `major` · `minor` · `nit` (preference, author may ignore).
- **Confidence:** `high` / `med` / `low`, from the verifier.
Keep a finding only if fixing it improves overall code health AND it is evidence-backed — there is
only *better* code, not perfect code.

## Examples

Survives verification (report it):
> `major [high] src/db/repo.ts:42 — list() returns null but caller dereferences`
> `list()` returns `null` for an unknown floor (line 42); `useX` does `rows.length` (line 20) → TypeError on first load of a never-seeded floor. Fix: guard `if (rows === null)`.

Refuted (drop it):
> Claimed: "photoUrl may leak on unmount." Verifier: cleanup revokes `urlRef.current` (line 45) which is updated on every set; no reachable path leaks. → isReal=false.

## Guardrails

- **Local-only. Never push** agent artifacts, the refuted-ledger, or skill edits to any remote
  unless the user explicitly says so. Ensure the ledger is gitignored.
- Don't fabricate findings to look thorough — an empty confirmed list after a real verify pass is a
  valid, good outcome. But it is only "clean" if the finders actually READ files: if scope resolved to
  0 files (e.g. `git diff base...HEAD` empty because the branch is already merged), that is "did not
  look", not "clean" — say so, and log how many files each finder read.
- Respect the repo's own CLAUDE.md / lint config when proposing fixes.
- **Auto-trigger gate:** when invoked implicitly (not an explicit `/adversarial-review`), surface
  blockers/majors + the proposed fix BEFORE writing them. Explicit invocation may fix directly —
  except the money/auth/migration carve-out above still holds regardless of how the review was
  invoked: those files are surfaced with a proposed fix, never auto-applied.

## Anti-patterns

- Folding error-handling into "correctness" — run it as its own lens.
- Handing every finder the same prompt — they converge on the same bug.
- Reporting a "could be null" with no reachable path — refute it (see the 4 gates in the template).
- One giant review over a 5000-line diff — cap scope; quality degrades on oversized changesets.
- Auto-applying nits or large refactors without asking.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Má každý `confirmed` nález, na ktorý si siahol do kódu, dôkaz zo SPUSTENIA (reprodukcia alebo padajúci test) — a nie iba súhlas druhého modelu s prvým?
