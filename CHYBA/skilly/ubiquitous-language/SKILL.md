---
name: ubiquitous-language
description: Build/maintain a per-project domain glossary (DDD ubiquitous language) — one markdown file of shared terms that code, tests, PRDs and the AI all use identically. Use when starting a domain-heavy feature, when the AI's wording drifts from the domain, when one concept has several names in the codebase, or when money/legal/payroll terms must stay precise. Triggers on "ubiquitous language", "glossary", "domain terms", "shared language", "what do we call this". Do not use for API/reference docs (use generate-documentation) or file/naming conventions (use design-schema).
argument-hint: [feature or domain area]
allowed-tools: Read, Grep, Glob, Edit, Write
---

# Ubiquitous language (shared domain glossary)

## Why
You and the AI misalign because you use different words for the same concept. One authoritative
glossary — used verbatim in code, tests, PRDs and conversation — cuts misalignment and AI verbosity,
and keeps money/legal/payroll terms exact enough to assert on (feeds `test-layers-money-critical`).

## Produce / update `docs/ubiquitous-language.md`
1. Explore the codebase for domain terms: entities, statuses/enums, roles, money terms (rate, gross,
   net, VAT, deduction…), lifecycle verbs. Grep enums and type names FIRST — they are the real vocabulary.
2. Write markdown tables: **Term | Definition | Code symbol | Notes / gotchas**. One row per concept.
3. Flag SYNONYM COLLISIONS explicitly ("called `X` in the API but `Y` in the UI — pick one").
4. Make it authoritative: from now on code, tests and PRDs use these exact terms; fix drift on sight.

## Rules
- One term = one meaning. If a word means two things, split it into two terms.
- Money/legal terms: define precisely enough to write a test assertion from.
- Keep it SHORT and current — a stale glossary is worse than none. Update when a new concept appears.
- Open it during grilling/planning so you and the AI stay on the same wavelength.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Má každý riadok glosára skutočný symbol nájdený grepom v kóde a je pri každej synonymickej kolízii vypísaný AJ ten druhý, zavrhnutý názov?
