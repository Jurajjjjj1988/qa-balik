---
name: test-layers-money-critical
description: Use when building or reviewing tests for money/payroll/billing/pricing/invoice math, when a suite uses a test double/fake/mock for a real dependency (DB/API with constraints, triggers, enums), or deciding how thorough a feature's tests must be — especially when green but you doubt it catches bugs or fear production breaks at an untested seam. Triggers on "payroll", "money math", "tests pass but", "mutation testing", "fake/mock/stub", "integration", "enum", "trigger", "constraint".
---

# Test layers + money-critical rigor

## Core principle

Tests are **LAYERS, not one pass** — each layer catches a bug class the others miss. A feature is
"tested" only when every applicable layer is present. **Money math (payroll, pricing, billing,
invoices, tax) sits at the TOP of the rigor ladder**: it gets every layer PLUS mutation-kill tests
that pin each arithmetic operator, comparison boundary and branch. A green suite of example tests on
money code is a lie — arithmetic mutants (`+`→`-`, `*`→`/`) survive trivially.

## The layers (add upward; money code needs ALL that apply)

| Layer | Catches | Tool |
|---|---|---|
| 1 Unit / example | basic logic, known input→output | vitest/jest |
| 2 Property-based | boundary/edge/unicode cases humans miss; invariants (`total === Σ lines`) | fast-check |
| 3 Failure-injection | swallowed errors, missing rollback, phantom state, double-apply | MSW, fake repos |
| 4 Integration / DB | constraints, RLS, triggers, tamper-detection — enforced regardless of UI | pgTAP |
| 5 **Mutation** | **vanity-green tests** — the meta-layer that tests the tests | Stryker |
| 6 E2E | wiring/journey gaps | Playwright |
| 7 Adversarial review | design-level defects | refute-by-default pass |

Layer 5 is non-negotiable for money: it is the only layer that proves the others assert anything.

## The money rule

Money/payroll computation MUST:
1. Have the **highest mutation score in the repo** — gate it **per-file** (`break` on that file),
   not just the repo average (an 85 % repo can hide a 55 % wage file).
2. Assert **exact values**, never `wage > 0` (survives every arithmetic mutant).
3. Have a **named mutation-kill test per mutant class** (below). Name the test by the mutant it kills.
4. Never coerce a missing rate to `0` — surface a **warning** (parse-don't-validate), never silent free.

## Money mutant classes — one killing test each

- **Arithmetic** (`+`→`-`, `*`→`/`): assert exact sum; comment the wrong value the mutant produces.
- **Comparison boundary** (`>`→`>=`, `<`→`<=`): test ON the boundary and one step past.
- **Condition → true/false** (feature gates): test BOTH branches (grouted vs not → seal counted vs not).
- **Sort + tiebreaker**: assert order AND the tiebreaker key.
- **Accumulate vs overwrite** (`map.get(k) ?? 0` → `0`): two items same key → assert SUM, not last.
- **Empty/missing guard**: empty date/rate → NO-OP or warning, never counted / never silent €0.

## The pattern (real payroll example — each test names its mutant)

```ts
it("wageForCell: wall+ceiling in the same cell SUMS (kill + → -)", () => {
  // pp/d90 = {wall:10, ceiling:10}; 50% effective → 10*(20*.5) + 10*(12*.5) = 100 + 60 = 160
  const jf = computePayroll([wall("2026-07-10"), floor("2026-07-10")], S).workers.find(w => w.key === "jf");
  expect(jf?.wage).toBeCloseTo(160, 2);      // 100 - 60 = 40 would pass a weak `>0` test — this fails the mutant
});

it("inRange: on dateTo included, one day past excluded (kill > → >=, boundary)", () => {
  expect(computePayroll([wall("2026-07-20")], S, "", "2026-07-10").grandTotal).toBe(0);          // past → out
  expect(computePayroll([wall("2026-07-10")], S, "", "2026-07-10").grandTotal).toBeGreaterThan(0); // == → in
});

it("two items same day ACCUMULATE (kill map-init → last write wins)", () => {
  const out = dailyByWorker([penWithCount(2), penWithCount(3)], "", "", "pen");
  expect(out[0]?.total).toBe(5);             // 2+3 summed; overwrite mutant yields 3
});

it("used cell WITHOUT a rate → warning, not silent €0 (parse-don't-validate)", () => {
  expect(computePayroll([wall("2026-07-10")], { ...S, rates: {} }).warnings.unpricedCells.length).toBeGreaterThan(0);
  expect(computePayroll([wall("2026-07-10")], S).warnings.unpricedCells).toEqual([]);
});
```

## When green lies: seams, fakes, and enum ranges

A green suite can hide a bug that breaks production **on the first real call** when the tests never
exercised the real dependency or the full value range. Four recurring gaps — each with its fix:

1. **The fake is more permissive than reality → false green.** Unit tests run against an in-memory
   double (fake repo/store) that has **no CHECK / FK / unique / trigger**. The saga logic is proven,
   but the DB rejects data the fake accepted. *Fix:* run the key scenarios against the **real
   dependency** (integration/DB test), or a parity test that the fake only accepts what the real one does.
2. **An enum tested with ONE value.** Code derives a value from a status/type (`'SALE_' || status`)
   that a constraint validates — but tests only used the *default* value (`OPEN`). *Fix:* exercise the
   **FULL enum range** through the real path, especially where a derived value is validated downstream.
3. **The seam between two independently-tested components is untested.** Component A (saga logic ✓)
   and B (DB constraints ✓) each pass alone, but the **contract** between them (A's outputs must be
   accepted by B) never ran together. *Fix:* one integration test across the seam; a
   **producer→validator** test (every value the producer can emit is accepted by the validator).
4. **The same contract fact is decoded in TWO places → you fix one, the sibling silently keeps the old
   answer.** A response with several shapes (online / offline / rejected) is decoded in the happy path
   (`doIt()`) AND again in a recovery/status path (`getStatus()` after a lost response). You teach the
   happy path a new shape; the recovery path has its **own copy** of the decode and still returns the
   stale answer — the two now disagree about the *same fact*. Deadly when the recovery answer drives an
   **irreversible money action** and "unknown" collapses to the destructive default (a refund/charge).
   *Fix:* ONE shared decoder both callers route through (single source of truth), plus a **parity test**
   that feeds the *same* payload through both callers and asserts they return the *same* thing — it goes
   red the moment one path drifts, even while each path's own tests stay green. And never coerce "I don't
   know" (unparseable / unexpected shape) into a definitive negative that moves money — give it a third
   lane (throw → leave record pending → retry/alert), never the silent destructive default.

**Real example (this cost a production-breaking latent bug):** a DB trigger wrote
`event_type = 'SALE_' || status` (`SALE_DONE`, `SALE_CHARGED`…), but the audit table's CHECK allowed
only `SALE_OPEN`. Every unit test used the in-memory store (no CHECK); the one pgTAP inserted only
`OPEN`. All green — yet the first real transition to `DONE` would throw at the DB. The catch: a pgTAP
that drives a row through **every** status via the real trigger+CHECK (insert AND update paths) and
asserts the hash-chain stays intact. It fails red on the old constraint, green on the fix.

**Real example #2 — gap 4 (this was a live-verified BLOCKER on a fiscal/eKasa adapter):** the same API
response identifies a receipt three ways — online (`response.data.id`), offline (`response:null`, id is
in `request.data.okp`), rejected (none). `fiscalize()` was fixed to read `okp` when offline; the
recovery path `getFiscalStatus()` had its **own** schema that only knew `response.data.id`, so for an
offline receipt it returned "doesn't exist" → the saga **refunded the card and marked the sale
REVERSED**, even though the receipt was in the CHDÚ and reached the tax authority within 48h (and
reconciliation was deliberately off, so nothing caught it). Both paths had green offline-ish tests. The
catch: extract ONE `receiptRefOf(response)` both call, then a **parity test** — same offline payload
through `fiscalize()` and `getFiscalStatus()`, assert identical id. It reds instantly if either path
drifts again. Second fix in the same bug: an unparseable lookup body used to become `'none'` (=refund);
now it **throws**, leaving the record CHARGED for the outbox to retry — "unknown" must never be the
destructive default.

## Common mistakes

- **`expect(wage).toBeGreaterThan(0)`** on money — survives `+`→`-`, `*`→`/`, and rate-lookup mutants. Assert the exact number.
- **One layer** ("it has unit tests") — mutation reveals they assert nothing meaningful.
- **Repo-wide mutation gate only** — money file drifts low under a healthy average. Gate per-file.
- **Testing a warning EXISTS but not that silent-0 is ABSENT** — both directions or the mutant lives.
- **No boundary test** on date ranges / brackets — off-by-one (`>` vs `>=`) is the classic money bug.

## Related

Compose with **robust-stateful-frontend** (Pattern 3: no silent wrong number; money in integer cents),
**anti-ai-slop** (vanity-green suites), **ai-test-smell-detector** (magic-number smell),
**ecommerce-testing-patterns** (idempotency on charge/order), **critical-engineer** (is this actually enough).

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Je ten peňažný súbor MENOVANÝ vo výstupe mutačného behu a má vlastnú podlahu — alebo si videl len repo priemer a v reporte možno vôbec nie je?
