# Project Setup

## Folder Structure

```
project/
├── pages/           # Page Object Models
├── fixtures/        # Playwright fixtures
├── helpers/         # Parsers, utilities
├── data/            # Test constants (as const)
├── tests/           # Test specs
├── playwright.config.ts
├── .env             # Credentials (gitignored)
└── .gitignore
```

## Config Template

```typescript
import { defineConfig, devices } from '@playwright/test';
import dotenv from 'dotenv';
dotenv.config();

export default defineConfig({
  testDir: './tests',
  retries: process.env.CI ? 2 : 1,
  workers: process.env.CI ? 1 : 2,
  timeout: 30_000,
  expect: { timeout: 10_000 },
  use: {
    baseURL: process.env.BASE_URL,
    testIdAttribute: 'data-test',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
  },
  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['json', { outputFile: 'test-results/results.json' }], ['github']]
    : [['html', { open: 'on-failure' }]],
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 5'] } },
  ],
});
```

## Dependencies

```bash
npm init -y
npm install -D @playwright/test dotenv eslint-plugin-playwright
npx playwright install chromium
```

## .gitignore

```
node_modules/
test-results/
playwright-report/
.env
```

## Helpers Template

```typescript
// helpers/parsers.ts
export function parsePrice(text: string): number {
  return parseInt(text.replace(/\s/g, '').replace(/[^\d]/g, ''), 10);
}
```
