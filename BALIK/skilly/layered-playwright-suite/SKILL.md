---
name: layered-playwright-suite
description: The clean layered Playwright suite architecture (spec → page objects → fixtures → helpers) that a senior SDET writes — the pwm-blueprint reference. Use when writing a NEW Playwright test, page object, fixture, block, or suite so the output is professional and consistent: base fixture as the single import source, no god-class, readonly `[LABEL]` locators, web-first assertions, role-split helpers. Scaffold from the bundled reference/ templates rather than from scratch.
---

# Layered Playwright suite (the pwm-blueprint architecture)

The house standard for pretty, professional Playwright tests. When you write a new
test / page object / fixture / suite, **do not write from a blank file** — read the
matching template under `reference/` and copy its exact shape, then fill in the app's
specifics. That is what keeps every test consistent and clean.

`reference/` is a curated, de-identified snapshot of the pwm-blueprint suite (a real
senior-written Playwright tree). It models a generic shop; swap the placeholders for
the target app — see `reference/docs/BLUEPRINT.md` for the fill-in points.

## When this fires
Writing or refactoring: a Playwright `*.spec.ts`, a `*.page.ts` / `*.block.ts`, a
fixture, or standing up a new suite. Also "make this test prettier / more professional",
"scaffold a POM/fixture", "match our architecture".

## The layered tree (what goes where)
```
tests/<area>/<name>.spec.ts     # journeys only — no locators, no page.goto
helper/
  page-object/
    basepage.ts / baseblock.ts  # scaffolding — wire `page`, NEVER a god-class
    pages/<name>.page.ts         # one PageClass PER ROUTE
    blocks/<name>.block.ts       # reusable sections (≥5 locators / 3 methods)
  fixtures/base.fixture.ts       # the ONLY file that imports @playwright/test
  fixtures/<name>.fixture.ts     # one concern per fixture (staging, auth, mocks)
  api/<name>.api.ts              # request wrappers for data setup / teardown
  actions/                       # cross-page flows (multi-POM orchestration)
  utilities/                     # pure helpers (logger, formatters) — unit-tested
  test-data/                     # constants: urls.ts, labels, cookies, files
  types/                         # external (API) + internal data shapes
```
Path aliases (`@fixtures`, `@page-object`, `@logger`, …) resolve via
`reference/config/tsconfig.json` — copy those `paths` when standing up a suite.

## The conventions (non-negotiable — this is what "pretty" means here)

**Specs** (`reference/tests/example.spec.ts`):
- `import { test, expect } from '@fixtures/base.fixture';` — **NEVER** `@playwright/test`.
- Page objects arrive as **injected fixtures** (`{ cartPage, designsPage, authenticatedUser }`), not `new Page(page)`.
- Structure with `test.describe(..., { tag: [...] })` + `test.step(...)` per phase.
- Assert the **outcome and the render**, not just the URL — `toHaveURL` *and* `heading.toBeVisible`.
- No locators, no `page.goto`, no waits in the spec — those live on the page object.

**Page objects** (`reference/helper/page-object/pages/cart.page.ts`):
- `const LABEL = 'Cart';` then `extends BasePage` — **no own constructor** (BasePage wires `page`).
- Locators are `readonly` fields with `.describe(`[${LABEL}] …`)` — every locator is labelled.
- Locator priority: `getByTestId` → `getByRole` → `getByLabel` → `getByPlaceholder`. Never `.nth()` / CSS class as the primary.
- `readonly url` + an `async waitForPageLoad()` (web-first assertions, generous timeouts).
- Methods carry `[LABEL]` assertion messages and use `logger`; web-first assertions only — **no hard waits**.

**Fixtures** (`reference/helper/fixtures/base.fixture.ts` + `staging.fixture.ts`):
- `base.fixture.ts` is the single source of `test`/`expect`; each further fixture `test.extend()`s it, one concern per file. Worker-scope expensive setup (auth → storageState); test-scope anything touching `page`.

**TypeScript:** no `any`, `tsc --noEmit` clean, JSDoc on public methods.

## How to use it (the workflow)
1. **Read the matching template** in `reference/` before writing — the page for a POM, `example.spec.ts` for a spec, `base.fixture.ts` for fixtures.
2. **Copy the shape**, rename `LABEL`, swap routes (`reference/helper/test-data/urls.ts` pattern) + locators + labels for the target app.
3. **Beautify existing tests** by mapping them onto this tree: inline `page.goto`/locators → a page object; `@playwright/test` import in a spec → `@fixtures/base.fixture`; a god-class → one POM per route; bare assertions → `[LABEL]`-messaged web-first ones.
4. Keep each layer's `reference/**/CLAUDE.md` open — they are the per-layer authoring guides (page-object, fixtures, api, test-data, utilities, actions).

## Relationship to the other test skills (don't duplicate — compose)
- **pom-design** — the deeper *why* of POM splitting / grouping / god-class avoidance. This skill is the concrete CODE + suite-level shape; pom-design is the rationale. Read both for a non-trivial POM.
- **fixture-architecture** — the deeper *why* of fixture layering / scope / auto-vs-explicit. This skill bundles the working `base.fixture.ts` + `staging.fixture.ts`; that skill explains the trade-offs.
- **real-testing-patterns** — the quality bar ("would this fail if the behaviour broke?"). Apply it to every spec you write from this template.

The structural contract in full: `reference/docs/ARCHITECTURE.md`.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Overuje aspoň jedna assertion DÁTA, ktoré tá akcia mala zmeniť — alebo si celú sadu tvrdení zdedil zo šablóny (`waitForPageLoad` + `toHaveURL` + `[LABEL]` nadpis), takže spec prejde aj vtedy, keď sa zápis vôbec neuložil?
