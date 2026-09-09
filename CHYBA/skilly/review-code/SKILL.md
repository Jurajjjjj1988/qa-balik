---
name: review-code
description: Read-only code review in 3 modes — Fast (red flags, table), Standard (Before/After + criticality scores), Risk Analysis (per-line edge-case/failure drill-down). Use to review a file, diff, or PR. Triggers on "review this code", "code review", "look over this", "spot issues". For the executed static-gate + refute-by-default find/verify/fix workflow use adversarial-review; for feasibility/design critique use critical-engineer.
argument-hint: [file, PR, or code]
allowed-tools: Read, Grep, Glob, Bash(git diff *), Bash(gh pr diff *)
---

Review this code. For each finding:

**[Criticality: X/10]** Issue title
- **File:** path:line
- **Before:** current code
- **After:** fixed code
- **Why:** explanation

Check:
- Does it do what it claims?
- What inputs break it?
- Duplicated logic?
- Meaningful names? (no `data`, `temp`, `res`)
- Proper TypeScript types? (no `any`)
- Correct async/await?

## Risk Analysis (per-line drill-down)

For each non-trivial function / method, walk through this checklist:

1. **Input edge cases:** What breaks with `null`, `undefined`, empty
   string, empty array, very large input, negative numbers, Unicode,
   leading/trailing whitespace?
2. **External failure:** What happens when an API call fails, times out,
   returns 5xx, returns malformed JSON, or hangs indefinitely?
3. **Hardcoded values:** Are there magic numbers, hard-coded URLs, env
   strings, or "for now" constants that should be extracted to config?
4. **Accidental success:** Does this work today by coincidence (timing
   race, browser default, lucky CSS specificity) and will break under
   different conditions?
5. **Missing error handling:** Unhandled promise rejections, empty catch
   blocks, swallowed errors, missing fallbacks, no logging at the failure
   boundary?

For each issue found, output in the standard format above (criticality
score + file:line + Before/After + Why).

## Fast mode (quick scan)

5-second scan. Red flags only. Use as a PR pre-screen or daily check
before commit.

Hunt list:

- Hardcoded secrets, API keys, tokens
- Missing `await` on async calls
- Empty catch blocks
- `console.log` / `console.debug` leftovers in production code
- `any` types
- Obvious `null` / `undefined` bugs
- Commented-out code blocks

Output format — compact table, NOT Before/After:

| File:Line | Issue | Fix |
|---|---|---|
| `src/api.ts:42` | Missing await on `fetch()` | Add `await` |

Skip in Fast mode:

- Formatting / style nitpicks
- Naming taste ("this could be clearer")
- Performance micro-optimizations that aren't bugs
- Architectural suggestions

When to use Fast mode:

- Pre-PR self-check before pushing
- Triage on a large diff to decide where deep review is worth it
- Quick sanity scan after an AI session

For deeper review with Before/After + criticality scores, use the
standard mode above. For edge-case / external-failure drill-down, use
the Risk Analysis section above.

Avoid review mistakes listed in [antipatterns/common.md](antipatterns/common.md).

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Stojí za každým X/10 otvorený VOLAJÚCI, ktorý tú hodnotu nekontroluje — a menuje prázdna Fast tabuľka rizikové súbory, ktoré do skenovaného diffu nepatrili?
