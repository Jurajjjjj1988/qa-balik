---
name: comment-discipline
description: When to write code comments vs delete them. Three-tier rule (WHY only / WHAT only when non-obvious / DELETE). Catches the AI-comment-essay smell. Use when reviewing or writing code (especially AI-generated), or when comments exceed 3 lines above a function/test.
allowed-tools: Read, Write, Edit, Bash
---

# Comment Discipline — write less, mean more

## TL;DR

- **Names carry _what_. Comments carry _why_.** If your comment says what the code does — rename the function instead.
- **Three tiers: WHY-only (keep), WHAT-only-if-non-obvious (keep terse), restating-the-code (delete).** Default is delete.
- **In tests, the test NAME is the documentation.** If the body needs a comment block to be understood, the test name is broken or the test is doing too much.

## 1. The three-tier rule

### Tier 1 — WHY-only (high value, KEEP)

Reasons the reader cannot derive from the code. Business decisions, external constraints, references to specific bugs/PRs.

```ts
// Stripe rate-limits us at 25 req/s on this endpoint; back off here, not at caller.
await sleep(40);

// Empty string here matters: backend treats `null` as "unchanged", `""` as "clear".
payload.notes = userInput ?? "";

// FIXME(juraj, 2026-05-20, INV-1234): Cognito JWT TTL is ~5 min and the full
// suite runs ~8 min serially — sessions expire mid-run. Refresh token in
// auth-setup.ts or bump workers>=4.
test.fixme("browser back after logout does not restore profile content", ...);
```

These earn their lines. Without the comment, a future maintainer either repeats the investigation or deletes load-bearing code.

### Tier 2 — WHAT-only-if-non-obvious (medium value, KEEP TERSE)

The code does something surprising — a workaround, an asymmetric handler, a deliberate exception to project convention. One line, trailing or above.

```ts
// UI formats the API phone with spaces — assert the formatted form.
await expect(personalData.phoneValue).toHaveText(
  DEFAULT_USER_DISPLAY.phoneFormatted,
);

// Native checkbox is visually-hidden — setChecked({force:true}) fires the change event React listens for.
await toggle.setChecked(true, { force: true });

// 6 zeros: valid format, invalid value — auto-submit fires; mock returns the live 400.
await profilePage.mfa.smsCodeInput.fill("000000");
```

Rule of thumb: **one line, at most two**. If your "what" comment needs a paragraph, the code is too clever — refactor instead.

### Tier 3 — DELETE (negative value)

Restating the code, ceremony, or AI-essay discovery trails. Net-negative because they:

1. Bloat the file (readers skim past 20-line blocks to find the assertion).
2. Drift (when the code changes, the comment lies).
3. Train the next reader that comments here are noise — so they miss the load-bearing Tier 1 ones.

```ts
// DELETE — restates the code
// Iterate through users
for (const user of users) { ... }

// DELETE — apologizes for naming
// This actually returns the user's ID, not the user
function getUser(id) { ... }

// DELETE — ceremony
// Arrange
const user = aUser().build();
// Act
const result = save(user);
// Assert
expect(result.ok).toBe(true);

// DELETE — AI essay (discovery trail belongs in a PR description or the POM)
// Verified via chrome-devtools-mcp (2026-05-20): document items are
// <div [cursor=pointer]> with a React onClick that calls
//   window.open("https://www.investown.com/<slug>", "_blank")
// — i.e. a NEW TAB pointing to a marketing-site page (NOT a binary
// download, NOT in-place navigation, NOT a modal). The dev build does
// not use <a href> so getByRole('link') would miss them entirely.
// We assert via page.waitForEvent('page') because that's the only
// observable signal of window.open in Playwright.
const [popup] = await Promise.all([...]);
```

## 2. Decision tree

```
Is this comment...?
│
├─ ...restating the identifier or the next line of code?
│       → DELETE. The reader can read code.
│
├─ ...explaining the WHY (rate limit, business rule, bug ticket, RFC ref)?
│       → KEEP. Tier 1. Make it scannable.
│
├─ ...a one-liner flagging a surprising WHAT (workaround, asymmetric branch)?
│       → KEEP. Tier 2. Trailing or single-line above.
│
├─ ...a 5+ line block above a 5-line function/test?
│       → DELETE or extract. Tier 3. Move to JSDoc on the called helper, or PR description.
│
├─ ...commented-out code?
│       → DELETE. Git remembers. If "we'll need this later" — write a ticket.
│
├─ ...a TODO without owner+date+ticket?
│       → REWRITE. `// TODO(juraj, 2026-06-01, INV-1234): ...`
│
└─ ...contradicting what the code does?
        → FIX the code OR FIX the comment. One of them is lying. Most dangerous case.
```

## 3. Concrete Before/After examples

### Example A — AI essay above a popup test (real Investown cleanup)

**Before** (54 lines, 38 of them comment):

```ts
test(
  "clicking a document opens its content in a new tab",
  { tag: ["@positive", "@docs"] },
  async ({ page, profilePage }) => {
    // Verified via chrome-devtools-mcp (2026-05-20): document items are
    // <div [cursor=pointer]> with a React onClick that calls
    //   window.open("https://www.investown.com/<slug>", "_blank")
    // — i.e. a NEW TAB pointing to a marketing-site page (NOT a binary
    // download, NOT in-place navigation, NOT a modal). The dev build does
    // not use <a href> so getByRole('link') would miss them entirely.
    // We assert via page.waitForEvent('page') because that is the only
    // observable signal of window.open in Playwright.
    // We close the popup explicitly to avoid the test runner pinning the
    // real marketing site as an open page (which slows trace export).
    // ...

    const [popup] = await Promise.all([...]);
  },
);
```

**After** (20 lines, 1 line comment):

```ts
test(
  "opens a document in a new tab pointing to investown.com",
  { tag: ["@positive", "@docs"] },
  async ({ page, profilePage }) => {
    // Docs use window.open(url, "_blank") — assert via popup event.
    await profilePage.gotoSection("documents");
    const firstDocName = profilePage.documents.names[0];
    if (!firstDocName) throw new Error("documents.names is empty");

    const [popup] = await Promise.all([
      page.context().waitForEvent("page", { timeout: 5_000 }),
      profilePage.documents.documentLinkByName(firstDocName).click(),
    ]);

    expect(popup.url()).toMatch(/^https?:\/\/(www\.)?investown\.com\/.+/);
    await popup.close();
  },
);
```

The discovery trail (chrome-devtools findings) belongs in the POM's JSDoc or a PR description — not above every test that touches the feature.

### Example B — Restating the variable name

**Before:**

```ts
// Check if user has been authenticated
if (user.isAuthenticated) { ... }

// Loop through each item in the cart
for (const item of cart.items) { ... }

// Increment the counter by one
counter++;
```

**After:**

```ts
if (user.isAuthenticated) { ... }
for (const item of cart.items) { ... }
counter++;
```

The condition reads itself. The loop reads itself. The `++` reads itself.

### Example C — Apologizing for a name vs renaming

**Before:**

```ts
// This actually returns the user's ID, not the full user object
function getUser(id: string): string { ... }
```

**After:**

```ts
function getUserId(id: string): string { ... }
// or, if "id" is the input and we return a different id:
function findUserIdByEmail(email: string): string { ... }
```

Comments that apologize for the name are a tell that the name is wrong. Fix the name.

### Example D — Test ceremony (Arrange/Act/Assert)

**Before:**

```ts
test("user can place an order", async ({ page }) => {
  // Arrange
  await page.goto("/checkout");
  await page.getByLabel("Address").fill("Main St 1");

  // Act
  await page.getByRole("button", { name: "Place order" }).click();

  // Assert
  await expect(page.getByRole("heading")).toHaveText("Order confirmed");
});
```

**After:**

```ts
test("user places an order with a saved address", async ({ page }) => {
  await page.goto("/checkout");
  await page.getByLabel("Address").fill("Main St 1");
  await page.getByRole("button", { name: "Place order" }).click();
  await expect(page.getByRole("heading")).toHaveText("Order confirmed");
});
```

The structure of a test (setup → action → assertion) is universally understood. Labeling it adds zero information.

### Example E — A genuine WHY that earns its lines

**Keep this one:**

```ts
test("user submits checkout twice — only one order is created", async ({
  page,
  request,
}) => {
  // CRITICAL: Stripe webhooks can fire twice (network retry). The dedupe key
  // lives on our /orders endpoint, not Stripe's side. Don't replace this with
  // a mock — the real bug we caught (INV-2102) was the dedupe key being trimmed
  // by an upstream proxy, so the mock would always pass.
  await page.goto("/checkout");
  // ...
});
```

Without this comment, the next reviewer deletes the test as "duplicate" and the bug returns.

## 4. Anti-pattern catalog

| Anti-pattern                     | Why bad                                                  | Refactor                                                                    |
| -------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------- |
| Restating the identifier         | Reader can read code. Wastes screen real estate.         | Delete.                                                                     |
| AI essay above small body        | 15-line comment for 5-line block. Smells of vibe-coding. | Compress to 1 line or delete. Discovery notes go in POM/JSDoc.              |
| TODO without owner/date          | Stays forever. Nobody knows whose problem it was.        | `// TODO(name, YYYY-MM-DD, TICKET): ...` or delete.                         |
| Commented-out code               | Git remembers. Dead code is confusion.                   | Delete. Write a ticket if it might come back.                               |
| Comment that lies                | Most dangerous. Reader trusts the comment over the code. | Fix one of them. If unsure which is correct, write a test.                  |
| WHAT instead of WHY              | Tells me what I can see. Misses what I can't.            | Rename the function/variable. If naming can't carry it, switch to WHY.      |
| Arrange/Act/Assert labels        | Ceremony. Structure of a test is universally understood. | Delete labels. Trust the reader.                                            |
| JSDoc on private one-liner       | Documentation for self. Drift risk.                      | Delete. Reserve JSDoc for public API methods.                               |
| Bilingual mixing                 | Half English / half Slovak / half Czech in one block.    | Pick one language for comments (English by default). Keep UI strings as-is. |
| Comment defending banned pattern | Justifies an anti-pattern in prose instead of fixing it. | Fix the pattern. Defending it in a comment locks it in.                     |

## 5. The Ousterhout vs Uncle Bob debate

Uncle Bob (_Clean Code_, 2008): **comments are failures** — apologies for code you couldn't make expressive. Rename instead. Extract instead.

John Ousterhout (_A Philosophy of Software Design_, 2018): **comments capture what code cannot** — the _why_, the rationale, the conditions under which a method makes sense to call. Calls "code is self-documenting" a "delicious myth."

The two debated in public Sep 2024 – Feb 2025 ([read it raw on GitHub](https://github.com/johnousterhout/aposd-vs-clean-code)). Both are right in different scopes — a small function with a sharp name carries meaning alone; a module interface or surprising workaround needs prose.

**2026 consensus**: comments capture what code CAN'T. Names carry _what_, comments carry _why_, types carry _shape_, tests carry _what should be true_. Delete the ones that just restate.

Mark Seemann's late-2025 post [Treat test code like production code](https://blog.ploeh.dk/2025/12/01/treat-test-code-like-production-code/) extends this to tests — same readability standards apply, with test-specific dispensations (hardcoded test passwords, DAMP over DRY in bodies).

## 6. Test code is special

Tests are user-facing through their NAMES. The test report shows the title; the body only matters when one fails.

```ts
// BAD — comments propping up a vague name
test("password test", async ({ page }) => {
  // This test verifies that when a user enters an empty password and
  // tries to submit the form, the submit button stays disabled, because
  // RHF onBlur mode requires all fields to validate before enabling.
  // ...
});

// GOOD — name carries it, no comment needed
test("submit stays disabled with empty password", async ({ page }) => {
  // ...
});
```

**Heuristic**: if your test body needs a comment block to be understood, either:

1. The test name is too vague → rename it.
2. The test does too many things → split it.
3. The code under test does something genuinely weird → keep ONE WHY comment.

The Investown cleanup we just did reduced comment essays in `profile.spec.ts` by ~70%. The tests didn't get harder to read — they got easier. Names did the work the prose was failing to do.

## 7. When to keep a comment (the short list)

Keep when the comment captures one of:

- **`// FIXME:` or `// TODO:` with owner+date+ticket.** Stale ones get reaped quarterly.
- **`// Verified via Walk & Watch` or `// Verified via chrome-devtools-mcp`.** Audit trail for surprising selectors — but in the POM file, not above every test.
- **Algorithmic insight that took >30 min to figure out.** Save the next reader the rediscovery cost.
- **References to external context** — bug tickets, RFCs, library issues, blog posts that explain the workaround.
- **Surprising workarounds** with a link to the upstream issue (`// Workaround for playwright/playwright#12345`).
- **Security-critical invariants** (`// Never log this — PII per GDPR Art 9`).
- **Performance assumptions** (`// O(n²) is OK here — n is bounded to ~10 by the schema`).

If you're writing a comment and it doesn't fit one of these categories, ask: would deletion lose information that can't be reconstructed from the code? If no — delete it.

## 8. Quick self-check before committing

Run this checklist on any block of comments before pushing:

```
□ Does this comment say WHY (not WHAT)?
□ Can I shrink it to one line without losing info?
□ If I delete it and read the code, do I lose anything?
□ Is there a name change that would make it unnecessary?
□ Does it match the code as currently written? (Drift check.)
□ Would I write this comment if no AI tool had generated it?
```

If any answer is _no_ or _yes I'd shrink it_, do that before committing. The reality-check skill catches the worst cases pre-PR, but the cheap version is asking these six questions at the cursor.

## Cross-links

- See also: `ai-test-smell-detector` (catches the broader AI-cluster of which comment-essays are one signal).
- See also: `test-organization` (test names that are self-documenting reduce the need for comments inside the body).
- See also: `real-testing-patterns` (Anti-pattern A8: defensive comments propping up banned patterns; A1: vanity assertions whose comments admit they prove nothing).
- See also: `improve-tests` (uses this skill as a sub-check during test review).
- See also: `review-code` (comment density is a code-review smell signal).

## Sources

- [Ousterhout vs Martin debate (2024–2025)](https://github.com/johnousterhout/aposd-vs-clean-code)
- [Jonathan Hall — Comments vs self-documenting code](https://jhall.io/archive/2024/02/16/comments-vs-self-documenting-code/)
- [Mark Seemann — Treat test code like production code (Dec 2025)](https://blog.ploeh.dk/2025/12/01/treat-test-code-like-production-code/)
- [arXiv 2410.10628 — Test smells in LLM-generated unit tests](https://arxiv.org/abs/2410.10628)
- Pragmatic Engineer interview with Ousterhout — Philosophy of Software Design
- Internal: `/Users/kapusansky/.claude/skills/code-readability-research.md` (full research notes)
- Internal: `/Users/kapusansky/.claude/skills/test-syntax-audit-report.md` (Investown audit findings)

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Dá sa informácia z KAŽDÉHO zmazaného komentára zrekonštruovať z kódu — alebo si zmazal jediné miesto, kde bol dôvod (ticket, meranie, upstream issue, GDPR/perf predpoklad)?
