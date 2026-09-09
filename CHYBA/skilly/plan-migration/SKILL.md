---
name: plan-migration
description: Plans migrations step by step — library upgrades, framework changes, DB schema changes — with breaking-changes analysis, rollback plan, and testing strategy. Use when upgrading a major dependency, switching framework, or changing a schema. Triggers on "migrate", "upgrade", "breaking changes", "rollback plan", "schema migration", "version bump".
argument-hint: [what to migrate from/to]
allowed-tools: Read, Grep, Glob, Bash(npm outdated *), Bash(npm ls *), Bash(npx npm-check *)
---

Before starting (dependency upgrades only):
```
npx --yes npm-check --version 2>/dev/null || true   # npx fetches transiently; skip for DB/framework migrations
```

Plan migration:

1. **Classify → pick a pattern** (migration type decides strategy):
   - System / framework replacement → **strangler-fig**: route slices to the new system incrementally, retire the old.
   - DB schema change → **expand-contract**: add new shape → dual-write / backfill → switch reads → drop old. Never rename-in-place.
   - Library swap behind your code → **branch-by-abstraction**: introduce an interface, migrate callers, delete the old impl.
2. **Scope** — what changes, what is affected. Dep upgrades: `npm outdated` / `npx npm-check`. DB/framework: those are irrelevant — read changelogs + build the matrix below.
3. **Compatibility matrix** — rollout must keep BOTH pairs green: old-code × new-schema AND new-code × old-schema. If either breaks, slice finer.
4. **Steps** — one step = one reversible change; run tests after each. Destructive/irreversible steps (drop column, delete data) go **last**, only after the new shape is proven.
5. **Online DB mechanics** (zero-downtime): batched backfill (not one giant UPDATE), short `lock_timeout`, `CREATE INDEX CONCURRENTLY`, and `gh-ost` / `pt-online-schema-change` for large-table alters.
6. **Rollback** — classify each step reversible vs irreversible; keep the old shape until the new one is proven; feature-flag the cutover so revert is a flag flip, not a redeploy.
7. **Testing** — before / during / after; include the compatibility-matrix checks in CI.

Rule: never migrate everything at once. Incremental, reversible steps; destructive last.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Skúsil si nevratný krok a jeho rollback na KÓPII produkčných dát, alebo plán stojí len na changelogu a schéme?
