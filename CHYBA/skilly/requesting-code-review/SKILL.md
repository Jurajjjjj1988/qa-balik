---
name: requesting-code-review
description: Use when completing a task, implementing a major feature, or before merging to main — get an independent fresh-context review that the work meets requirements. Triggers on "request review", "get this reviewed", "code review before merge", "review my work". This requests and orchestrates the review; to evaluate review feedback you have received, use receiving-code-review instead.
---

# Requesting Code Review

Get an independent review to catch issues before they cascade — from a FRESH context, never your session's history, so the reviewer judges the work product, not your thought process. In this environment use the local `adversarial-review` skill (static gate + refute-by-default find/verify/fix on the working branch) or the `/code-review` command (reviews the current diff or a GitHub PR). A fresh-context reviewer beats the agent that wrote the code — it has no authorship bias.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Run the review:**

- Local working branch → invoke the `adversarial-review` skill (static gate, then find → refute-by-default verify → fix, so only real defects survive).
- A specific diff or GitHub PR → run `/code-review` (add `--comment` to post inline, `--fix` to apply findings).
- Hand the reviewer, as context (not your chat history): WHAT you built, the PLAN/REQUIREMENTS it must meet, and the `BASE..HEAD` range. The `code-reviewer.md` template in this folder is that context format.

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Invoke the adversarial-review skill on BASE..HEAD]
  WHAT_WAS_IMPLEMENTED: Verification and repair functions for conversation index
  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each batch (3 tasks)
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Sedí rozsah BASE..HEAD, ktorý si recenzentovi dal, na všetky zmeny, o ktorých hlásiš „prešlo" — alebo môže byť čisto preto, že sa nepozeral na nič?
