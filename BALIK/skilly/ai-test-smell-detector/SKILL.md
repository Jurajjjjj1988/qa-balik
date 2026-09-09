---
name: ai-test-smell-detector
description: Quick-scan checklist for detecting AI-generated test code patterns. arXiv 2410.10628 found 99.85% of GPT-3.5 unit tests have the Magic-Number-Test smell. Use when reviewing AI-generated PRs, after a Claude session, or when test code "feels symmetric". Detects 10 telltale patterns. This is a read-only SCAN — do not use to author or rewrite tests (new E2E/UI tests are write-tests / layered-playwright-suite, hardening existing ones is improve-tests, the full anti-pattern catalog is real-testing-patterns), nor for non-test production code (anti-ai-slop).
---

# AI Test Smell Detector

## TL;DR

- **Look for clusters, not items.** One magic number is fine. Three magic numbers + 19-line JSDoc header + symmetric describe blocks = AI-shaped. The smells co-occur; the cluster is the tell.
- **Fix the highest-severity smells first.** Magic numbers and vanity assertions ship bugs to production. Comment essays and bilingual labels are taste, not correctness — fix them last.
- **Trust the "feels symmetric" intuition.** If every describe has exactly three tests and every test has exactly four lines, a machine wrote it. Real humans write lumpy codebases.

## Background — why this is measurable, not vibes

arXiv [2410.10628 — On the Diffusion of Test Smells in LLM-Generated Unit Tests](https://arxiv.org/abs/2410.10628) analyzed 20,505 LLM-generated test suites. The headline numbers:

- **99.85%** of GPT-3.5 unit tests had the _Magic-Number-Test_ smell.
- **48.67%** had _Lazy-Test_ (asserts nothing meaningful).
- **46.94%** had _Assertion-Roulette_ (multiple unrelated `expect`s in one test).
- **22–45%** had _Eager-Test_ (one test exercises a whole workflow).

Followup work ([arXiv 2510.03029](https://arxiv.org/pdf/2510.03029), [arXiv 2511.15817](https://arxiv.org/html/2511.15817)) confirms LLMs produce **categorically different** smells than humans. Humans skew toward state-management smells (shared fixtures, cross-test contamination). LLMs skew toward procedural ones (magic numbers, exhaustive AAA labels, symmetric coverage). Codex was the worst offender (84.97% smell increase rate over human baseline); even the best (Falcon) sat at 42.28%.

The point: the AI cluster is **statistically detectable**. A senior reviewer who says "this feels machine-written" is reading the cluster, not vibing. This skill makes that scan systematic so a junior can do it too.

Mark Seemann's Dec 2025 post [Treat test code like production code](https://blog.ploeh.dk/2025/12/01/treat-test-code-like-production-code/) makes the complementary point: tests deserve the same review discipline as production code. Most AI smells survive into PRs because reviewers grade test code on a curve. Stop doing that.

CEE reviewers (SK/CZ/PL) compress AI-detection to 10–20 minutes max and call it out flatly — "vyslovene strojové" ("outright machine-written"). The regional preference for terseness over comprehensiveness makes AI cluster particularly conspicuous; what reads as "thorough" in a US/UK shop reads as "smell" in a Prague code review.

---

## The 10 detectors

Each detector has: **name**, **signal** (what to grep), **why** (1–2 sentences), **before/after**, **severity**.

### Detector 1 — Magic-Number-Test smell

**Signal:** Hardcoded numbers (or string literals) inside `expect(...)` with no source comment.

**Why:** The single most-frequent AI test smell — arXiv 2410.10628 measured 99.85% incidence on GPT-3.5. The reader has no idea whether `42` is significant, arbitrary, derived from setup, or a typo. Six months later, nobody touches the test because they don't understand it.

```ts
// BEFORE — what does 42 mean? Did the AI roll dice?
test("user can update name", async ({ page }) => {
  await page.goto("/users/42");
  await page.getByLabel("Name").fill("New Name");
  await expect(page.getByTestId("user-id")).toHaveText("42");
});

// AFTER — derive from setup, or extract with reason
test("user can update name", async ({ page, api }) => {
  const user = await api.createUser({ name: "Old Name" });
  await page.goto(`/users/${user.id}`);
  await page.getByLabel("Name").fill("New Name");
  await expect(page.getByTestId("user-id")).toHaveText(user.id);
});
```

**Severity: Critical.** Magic numbers ship bugs because they couple tests to brittle test-data assumptions. Fix on sight.

### Detector 2 — Symmetric file structure

**Signal:** Every component has exactly one `*.test.ts` file. Every describe has 3–5 tests. Every test is 4–8 lines. The repo tree looks like it was raked.

**Why:** Real codebases are **lumpy**. Some components are tested via integration only (no spec file). Some have three test files (happy + edge + bug-regression). Some specs have 12 tests, others 1. Symmetric structure is the visual signature of a machine that didn't have a release deadline.

```text
# BEFORE — symmetric, every file balanced. Human under deadline does not produce this.
src/
  components/
    Header/
      Header.tsx
      Header.test.tsx          # 4 tests, 60 lines
    Footer/
      Footer.tsx
      Footer.test.tsx          # 4 tests, 58 lines
    SearchBar/
      SearchBar.tsx
      SearchBar.test.tsx       # 4 tests, 61 lines

# AFTER — lumpy, asymmetric. Real humans write this.
src/
  components/
    Header/
      Header.tsx
      Header.test.tsx          # 2 tests covering the sticky-on-scroll bug we hit in Q3
    Footer/
      Footer.tsx               # tested via e2e checkout flow, no unit spec
    SearchBar/
      SearchBar.tsx
      SearchBar.test.tsx       # 1 happy + 1 regression (LINEAR-1842)
      SearchBar.a11y.test.tsx  # split out after the screen-reader incident
```

**Severity: Major.** Symmetric structure isn't a bug per se, but it's the strongest correlational tell — a senior reviewer scans the tree and forms an opinion in 30 seconds. See [Sam Saffron's slop-PR post](https://samsaffron.com/archive/2025/10/27/your-vibe-coded-slop-pr-is-not-welcome): "asymmetry — code that took seconds to create but hours to review."

### Detector 3 — Comprehensive coverage paradox

**Signal:** Tests cover every branch including the trivially obvious. Constructor tests. Getter tests. Tests that assert defaults match defaults.

**Why:** LLMs are trained on "test coverage = quality" without the human prior of "test where bugs actually live." A senior writes 3 tests on the auth flow and 0 on the React rendering of a static `<h1>`. AI writes 4 of each.

```ts
// BEFORE — vanity coverage, the constructor literally cannot fail
describe("User class", () => {
  it("constructs with a name property", () => {
    const u = new User({ name: "Alice" });
    expect(u.name).toBe("Alice");
  });
  it("constructs with an email property", () => {
    const u = new User({ email: "a@b.com" });
    expect(u.email).toBe("a@b.com");
  });
  // ...20 more like this
});

// AFTER — test where bugs actually hide
describe("User", () => {
  it("normalizes email to lowercase before save", () => {
    const u = new User({ email: "Alice@BIG.com" });
    expect(u.email).toBe("alice@big.com");
  });
  it("rejects construction with invalid email and includes field in error", () => {
    expect(() => new User({ email: "not-an-email" })).toThrow(/email/);
  });
});
```

**Severity: Major.** Comprehensive-but-shallow suites are worse than no suite — they consume CI time, paper over bug-prone areas, and create false confidence. See [Kent C. Dodds on testing implementation details](https://kentcdodds.com/blog/testing-implementation-details).

### Detector 4 — Procedural test style (AAA labels everywhere)

**Signal:** Every test has `// Arrange`, `// Act`, `// Assert` comment labels. Or worse: `// 1. Setup`, `// 2. Action`, `// 3. Verify`.

**Why:** AAA is a useful mental model. AAA as **literal comment labels in every test** is the procedural-test giveaway. Humans use the structure; they don't narrate it. The labels are also a strong signal that the test was generated from a template — and templated tests rarely catch real bugs.

```ts
// BEFORE — AAA labels are pure noise; the structure is self-evident
test("user submits checkout", async ({ page }) => {
  // Arrange
  await page.goto("/checkout");
  const cart = page.getByTestId("cart");
  // Act
  await page.getByRole("button", { name: "Place order" }).click();
  // Assert
  await expect(page.getByRole("heading")).toHaveText("Order confirmed");
});

// AFTER — let the code speak; comments only carry the WHY
test("user submits checkout", async ({ page }) => {
  await page.goto("/checkout");
  await page.getByRole("button", { name: "Place order" }).click();
  await expect(page.getByRole("heading")).toHaveText("Order confirmed");
});
```

**Severity: Minor (alone) / Critical (clustered).** A single `// Arrange` is fine. The same labels in every test in the file = AI. See `real-testing-patterns/SKILL.md` "Structural tells" section.

### Detector 5 — Excessive comment essays above small test bodies

**Signal:** 10–20 line JSDoc block above a 5-line test. Sentences like "Comprehensive test ensuring robust handling of edge cases for seamless user experience."

**Why:** The dead giveaway. Humans don't write essays above 5-line tests. They write a verb-phrase test name and let the code carry the rest. AI hedges with prose because it was trained to.

```ts
// BEFORE — 8 lines of comment for a 3-line test
/**
 * Comprehensive test suite for user authentication.
 * This test ensures that the login functionality works correctly
 * when valid credentials are provided. It validates the seamless
 * user experience by verifying redirect behavior.
 *
 * @author AI-generated
 */
test("login redirects to dashboard", async ({ page }) => {
  await login(page, "user@example.com", "password");
  await expect(page).toHaveURL(/dashboard/);
});

// AFTER — the test name says everything; no header comment needed
test("login redirects to dashboard", async ({ page }) => {
  await login(page, "user@example.com", "password");
  await expect(page).toHaveURL(/dashboard/);
});
```

**Vocabulary blacklist** (canonical list lives in `real-testing-patterns`; test-specific additions here) — if you see any of these in a test file, smell increases sharply:

`comprehensive`, `robust`, `ensures`, `leverages`, `seamlessly`, `thoroughly`, `elegant`, `cutting-edge`, `in today's fast-paced world`, `delve into`, `it is important to note`, `ensuring`, `validates`, `verifies`, `properly handles`.

A senior tester writes `// gets weird with stale cookies`, not `// This handler ensures robust handling of edge cases`.

**Severity: Major.** Pure noise. Delete on sight. The exception: comments that carry _why_ — `// Stripe rate-limits us at 25 req/s` — those stay.

### Detector 6 — `waitForTimeout` and hard waits

**Signal:** `await page.waitForTimeout(2000)`, `await sleep(500)`, `setTimeout(... , 1000)` inside a test.

**Why:** Senior testers use `expect.poll`, web-first assertions, or `waitForResponse`. LLMs hedge with arbitrary timeouts because their training data is full of 2018-era Selenium tutorials that did the same. Hard waits are simultaneously flaky and slow — they wait too long when the app is fast and not long enough when CI is loaded.

```ts
// BEFORE — slow AND flaky, the unholy combo
await page.getByRole("button", { name: "Submit" }).click();
await page.waitForTimeout(3000); // "give it time to load"
await expect(page.getByText("Success")).toBeVisible();

// AFTER — web-first assertion auto-waits with retry
await page.getByRole("button", { name: "Submit" }).click();
await expect(page.getByText("Success")).toBeVisible(); // auto-waits up to 5s
```

For genuinely eventual operations (webhook fires, async job completion), use `expect.poll`:

```ts
await expect
  .poll(() => api.getOrderStatus(orderId), {
    intervals: [250, 500, 1000, 2000],
    timeout: 10_000,
    message: "wait for Stripe webhook → order=paid",
  })
  .toBe("paid");
```

**Severity: Critical.** Hard waits are banned by the user's global rule. Replace on sight.

### Detector 7 — Defensive `.catch(() => false)` and try/catch around assertions

**Signal:** `.catch(() => false)`, `try { await expect(...) } catch { /* ignore */ }`, generic `.catch(() => {})` to swallow errors.

**Why:** Either handle the error or let Playwright fail the test. Wrapping assertions in try/catch turns a clear failure ("button never appeared") into a silent pass. The AI tendency to defensively wrap everything is one of the strongest correlational tells — it's also one of the most damaging because the suite reports green forever.

**Not every catch is this smell.** A teardown `.catch(() => {})` on cleanup (`context.close().catch(...)`) masks no assertion, and a best-effort *secondary* check whose *primary* signal already passed (the two-signal URL-canonical pattern in `real-testing-patterns`) is a documented resilience move — not a swallow. Flag catches that turn an ASSERTION into a silent pass. The 30-second grep also *misses* `.catch((e) => false)` (it wants empty `()`), so eyeball for that variant too.

```ts
// BEFORE — silently masks the regression
const visible = await profilePage.successBanner
  .isVisible({ timeout: 5_000 })
  .catch(() => false);
expect(visible).toBeTruthy();
// If isVisible THROWS (e.g. context closed), test passes with `false`.

// AFTER — explicit, fails loudly when the affordance is broken
await expect(profilePage.successBanner).toBeVisible({ timeout: 5_000 });
```

**Severity: Critical.** Silently masks failures. The Investown audit (`test-syntax-audit-report.md` Issue 5) flagged this in `profile.spec.ts:382-389` — the test even had a comment _defending_ the pattern, which is worse than not having it at all.

### Detector 8 — Vanity assertions

**Signal:** `await expect(x).toBeVisible()` as the only assertion in a test. `await expect(input).toHaveValue("foo")` right after `await input.fill("foo")`. Asserting that a label renders ("the heading exists").

**Why:** These are trivially true. The mutation test (delete the line under test — does the assertion still pass?) is the entry gate. A test that passes after the implementation is gutted is theatre.

```ts
// BEFORE — A1 vanity. If the dev replaces the page with <h1>Hello</h1>, this still passes.
test("personal data renders", async ({ profilePage }) => {
  await profilePage.gotoSection("personalData");
  await expect(profilePage.personalData.heading).toBeVisible();
});

// AFTER — assert what the user actually sees and what the contract guarantees
test("personal data shows API name, email, and formatted phone", async ({
  profilePage,
}) => {
  await profilePage.gotoSection("personalData");
  await expect(profilePage.personalData.nameValue).toHaveText(
    DEFAULT_USER_DISPLAY.fullName,
  );
  await expect(profilePage.personalData.emailValue).toHaveText(
    DEFAULT_USER_DISPLAY.email,
  );
  await expect(profilePage.personalData.phoneValue).toHaveText(
    DEFAULT_USER_DISPLAY.phoneFormatted, // backend gives raw; UI formats
  );
});
```

**Severity: Critical.** A test that doesn't catch bugs is worse than no test — it's a maintenance liability that creates false confidence. The Investown audit flagged Issue 9 exactly here (`profile.spec.ts:58`).

### Detector 9 — Multi-clause test names with "and"

**Signal:** Test titles like `"validates input and shows error message"`, `"loads user and renders profile"`, `"Czech is initially selected and clicking English flips the radios"`.

**Why:** Two behaviors joined by "and" should be two tests. When the test fails, the report says "X and Y broke" — you can't tell which one. A failing test should point at the regression with one finger, not two.

```ts
// BEFORE — two When clauses, one test
test("Czech is initially selected and clicking English flips the radios", async ({
  profilePage,
}) => {
  await profilePage.gotoSection("notifications");
  await expect(profilePage.notifications.czechRadio).toBeChecked();
  await profilePage.notifications.englishRadio.click();
  await expect(profilePage.notifications.englishRadio).toBeChecked();
});

// AFTER — one behavior per test, failure report points exactly
test("Czech is initially selected", async ({ profilePage }) => {
  await profilePage.gotoSection("notifications");
  await expect(profilePage.notifications.czechRadio).toBeChecked();
});

test("clicking English flips the radios", async ({ profilePage }) => {
  await profilePage.gotoSection("notifications");
  await profilePage.notifications.englishRadio.click();
  await expect(profilePage.notifications.englishRadio).toBeChecked();
});
```

**Severity: Major.** The Investown audit caught this in `profile.spec.ts:357`. Also see `real-testing-patterns` "One When per test."

### Detector 10 — Identical setup repeated across describes

**Signal:** The same 4–6 lines of setup repeated at the top of every `it` block when an obvious `beforeEach` or fixture would consolidate them.

**Why:** AI duplicates because it generates each test in isolation. Humans extract on the second copy. The duplication itself isn't the smell — the _refusal to extract_ is. (Note: DAMP says don't over-extract; the boundary is "would extraction hide the failure narrative?" If extraction just removes boilerplate, extract.)

```ts
// BEFORE — same 3 lines of setup in every test
describe("checkout", () => {
  it("shows cart total", async ({ page }) => {
    await page.goto("/checkout");
    await page.getByRole("button", { name: "Accept cookies" }).click();
    await expect(page.getByTestId("cart-total")).toHaveText("$42.00");
  });
  it("shows shipping options", async ({ page }) => {
    await page.goto("/checkout");
    await page.getByRole("button", { name: "Accept cookies" }).click();
    await expect(page.getByText("Standard shipping")).toBeVisible();
  });
  it("shows payment form", async ({ page }) => {
    await page.goto("/checkout");
    await page.getByRole("button", { name: "Accept cookies" }).click();
    await expect(page.getByLabel("Card number")).toBeVisible();
  });
});

// AFTER — a fixture extracts setup; tests read top-to-bottom
const checkoutTest = base.extend({
  page: async ({ page }, use) => {
    await page.goto("/checkout");
    await page.getByRole("button", { name: "Accept cookies" }).click();
    await use(page);
  },
});

checkoutTest("shows cart total", async ({ page }) => {
  await expect(page.getByTestId("cart-total")).toHaveText("$42.00");
});
checkoutTest("shows shipping options", async ({ page }) => {
  await expect(page.getByText("Standard shipping")).toBeVisible();
});
checkoutTest("shows payment form", async ({ page }) => {
  await expect(page.getByLabel("Card number")).toBeVisible();
});
```

**Severity: Minor.** The Investown audit flagged this as Issue 2 — twelve copies of `await profilePage.gotoSection("X")` in `profile.spec.ts`. Fixture extraction is the canonical fix.

---

## Detection workflow

```
1. Open the file. Read the first 3 tests + the file structure.
2. Apply the 10-detector checklist (one pass per file).
3. Score:
   - 0–3 smells   → human-written (or AI with disciplined editing)
   - 4–7 smells   → AI-assisted (humans accepted suggestions without trimming)
   - 8+ smells    → AI-generated, untouched (likely; verify with defendability gate)
4. Order findings by severity:
   - Critical first: Detectors 1, 6, 7, 8 (ship bugs)
   - Major next:    Detectors 2, 3, 5, 9 (review-rejection-grade)
   - Minor last:    Detectors 4, 10        (taste, refactor when nearby)
5. Apply fixes in PRs of ~10 tests max. Don't do a 200-test sweep in one PR.
```

### The defendability gate

After the 10 detectors, run the **causal check** (this subsumes all correlational tells):

> "Can the author defend each test in 60 seconds, without saying 'best practice' or 'standard pattern'?"

If no, the test is AI-shaped regardless of how it scores on the checklist. Polished prose + collapse on follow-up question = the failure mode. See [Stenberg's "Death by a thousand slops"](https://daniel.haxx.se/blog/2025/07/14/death-by-a-thousand-slops/), [Sam Saffron's slop-PR post](https://samsaffron.com/archive/2025/10/27/your-vibe-coded-slop-pr-is-not-welcome).

---

## What's NOT an AI smell (false positives to ignore)

Some patterns look AI but are legitimate. Don't reflexively delete:

- **Long JSDoc on _public API_ functions in the POM** — `profilePage.fillCurrentPassword()` deserves a docstring explaining when to call it and what it leaves on the page. Public surface ≠ test body.
- **`// Verified via chrome-devtools-mcp (2026-05-20)` audit trails in POM files** — these are discovery notes for the DOM shape. They belong in the POM, not in test bodies. If you see them in a test body, move them; if in the POM, leave them.
- **FIXME / TODO comments with diagnostic notes** — `// FIXME: this XPath breaks if the form wraps the field in another <div>; need data-testid from dev team` is load-bearing. AI doesn't write these; humans hedging against future regressions do.
- **Bilingual matchers when the app itself is multilingual** — if the app has a Czech UI, `getByRole("button", { name: "Odeslat" })` is correct. The smell is _mixed-language comments_, not mixed-language selectors.
- **Comments explaining WHY a banned pattern is used** — `// .catch(() => false) because the success can flash and disappear in <100ms` is still wrong (the pattern is banned), but it indicates a human author who knew it was suspicious. Fix the code, keep the awareness.
- **Verb-phrase test names without "should"** — `"login redirects to dashboard"` looks AI-shaped if you grew up with `"should redirect on login"`. It's not. It's the [2025–2026 community drift](https://google.github.io/eng-practices/review/reviewer/looking-for.html) away from performative "should".
- **One file with 12 tests + another with 1 test** — asymmetric coverage is the _opposite_ of a smell. It's the human signal. Don't normalize it.

---

## Quick scan — grep one-liners

Run these in the file under review for a 30-second triage:

```bash
# Detector 1 — magic numbers in assertions (Jest/Vitest unit matchers too, not only Playwright web ones)
grep -nE 'expect\(.*\)\.(toBe|toEqual|toStrictEqual|toHaveLength|toHaveText|toContainText|toHaveValue|toBeCloseTo|toBeGreaterThan(OrEqual)?|toBeLessThan(OrEqual)?)\([^)]*[0-9]' tests/
# ^ when eyeballing hits, discount universal constants: HTTP status (200/404), 0/1/-1, small array lengths are not magic numbers.

# Detector 5 — vocabulary blacklist
grep -nE 'comprehensive|robust|ensures|seamlessly|thoroughly|leverages' tests/

# Detector 6 — hard waits
grep -nE 'waitForTimeout|setTimeout|page\.sleep|await sleep' tests/

# Detector 7 — defensive catches
grep -nE '\.catch\(\(\)\s*=>' tests/

# Detector 9 — multi-clause titles
grep -nE 'test\(["\x27].* and .*["\x27]|it\(["\x27].* and .*["\x27]' tests/
# ^ discount 'and' inside a single noun phrase ("salt and pepper", "terms and conditions", "health and safety") — that is one behavior, not two.

# Detector 4 — AAA labels
grep -nE '// (Arrange|Act|Assert)\b' tests/
```

Three or more lines from any one query = look harder. Three or more queries returning hits = open the file with intent.

---

## Connection to other skills

- **`comment-discipline`** — when you find essays above tests (Detector 5), the deletion / why-not-what rules live there.
- **`real-testing-patterns`** — overlapping turf on selectors, assertion families, A1–A13. This skill is the _fast detector_; that one is the _comprehensive playbook_. When in doubt, the fix lives there.
- **`improve-tests`** — once you've detected, this skill helps apply the fix in Before/After form.
- **`test-organization`** — naming convention (Detector 9) and file structure (Detector 2) live there in full.
- **`check-selectors`** — selector-specific smells (CSS classes, nth, XPath) are detected and fixed there.

This skill is the **first-pass detector**. The fix-it skills are downstream.

---

## Sources

- [arXiv 2410.10628 — On the Diffusion of Test Smells in LLM-Generated Unit Tests](https://arxiv.org/abs/2410.10628) — measured 99.85% Magic-Number-Test smell rate in GPT-3.5 unit tests; 20,505-suite corpus.
- [arXiv 2510.03029 — Investigating the smells of LLM-generated code (2025)](https://arxiv.org/pdf/2510.03029) — categorical difference between human and LLM smell distributions.
- [arXiv 2511.15817 — LLM test smells follow-up (2025)](https://arxiv.org/html/2511.15817) — confirms procedural vs state-management split.
- [Mark Seemann — Treat test code like production code (Dec 2025)](https://blog.ploeh.dk/2025/12/01/treat-test-code-like-production-code/) — test code deserves the same review discipline; stop grading on a curve.
- [Daniel Stenberg — Death by a thousand slops](https://daniel.haxx.se/blog/2025/07/14/death-by-a-thousand-slops/) — the defendability gate, the curl/Ghostty reviewer mental model.
- [Sam Saffron — Your vibe coded slop PR is not welcome](https://samsaffron.com/archive/2025/10/27/your-vibe-coded-slop-pr-is-not-welcome) — asymmetry, the symmetric-structure smell.
- [msgtester.sk — ChatGPT automatizácia testov](https://msgtester.sk/chatgpt-automatizacia-testov/) — the CEE rejection register; regional terseness preference.
- [Honza Javorek on Lupa.cz](https://www.lupa.cz/clanky/honza-javorek-junior-guru-jenom-clovek-vam-rekne-co-chatgpt-poradil-spatne/) — only a human will tell you what ChatGPT got wrong.
- [Kent C. Dodds — Testing implementation details](https://kentcdodds.com/blog/testing-implementation-details) — the comprehensive-but-shallow paradox.
- [Google eng-practices — Looking for in code review](https://google.github.io/eng-practices/review/reviewer/looking-for.html) — read tests first; verb-phrase titles.
- `test-syntax-audit-report.md` (Investown audit, 2026-05-20) — concrete examples of all 10 detectors in a real production suite.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Videli tie grepy vôbec testy TOHTO repa (iná cesta než `tests/`, iný runner a iné matchery) — alebo hlásiš čistotu nad prázdnou množinou?
