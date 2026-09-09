---
name: generate-documentation
description: Generates technical documentation — README, architecture docs, API docs, setup guides, test docs, runbooks — concise, structured, Diátaxis-classified, with code examples. Use when writing or updating project documentation. Triggers on "write docs", "README", "architecture doc", "API docs", "runbook", "setup guide". Do not use for per-UI-component reference docs (use documenting-ui-components) or E2E/test-repo READMEs (use readme-test-repo-pattern).
argument-hint: [what to document]
---

Generate documentation. No fluff.

First **classify by Diataxis** — never mix modes on one page:
**Tutorial** (learning, step-by-step) · **How-to** (task recipe) · **Reference** (dry facts: API, config) · **Explanation** (the why / decisions).

Rules:
- Headings, tables, code examples; Quick Start for setup guides; Mermaid for complex architecture; include prerequisites.
- Reference code, don't copy it (copies rot). OpenAPI spec / TS types = single source of truth for API docs.
- Docs-as-code: colocate `.md` with what it documents; update docs in the SAME PR as the change; delete stale content.
- Anti-slop voice: active voice, terse. Ban "powerful", "seamless", "robust", "comprehensive", "leverage".
- CI-lint docs (Vale + markdownlint + link-check) so they can't rot silently.

Types (mapped to Diataxis):
1. README — overview, setup, usage (tutorial + how-to)
2. Architecture — modules, data flow, decisions (explanation)
3. API docs — endpoints, request/response, errors (reference; generate from OpenAPI)
4. Test docs — strategy, coverage, how to run (how-to)
5. Setup guide — step by step (tutorial)
6. Runbook — what to do when it breaks (how-to)

Per-component reference docs → `documenting-ui-components`. Test-repo READMEs → `readme-test-repo-pattern`.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Spustil si každý príkaz a otvoril každú cestu, ktorú tento dokument tvrdí ako fakt — alebo si ich odpísal zo zdrojáka, zámeru a starého README?
