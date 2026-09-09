# Page Object Model Pattern

## Rules

1. `page` is `private readonly` — tests never access page directly
2. Locators in constructor as `readonly`
3. JSDoc on every public method with `@param` and `@returns`
4. Verify methods in POM — test decides WHEN, POM decides HOW
5. One POM per page — never duplicate
6. BasePage for shared elements (header, nav, overlay dismiss)
7. Data extraction via `helpers/parsers.ts`, not inline
8. Auth is setup — login in `beforeEach` or fixture, not in test body

## BasePage Skeleton

```typescript
export abstract class BasePage {
  constructor(private readonly page: Page) {}

  async navigate(path: string) {
    await this.page.goto(path, { waitUntil: 'domcontentloaded' });
    await this.dismissOverlay();
  }

  async dismissOverlay() {
    try {
      const btn = this.page.getByRole('button', { name: /accept|allow/i });
      await btn.waitFor({ state: 'visible', timeout: 5000 });
      await btn.click();
      await btn.waitFor({ state: 'hidden', timeout: 5000 });
    } catch { /* not present */ }
  }

  async waitForPageLoad() {
    await this.page.waitForLoadState('domcontentloaded');
  }

  async verifyUrlMatches(pattern: RegExp) {
    await expect(this.page).toHaveURL(pattern);
  }

  protected getPage(): Page { return this.page; }
}
```
