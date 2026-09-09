---
name: invariant-bypass-audit
description: >-
  Use when writing or reviewing an INVARIANT that must always hold — append-only book, tenant isolation,
  "only one open X", non-negative money, immutable audit trail, single source of truth for a stored record.
  Catches the class where the invariant is enforced by a mechanism with a blind spot and the tests only
  exercise the paths the author thought of (row trigger vs TRUNCATE, RLS vs default privileges, one writer
  vs a second writer that overwrites the whole record). Triggers on "append-only", "immutable", "audit
  trail", "cannot be deleted", "only one", "RLS", "least privilege", "guard", "invariant".
  Do not use for ordinary input validation of a single field — that is negative-number/guard territory.
---

# Invariant bypass audit — count the doors, not the lock

## The class

**An invariant is only as strong as the weakest path that reaches its effect.** The failure is never
"we forgot to write a guard". It is: a guard exists, it is tested, it passes — and a *different route*
to the same outcome walks around it. The author tests the door they built. Nobody tests the window.

Three confirmed instances, three different technologies, same shape:

| Project | Invariant | Enforced by | What walked around it |
| --- | --- | --- | --- |
| SprayFlow (Postgres/PGlite) | stock ledger is append-only | `before update/delete … for each row` triggers | `TRUNCATE` — row triggers never fire; balance went 5 → 0 |
| firestop-app / taleapp (Supabase) | tenant isolation, append-only audit | RLS policies / absence of a DELETE grant | `TRUNCATE` (not subject to RLS) and platform **default privileges** granted on top of the migration |
| SprayFlow (React store) | measurement book is never overwritten | the writer that appends (`recordMeasurement`) | a **second writer** (`setDft`, autosave) that replaced the whole record and dropped the book |

Note the third row: this is not a database topic. It is about how many writers can reach one piece
of state.

## The method: enumerate effects, then routes

Do not start from the guard. Start from the **effect you are forbidding**, then list every route that
produces it. For each route: is it refused, and is there a test that proves it?

1. Name the forbidden effect in one sentence — "a movement row can disappear", "user A reads user B's
   rows", "the stored quantity becomes negative", "the book loses an entry".
2. List routes exhaustively (checklists below). Include routes that belong to the *platform*, not to
   your code — those are the ones that get missed.
3. For each route, one test that attempts it and asserts refusal. Red first: remove the guard, watch
   the test fail. A test that never saw red is decoration.
4. Where the list is table-driven (N tables, N stores), make the check **loop over a declared list**,
   so adding the next table cannot silently skip a route.

## Route checklists

### Postgres / any SQL

For "rows cannot be modified or lost":
- `UPDATE`, `DELETE` — the obvious ones, usually covered
- **`TRUNCATE`** — row-level triggers do NOT fire; RLS does NOT apply. Needs
  `before truncate … for each statement` **and** the privilege withheld
- `DROP TABLE` / `ALTER TABLE … DISABLE TRIGGER` — owner-only, but confirm the app role is not owner
- `COPY … FROM` (an INSERT path — fine for append-only, fatal for uniqueness assumptions)
- privileges granted **outside** the migration: platform **default privileges** (`pg_default_acl`),
  broad `grant … on all tables`, role inheritance, `PUBLIC`
- `SECURITY DEFINER` functions — they run as owner and bypass RLS by design

For "value stays in range": a CHECK on the column is the last line of defence; application validation
is not. Signed columns need the sign tied to the row's type, not just `<> 0`.

**A policy expression runs as the CALLER, not as the policy author.** An inline subquery inside
`using`/`with check` needs the calling role to hold `SELECT` on every table it touches. So a policy can
silently depend on a grant your security model forbids — and it keeps working right up until someone
tightens that grant. Only `SECURITY DEFINER` functions escape this; that is why the escape hatch exists.

> firestop 2026-07-31: `projects` had `with check (has_access… or not exists (select 1 from
> project_members …))`. `project_members` is deliberately grant-less (escalation guard), so the policy
> only worked thanks to an accidental platform default grant. Revoking it — the correct hardening —
> made **creating a project** fail with `42501 permission denied for table project_members`, and the
> connector dropped the write silently. Fix: move the subquery into a `SECURITY DEFINER` function.

### Tightening a privilege is a change to WRITE paths

Removing a grant reads like a pure security edit, so it gets reviewed like documentation. It is not:
whatever was leaning on that grant now breaks, and the breakage surfaces as a permission error deep
inside someone else's feature — often on a path that only runs in production (first project created,
first invoice issued, first member added).

- After any `revoke`, **re-run the write paths**, not just the reads. Create, update, delete — the
  bootstrap ones especially, because they have no prior state to lean on.
- Two layers that each look fine can be **coupled**: layer A silently satisfied a precondition of
  layer B. Hardening A is what reveals it — a good outcome, but only if a write path exercises it
  before the customer does.
- Reproduce under the **real role**, not as owner: `set local role authenticated;` +
  `set_config('request.jwt.claims', …)` inside a transaction you roll back. Owner bypasses RLS, so
  testing as owner proves nothing about what the client can do.

### Client-side stores (localStorage / IndexedDB / any shared state)

For "this stored field is never lost":
- every **other writer** of the same record — a writer that rebuilds the object instead of spreading
  it (`{ …previous, x }`) silently drops siblings. Count the writers; there is usually one you forgot
- **restore / import** paths (backup restore, seed, demo data) that write the whole key
- another tab, and the rebase-on-storage path inside the store
- the quota-full path (write fails; what is authoritative afterwards?)
- reading a stale copy before the update instead of computing inside the updater (lost update)

### HTTP / API

- the second endpoint that touches the same resource (admin route, bulk import, webhook)
- the retry that is not idempotent
- the client-side check with no server-side twin

These route lists are STARTERS, not a complete catalogue — a bypass not on them is still a bypass.
Derive the routes from the forbidden EFFECT each time (question 2 below); don't tick the list and stop.
This skill is a method + a gate SHAPE, not a bundled detector — nothing here scans the repo for you.

## Making it mechanical

Ordering, strongest first: **type/lint > declared list checked by a gate > a test > a sentence in a doc.**

A gate that iterates a declaration beats a hand-written test per case, because the declaration is what
a future author edits. Concrete shape (SprayFlow `scripts/check-db-schema.mjs`):

```js
// Declaration a future author must extend — the loop cannot forget a route.
const APPEND_ONLY = ['stock_movement'];
for (const table of APPEND_ONLY) {
  for (const route of [`update ${table} set …`, `delete from ${table} …`, `truncate table ${table}`]) {
    if (!(await refused(route))) fail(`${table}: ${route} passed`);
  }
}
```

The gate must **attempt the operation**, not read the catalogue. "A trigger named no_delete exists" is
not evidence; "DELETE was refused" is. And it must exit non-zero, or it is a report nobody reads.

## Review questions (fast pass)

1. What effect is forbidden here, in one sentence?
2. How many routes reach that effect? Name them out loud, including platform ones.
3. Which of them has a test that has actually been red?
4. Is the enforcement a single layer? (RLS alone, one trigger alone, one writer alone.) A second layer
   is warranted when the cost of breach is data loss, money, or cross-tenant exposure.
5. When the next table/store/endpoint is added, what forces the same routes to be covered?

## Where this came from

Sessions 2026-07-31 across firestop-app, taleapp and SprayFlow. Related memory notes:
`reference_db_privilege_drift_audit` (the 9 read-only SQL diagnostics + how to read them) and
`reference_negative_number_passes_guards` (the sibling class where the guard is blind to a *valid but
wrong* value rather than to a route).

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Bola každá cesta zo zoznamu naozaj SPUSTENÁ pod rolou aplikácie a odmietnutá — vrátane aspoň jednej cesty, ktorú checklist v skille nemenuje?
