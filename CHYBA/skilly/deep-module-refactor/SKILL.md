---
name: deep-module-refactor
description: Refactor toward Ousterhout "deep modules" (lots of behavior behind a small, well-designed interface) and away from the shallow-module sprawl the AI creates by default. Makes code testable at the interface and safe to gray-box. Also enforces VERTICAL slicing (thin end-to-end slices) over horizontal layer-by-layer work. Use when a codebase is hard to change/test, when planning how to slice a feature, or when the AI produced many tiny shallow files. Triggers on "deep module", "shallow module", "hard to test", "refactor architecture", "vertical slice", "tracer bullet".
argument-hint: [module, feature, or codebase area]
allowed-tools: Read, Grep, Glob, Edit, Write
---

# Deep-module refactor + vertical slicing

## Principle (Ousterhout — A Philosophy of Software Design)
Good code = few DEEP modules: much behavior hidden behind a small, well-designed interface. Bad code
(the AI default) = many SHALLOW modules: little behavior, wide interface, complexity leaking
everywhere. Deep modules are testable — test at the interface, gray-box the implementation. Shallow
sprawl is unnavigable for both you and the AI, so the AI can't understand its own codebase.

**Why it pays off (Farley / Gene Kim):** design exists to lower the COST OF CHANGE — a small requirement
change should be a small code change, not a rewrite — and to keep the system OPTION-RICH (max
uncertainty → most value in keeping options open). A small, well-chosen interface is exactly what lets
you swap the implementation cheaply later; shallow sprawl hard-wires today's guesses everywhere.

## Refactor procedure
1. Find related logic scattered across shallow modules / tiny functions with wide surface area.
2. Design the INTERFACE yourself — small, purposeful, hides the mess. This is the part you own.
3. Wrap the related code behind it as one deep module. Test at the interface only.
4. Gray-box the implementation (delegate, don't over-review) — EXCEPT money/auth/security/
   data-integrity: full review, ≥90% coverage AND mutation, never gray-boxed.

## Vertical slicing (Pragmatic Programmer — tracer bullets)
When planning WORK, slice VERTICALLY (thin end-to-end: DB→API→UI for one small capability), never
HORIZONTALLY (all DB, then all API, then all UI). Horizontal = no integrated feedback until the end.
Each vertical slice should fit one context window and be independently testable.

## Rules
- Interface first, implementation second. A wrong interface costs more than a wrong implementation.
- "Every changed line traces to the request" still holds — see Surgical changes in CLAUDE.md.
- Reject blind specs-to-code: keep the code in view; the code is the battleground.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Musí volajúci po refaktore vedieť MENEJ (menej pojmov, menej povinného poradia volaní), alebo si rovnaké vnútro len schoval za nový názov?
