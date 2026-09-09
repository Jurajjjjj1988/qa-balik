---
name: reality-check
description: Fast pre-commit / pre-ship self-review — does it match the requirement, anything half-done, did I break something else, do tests catch bugs, would I approve this PR. Use when about to commit, open a PR, or call work "done" and you want a quick honesty pass. Triggers on "reality check", "sanity check", "is this done", "ready to ship", "before I commit". For running the actual verify commands and evidence-gating success claims, use verification-before-completion.
argument-hint: [task or PR]
allowed-tools: Read, Grep, Glob, Bash(git diff *), Bash(git status *), Bash(npx playwright test *)
---

Sanity check before shipping. Be brutally honest:

1. Does it match the original requirement?
2. Anything half-done? TODO comments? Placeholder values?
3. Does it actually WORK or just not throw errors?
4. Did I break something else?
5. Missing error handling, tests, types?
6. Would I approve this PR if someone else wrote it?
7. Do tests catch bugs or just pass?

Verdict: **SHIP IT** / **FIX FIRST** / **START OVER**

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Máš výstup behu na otázky 3 („funguje to, alebo len nehádže chyby?") a 4 („nerozbil som niečo iné?") — alebo ich verdikt SHIP IT vyhlásil za zodpovedané z čítania diffu?
