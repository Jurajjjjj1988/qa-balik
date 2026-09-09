---
name: real-testing-patterns
description: Use when writing or reviewing E2E/UI tests (Playwright, Cypress, Selenium). Catches AI-generated test smells, enforces user-journey verification over static property checks, prevents the "tests pass but don't catch bugs" failure mode. Triggers on "write tests", "review tests", "improve tests", "are these tests good", "test patterns", or any test creation/review request — apply even when the user does not explicitly say "patterns" or "review". Do not use for a quick AI-shape scan of unit tests (that is ai-test-smell-detector), for non-test production code (anti-ai-slop), or when the question is whether the GATE itself works rather than whether the tests do (gate-audit).
---

# Real Testing Patterns

## The rule

Every test must answer: **"Would this fail if the underlying behavior broke?"**

If "no" or "I'm not sure" — rewrite. This is the only rule. The rest is how to apply it.

## Trigger → Action (apply on sight)

| If you see…                                           | Do this                                                                                        |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `toBeVisible()` as the only assertion                 | Add user action + outcome assertion                                                            |
| `toHaveCount(N)` without using one of N               | Click one, assert destination or effect                                                        |
| `waitForTimeout` / `setTimeout` / `sleep`             | Replace with `expect.poll` or web-first assertion                                              |
| `expect(await x.isVisible()).toBe(true)`              | `await expect(x).toBeVisible()`                                                                |
| `.locator('div.foo > span:nth-child(N)')`             | `getByRole` / `getByLabel` / `getByTestId`                                                     |
| `.not.toBeVisible()`                                  | `.toBeHidden()` (positive form retries correctly)                                              |
| Click with no `expect` after                          | Add outcome assertion                                                                          |
| Click with no `expect(...).toBeVisible()` _before_    | Add sanity guard — fails fast at the broken affordance, not 15s later in the outcome assertion |
| Test name is a noun phrase (`'header renders'`)       | Rename to verb phrase: `'user does X'`                                                         |
| Test description contains "and also" / "then"         | Split into two tests — one When per test                                                       |
| Hardcoded number with no source comment               | Extract constant with reason, or derive from setup                                             |
| Cannot name the user goal this protects               | Delete the test                                                                                |
| `mergeTests(a, b)` in fixture chain                   | Linear `.extend()` chain — mergeTests kills TS types                                           |
| Login UI clicked in every test                        | Setup via API; assert via UI                                                                   |
| Try/catch that SWALLOWS `page.click/fill/expect`      | Delete it — Playwright auto-retries. Exception: a best-effort *secondary* check whose *primary* signal already passed (the two-signal URL-canonical pattern below) is not a swallow. |
| Asserting on `data-loaded`, internal state, URL query | Assert what the user perceives instead                                                         |

## Assertion families — pick by intent

Audit the file by family, not by grep'ing `expect`. A healthy E2E suite is heavily skewed to visibility + URL; everything else is rare and load-bearing.

| Family        | Asserts                                     | Use when                                                                                            | Smell when                                                                    |
| ------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Visibility    | `toBeVisible` `toBeHidden` `toBeInViewport` | Sanity guard before click + outcome after click. `toBeHidden` for post-action disappearance.        | Only assertion in test (A1). `toBeInViewport` outside scroll/sticky tests.    |
| State         | `toBeEnabled` `toBeDisabled` `toBeChecked`  | Form-submit affordance must be clickable; checkbox/radio reflects user choice.                      | Asserting every visible button is enabled (vanity).                           |
| Attribute     | `toHaveAttribute`                           | User-perceivable contracts: `tel:` href format, `target=_blank`, `aria-expanded`, skip-link `href`. | Asserting `data-loaded`, `data-state`, internal hooks (A6 / impl detail).     |
| Text          | `toContainText` `toHaveText`                | Rare. Prefer `getByText(/regex/)` matcher — flexes to copy edits inside the bounded pattern.        | Full marketing copy (A10). Exact `toHaveText` brittles on whitespace.         |
| Value         | `toHaveValue` `toHaveJSProperty`            | Almost never in E2E — asserting input value after `fill` tests Playwright, not the app.             | Asserting `input.value === "tshi"` after typing — assert the _outcome_.       |
| URL           | `toHaveURL`                                 | After navigation. `Promise.all([page.waitForURL(...), click])` is also a URL assertion (throws).    | —                                                                             |
| Count / Class | `toHaveCount` `toHaveClass` `toHaveCSS`     | Almost never. `toHaveCount` only with a derived expectation (e.g. cart len === setup len).          | A9 vanity (count without using one) / A6 impl detail (`toHaveClass(/open/)`). |

Triage: grep each family across the file. Visibility-heavy + zero `toHaveCount`/`toHaveClass` is the healthy *shape* — but shape is necessary, not sufficient: 40 tests of `goto → toBeVisible(heading)` with no action-then-outcome are pure A1 vanity and pass this distribution check. Confirm the suite's visibility assertions include real *outcome* checks (a visibility that follows a user action and verifies its result) — not only legitimate pre-click sanity guards; a suite that is all sanity-guard and no outcome is A1 vanity. The matcher mix alone does not certify health. Many `toHaveValue` / `toHaveProperty` = implementation testing leaking in.

## Anti-patterns A1–A13

One-line spec; full examples in references.md.

- **A1 vanity exists** — `toBeVisible()` and nothing else. Mutation test fails on day one.
- **A2 manual no-wait** — `expect(await x.isVisible()).toBe(true)`. Race guaranteed.
- **A3 CSS structural selector** — couples test to refactor-volatile DOM.
- **A4 hard wait** — `waitForTimeout`. Ban.
- **A5 click without assert** — action with no outcome verification.
- **A6 implementation detail** — `toHaveClass(/menu--open/)` instead of `getByRole('menu').toBeVisible()`.
- **A7 third-party content** — asserting twitter.com loaded after clicking a link to it.
- **A8 monolithic test** — one giant test; first failure hides the rest.
- **A9 `toHaveCount` without using** — counts links, never clicks one. **The classic AI smell.**
- **A10 full text content** — `toContainText('© 2026 Acme. All rights reserved.')` — copy edit breaks test, no real regression.
- **A11 orphan test** — the file exists, reads well, and **nothing collects it**. Indistinguishable from a deleted test, but in the repo it looks like coverage. Ask the runner *this repo actually calls*, never the config: derive the runners from the `test:*` scripts in package.json, then confirm collection (`vitest list <file>`, `playwright test --list <file>`, or the glob in a `node --test`/jest/mocha invocation). **A runner you don't recognise is a HOLE, not a finding** — assuming "vitest or playwright, else orphan" produces false accusations, e.g. against `node --import tsx --test` suites that CI runs perfectly well. The commoner cause is not a bad glob but a `test:*` script **nobody calls**: grep `.github/` and your gate for every one of them. Measured 2026-08-02 across 5 repos: 6 real orphans (a POS **sale + fiscal** layer, the only proof of 2-device sync) — and one whole suite wrongly accused before the runner list was widened.
- **A13 round-trip with no independent oracle** — `inverse(forward(x)) === x` passes even when `forward` is WRONG, as long as the same error sits in both directions: the point maps wrongly, maps back wrongly, and identity holds. It proves CONSISTENCY, not correctness — so a green round-trip says nothing about whether the value is right. Measured: a property round-trip over 200 pseudo-random cases to 1e-9 sat next to **55 of 97 mutants unkilled** (36× arithmetic operator) in the module doing the actual maths; one test asserting an *external* fact (the page's four corners must land exactly on the canvas envelope) took it to 16. Pair every round-trip with something that does NOT use the transform to check it: a geometric/physical fact, a second independent implementation, an authoritative library's value, a hand-computed case, byte-exact content.
- **A12 test in no tsconfig** — the test tree is outside every TS project (`include: ["src"]`, no `references`), so path aliases don't resolve and the fixture import degrades to `any`. The project typecheck then reports **nothing** on a genuine type error, and editors that follow the same project graph have nothing to underline either. You find out in CI. Worse when `typecheck:e2e` runs *before* the e2e job: one TS2322 blocks the whole layer — measured, 3 builds in a row where e2e never started. Check by running, not reading: `tsc -p <cfg> --listFilesOnly | grep <yourtest>` must hit in some project.

## AI signature — what to NOT produce

A senior reviewer recognizes AI-written tests in seconds because the tells **cluster**. Avoid the cluster, not just individual tells.

### Vocabulary blacklist

Never write in code, comments, test names, commit messages, README:

`comprehensive`, `robust`, `ensures`, `leverages`, `seamlessly`, `thoroughly`, `elegant`, `cutting-edge`, `in today's fast-paced world`, `delve into`, `it is important to note`.

These read as machine politeness. Senior writes terse, sometimes ungrammatical: `// gets weird with stale cookies`, not `// This handler ensures robust handling of edge cases`.

### Structural tells (3+ at once = AI-detected)

- Every test has 3 labeled blocks (`// Arrange`, `// Act`, `// Assert`)
- 5-line JSDoc above every 4-line test
- 1:1 component-to-test file mapping (every `Foo.tsx` has `Foo.test.tsx`)
- `should_verb_when_condition_and_state` underscore names everywhere
- Magic numbers in assertions with no provenance comment
- Defensive try/catch around code that can't throw
- ADRs, TEST-CATALOG, OQ-X notation for a 1-day task
- Symmetric file structure — no ragged edges, no in-progress files

Source for magic-number rate: arXiv 2410.10628 measured 99.85% of GPT-3.5 unit tests had Magic-Number-Test smell.

### Human asymmetry

Real codebases are lumpy. Some components are tested via integration, some helpers don't need tests, some files have multiple test files (happy + edge). Test names describe the bug being prevented: `'cart shows 0 when last item removed mid-checkout'`, not `should_handle_cart_state_correctly_when_user_removes_last_item`.

### The causal tell — defendability

Stenberg (Curl), Hashimoto (Ghostty), and reviewer-mental-model research converge on **one** signature that is causal, not correlational:

> "The submission reads beautifully; the author cannot defend it."

Polished prose + collapse on follow-up question = AI-shaped. Every other tell (vocabulary, symmetric structure, magic numbers) is _correlated_ with this. The defendability gate at the end of this skill is the single check that catches the failure mode.

## User-journey heuristic (before / after)

```ts
// BEFORE — static property smell, name is a noun phrase
test("header renders", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByTestId("logo")).toBeVisible();
  await expect(page.getByRole("navigation").getByRole("link")).toHaveCount(5);
});
// Mutation test: delete every href in nav. Test still passes. Useless.

// AFTER — user journey, verb-phrase name, outcomes asserted
test("user navigates from header to pricing then signs in with returnTo", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("navigation")
    .getByRole("link", { name: "Pricing" })
    .click();
  await expect(page).toHaveURL(/\/pricing$/);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Pricing");

  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page).toHaveURL(/\/login\?returnTo=%2Fpricing/);
});
// Fails if: pricing link broken, returnTo logic regresses, auth route changes.
```

## Behavior recognizers (apply mid-write)

- **Cannot name the user goal?** → delete test (Bach: testing protects user value, not code paths)
- **Two Whens — wrote `and`?** → split into two tests
- **Asserting on `data-loaded`, URL query, internal state?** → user can't perceive it; assert visible outcome
- **Setup is 40s of clicking?** → setup via API; assert via UI (Vocke practical pyramid)
- **Test fails on internal-method rename?** → implementation test; rewrite
- **100% happy path?** → add failure scenarios. Card declined, session expired mid-checkout, duplicate submit, 5×wrong-password lockout. Adzic: failure examples are first-class.
- **5+ scenarios with combinatorial params?** → Google SRE: pick 5–7 critical user journeys, drop the Cartesian product
- **Adjective in AC ("handles errors gracefully")?** → unfinished spec. Demand a concrete example before writing the test.

## Decision triggers — should I write / delete / mock?

Apply on sight; these prevent over-coverage and over-mocking AI smells.

- Test catches only TS-checkable errors → **DELETE** (compiler covers it; zero delta coverage)
- Same assertion exists at lower pyramid level → **DELETE the higher one** (Vocke)
- Test asserts mock call sequence with no observable output → **DELETE** (tests the mock, not the code)
- Test would need > 5 mocks → **STOP** — switch to integration with real services (GOOS: listen to the tests)
- Dependency is clock / RNG / UUID / `Date.now()` → **always fake** (`page.clock`, `vi.useFakeTimers`)
- Dependency is third-party library / SaaS → **wrap it, mock the wrapper** (Searls: don't mock what you don't own)
- Dependency is your own code, fast, deterministic → **real, not mock** (Fowler: sociable beats solitary)
- E2E count > 10% of suite → **reject new E2E** unless catching a class no other level can (Google 70/20/10)
- Flaky > 2 sprints, no owner fixing it → **DELETE or rewrite with fakes** — never quarantine indefinitely (silent deletion with maintenance cost)
- `it.skip` / `@Disabled` without ticket reference and date → **DELETE** (FSE 2021: most stay disabled forever)

## Test-data anti-patterns (recognizer cues)

Match these in any test file under review; each is a real production-incident class.

- **Hardcoded creds** — `password: 'Admin123!'`, `API_KEY = 'sk_live_...'` in test source. GitGuardian 2026: 28.65M secrets pushed to public GitHub in 2025. Fix: per-env `.env` (gitignored), test users via API with random passwords.
- **Disabled-and-forgotten** — `it.skip(...)` / `xit(...)` / `@Disabled` without ticket+date. Fix: skip only with `// JIRA-1234, 2026-04-15` annotation; CI fails skips older than N days.
- **Wall-clock test** — `new Date()` / `Date.now()` inside SUT, real time in test. Bites on DST transitions, leap day, midnight UTC. Fix: inject Clock; `page.clock.install({ time: ... })`. Run a CI job pinned to Feb 29.
- **Faker without seed in branch logic** — `if (faker.number.int({max: 10}) > 5)` flakes 1/50 in CI. Fix: `faker.seed(N)` per test, or only use Faker for _shape_ (any string).
- **Faker generating real domains** — `faker.internet.email()` returns `@gmail.com` / `@yahoo.com` real addresses; signup tests email actual humans. Fix: `faker.internet.email({ provider: 'example.com' })` (RFC 2606 reserved) or `qa+${uuid}@example.com`.
- **Real PII in non-prod** — `pg_dump prod | psql staging`. GDPR Art. 5/25 violation; bounce-rate poisons sender domain. Fix: masking pipeline (postgresql-anonymizer, Microsoft Presidio); block egress from CI to real SMTP/SMS.
- **Hardcoded ID coupling** — `expect(api.get('/users/42'))` assumes user 42 exists forever. Fix: create the user in `beforeEach`, capture the returned ID.
- **Shared mutable fixture ordering** — `beforeAll(seed); test('A modifies row 1'); test('B reads row 1')`. Passes serial, fails parallel. Fix: `beforeEach` per-test data with UUID suffix.
- **Multi-tenant cross-contamination** — parallel tests both write to `workspace = 'qa-shared'`; assertions count rows globally. Fix: each test gets fresh `tenant_id` (UUID); query by it.

## Real-world patterns (worth stealing — element-hq/element-web, microsoft/playwright)

```ts
// Linear fixture extension — never mergeTests, it collapses TS types to any
export const test = base.extend<{ axe: AxeBuilder }>({
  axe: async ({ page }, use) => { await use(new AxeBuilder({ page })); },
});

// Per-test unique user via testInfo.testId — no DB cleanup, isolation by namespace
credentials: async ({ homeserver }, use, testInfo) => {
  const creds = await homeserver.registerUser(`user_${testInfo.testId}`, ...);
  await use(creds);
},

// Kill 90% of CSS-animation flake in one line
await page.addStyleTag({
  content: `*, *::before, *::after { transition: none !important; animation: none !important; }`,
});

// Two-signal flake handling — URL is canonical; DOM is best-effort
await page.waitForURL((url) => url.search.includes(slug));    // strong signal
try { await expect(link).toHaveAttribute("data-selected", "true", { timeout: 1000 }); }
catch { /* unmounted on mobile drawer; URL already confirmed */ }

// storageState gotcha — login page MUST start with no auth
const page = await browser.newPage({ storageState: undefined });
```

## Reviewer's 30-second triage — what gets opened first

A senior reviewer rejects in minutes by triaging in this order. Optimize the _shape_ of the submission for this scan, not for "comprehensive coverage."

1. **README** (30s) — terse + honest about gaps wins; polished + "comprehensive" loses. GitHub Engineering strips git history from take-homes because it leaks process; reviewers re-derive process from README + commits.
2. **Folder tree** (30s) — asymmetric (human under time pressure: one POM full, another a stub) wins; symmetric (every folder filled, every file similar size) loses. Sam Saffron: "asymmetry — code that took seconds to create but hours to review."
3. **`git log`** (30s) — many small commits with human messages ("wip", "fix typo") wins; one or two giant "initial commit" loses.
4. **One random test file** (1–2 min) — pick one assertion, mentally delete the line of production code it depends on. Did the test break? If no, the file is theatre.
5. **The "walk me through this" question** — the kill-shot. If you can't defend a single decision in 60s without "best practice" or "framework picked", the rest is not read.

CEE reviewers (Slovak/Czech/Polish) compress this to 10–20 minutes max. Verdicts get relayed verbatim ("Roman povedal: vyslovene strojové"). Terseness over comprehensiveness is the regional preference, not a quirk — "comprehensive" reads as smell, not praise. See `references.md` for the CEE rejection register and full reviewer mental model.

## Documentation discipline (1-day / take-home / showcase tasks)

1. README ≤ 50 lines. What it is, how to run, what's tested (1 sentence each), known limitations.
2. **No ADRs.** Production codebase only.
3. **No TEST-CATALOG, no CHANGELOG, no `OQ-X` notation, no "Engineering decisions of note".**
4. Inline comments: only for non-obvious **why**. Never **what** (the code says what).
5. Commit messages: `cover header, footer, search` — not `feat: aggressive bug-finding suite expansion + 6 ADRs`.
6. One README table is enough. Multiple "by priority / by dimension / by project" tables = AI smell.

## Scoping discipline

If brief says "test X": stay in X. Drop SEO meta, robots.txt, JSON-LD, perf, dup-IDs unless explicitly asked.

Sanity check: would this test still make sense if the brief changed from X to Y? If yes, it's not an X test.

## Self-check (run before declaring done)

- [ ] Mutation-tested mentally — would test fail if I delete the line being tested?
- [ ] Test name is a verb phrase describing the user journey
- [ ] Every action followed by an outcome assertion
- [ ] Every click preceded by a `toBeVisible()` sanity guard on the affordance
- [ ] No `toHaveCount(N)` without using one of N
- [ ] No `waitForTimeout`, no `.not.toBeVisible`
- [ ] Selectors are role / label / testId only
- [ ] One When per test (no "and also" in description)
- [ ] Setup via API where UI isn't the user goal
- [ ] No magic numbers without provenance
- [ ] Test scope matches the brief
- [ ] No ADRs / CATALOG / CHANGELOG for 1-day task
- [ ] No vocabulary-blacklist words
- [ ] **Defendability gate** — can I defend every file and every decision in 60 seconds, **without** saying "best practice" or "framework picked"? If no, delete or rewrite until yes. This is the single causal check; everything above is correlation.

## Out of scope (other skills own these)

- New test creation workflow → `write-tests`
- Refactoring existing tests → `improve-tests`
- Scenario design from Jira/AC → `test-strategy`
- E-commerce / checkout / cart / payment / Stripe specifics, money math, idempotency, PCI guards, customization uploads → `ecommerce-testing-patterns`
- Author quotes, full taxonomies (Meszaros, Fowler doubles), advanced patterns (Pact, property-based, approval, metamorphic, Sandi Metz outgoing queries), reviewer mental model, CEE rejection register, visual regression tool decision → `references.md` in this skill folder

Read `references.md` only when you need a citation, a less-common pattern, or to defend a choice in code review.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Je aspoň jedna visibility v každom teste VÝSLEDKOM akcie, nie sanity guardom pred klikom — a potvrdil každé obvinenie z osirotenia skutočný runner z `test:*`, nie tvoj menoslov?
