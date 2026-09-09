---
name: anti-ai-slop
description: Use when writing or reviewing AI-generated code destined for production, before merging AI-authored changes, when a suite is all-green but you doubt it catches bugs, when a feature "feels done", or when a task handles money/auth/data-integrity. Triggers on plausible-but-wrong logic, vanity-green tests, hallucinated APIs/packages, copy-paste debt, silent scope drift. Do not use when the artifact under review IS the test suite — E2E/UI test authoring and review is real-testing-patterns, an AI-shape scan of unit tests is ai-test-smell-detector — or when the doubt is about a threshold, hook or CI step rather than the code (gate-audit).
---

# Anti-AI-slop — ship professional code, not plausible-but-wrong code

## Core principle

**Slop = choices that are technically valid but logically wrong.** It compiles, looks
plausible, and the tests pass — yet it quietly solves the wrong problem. The danger is the
*absence* of a red flag. The only defense is **verification against intent + objective
test-quality**, never "does this look right?". Correctness feeling ≠ correctness (METR: devs
were 19% slower with AI but believed they were 20% faster — trust the metric, not the feeling).

## Red flags — you are about to ship slop

- All tests green but you never watched one FAIL for the bug it "covers".
- Coverage is high; mutation score is unknown.
- A lookup returns `0`/default for "missing" instead of surfacing it.
- A new dependency you didn't verify exists (slopsquatting: LLMs invent package names).
- Duplicated block instead of reusing an existing function.
- An abstraction added for a problem that needed five lines.
- "It feels done" with no acceptance criterion written down first.
- The invariant is enforced only in the client, not at the trust boundary (DB/API).
- You (an AI) reviewed your own diff and found nothing — correlated blind spots.

## Gates (run per change; scale to risk)

1. **Intent first.** Write the acceptance criterion BEFORE code. No spec ⇒ nothing to verify against.
2. **Red-green, always.** A bug-catching test must be watched failing against the broken code first. Can't make it fail ⇒ it tests nothing.
3. **Objective test-quality, not coverage.** Mutation testing (Stryker) on pure logic; survivors = gaps. Coverage is a vanity metric.
4. **Escape your own assumptions.** Property-based tests (invariants over generated inputs) + failure-injection at the persistence/network boundary (force writes to fail → assert error surfaces AND state doesn't corrupt).
5. **Server-authoritative invariants.** Money/auth/inventory rules enforced by DB CHECK/RLS/trigger, not just Zod on the client — hold for every writer, not just the happy UI path.
6. **Adversarial verify, refute-by-default, fresh context.** A separate reviewer that tries to REFUTE each claim (quote code, trace reachable path, rule out guards, give a trigger). Kills plausible-but-wrong findings AND plausible-but-wrong code. → **REQUIRED SUB-SKILL:** adversarial-review.
7. **Invariant registry, auto-enforced.** Standing rules in CLAUDE.md + typed ESLint (no-floating-promises, exhaustive switch) + import-boundaries — the machine enforces architecture, not discipline.
8. **Verify dependencies exist.** Every new import resolves to a real, pinned package; no hallucinated names. Prefer stdlib/existing deps over new ones.
9. **Tight scope.** Small task + clear AC produces far less slop than "build this feature".
10. **Human review at milestone boundaries.** The senior makes the judgment calls tooling can't; don't generate faster than it can be reviewed.
11. **Ground truth is the ceiling.** Tests encode YOUR assumptions, not the real business rules / law / hardware. No tooling closes this — only real requirements + a pilot do. Name this gap; don't paper over it.

## When to reach for which

- Feasibility / "will this actually work" skepticism → **critical-engineer**.
- Find→verify→fix a diff before merge → **adversarial-review**.
- State/persistence/export/offline bug classes → **robust-stateful-frontend**.
- Authoring/editing a skill itself → **writing-skills** (TDD for docs; don't ship untested skills).

## Anti-patterns

- Treating a green suite as proof of correctness. It's proof of nothing until mutation-tested.
- "I manually checked it" — the reconciliation bug (140 tests, 92% coverage) shipped and silently duplicated data via reference-equality. Manual + coverage missed it; mutation/property/adversarial catch it.
- One giant AI PR nobody can review — split it; unreviewed AI code is defect density, not velocity.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Podložil si verdikt „slop som nenašiel" aspoň jedným MERANÍM — zabitý mutant, test padnutý presne na tej chybe, overené že importovaný balík naozaj existuje — alebo si len prečítal diff, ktorý si sám napísal?
