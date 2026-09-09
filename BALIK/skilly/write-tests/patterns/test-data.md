# Test Data Patterns

```typescript
export const TEST_DATA = {
  VALID_USER: {
    firstName: 'John',
    lastName: 'Doe',
    email: 'john.doe@test.com',
  },
} as const;
```

## Rules

1. Centralize in `data/` — never hardcode in tests
2. Realistic but fake — `john.doe@test.com`, not `test@test.com`
3. `as const` for type safety
4. Credentials in `.env` via `process.env`, never in data files
