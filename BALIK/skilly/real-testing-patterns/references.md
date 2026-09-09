# References — full quotes, taxonomies, advanced patterns

Load this only when you need a citation, an advanced pattern, or to defend a choice. The operational rules live in `SKILL.md`.

## Authoritative quotes

> "Automated tests should verify that the application code works for the end users, and avoid relying on implementation details such as the name of a function, whether something is an array, or the CSS class of some element."
> — Playwright official docs, [Best Practices](https://playwright.dev/docs/best-practices)

> "Testing implementation details … can break when you refactor application code (false negatives) and may not fail when you break application code (false positives)."
> — Kent C. Dodds, [Testing Implementation Details](https://kentcdodds.com/blog/testing-implementation-details)

> "Test for observable behaviour instead. Think about _if I enter values x and y, will the result be z?_ instead of _if I enter x and y, will the method call class A first…_"
> — Ham Vocke, [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)

> "Checking is the mechanistic process of verifying propositions about the product. Testing is the process of evaluating a product by learning about it through experiencing, exploring, and experimenting."
> — James Bach & Michael Bolton, [Testing vs Checking Refined](https://www.satisfice.com/blog/archives/856)

> "If you liked it, you shoulda put a test on it." — The Beyoncé Rule. Untested invariants are not features; if a downstream consumer relies on undocumented behavior, the cost of breakage falls on them.
> — Mike Bland, [Software Engineering at Google ch.11](https://abseil.io/resources/swe-book/html/ch11.html)

> "You get diminishing returns on your tests as the coverage increases much beyond 70%."
> — Kent C. Dodds, [Write tests. Not too many. Mostly integration.](https://kentcdodds.com/blog/write-tests)

## LLM-generated test smell measurements

arXiv 2410.10628 — _On the Diffusion of Test Smells in LLM-Generated Unit Tests_ (20,505 suites analyzed):

- **Magic-Number-Test**: 99.85% prevalence in GPT-3.5
- **Lazy-Test** (asserts nothing meaningful): 48.67%
- **Assertion-Roulette** (multiple unrelated expects): 46.94%
- **Eager-Test** (one test exercises whole workflow): 22–45%

## Classic test smells (Gerard Meszaros)

Source: [xunitpatterns.com](http://xunitpatterns.com/)

- **Eager Test** — verifies multiple unrelated behaviors. Split.
- **Mystery Guest** — depends on external state not visible in the test. Make all setup explicit or use named fixtures.
- **Conditional Test Logic** — `if/else` inside a test. Split into two.
- **Resource Optimism** — assumes a service/file is available without asserting it. Add a precondition or fail fast.
- **Test Code Duplication** — same setup in 5 tests. Extract to fixture only when reused 3+ times.
- **Fragile Test** — breaks on unrelated changes. Symptom of testing implementation, not behavior.
- **Slow Test** — > 5s for a unit, > 30s for an E2E. Profile and split.
- **Obscure Test** (Magic Numbers) — assertions with values that have no source. Extract constants with reasoning.

## Test Double taxonomy (Martin Fowler)

Source: [martinfowler.com/bliki/TestDouble.html](https://martinfowler.com/bliki/TestDouble.html)

- **Dummy** — fills argument slots, never used
- **Stub** — returns canned data (`mockResolvedValue`)
- **Spy** — records calls, verify after
- **Mock** — pre-programmed expectations (`expect(fn).toHaveBeenCalledWith`)
- **Fake** — working in-memory implementation (in-memory DB)

## Don't mock what you don't own (Steve Freeman)

Mock at YOUR system boundary, not at internal classes or third-party APIs.

- ❌ `mock(Stripe.Charge)` — Stripe's API may change; your mock won't.
- ✅ Wrap Stripe in `PaymentGateway` (yours), mock `PaymentGateway`.

For E2E: mock the network at `page.route()`, not the DOM.

## Sandi Metz: Test the message you send to yourself

Source: [Sandi Metz testing rules](https://gist.github.com/Integralist/7944948)

| Message direction | Type    | What to test                       |
| ----------------- | ------- | ---------------------------------- |
| Incoming          | Query   | Assert the return value            |
| Incoming          | Command | Assert the public side effect      |
| Outgoing          | Query   | **Stub it. Do not assert.**        |
| Outgoing          | Command | **Mock it.** Verify it was called. |
| Self / private    | Any     | **Do not test.**                   |

Trigger: you're about to write `expect(obj).to receive(:internal_helper)` — stop.

## Test Data Builder over Object Mother

Source: [Nat Pryce — Test Data Builders](http://natpryce.com/articles/000714.html)

```ts
// BAD — Object Mother becomes a god class
const user = ObjectMother.adminWithExpiredSubscriptionAndTwoOrders();
// GOOD — Builder, intent-revealing, each test customizes only what matters
const user = aUser().withRole("admin").withExpiredSubscription().build();
```

When to pick: Object Mother for 1–2 standard fixtures used everywhere. Builder when each test needs different combinations.

## Test-Induced Design Damage (DHH)

Source: [dhh.dk/2014/test-induced-design-damage.html](https://dhh.dk/2014/test-induced-design-damage.html)

Constructor injection just to mock the filesystem warps production design. Don't change architecture to enable mocking. Use a thin seam (one wrapper class) instead.

## Consumer-Driven Contract Tests (Pact)

Source: [docs.pact.io](https://docs.pact.io/consumer)

Replaces brittle E2E across services. Consumer publishes a pact; provider verifies it.

**Anti-patterns specific to Pact:**

- Stub-mode usage — consumer-side calls never verified against provider, defeats the purpose.
- Over-strict matchers — regex on every field, exact string match on fields you don't read. Every provider change breaks consumers; signals you should ask the API for a separate field.

> "The art of consumer Pact tests is knowing what _not_ to test."

## Property-based testing (fast-check)

Source: [fast-check.dev](https://fast-check.dev/)

```ts
fc.assert(
  fc.property(
    fc.array(fc.integer()),
    (arr) => sort(sort(arr)).join() === sort(arr).join(),
  ),
);
```

Tactics catalog (Hillel Wayne — [hillelwayne.com/post/contract-examples](https://www.hillelwayne.com/post/contract-examples/)):

- **Sanity** — output in valid domain
- **Bounds** — compare to reference point
- **Definition** — encode the spec
- **Preserving Transformation** — semantic-neutral input change keeps output: `mode(sorted(xs)) == mode(xs)`
- **Controlled Transformation** — input +1 → output +1: `mode([x+1 for x in xs]) == mode(xs)+1`
- **Oracle Comparison** — alternative implementation
- **Oracle Generator** — build inputs from known outputs

## Approval Testing (Emily Bache)

Source: [Approval Testing — 97 Things](https://medium.com/97-things/approval-testing-33946cde4aa8)

For combinatorial explosion: dump all input/output pairs to a text file, human-approves once, subsequent runs diff. Prefer "approval" over "snapshot" — forces approval, prevents nuke-and-re-record.

## Snapshot anti-pattern: Big Ball of Snapshot

Source: [Kent C. Dodds — Effective Snapshot Testing](https://kentcdodds.com/blog/effective-snapshot-testing)

Snapshots > 30 lines or with timestamps/IDs become rubber-stamped. Prefer inline focused snapshots:

```ts
expect(button).toMatchInlineSnapshot(`<button class="primary">Save</button>`);
```

## Eventual Assertion (`expect.poll`)

Source: [playwright.dev/docs/test-assertions#expectpoll](https://playwright.dev/docs/test-assertions#expectpoll)

```ts
await expect
  .poll(() => api.getStatus(), {
    intervals: [250, 500, 1000, 2000],
    timeout: 10_000,
    message: "wait for job to finish processing",
  })
  .toBe("done");
```

Custom backoff intervals + a message that shows in trace.

## Database isolation: Transactional Rollback

```ts
beforeEach(async () => {
  tx = await db.beginTransaction();
});
afterEach(async () => {
  await tx.rollback();
});
```

~10× faster than truncate, perfectly isolated.

## Test naming: Osherove convention

Source: [osherove.com/blog/2005/4/3/](http://osherove.com/blog/2005/4/3/)

`UnitOfWork_Scenario_ExpectedBehavior` — never `testFoo`. For E2E, prefer the verb-phrase user-journey form ("user does X when Y").

## POM overuse anti-pattern

Source: [Titus Fortner — Page Object Anti-Pattern](https://titusfortner.com/2020/10/02/page-object-anti-pattern.html)

Use POMs only when:

1. Locator logic reused 3+ times, OR
2. The action has domain meaning (`addToCart`), OR
3. The locator is non-obvious (custom element, shadow DOM)

Otherwise inline. Playwright's auto-wait makes Selenium-style POM mostly redundant.

## Frontend Testing Trophy (Kent C. Dodds)

Source: [The Testing Trophy](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications)

For frontend SPAs: integration > unit > E2E > static. Unit-heavy frontend pyramids over-test render-prop minutiae. Apply Trophy when testing a React/Vue/Angular SPA. If > 50% of frontend tests are unit, you're over-testing.

## Visual regression: mask, don't disable

```ts
await expect(page).toHaveScreenshot({ mask: [page.locator(".timestamp")] });
```

Element-web's stronger pattern: tag-gate via `@screenshot` tag, scoped CSS via `addStyleTag`, annotate baseline filenames, fail CI on orphaned PNGs.

## Beck's Test Desiderata

Source: [testdesiderata.com](https://testdesiderata.com/) and [Kent Beck on Medium](https://medium.com/@kentbeck_7670/test-desiderata-94150638a4b3)

Twelve properties; the three Claude should always check:

- **Specific** — when a test fails, the cause is obvious from the assertion
- **Behavioral** — sensitive to changes in user-perceivable behavior
- **Structure-insensitive** — refactoring without changing behavior must not break the test

## Hendrickson's input-design recipes

Source: [Explore It! — Test Heuristics Cheat Sheet](https://www.oreilly.com/library/view/explore-it/9781941222584/f_0098.html)

When designing test inputs, walk this menu:

- **Zero–One–Many** (empty, single, plural)
- **Some–None–All**
- **Beginning–Middle–End** (where in a sequence does the action go)
- **Boundaries** (just inside, on, just outside)
- **Goldilocks** (too small, too big, just right)
- **CRUD** (does each operation work and unwind?)
- **Interruption / Starvation** (kill the network, exhaust disk)

Single test value with one input = skipped this entire menu.

## Specification by Example (Gojko Adzic)

Source: [Anatomy of a good acceptance test](https://gojko.net/2010/06/16/anatomy-of-a-good-acceptance-test/)

Replace adjectives in AC ("handles invalid input gracefully") with a Given-When-Then table of 3–5 concrete examples. The example IS the test IS the spec.

## "Don't BDD without stakeholders"

Source: [Liz Keogh — ATDD vs BDD](https://lizkeogh.com/2011/06/27/atdd-vs-bdd-and-a-potted-history-of-some-related-stuff/)

Recognizer: no business stakeholder reads your `.feature` files; you wrote both Gherkin and step defs alone; step defs are 1:1 with Playwright calls. Delete the Gherkin layer, write Playwright with behavior-shaped names.

## Other anti-patterns to call out by name

- **Shared Fixture / Test Run War** — `beforeAll` for mutable state turns parallel tests into a flaky chain
- **Conditional Test Logic** — `if (env === 'prod')` inside a test = two tests masquerading as one
- **Asserting on log output** — couples tests to formatting; assert on the side effect instead
- **Mocking the system clock globally** — leaks across tests; scope per-test via `page.clock.install()` then `uninstall()`
- **Selenium-style POMs in Playwright** — auto-wait makes most wrappers redundant
- **Test code clones** (Garousi et al., 2021) — test code has 2× more clones than production. Refactor to parameterized tests + factory fixtures before refactoring production.
- **Negative assertions** (`.not.toBe*`) — research (NeQA benchmark) shows negative instructions degrade with model scale; positive form is also more correct technically (`toBeHidden` retries; `not.toBeVisible` does not)

## Testing Trophy / Pyramid / Honeycomb decision

- **Pyramid** (Mike Cohn): 70% unit, 20% integration, 10% E2E. Backend monoliths.
- **Honeycomb** (Spotify): mostly integration, few unit, zero "integrated tests" that spin up other services. Microservices (3+).
- **Trophy** (Kent C. Dodds): integration > unit > E2E > static. Frontend SPAs.

If unsure: pick Trophy for frontend, Pyramid for backend, Honeycomb only when you have 3+ microservices crossing real network boundaries.

## Time-dependent tests use `page.clock`

```ts
await page.clock.install({ time: new Date("2026-01-01") });
await page.clock.runFor("1 hour");
```

Never `waitForTimeout` for date/countdown logic.

## Authenticate once, reuse forever

Save authenticated state via `storageState`. Or skip the UI entirely with programmatic auth via API + cookie injection. Per-worker scope when each parallel worker can hold one account; per-test only when isolation requires.

## Trace strategy

`trace: 'on-first-retry'` — captures only when a test failed once. `'on'` floods CI artifacts; `'off'` makes debug impossible. Local: `npx playwright test --trace on` for one failing test, then disable.

## DAMP > DRY in tests

Production code is DRY. Tests are DAMP — Descriptive And Meaningful Phrases. A test must read top-to-bottom without jumping into helpers. Helpers that hide the failure narrative make debug 3× longer. Use POM methods only for actions reused 3+ times; otherwise inline.

## Visual regression — tool decision and patterns

**Tool comparison** (independent: Vizzly, Lost Pixel, ITNEXT critiques — vendor docs are biased):

| Tool                              | Type            | Free tier       | Strength                                           | When to pick                                         |
| --------------------------------- | --------------- | --------------- | -------------------------------------------------- | ---------------------------------------------------- |
| **Playwright `toHaveScreenshot`** | Built-in        | Free + git PNGs | Zero infra, native masking, per-platform baselines | Solo / small team, < 500 snapshots, single browser   |
| **Argos**                         | OSS + SaaS      | 5k snapshots/mo | Playwright-native, GitHub PR app, OSS-friendly     | OSS budget, Playwright stack, want hosted review UI  |
| **Chromatic**                     | SaaS, Storybook | ~5k/mo          | Component-level, design-system collab, TurboSnap   | You have Storybook, designer-engineer collab matters |
| **Percy (BrowserStack)**          | SaaS, full-page | None practical  | Cross-browser, AI-filter for AA differences        | Enterprise budget, need real-device cross-browser    |
| **Lost Pixel**                    | OSS + SaaS      | OSS free        | Storybook + page + custom shots, self-hostable     | Want OSS self-hosted with Loki feels too narrow      |

Decision: Playwright snapshots → Argos → Chromatic → Percy (in budget order).

**Mask rules** (concrete):

1. Timestamps / dates — `mask: [page.locator('[data-testid="timestamp"]')]` or freeze `Date.now` via `page.addInitScript`.
2. Animations / transitions / spinners — `animations: 'disabled'` in `toHaveScreenshot`, plus `addStyleTag({ content: '* { animation-duration: 0s !important; transition-duration: 0s !important; }' })`.
3. Lottie / video / canvas — mask entirely; non-deterministic.
4. User avatars / hash-derived colors — mask or stub via fixture.
5. A/B variants — pin via cookie/feature flag in `beforeEach`; if you can't, mask.
6. Ads / 3rd-party iframes — block at network (`page.route('**/ads/**', r => r.abort())`) so layout reflow IS captured.
7. CSRF tokens / nonces / random IDs — stub via `page.route` or strip via `addStyleTag`.
8. Cursor — `caret: 'hide'`.
9. Scrollbars — `--force-device-scale-factor=1` and overlay scrollbars off.
10. Fonts not yet loaded — `await document.fonts.ready` before snapshot.

```ts
await expect(page).toHaveScreenshot("checkout.png", {
  mask: [page.getByTestId("timestamp"), page.locator('iframe[src*="ads"]')],
  animations: "disabled",
  caret: "hide",
  maxDiffPixelRatio: 0.01,
});
```

**Threshold strategy**: lock with `maxDiffPixelRatio: 0.01` globally; tighten per-test. `threshold: 0.2` is the default per-pixel YIQ diff. Set `diffIncludeAntiAliasing: false` (Chromatic) — without it, every Mac↔Linux run will flake.

**Sub-pixel rendering across OS**: macOS LCD smoothing ≠ Linux freetype ≠ Windows DirectWrite. Generate baselines in the same Docker image CI uses:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  mcr.microsoft.com/playwright:v1.49.0-jammy \
  npx playwright test --update-snapshots
```

Local dev uses `--ignore-snapshots` on Linux; never commit baselines from your laptop.

**Anti-patterns**:

- Auto-approve via `--update-snapshots` in CI — kills the whole point. Approval must be human.
- Big Ball of Snapshot (full HTML or 400-line JSON) — diffs unreviewable. Snap targeted regions.
- Mask-everything (>80% of viewport) — catches nothing. Delete the test.
- Cross-browser × cross-viewport snapshot multiplier (4 × 3 × 200 = 2400 PNGs) — cap to one browser unless visual cross-browser matters.
- Visual snapshots for accessibility (color contrast, DOM order) — pixel diff can't catch these. Use axe-core.
- Snapshots without `await document.fonts.ready` — flake from font swap.
- Rebase-storm baseline bloat — fix CI speed, not the symptom.

**Caveat on element-web stale-screenshot reporter**: I claim element-web ships a `@screenshot` tag-gate + orphaned-PNG-fail-CI reporter. This was reported by research but the source files were not directly verified at standard paths. Treat as inspirational pattern; if defending in code review, link to a verified file first.

Sources: [Vizzly tool comparison](https://vizzly.dev/visual-testing-tools-comparison/), [ComplyAdvantage cost analysis](https://technology.complyadvantage.com/how-we-cut-our-chromatic-costs-by-60-a-visual-testing-optimisation-story/), [Playwright snapshot docs](https://playwright.dev/docs/test-snapshots), [Playwright issue #34775 (orphan detection)](https://github.com/microsoft/playwright/issues/34775).

## E-commerce-specific patterns (cart / checkout / payment / customization)

> Owner: this content is now in the dedicated `ecommerce-testing-patterns` skill — load that one when working on e-shop / checkout / Stripe / cart / customization. The brief patterns below stay here as a quick reference; for full rules (idempotency tests, money math line-by-line, PII / PCI guard, required Stripe failure cards, cart state machine, Storefront UI rules) see that skill.

When testing e-commerce flows (CustomInk, Shopify, Saleor type sites):

**Algolia search — mock the index, not just the UI**

```ts
await page.route("**/*algolia*/queries**", (route) =>
  route.fulfill({ json: fixtures.searchHits.tshirts }),
);
```

Run a tiny contract test against real Algolia daily (separate suite) for index drift.

**Stripe — test cards + frame-aware locators**

Stripe Elements live in iframes; use `frameLocator()`. Test card matrix:

- `4242424242424242` — success
- `4000000000000002` — generic decline
- `4000000000009995` — insufficient funds
- `4000002500003155` — 3DS challenge required

```ts
const stripeFrame = page.frameLocator('iframe[name^="__privateStripeFrame"]');
await stripeFrame
  .getByPlaceholder("1234 1234 1234 1234")
  .fill("4242424242424242");
```

For webhook-driven order confirmation: use `stripe trigger` CLI in CI, then `expect.poll` order state.

**File upload — assert processed response, not filename**

```ts
const [resp] = await Promise.all([
  page.waitForResponse(
    (r) => r.url().includes("/api/artwork") && r.status() === 200,
  ),
  page
    .getByLabel("Upload your design")
    .setInputFiles("fixtures/logo-300dpi.png"),
]);
const body = await resp.json();
expect(body.dpi).toBeGreaterThanOrEqual(150);
```

Keep deliberately bad fixtures (`too-small.jpg`, `wrong-format.bmp`, `corrupt.png`) — one test per rejection reason, assert _specific_ error message.

**Canvas / WebGL preview — assert state, snapshot scoped region**

Don't snapshot the whole canvas (anti-aliasing varies by GPU). Assert via `evaluate()` against the design state object the canvas reads from:

```ts
const designState = await page.evaluate(() => window.__design.serialize());
expect(designState.layers).toHaveLength(2);
expect(designState.layers[0]).toMatchObject({
  color: "#FF0000",
  x: 100,
  y: 100,
});
```

Visual sanity check on small stable region only, with generous threshold.

**Cart persistence — test the storage contract directly**

```ts
const guestCart = await page.evaluate(() => localStorage.getItem("cart"));
expect(JSON.parse(guestCart!).items).toHaveLength(1);
await login(user);
const serverCart = await request.get("/api/cart").then((r) => r.json());
expect(serverCart.items[0].sku).toBe("TSH-001");
```

**Multi-tab cart sync** — open two contexts, add in tab A, assert tab B updates without reload (real bug class).

**Email verification — Mailpit API, not UI polling**

```ts
const msgs = await fetch(
  "http://localhost:8025/api/v1/search?query=to:test@x.com",
).then((r) => r.json());
expect(msgs.messages[0].Subject).toMatch(/Order #\d+ confirmed/);
```

**Anti-patterns to reject in e-commerce tests**:

- Real Stripe API in CI → Stripe test mode + CLI fixtures
- Real SMTP / email → Mailpit container
- Hardcoded SKUs from prod catalog → seed fixtures via API before test
- One mega-test for full checkout → split: cart, address, payment, confirmation
- Tests depending on prior test order → each test seeds its own user/cart

Sources: [Stripe testing docs](https://docs.stripe.com/testing), [Stripe CLI triggers](https://docs.stripe.com/stripe-cli/triggers), [Checkly checkout testing guide](https://www.checklyhq.com/docs/learn/playwright/checkout-testing-guide/), [Mailpit API](https://github.com/mpspahr/mailpit-api).

## Reviewer mental model — the loop Claude runs before claiming done

The compressed POV (Google eng-practices + Beck Test Desiderata + Bugayenko):

> Read the description. Open the biggest file. Read names without bodies — do they describe behavior? Pick one assertion — would deleting it matter? Look at the setup with maximum suspicion. Distrust comments and mocks. Name the bug class each test catches; delete the ones with no answer. Ask: would I approve this cold from a stranger? Then ask it again, refusing to rubber-stamp my own work.

**Trust hierarchy (verify vs trust)**:

| Layer            | Trust level                  | Why                                                            |
| ---------------- | ---------------------------- | -------------------------------------------------------------- |
| Test name        | High _if_ describes behavior | Beck _Readable_: name encodes intent                           |
| Assertions       | Low until inspected          | Mutation thinking: assertion may be dead                       |
| Setup / fixtures | Highest suspicion            | Hides coupling, shared state, order-dependence                 |
| Mocks / stubs    | High suspicion               | Bugayenko's "Mockery" — mocks of SUT mean test asserts on test |
| Comments         | Lowest trust                 | Often lie, drift, or excuse instead of explain                 |

**"Read tests first" technique** (Google eng-practices) — read tests _before_ implementation. Lets you judge tests on their own merits without your implementation biasing what you expect them to assert.

**Rubber-stamp warning** (VirtuallyScott): "sharp people turn into rubber stamps because fighting for quality stopped being worth the grief... six months later, someone is wondering why nobody caught the bug." Ask yourself: am I clicking through my own tests because I'm tired, or because they're sound?

Sources: [Google eng-practices — What to look for](https://google.github.io/eng-practices/review/reviewer/looking-for.html), [Kent Beck — Test Desiderata](https://testdesiderata.com/), [Bugayenko — Reviewing Angry Tests](https://zhisme.com/articles/reviewing-angry-tests/), [VirtuallyScott — The Rubber Stamp Engineer](https://virtuallyscott.medium.com/the-rubber-stamp-engineer-how-bad-code-review-culture-kills-good-engineers-46a4ae224e9f).

## CEE rejection register (Slovak / Czech / Polish reviewer culture)

Roman's "vyslovene strojové" is not idiosyncratic — it is the regional register. Sources: [Honza Javorek (junior.guru) on Lupa.cz](https://www.lupa.cz/clanky/honza-javorek-junior-guru-jenom-clovek-vam-rekne-co-chatgpt-poradil-spatne/), [msgtester.sk on ChatGPT-generated tests](https://msgtester.sk/chatgpt-automatizacia-testov/), [Maciej Wyrodek (PL)](https://www.wyrodek.pl/ai-i-qa/), [testerzy.pl](https://testerzy.pl/baza-wiedzy/artykuly/testowanie-z-ai-w-praktyce-modele-narzedzia-i-podejscia).

**CEE-specific style preferences** (vs US/UK reviewer norms):

- **Terseness over comprehensiveness.** US reviewers praise "comprehensive coverage" as positive; CEE reviewers read "comprehensive" as a smell — too many tests = nobody will maintain them = AI wrote them.
- **No marketing in code or PR descriptions.** "Robust", "comprehensive", "production-grade", "best practices" in a take-home read as red flags. Senior CEE engineers tend to delete adjectives and keep verbs.
- **Bluntness is normal, not rude.** Softening ("I think maybe consider…") reads as evasive. A one-line rejection IS the standard register.

**Common rejection one-liners** (in the wild on LinkedIn / Slack, paralleled in published critiques):

- SK: _"To je generované."_ / _"Vyslovene strojové."_ / _"To nikto nečíta."_ / _"Chýba tomu hlava aj päta."_
- CZ: _"To psal ChatGPT."_ / _"Působí to jako AI slop."_ / _"Tohle nikdo nereviewoval."_
- PL: _"Wygląda jak wygenerowane."_ / _"Brak kontekstu projektu."_ / _"AI slop."_ / _"Po co tyle testów?"_

**msgtester.sk on AI-generated tests** (direct Slovak technical critique):

> _"Chýbajú mu však odborné znalosti v akejkoľvek špecifickej oblasti. To vedie k nedostatočnej presnosti."_ (Lacks domain knowledge → inaccuracy.)
>
> _"Nie je vhodný na komplexné testovacie scenáre."_ (Not fit for complex scenarios.)
>
> _"kód, ktorý vytvorí, bude používať tieto zastarané metódy."_ (The code it produces uses outdated methods.)

The last one is the technical version of "vyslovene strojové": outdated APIs, generic patterns, no awareness of project conventions.

**CEE review pattern**: 10–20 minutes max. Reviewers open README, one test file, one POM. If those three feel generated, the rest is not read. Recruiters relay verdicts verbatim — the candidate hears the rejection language directly. The take-home is treated as a writing sample of _judgement_, not a coverage exercise.

**OSS maintainer policies on AI submissions** (universal, not CEE-specific, but reinforces register):

- Mitchell Hashimoto (Ghostty): "Drive-by AI PRs will be closed without question. Bad AI drivers will be banned from all future contributions."
- Daniel Stenberg (Curl), 2026: confirmation rate of bug bounty submissions dropped from 15% real → <5% real after AI flood; "not a single one [AI submission] discovered a genuine vulnerability — zero."
- Linus Torvalds: "The AI slop people aren't going to document their patches as such. The documentation is for good actors." Implication: don't trust `Generated-by:` trailers — defence must stand on the _code_.

Sources: [Sam Saffron — Your vibe coded slop PR is not welcome](https://samsaffron.com/archive/2025/10/27/your-vibe-coded-slop-pr-is-not-welcome), [Stenberg — Death by a thousand slops](https://daniel.haxx.se/blog/2025/07/14/death-by-a-thousand-slops/), [Torvalds on AI slop docs (Phoronix)](https://www.phoronix.com/news/Torvalds-Linux-Kernel-AI-Slop).
