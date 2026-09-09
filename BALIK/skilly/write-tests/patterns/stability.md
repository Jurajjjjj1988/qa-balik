# Stability Patterns

## Wait Strategy

Never write manual retry loops or `waitForTimeout`. Playwright has built-in tools.

**Before click:**
1. `waitFor({ state: 'visible' })` — in DOM and visible?
2. `scrollIntoViewIfNeeded()` — in viewport?
3. `dismissOverlay()` — nothing blocking?
4. `click()`

**After action:**

| What happened | Wait |
|--------------|------|
| URL changed | `expect(page).toHaveURL()` |
| API called | `waitForResponse()` (set listener BEFORE action) |
| Content changed | `waitForLoadState('domcontentloaded')` + `expect(el).toBeVisible()` |
| Complex async | `expect(async () => { ... }).toPass()` |
| Dynamic value | `expect.poll(async () => ...).toBe(...)` |

First 3 rows cover 95%. `toPass()` and `poll()` handle the rest.

## waitForResponse Order

```typescript
// ❌ response may arrive before listener
await button.click();
await page.waitForResponse('/api/data');

// ✅ set listener BEFORE action
const responsePromise = page.waitForResponse('/api/data');
await button.click();
await responsePromise;
```

## Overlay Handling

Overlays can reappear after sort/filter/navigation. Dismiss before every interaction, not just on page load.

## Autocomplete Inputs

`fill()` doesn't trigger JS events. Use `pressSequentially({ delay })` + wait for suggestions + click exact match.

## Deprecated API — Do Not Use

| Deprecated | Replacement |
|-----------|-------------|
| `waitForNavigation()` | `expect(page).toHaveURL()` |
| `waitForSelector()` | `expect(locator).toBeVisible()` |
| `waitForTimeout()` | `expect(el).toBeVisible()` or `toPass()` |
| `page.$()` / `page.$$()` | `page.locator()` / `.all()` |
| `networkidle` | Specific condition |

## Flaky Test Mistakes

- `isVisible()` returns instantly — use `toBeVisible()` which auto-retries
- `{ force: true }` hides real problems — fix overlay/timing instead
- `not.toBeVisible()` passes when element doesn't exist — use `toBeHidden()`
- `networkidle` unreliable with websockets/analytics

## Code Quality

- Install `eslint-plugin-playwright` — catches missing `await`, hard waits, `{ force: true }` automatically
- `test.step()` on every logical block — without steps, reports show only test name on failure
- Tests are deterministic — no `if` conditions, no runtime `test.skip()`
