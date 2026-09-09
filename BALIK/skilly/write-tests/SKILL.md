---
name: write-tests
description: Creates NEW E2E/UI tests with Playwright + POM via a strict gated workflow - information gathering, test scenarios, architecture, implementation, feedback loop. Never proceeds without complete information (selectors, ACs). Use when authoring tests for a feature or Jira ticket from scratch. Triggers on "write tests", "create tests", "add E2E tests", "test this feature", "cover this ticket". Do not use for hardening/refactoring EXISTING tests → improve-tests; anti-pattern catalog → real-testing-patterns.
argument-hint: [feature or Jira ticket to test]
allowed-tools: Read, Grep, Glob, Bash(npx playwright *)
---

# Test Creation Workflow

Follow phases IN ORDER. Do NOT skip. Do NOT proceed if a gate is not passed.

## Phase 0: Project Setup

If no test project exists, initialize:

1. **Folders** — layered, one home per concern:
   - `pages/` — page objects (one per route)
   - `blocks/` — reusable sections / components (header, footer, modal) — Pattern 3 in `pom-design`
   - `fixtures/` — DI: page fixtures + mock fixtures + composite scenarios
   - `actions/` — cross-page flows (compose 2+ POMs)
   - `api/` — request wrappers, one file per endpoint — **the only sanctioned way to prepare test data**
   - `utilities/` — pure functions (`parse*`, `get*`, `calculate*`, `verify*`) — 100% unit-coverage gate
   - `test-data/` — constants only (URLs, IDs, cookies, ticket suite IDs)
   - `types/` — `external/` (API shapes) + `internal/` (test-internal types)
   - `tests/` — specs, mirroring config-project structure
2. **Deps**: `@playwright/test`, `dotenv`, `eslint-plugin-playwright`, `@typescript-eslint/no-floating-promises`
3. **Config**: `playwright.config.ts`, `tsconfig.json`, `.env`, `.gitignore`
4. **Path aliases — mandatory.** Add to `tsconfig.json` `paths` and `playwright.config.ts` resolver: `@pages`, `@blocks`, `@fixtures`, `@actions`, `@api`, `@utilities`, `@test-data`, `@types`. **No relative imports.** Specs that read `import { test, expect } from "@fixtures/base.fixture"` survive folder moves; `../../fixtures/...` doesn't.
5. **Component POMs over `BasePage` god class** — Playwright auto-wait makes utility methods redundant. If you need a shared abstract base, keep it to `page: Page` parameter wiring + an abstract `waitForPageLoad()`. Nothing else. (See `pom-design` for the BasePage anti-pattern.)
6. **`fixtures/base.fixture.ts`** is the **single import source** for `test` and `expect` across the whole suite — re-exported from `@playwright/test`. Never import them from `@playwright/test` directly in a spec.
7. Linear `.extend()` chain for fixture layering, never `mergeTests` (collapses TS types to `any`).

**GATE:** Project structure must be complete. Path aliases must resolve in both `tsc --noEmit` and Playwright runtime.

## Phase 1: Information Gathering

Answer ALL before writing code:

1. Do I know ALL selectors needed?
2. Do I understand the full functionality?
3. Can I list ALL parts that need testing?
4. What test modalities does this feature need — UI / API contract / A11y / Visual / Security? Most features need 1–2 (UI + maybe API). Explicitly decide; default to UI-only and the others silently regress. If 3+ modalities apply, file separate tests per modality and link them via a shared tag.

**Sources:** Jira ticket → Company docs → Exploration test (log inputs/buttons/data-attributes) → Playwright MCP → Codebase

**GATE:** Missing selectors → ask. Guessing → stop and ask.

## Phase 2: Test Scenarios

Create scenarios BEFORE code. Categories: Happy Path, Edge Cases, Negative.

**GATE:** Every AC and DOD item covered by at least one scenario.

## Phase 3: Architecture

Before implementation, decide:

1. **POM** — exists? Use it. Never duplicate. POM only when locator logic is reused 3+ times, the action has domain meaning (`addToCart`), or the locator is non-obvious (shadow DOM, custom element). Otherwise inline.
2. **Selectors priority**: `getByRole` → `getByLabel` → `getByPlaceholder` → `getByTestId`. Never `nth()`, never CSS classes as primary. Compose with `locator.or()`, `locator.and()`, `locator.filter({ hasNotText })` (v1.50) instead of try/catch.
3. **Assertions** — web-first only (`await expect(locator).toX()`). Every action followed by an outcome assertion. Use `toMatchAriaSnapshot()` (v1.49) for structural regression; replaces fragile DOM snapshots.
   - **`[LABEL]` messages mandatory inside POM methods.** When `expect()` fires from inside a page-method, the spec author can't see the assertion line. Every such `expect()` takes a message — `expect(x, '[PDP] Add-to-cart button should be enabled').toBeEnabled()`. Specs can omit the message when the locator name + assertion is self-explanatory, but bias toward including it.
   - **Soft assertions for independent multi-checks.** When a step verifies several *independent* properties and you want all failures reported at once (not fail-fast), use `expect.soft(...)`. Keep **hard** assertions for preconditions and anything the rest of the step depends on.
3a. **Grab → Parse → Assert for any data-derived assertion.** When the assertion needs raw DOM strings transformed (parsed into numbers, objects, arrays), use a three-layer flow — never collapse:
   - **Grab** — page method returns raw `string[]` via `allTextContents()`. Asserts the array is non-empty before returning.
   - **Parse** — pure `utilities/` function (`parsePrices(texts: string[]): Price[]`). Unit-tested. No browser, no I/O.
   - **Assert** — spec calls `expect(parsed[0].amount, ...).toBe(expected)`.

   ```ts
   // page method — GRAB
   async getPriceTexts(): Promise<string[]> {
     const texts = await this.arrayPrices.allTextContents();
     expect(texts.length, "[PDP] Prices should not be empty").toBeGreaterThan(0);
     return texts;
   }
   // utility — PARSE (pure)
   export function parsePrices(texts: string[]): Price[] { /* … */ }
   // spec — ASSERT
   const prices = parsePrices(await pdp.getPriceTexts());
   expect(prices[0].amount, "[PDP] First price should match").toBe(19.99);
   ```

   For plain checks — visible text, input value, element count — **skip the grab/parse and assert directly on the locator** (`toHaveText`, `toHaveValue`, `toHaveCount`). `expect(value).toBe(...)` is reserved for genuinely parsed data, never as a substitute for `toHaveText`.
4. **Waits** — `expect.poll` or web-first auto-retry. Never `waitForTimeout`. `page.clock` for time-dependent logic.
5. **Fixtures** — linear `.extend()` chain (not `mergeTests` — kills TS types). Auto fixtures (`{ scope: 'test', auto: true }`) for cross-cutting guards (console errors, network errors). `storageState: undefined` on the login page.
6. **Auth as setup** — login once via API + `storageState`, reuse. Worker-scoped per `testInfo.parallelIndex` for parallel write-tests (one user per worker, not per test). Use `setup` project with `dependencies: ['setup']`.
7. **Trace strategy** — `trace: 'retain-on-first-failure'` (v1.45) in CI. Lighter than `retain-on-failure`, richer than `on-first-retry`.
8. **Locator clarity** — `locator.describe('checkout submit button')` (v1.52) for trace readability.

CI config additions: `failOnFlakyTests: !!process.env.CI` (v1.52) — red-light flakes instead of silent retry-pass.

For anti-patterns to avoid (A1–A13), AI-signature blacklist, decision triggers (write/delete/mock), test-data anti-patterns: see `real-testing-patterns`.

## Phase 4: Implementation

- `test.step()` for every **action → expectation** pair — without steps, failure reports show only test name. Step title names the **action** (imperative), step body performs it then asserts the expectation. **No nested steps.** Don't create a step that just restates a lone assertion.
- **Naming — verb phrase, no `should`.** See `test-organization` and `real-testing-patterns`: titles read as user behavior, not framework ceremony.
  - With a ticket system: `[TICKET-ID] - Check that <user-perceivable outcome>` — e.g. `[CHK-42] - Check that empty cart redirects to PDP`.
  - Without: `<actor/system action> <object> [<deviation>]` — e.g. `submits a payment to another user`, `rejects login with invalid password`.
  - **Never** `should_[action]_when_[condition]` — flagged by `ai-test-smell-detector` as machine-shaped.
- Tests are deterministic — no `if` conditions, no runtime `test.skip()` (skip in `beforeEach` with mandatory reason).
- JSDoc on all public POM methods — WHY only, not WHAT.
- `eslint-plugin-playwright` catches missing `await`, hard waits, `{ force: true }`
- Never use deprecated API: `waitForNavigation()`, `waitForSelector()`, `page.$()`
- **Never `page.goto()` in a test** — always a page object's `open()`. Specs are behavior, not URL strings.

## Phase 5: Feedback Loop

1. Run tests: `npx playwright test`
2. All tests must PASS
3. Tests must FIND BUGS — not just pass

**GATE:** Do NOT deliver if any test fails or tests pass with broken functionality.

## Phase 6: Mutation test (real verification)

Before declaring done, pick 2–3 tests and mentally mutate the production code:

1. Delete the `href` from the `<a>` — does my test fail?
2. Flip `>` to `>=` in the boundary — does my test fail?
3. Make the function return `null` — does my test fail?

If all three pass — the tests are theatre. Rewrite them with outcome assertions, not visibility checks.

Run the self-check from `real-testing-patterns` before declaring done.

## Documentation discipline (1-day / take-home / showcase tasks)

- README ≤ 50 lines. **No ADRs**, **no TEST-CATALOG**, **no CHANGELOG**, **no `OQ-X` notation**.
- Inline comments only for non-obvious **why**.
- Commit messages are terse: `cover header, footer, search` — not `feat: aggressive bug-finding suite expansion + 6 ADRs`.
- See `real-testing-patterns` for the vocabulary blacklist (`comprehensive`, `robust`, `ensures`, `leverages`).

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Pri každom scenári z Fázy 2: pokazil si to správanie priamo v kóde (nie „mentally" ako káže Fáza 6) a videl padnúť práve ten jeden nový test — na asserte VÝSLEDKU, nie na `toBeVisible`?
