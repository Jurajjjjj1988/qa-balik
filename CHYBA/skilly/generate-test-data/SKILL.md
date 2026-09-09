---
name: generate-test-data
description: Generates test fixtures — factory functions with defaults/overrides, realistic fake data, edge-case values, TypeScript const assertions. Use when a suite needs reusable test data or factories. Triggers on "test data", "fixtures", "factory", "fake data", "seed data", "mock data". Follow the test-data safety rules in real-testing-patterns (seed Faker, RFC 2606 example.com domains, never real PII).
argument-hint: [entity or data type]
---

Generate test data:

1. TypeScript interface for the shape
2. Factory function with defaults + overrides: `createUser({ email: 'custom@example.com' })`
3. Realistic fake values — john.doe@example.com, not test@example.com
4. Edge cases — empty string, max length, special chars, Unicode, 0, -1
5. Constants file with `as const`

```typescript
export function createUser(overrides?: Partial<User>): User {
  return { firstName: 'John', lastName: 'Doe', email: 'john.doe@example.com', ...overrides };
}
```

## Safety (non-negotiable)

- **Domains:** use `example.com` / `.org` / `.net` (RFC 2606 reserved); invalid cases use `.invalid` / `.test`. NEVER `test.com` (a live registered domain) or real providers like `gmail.com`.
- **Determinism:** seed Faker per test — `faker.seed(N)` in `beforeEach`, reset in `afterEach`, log the seed on failure. Unseeded random in branch logic flakes in CI.
- **Overrides are a SHALLOW merge:** `{...defaults, ...overrides}` replaces a nested object wholesale, and `undefined` clobbers a default. Type overrides as `Partial<T>`; for nested shapes use a builder, not a spread.
- **Uniqueness:** for DB-unique columns don't trust random — use `faker.helpers.uniqueArray` or a per-test counter/UUID suffix.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Podstrčil si tie okrajové hodnoty (prázdny reťazec, max dĺžka, Unicode, −1) SKUTOČNÉMU testu a videl si ho na nich padnúť — alebo ležia v `as const` súbore, ktorý nikto neimportuje?
