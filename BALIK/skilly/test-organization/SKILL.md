---
name: test-organization
description: Modern (2025-2026) hierarchical organization and naming conventions for E2E test suites (Playwright, Cypress). Folder = feature group, file = feature, max 2 describe levels. Verb-phrase test titles without "should". POS/NEG/EDGE as tags, not describe splits or prefixes.
allowed-tools: Read, Write, Edit, Bash
---

# Test Organization — naming & hierarchy

## 1. Decision tree

```
Picking structure for a new test suite?
│
├─ How many spec files do you expect?
│   ├─ ≤ ~10  → flat tests/ folder, one file per feature
│   └─ > ~10  → group into feature folders (auth/, payments/, dashboard/)
│
├─ How many tests per feature?
│   ├─ 1-10   → single describe block per file
│   └─ 10+    → optional sub-context describe (max 2 levels total)
│
└─ How to mark categories (positive/negative/edge, smoke/regression)?
    → ALWAYS use Playwright tags, never describe splits or title prefixes
```

## 2. Hierarchical pattern

**Level 1 — folder = feature group** (only when >10 spec files)

```
tests/
  auth/
    sign-in.spec.ts
    sign-up.spec.ts
  payments/
    new-transaction.spec.ts
```

**Level 2 — file = feature** (one feature per file, kebab-case)

**Level 3 — describe = optional sub-context** (max 2 levels, often 1)

```typescript
test.describe("New Transaction", () => {
  test("submits a payment to another user", ...);

  test.describe("user search by attribute", () => {
    for (const attr of ["firstName", "lastName", "email"]) {
      test(`finds users by ${attr}`, ...);
    }
  });
});
```

**Anti-pattern:** 3+ describe levels. Split the file.

## 3. Naming convention

### Title: `<actor/system action> <object> [<deviation>]`

| Variant  | Example                                       |
| -------- | --------------------------------------------- |
| Positive | `submits a payment to another user`           |
| Positive | `remembers user for 30 days after login`      |
| Negative | `rejects login with invalid password`         |
| Negative | `displays validation errors on empty amount`  |
| Edge     | `truncates transaction note over 200 chars`   |
| Edge     | `expires session after 30 days of inactivity` |

### Rules

1. **Active voice** — `submits`, `rejects`. Not `should submit`, not `login form`.
2. **Drop "should"** — filler, no information.
3. **Don't restate assertion** — `expect()` already does.
4. **Mention deviation only for NEG/EDGE** — happy path is implicit.
5. **Spec file:** `feature.spec.ts` kebab-case.
6. **Outer describe:** Feature name (not `"Sign in tests"` — redundant).

### Anti-patterns

- ❌ `should render the login form` — vanity (A1)
- ❌ `login form` — noun phrase, not a behavior
- ❌ `[NEG] login fails` — prefix (use tags instead)
- ❌ `if/else` inside a test for two scenarios — split into two tests

## 4. POS / NEG / EDGE — use tags

```typescript
test("rejects login with invalid password", {
  tag: ["@negative", "@auth"],
}, async ({ ... }) => { ... });
```

### Why tags, not describe splits or prefixes

| Approach                 | Problem                                          |
| ------------------------ | ------------------------------------------------ |
| Describe splits          | Fragments suite, doesn't compose with other axes |
| Title prefixes (`[NEG]`) | Noisy in reports, breaks alphabetical sort       |
| **Tags**                 | Cross-cutting, filterable in CI, compose freely  |

### Standard tag taxonomy

| Tag           | Use for                                  |
| ------------- | ---------------------------------------- |
| `@positive`   | Happy path                               |
| `@negative`   | Wrong input, error states                |
| `@edge`       | Boundaries, malformed input              |
| `@security`   | User enumeration, auth bypass, injection |
| `@smoke`      | Critical path subset                     |
| `@regression` | Larger nightly suite                     |
| `@slow`       | Tests >30s                               |

Plus **feature tags**: `@auth`, `@payments`, `@settings`.

### CI filtering

```bash
playwright test --grep @smoke
playwright test --grep @security
playwright test --grep-invert @slow
playwright test --grep "@negative.*@auth"
```

## 5. Example clean suite

```typescript
// tests/auth/sign-in.spec.ts
test.describe("Sign in", () => {
  test("login with valid credentials reaches dashboard", {
    tag: ["@positive", "@auth", "@smoke"],
  }, async ({ ... }) => { ... });

  test("login with wrong password shows error", {
    tag: ["@negative", "@auth"],
  }, async ({ ... }) => { ... });

  test("login with non-existent user shows generic error", {
    tag: ["@negative", "@security", "@auth"],
  }, async ({ ... }) => { ... });
});
```

## 6. Reference suites

- [Cypress Real World App](https://github.com/cypress-io/cypress-realworld-app/tree/develop/cypress/tests/ui)
- [Microsoft Playwright examples](https://github.com/microsoft/playwright/tree/main/examples)
- [GitLab E2E style guide](https://docs.gitlab.com/ee/development/testing_guide/end_to_end/style_guide.html)

## 7. Handling state across runs (shared test accounts)

Many E2E suites for third-party platforms (banks, fintechs) get **one test account** — running the suite mutates the account state (passwords reset, balances change, sessions invalidate). Strategies for stability:

### Strategy A — persist state between runs

```typescript
// helpers/credentials.ts — load/save current password atomically
export function saveCurrentPassword(password: string): void {
  const tmpPath = `${STORE_PATH}.tmp`;
  writeFileSync(
    tmpPath,
    JSON.stringify({ password, updatedAt: new Date().toISOString() }),
  );
  renameSync(tmpPath, STORE_PATH); // atomic on POSIX
}
```

Password-reset spec writes `auth/current-password.json`. Sign-in spec reads it. State persists across runs; `.env` is just the bootstrap fallback. **Always atomic write** (`.tmp + rename`) so an interrupted run doesn't leave a corrupt file.

### Strategy B — dedicated account per run

```typescript
const EMAIL = `test-${process.env.TEST_WORKER_INDEX}-${Date.now()}@inbox.testmail.app`;
```

Per-worker unique email — no race, no rate-limit conflict. Requires the platform to accept new signups during tests (not always possible on KYC).

### Strategy C — cool-down between runs

Some platforms rate-limit per account (Investown: ~30 min for password-reset). Pre-test wait in `globalSetup` or staging the test in CI nightly only.

| Strategy          | Stability | Setup cost               | Use when                                              |
| ----------------- | --------- | ------------------------ | ----------------------------------------------------- |
| **A (persist)**   | High      | Low                      | Single shared account, password-reset-style mutations |
| **B (per-run)**   | Highest   | Medium (need signup API) | Multi-worker CI, freshly creatable accounts           |
| **C (cool-down)** | Medium    | None                     | One account, infrequent runs                          |

### Mark tests honest about external dependencies

If your test depends on a rate-limit-decayed state or external API quota:

```typescript
test("Full reset flow ...", {
  tag: ["@positive", "@e2e", "@rate-limited"],
}, async ({ ... }) => {
  // Note: Investown rate-limits forgotten-password per account. Re-running
  // back-to-back (<30 min) makes the mail never arrive. Use a fresh account
  // or wait the cool-down before re-running.
  ...
});
```

`@rate-limited` tag lets CI exclude these from PR pipelines and run nightly only:

```bash
playwright test --grep-invert @rate-limited  # PR pipeline
playwright test --grep @rate-limited         # nightly only
```

## 8. When user asks "how should I structure my tests"

1. Count expected spec files. ≤10 → flat. >10 → feature folders.
2. One file per feature. One outer `describe` per file.
3. Titles: verb-phrase, active voice, no "should". POS/NEG/EDGE = tag.
4. Tags: `@positive` / `@negative` / `@edge` + feature + cross-cutting.
5. Filter via `--grep @tag` in CI.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Spustil si po presune a pretagovaní každý CI filter (`--grep @smoke`, `--grep-invert @slow`) a videl NENULOVÝ počet testov, ktorý sedí so súčtom pred zmenou?
