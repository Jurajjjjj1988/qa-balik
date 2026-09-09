---
name: test-strategy
description: Creates a test scenario table from a Jira ticket or feature description, mapping every acceptance criterion (AC) and Definition-of-Done (DOD) item to at least one test. Use when planning test coverage before writing test code. Produces a plan only — does not write test code (use write-tests for that). Triggers on "test plan", "test scenarios", "test strategy", "map ACs to tests", "coverage plan".
argument-hint: [Jira ticket or feature description]
allowed-tools: Read, Grep, Glob
---

Create test scenarios. No code — only a plan.

## Input Required

Before creating scenarios, get:

1. Acceptance criteria from Jira ticket
2. Definition of Done
3. Feature description

If any of these is missing, ask the user. Do not guess.

## Output

| #   | Category | Scenario | AC/DOD | Priority |
| --- | -------- | -------- | ------ | -------- |

- **Happy Path** — main flows
- **Edge Cases** — boundaries, empty, max
- **Negative** — errors, invalid inputs

Rules:

- Every AC item → at least 1 test
- Every DOD item → at least 1 test
- Priority: P1 (must), P2 (should), P3 (nice)

**Scenario name MUST be a verb phrase** describing a user journey:

- ❌ `'header renders'`, `'cart link exists'`, `'submit button present'`
- ✅ `'user navigates from header to pricing'`, `'user adds item and reaches cart'`

If the scenario name is a noun phrase, the test won't verify user value — rewrite it.

## Gherkin pass-through (when AC is already in BDD)

If the upstream AC is written in Gherkin (`Given/When/Then`), do NOT translate it to a scenario table — pass it through and add the priority + AC mapping columns alongside. The Gherkin clause IS the AC.

```gherkin
Scenario: User signs in via header
  Given I am on the homepage
  When I click the "Sign In" link in the header
  Then the URL should contain "/users/sign_in"
  And the email input should be visible
```

| Scenario | AC/DOD | Priority |
| --- | --- | --- |
| User signs in via header (above) | AC-3 | P1 |

For data-driven cases use `Scenario Outline` + `Examples`:

```gherkin
Scenario Outline: Login as <role>
  When I sign in with "<email>" / "<password>"
  Then I should land on "<landing_page>"

  Examples:
    | email          | password   | landing_page |
    | admin@x.com    | AdminPass1 | /admin       |
    | user@x.com     | UserPass1  | /dashboard   |
```

This collapses 3 Cartesian rows in the scenario table into one parameterized scenario — keeps the scenario count discipline from above intact.

**When to use this format:**
- PO/BA writes AC in Gherkin (avoid lossy translation)
- Team uses cucumber-js, pytest-bdd, Cucumber for Java, or any BDD tool
- Regulated context where AC must be human-readable for audit

**When NOT to use:**
- Engineers write tests directly in code without BDD layer (extra abstraction = pure tax)
- AC is loose English in Jira (just use the table; converting to Gherkin is busywork)

## Test architecture: Pyramid vs Honeycomb vs Trophy

Decision rule:

- **Frontend SPA (React/Vue/Angular)** → **Trophy** (Dodds). integration > unit > E2E > static. Unit-heavy FE pyramids over-test render-prop minutiae.
- **Backend monolith / library** → **Pyramid** (Cohn). 70% unit, 20% integration, 10% E2E.
- **3+ microservices crossing real network boundaries** → **Honeycomb** (Spotify). Mostly integration; few unit; **zero "integrated tests"** that spin up other services ("integrated tests are scams — they fail when someone else's service breaks, not yours").
- **Unsure** → Trophy for FE, Pyramid for BE. Don't pick Honeycomb unless you actually have multiple services.

E2E specifically: smoke / critical user journeys only (Google SRE: 5–7 CUJs is reasonable), never exhaustive coverage.

Source: Spotify Engineering, Google Testing Blog "Just Say No to More E2E Tests", Kent C. Dodds "The Testing Trophy".

## Scenario count discipline

If you generate > 12 scenarios from a single AC, you're hitting the Cartesian product. Pick the 5–7 highest-value journeys (Google SRE Critical User Journey doctrine) and drop the rest. Combinatorial coverage is a smell.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Existuje v tabuľke stav „NEPOKRYTÉ" a použil si ho pri každom AC/DOD, ktoré vypadlo pri škrtaní na 5–7 CUJ?
