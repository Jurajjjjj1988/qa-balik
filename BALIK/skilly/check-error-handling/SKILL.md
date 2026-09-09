---
name: check-error-handling
description: Finds missing or weak error handling — unhandled promises, empty catch blocks, swallowed errors, missing React error boundaries, requests without timeout/retry, logging gaps. Use when reviewing a module or file for error-handling robustness. Triggers on "error handling", "unhandled promise", "empty catch", "swallowed error", "error boundary".
argument-hint: [module or file]
allowed-tools: Read, Grep, Glob
---

Find error handling gaps:

1. Async without try/catch or .catch()
2. Empty catch blocks — error swallowed silently
3. Generic `catch(e) {}` without logging or re-throw
4. Missing React Error Boundary
5. Network requests without timeout/retry
6. User sees technical error instead of human message
7. Errors logged without context (no stack trace, no request ID)

For each: where, what happens when it fails, how to fix.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Pozrel si sa aj na `catch`-e, ktoré ošetrujú NAOKO (zaloguje a vráti default / `?? 0` / prehltnutý re-throw), alebo si hlásil len prázdne a chýbajúce?
