# Antipatterns — What NOT to Do

## Selectors

```typescript
// ❌ CSS class, XPath, nth(), attribute wildcards, tag selectors
page.locator('.btn-primary');
page.locator('xpath=//div[3]/button');
page.locator('input').nth(0);
page.locator('a[href*="/listing/"]');
page.locator('[class*="map"]');
page.locator('h1').first();

// ✅ Role-based, label, testId
page.getByRole('button', { name: 'Submit' });
page.getByRole('heading', { level: 1 });
page.getByLabel('Email');
page.getByTestId('login-form');
```

## Assertions

```typescript
// ❌ passes when feature is broken
await expect(results.first()).toBeVisible();

// ✅ verifies actual behavior
const prices = await getPrices();
expect(prices.length).toBeGreaterThan(0);
for (let i = 1; i < prices.length; i++) {
  expect(prices[i]).toBeGreaterThanOrEqual(prices[i - 1]);
}
```

```typescript
// ❌ toast is not proof of persistence
await saveButton.click();
await expect(successToast).toBeVisible();

// ✅ reload and verify
await saveButton.click();
await page.reload();
await expect(nameInput).toHaveValue('John');
```

## Deterministic Tests

```typescript
// ❌ IF makes test non-deterministic
if (await element.isVisible()) { ... }
if (title?.includes('error')) { test.skip(); }

// ✅ always same flow
await expect(element).toBeVisible();
```

## Waits

```typescript
// ❌ hard wait, networkidle, deprecated API
await page.waitForTimeout(3000);
await page.waitForLoadState('networkidle');
await page.waitForNavigation();
await page.waitForSelector('.item');

// ✅ specific conditions
await expect(element).toBeVisible();
await expect(page).toHaveURL(/dashboard/);
```

```typescript
// ❌ isVisible() returns instantly — no retry
if (await element.isVisible()) { ... }

// ✅ toBeVisible() auto-retries
await expect(element).toBeVisible();

// ❌ not.toBeVisible() — passes when element doesn't exist
await expect(element).not.toBeVisible();

// ✅ toBeHidden() — explicit
await expect(element).toBeHidden();
```

## Clicks

```typescript
// ❌ force hides real problem
await button.click({ force: true });

// ✅ fix actual problem
await dismissOverlay();
await button.click();
```

## Inputs

```typescript
// ❌ fill() for autocomplete
await input.fill('Praha');

// ✅ pressSequentially + wait for suggestions
await input.pressSequentially('Praha', { delay: 100 });
await suggestions.waitFor({ state: 'visible' });
```

```typescript
// ❌ substring match
page.getByText('Log');

// ✅ exact match
page.getByText('Log in', { exact: true });
```

## waitForResponse

```typescript
// ❌ response arrives before listener
await button.click();
await page.waitForResponse('/api/data');

// ✅ listener BEFORE action
const responsePromise = page.waitForResponse('/api/data');
await button.click();
await responsePromise;
```

## Architecture

```typescript
// ❌ test accesses page directly
await homePage.page.waitForLoadState();

// ✅ POM provides method
await homePage.waitForPageLoad();
```

```typescript
// ❌ login in every test
test('test1', async ({ page }) => { await login(page); ... });

// ✅ login in beforeEach
test.beforeEach(async ({ loginPage }) => { await loginPage.login(); });
```

```typescript
// ❌ no JSDoc
async fillForm(data) { ... }

// ✅ JSDoc with params
/** Fill form with user data. @param name - User name */
async fillForm(name: string) { ... }
```

```typescript
// ❌ inline parsing
const price = parseInt((await el.textContent())!.replace(/\s/g, ''), 10);

// ✅ helper function
import { parsePrice } from '../helpers/parsers';
```
