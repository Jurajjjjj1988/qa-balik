# Selector Patterns

## Philosophy

Test attributes (`data-testid`, `data-test`, `data-cy`) are an explicit contract between developers and QA. They exist specifically for test automation — stable, unique, unaffected by CSS or DOM changes. When available, they are the first choice.

## Before Writing Selectors

1. Explore the page first — run a test that logs all `[data-test], [data-testid], [data-cy], [data-qa]` elements
2. Check which test attribute the app uses. Common conventions:
   - `data-testid` — React Testing Library, Playwright default
   - `data-test` — Angular, Vue, custom projects
   - `data-cy` — Cypress community
   - `data-qa` — enterprise apps
   - `data-test-id` — variation
   - `data-automation-id` — enterprise variation
   Set `testIdAttribute` in `playwright.config.ts` to match the app's convention
3. Verify uniqueness — `count() > 1` means selector is too broad

## Priority Order

| # | Method | When |
|---|--------|------|
| 1 | `getByTestId()` | Element has test attribute — always first choice |
| 2 | `getByRole()` | No testId — interactive elements (buttons, links, headings) |
| 3 | `getByLabel()` | No testId — form inputs with label |
| 4 | `getByPlaceholder()` | No testId — inputs without label |
| 5 | `getByText()` | No testId — non-interactive visible text |

**Why testId first?** Developers add test attributes explicitly for QA. They are a contract — stable, unique, won't change on CSS refactor or text translation. When the app provides them, use them.

**When to use getByRole?** When element has no test attribute. Role-based selectors are the best fallback — they validate accessibility and survive DOM changes.

## NEVER Use

CSS classes, XPath, `nth()`, `first()`, `last()`, attribute wildcards (`[href*=]`, `[class*=]`), bare tag selectors (`locator('h1')`).

## Decision Flowchart

```
Has data-testid / data-test? → getByTestId() → done
No testId? → Has semantic ARIA role? → getByRole() with name/level
  Matches uniquely? → done
  Too broad? → add .filter({ hasText }) or scope within parent
No role? → Has label? → getByLabel()
No label? → Has placeholder? → getByPlaceholder()
No placeholder? → Has visible text? → getByText()
Nothing? → Ask developer to add testid. NEVER fall back to CSS/XPath.
```

## Scoping Within Parents

```typescript
const nav = page.getByRole('navigation');
nav.getByRole('link', { name: /home/i });

page.getByRole('row').filter({ has: page.getByText('user@test.com') });
```

## Exact Text Matching

```typescript
// "Log" matches "Log in", "Log out", "Blog" — use exact
page.getByText('Log in', { exact: true });
```
