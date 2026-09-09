---
name: readme-test-repo-pattern
description: Use when writing or restructuring a README for an E2E / test repository (Playwright, Cypress, Selenium, integration suites). Multi-angle pivot tables, bug-class column, layer annotations, honest pass-rate. Triggers on "test repo README", "test suite documentation", "restructure README", "README best practices for tests", "review README". Do not use for a general application or library README (use generate-documentation).
---

# README pattern for E2E / test repositories

## The senior-reviewer test

A reviewer (CEE-style: Slovak/Czech/Polish, terse) opens README. **30 seconds**: do they understand what's tested, from how many angles, with what techniques? If no — repo is read as AI-generated. The whole pattern below optimizes that 30-second window.

## What top suites DON'T do (the moat)

Survey of microsoft/playwright, element-hq/element-web, clerk/playwright-e2e-template, AndriiFrolov/playwright-portfolio, larsschieffer/outlook-playwright-e2e: **almost all** stop at "title + npm install + run command". `microsoft/playwright/tests/` has NO per-folder README; `element-hq/element-web/apps/web/playwright/` has NO README at all. **Doing the substance work below is the differentiator** — there's no established pattern competing with it.

## Volatile numbers must be CI-derived

Never hand-type a pass-rate or test count — it's stale on the next commit and reads as fabricated. Use a **dynamic shields.io badge** wired to CI output. Keep to **2-4 badges** (build, coverage, tests) — a badge wall is AI-smell. Gate the README itself with markdownlint + a link-checker in CI, and date-stamp any manual survey.

## The 3-pivot structure

A single 40-row inventory is unscannable; reviewer can't see "do they cover X from 3 angles?" at a glance. Use **three small pivots** with column headers that advertise the angles you care about.

### Pivot 1 — Journey × state × surface

Visual checkmark grid. Shows breadth at a glance. Same journey can touch header, footer, both — and behave differently per user state.

```markdown
| Journey              |   State   | Header | Footer |  Cross-page  |
| -------------------- | :-------: | :----: | :----: | :----------: |
| FIND (search submit) |   both    |   ✓    |        |              |
| CART (guest)         | anonymous |   ✓    |        |              |
| CART (persisted)     | logged-in |   ✓    |        |              |
| FOOTER LINKS (×16)   |   both    |        |   ✓    |              |
| RENDER consistency   |   both    |        |        | ✓ (5 routes) |
```

### Pivot 2 — Journey × variant × state × bug-class caught

The senior-reviewer hook. Every row answers "what bug would slip into production if this test didn't exist?" — not "what does this test do?"

```markdown
| Journey     | Variant |   State   | Bug-class caught                                   | Asserted via                                     |
| ----------- | :-----: | :-------: | -------------------------------------------------- | ------------------------------------------------ |
| FIND        | **POS** |   both    | Algolia returns 0 hits but route resolves OK       | `productLinks.count() > 2`                       |
| FIND        | **NEG** |   both    | Empty submit silently navigates user away          | `page.url()` unchanged after Enter               |
| LOGIN       | **POS** | anonymous | Form regresses from passwordless to password-based | "Continue With Email" + OAuth visible            |
| FOOTER LINK | **POS** |   both    | Wired to `/foo` but `/foo` is 200-OK custom 404    | heading `not.toHaveText(/page not found\|^404/)` |
```

**Variant column is critical** — POS / NEG / EDGE makes happy / failure / boundary paths scannable. Use **bold** for visual weight; centered alignment.

**State column** — both / anonymous / logged-in. Many bug-classes only manifest in one state.

**Bug-class column tags** (re-usable vocabulary): `auth-bypass`, `idempotency`, `race`, `silent-fail`, `redirect-chain`, `state-leak`, `xss`, `i18n`, `a11y`.

### Pivot 3 — Test × layer / technique

Shows technique depth — tests aren't all driven through the slowest UI layer.

```markdown
| Layer / technique                                           | Tests       | Where                                  |
| ----------------------------------------------------------- | ----------- | -------------------------------------- |
| `[POM]` Page-object actions                                 | most        | `HeaderComponent` + `FooterComponent`  |
| `[FIX]` `page.goto` default `waitUntil: domcontentloaded`   | all         | `pages.fixture.ts` page override       |
| `[STO]` `storageState: storage/auth.json`                   | logged-in 9 | `chromium-desktop-authed` project      |
| `[NET]` `Promise.all([waitForURL, click])` (URL as outcome) | ~25         | nav-after-click pattern                |
| `[A11Y]` `aria-expanded` state                              | 4           | mega-menu open/close + replace         |
| `[ALLOWLIST]` console / pageError / request allowlist       | cross-cut   | `pages.fixture.ts` `monitorPageHealth` |
```

**Layer codes:** `[POM]` page-object, `[FIX]` fixture-seeded state, `[NET]` network/URL outcome, `[STO]` storageState reuse, `[API]` request-context only, `[A11Y]` accessibility-state, `[ALLOWLIST]` cross-cutting allowlist.

## Top-of-README order

```
# Title
1-line tech-stack description
1-sentence bug-class lede ("Catches passwordless-login regressions, ...")
> [!TIP] Skip to Pivot 2 for the bug-class matrix

## Quick start
4-line code block

## What we test per state (open, NOT collapsed)
[chrome diff table + bullets per state]

## Pivot 1 — Journey × state × surface
## Pivot 2 — Journey × variant × state × bug-class
## Pivot 3 — Test × layer / technique

## Variant policy / Auth gating
## Architecture
  ### Engineering decisions in 60 seconds (Decision -> Trade-off -> Why)
  [link to ADRs]

## Running tests / CI/CD / Site behaviors the suite handles

## What a failed test looks like
[points at HTML report + trace viewer — npm run test:report]

## Open questions

## Bug-classes this suite would NOT catch
[the seniority-signal appendix — name your blind spots]

## Scoped out (and why)
[dimensions explicitly cut + rationale for re-adding]
```

## Patterns to ADOPT

1. **First screen = inventory, NOT story.** Reviewer's 30s clock starts at line 1. Put narrative below the pivots — but do NOT collapse the journey-bullet narrative if the reviewer wants it visible (depends on stakeholder preference; Pivot 2 stays open in either case).
2. **Bug-class column.** Every test row answers "what slips if absent?" — that's the senior-reviewer hook. Without it, a row is a description; with it, a row is a defended decision.
3. **Variant column** (`POS / NEG / EDGE`). Don't pack variants into row names. Don't prefix test names with `positive:/negative:/edge:` — the README pivot column does that job; the test name should read as natural-language documentation.
4. **State column** when tests run in multiple user states. `both / anonymous / logged-in` — most bug-classes only manifest in one. Use `<br>` to stack `Guest<br>Logged-in` in one cell when both apply (markdown tables don't allow real newlines; `<br>` is the only option).
5. **Layer codes** `[POM] [FIX] [NET] [STO] [API] [A11Y] [ALLOWLIST]` to advertise technique depth.
6. **One screen budget for inventory.** Pivots fit; detail narratives can be open below them.
7. **Bug-class lede sentence** before Quick Start. One sentence: "Catches passwordless-login regressions, server-cart loss on reload, 200-OK custom 404 footer drift." Reviewer immediately knows you think in failure modes, not features.
8. **GitHub `> [!TIP]` callout** above Quick Start — ONE, max. GitHub renders these as styled alerts since 2023. Use the alert syntax (`> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`) — appears as colored callout box, not just italic. Two+ alerts read as noise.
9. **Engineering decisions in 60 seconds** mini-table inside Architecture section. 3-5 rows: `Decision → Trade-off → Why`. Reviewers consistently say "show me how you think" — this is the cheapest place to do it. Format example: `POM only for Web Components → more files; no BasePage god-class → page churn doesn't ripple`.
10. **Mermaid sequence diagram for ONE representative journey** in collapsed `<details><summary>Journey diagram — X</summary>...</details>`. GitHub renders Mermaid natively since 2022. Pick the journey that catches the most-impressive bug-class (e.g., passwordless LOGIN → catches password-field regression). One diagram, not a wall.
11. **"What a failed test looks like" section** pointing at HTML report + trace viewer. 2 sentences + `npm run test:report` command. Most candidates never include this — reviewer screenshots the section as evidence you actually run the suite.
12. **"Bug-classes this suite would NOT catch" appendix** — 4-7 bullets naming your blind spots (visual regression, perf budget, multi-tab session sync, payment provider, cross-browser, real-email deliverability, concurrent writes). **Strongest seniority signal in the document** — inverts the junior instinct to overclaim coverage. No public Playwright README has this.
13. **"Scoped out (and why)"** rename — never use "Possible future additions" or "TODO" headers. The framing changes from "I didn't finish" to "I made a deliberate cut."
14. **Honest pass-rate (optional).** Date-stamped `passed / failed / wall-time` table at top is a strong AI-not-generated signal — but ONLY if number is ≥90%. Below 90% it self-DOSes the rest of the README; reviewer drills into every fail. Better to omit than to lie.
15. **Repo-shield row** under H1 — single line, ≤7 badges, in this order: `CI · Last run · Tests N · Avg wall-time · Pass-rate · Node · Playwright`. Use `img.shields.io/endpoint` for dynamic, `img.shields.io/badge` for static. Anti-pattern: badge wall (>7) reads as decoration.
16. **CI badge** instead of manual pass-rate numbers when possible — auto-updates, never stale.
17. **Known failures section** when honest. Pattern table with `Failure pattern | Tests affected | Root-cause hypothesis`. Shows you own the gaps, not pretending they don't exist. Drop after fixes land.

## Patterns to AVOID

| Anti-pattern                                                                   | Why it fails the 30s test                        |
| ------------------------------------------------------------------------------ | ------------------------------------------------ |
| One giant 40-row test inventory                                                | Unscannable; reviewer can't see angles           |
| Story narrative as the FIRST section                                           | Burns the 30s budget on prose, not data          |
| `should_X_when_Y` snake_case test names everywhere                             | AI structural tell #4 from real-testing-patterns |
| Test names with `positive:/negative:/edge:` prefix                             | Machine label, not natural language              |
| Adjective-only descriptions ("comprehensive coverage")                         | Vocabulary blacklist hit                         |
| ADRs for a 1-day project                                                       | "ADRs for take-home" is AI-smell signature       |
| TEST-CATALOG.md with N-row matrix                                              | Duplicates README + lives until stale            |
| Browser/viewport trivia (`Pixel 5`, `iPhone 13`) without mobile-specific tests | Vanity coverage advertised in config             |
| Wall-time numbers from a DIFFERENT run state                                   | Stale = worse than absent                        |
| `OQ-N` references to deleted Test #N                                           | Broken refs scream "didn't proofread"            |
| Roadmap items pointing at deleted files                                        | Same                                             |

## Reference

Survey of repos sourced via WebSearch + WebFetch:

- [microsoft/playwright README](https://github.com/microsoft/playwright/blob/main/README.md)
- [element-hq/element-web playwright suite](https://github.com/element-hq/element-web/tree/develop/apps/web/playwright)
- [Playwright tag annotations](https://playwright.dev/docs/test-annotations)
- [BrowserStack: Playwright tags guide](https://www.browserstack.com/guide/playwright-tags)
- [Adequatica: Ways to Organize End-to-End Tests](https://adequatica.medium.com/ways-to-organize-end-to-end-tests-76439c2fdebb)

Pattern is **not derived from any single source** — it's the synthesis from the survey + senior-reviewer mental model in the `real-testing-patterns` skill (CEE rejection register).

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Dokázal si pri každom riadku „Bug-class caught", že test sčervenie, keď tú chybu vneseš?
