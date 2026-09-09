# Assertion Patterns

## Core Rule

If the test passes when the feature is broken, the assertion is wrong.

## By Feature Type

| Feature | Bad | Good |
|---------|-----|------|
| Sort | "results visible" | Prices in ascending order |
| Search | "URL contains query" | Result content matches query |
| Filter | "something visible" | Count changed + results match filter |
| Form save | "success toast" | Reload page, values still there |
| Navigation | "URL changed" | URL + key element on target page |
| Responsive | Same as desktop | What's different: map hidden, mobile button visible |

## Never Assert on Empty Data

```typescript
// ❌ loop never runs on empty array — test passes
for (const p of prices) { expect(p).toBeGreaterThan(0); }

// ✅ check length first
expect(prices.length).toBeGreaterThan(0);
for (const p of prices) { expect(p).toBeGreaterThan(0); }
```

## Form Save — Verify Persistence

```typescript
// ❌ toast is not proof backend saved
await saveButton.click();
await expect(successToast).toBeVisible();

// ✅ reload and verify
await saveButton.click();
await page.reload();
await expect(nameInput).toHaveValue('John');
```
