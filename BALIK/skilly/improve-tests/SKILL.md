---
name: improve-tests
description: Improves existing tests — fixes flaky patterns, fragile selectors, missing assertions, duplication, readability — with Before/After per finding. Use when hardening or refactoring a test file that already exists (not authoring new ones). Triggers on "improve tests", "fix flaky test", "refactor tests", "tests are fragile", "clean up tests". New-test authoring → write-tests; anti-pattern catalog → real-testing-patterns.
argument-hint: [test file to improve]
allowed-tools: Read, Grep, Glob
---

Review tests and fix. For each finding: Before → After → Why.

Check for:

- **Flaky** — hard waits, race conditions, order-dependent
- **Missing assertions** — clicks without verifying result
- **Fragile selectors** — nth(), CSS classes instead of getByRole/getByLabel
- **Duplication** — repeated code that belongs in fixtures/helpers
- **Readability** — unclear test names, missing test.step()
- **Custom step helper** — replace with test.step() directly
- **Tests that only pass** — would this catch a bug? If not, rewrite it.

## Anti-patterns

A1–A13 anti-patterns and the AI-signature blacklist live in `real-testing-patterns`. When you spot one in the file under review, name it (e.g. "A9 — toHaveCount without using"), then apply the fix from that skill.

The mutation test is the entry gate: "If I deleted the line being tested, would this test fail?" If no — rewrite.

Do not duplicate A1–A13 examples here. Reference them.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Pustil si tú istú poruchu na PÔVODNÚ aj UPRAVENÚ verziu testu a sčervenali obe rovnako — alebo si po refaktore videl už len zelenú?
