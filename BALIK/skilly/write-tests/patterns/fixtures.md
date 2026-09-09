# Fixture Patterns

```typescript
import { test as base } from '@playwright/test';
import { HomePage } from '../pages/home.page';

type Fixtures = { homePage: HomePage };

export const test = base.extend<Fixtures>({
  homePage: async ({ page }, use) => { await use(new HomePage(page)); },
});
export { expect } from '@playwright/test';
```

## Rules

1. Import `test` and `expect` from fixture file, not from `@playwright/test`
2. Each fixture creates one page object
3. Overlay dismiss in BasePage, called in `navigate()` and before interactions
4. Data parsers in `helpers/`, not inline
