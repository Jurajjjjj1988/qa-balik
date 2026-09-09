# Review dimensions — bounded per-lens checklists

Pick 3–6 lenses for a run; give each finder ONE lens. Each bullet is a concrete thing to look for.
High recall within a bounded scope beats a vague "review everything".

## Contents
- [Correctness & data-flow](#correctness--data-flow)
- [Security (OWASP-bounded)](#security-owasp-bounded)
- [Concurrency & async](#concurrency--async)
- [Error handling](#error-handling)
- [API / contract](#api--contract)
- [Persistence / offline](#persistence--offline)
- [Performance](#performance)
- [Domain make-or-break core](#domain-make-or-break-core)

## Correctness & data-flow
- Nullable/optional return dereferenced without a guard (esp. under `noUncheckedIndexedAccess`).
- Off-by-one, wrong comparison/operator, inverted boolean, missing `switch` branch (no `default`).
- Stale/derived state: a value computed once at mount that should track a prop/dep.
- Identity vs value equality; mutating a shared object/array instead of copying.
- Silent truncation, unhandled empty-collection case, wrong key in a lookup/group.

## Security (OWASP-bounded)
- Input validation on the SERVER/trust boundary (not just client).
- Injection: SQL/NoSQL/command/XSS/path-traversal/template.
- AuthN + session handling; AuthZ / access-control / privilege-escalation (IDOR).
- Crypto strength + key management; no hardcoded secrets/tokens in source.
- Unsafe deserialization / XXE; SSRF on server-side fetches.
- Sensitive data in logs/errors; missing rate-limiting on abuse-prone endpoints.
- Business-logic / state races (double-spend, TOCTOU on ownership checks).

## Concurrency & async
- Data races / check-then-act; ordering assumptions between async steps.
- Unawaited promises (floating), unhandled rejection, lost errors in `.then` without `.catch`.
- React effect dependency arrays: stale closures, missing/extra deps, infinite loops, double-run.
- Resource cleanup: subscriptions, timers, object URLs, listeners, DB handles freed on unmount/exit.

## Error handling
- Empty or swallowed `catch`; error thrown away or logged then ignored.
- Unchecked nullable return treated as present.
- Missing resource cleanup on the error path (leak on throw).
- Secure error logging (no secrets/PII); missing error boundary / fallback UI.

## API / contract
- Breaking signature/shape change without back-compat; wrong HTTP status/verb.
- Request/response schema drift vs the documented contract; unvalidated external payloads.
- Pagination/idempotency-key/versioning omissions.

## Persistence / offline
- Data-loss on write (overwrite, last-write-wins where it shouldn't be); non-idempotent migration.
- Key collisions; orphaned rows on delete; seed-vs-persisted precedence bugs.
- Sync/merge correctness; optimistic update not reconciled with server truth.
- **Auth ↔ local-first sync-engine lifecycle** (PowerSync/RxDB/Replicache + Supabase/Firebase Auth): does logout `disconnect()` + **clear the local synced DB** (else next user on a shared device reads the previous user's rows / uploads their queue under a new JWT)? Is the clear guarded by an empty-upload-queue check (else offline work is destroyed)? Does logout **verify** signOut killed the session (offline `signOut` returns `{error}` before removing tokens → zombie session self-restores on reload)? Is there an `onAuthStateChange` subscription (else `user` stays set after the session dies)? Does a server rejection (RLS `42501`) SURFACE or get silently `console.error`+dropped?

## Performance
- N+1 queries/requests; unbounded loops or allocations on hot paths.
- Blocking/synchronous work on the main thread / request path; missing memoization causing re-renders.
- Large payloads shipped when a projection would do.

## Domain make-or-break core
- Name the app's ONE central invariant (e.g. "marker placement must stay pixel-accurate through
  zoom/rotation", "billing never double-counts") and hunt anything that could violate it. A single
  break here outweighs a dozen nits.
