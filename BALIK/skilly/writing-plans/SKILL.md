---
name: writing-plans
description: "Use when you have a spec or requirements for a multi-step task, before touching code — turns it into a detailed, task-by-task implementation plan with exact files, code, commands, and TDD steps. Triggers on \"write a plan\", \"implementation plan\", \"plan this feature\", \"plan the work\". Do not use before a design or spec exists — brainstorm first."
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Verification Discipline (per-task)

Each task in the plan must produce **evidence** that the change works.
The checkbox is the tick; the evidence is the proof. Don't tick without
both.

**Each task's success criteria must be:**

- **Independently verifiable** — separate proof per task (file existence,
  test pass, command exit code, screenshot, log line)
- **Exact** — numeric / date / quantity constraints are precise, never
  "approximately" or "around"
- **Grounded in dedicated controls** — when the task involves filters,
  sorts, or rankings, the verification must check the actual control's
  state (filter chip visible, sort dropdown value, etc.), not just the
  output appearance

**Hard rules for verification (extracted from Webwright methodology):**

- A search-box query NEVER satisfies an explicit filter requirement —
  use the dedicated filter / facet / sort control.
- Ranking claims ("cheapest", "best-selling", "highest-rated") must be
  grounded in the site's / system's actual sort control, not inferred
  from result order.
- Numeric, date, quantity, and unit constraints are EXACT. Wider buckets
  or broader defaults are failures unless no exacter control exists.
- If a selected state becomes hidden after a drawer / modal / dropdown
  closes, reopen it or capture a visible chip / summary before treating
  the state as verified.
- Empty result sets ARE valid evidence when the correct filters were
  demonstrably applied (e.g. zero search hits for a nonsense query when
  the query was actually submitted).

**Each task structure should include the "Expected" line** with the
concrete proof (command output, file content, exit code) that the
executing agent must observe before ticking the checkbox.

## Traceability anchors (`@prd` / `@task` / `@rules`)

Optional but high-value: thread requirement traceability through the plan
and into the implementation. Source pattern: agentic-SDLC frameworks where
*"any link can be scanned downstream when something changes — nothing
missed, nothing out of place."*

**Three anchor types:**

- **`@prd:<id>`** — link to the originating PRD / spec requirement
  (e.g. `@prd:REQ-42`, `@prd:doc-header.md#1.3-prvok-13`)
- **`@task:<id>`** — link to the task ID in this plan
  (e.g. `@task:T-007`)
- **`@rules:<id>`** — link to long-term stable constraints in
  `.claude/rules/*.md` (e.g. `@rules:R-12,R-15`)

**Where to put them:**

- Header comment of created / modified files:
  ```ts
  // @prd:REQ-42  @task:T-007  @rules:R-12,R-15
  ```
- Test case names or first `expect()` description:
  ```ts
  test("@rules:R-12 — empty cart shows empty-state copy", ...)
  ```

**Why bother:** when a downstream change happens (PRD update, rule change,
task scope shift), `grep -rn "@rules:R-12"` shows every place affected.
The chain becomes auditable — useful in regulated industries OR when
multiple agents / contributors work on the same surface.

**When to skip:** trivial 1-task plans, throwaway prototypes, single-person
projects with no traceability requirement. Don't bolt this on for show.

## Hard gates (optional blocking checks)

If you want stronger discipline than just self-review, define **explicit
gate checks** that block progression:

- **`/prd-check`** — before generating a plan, scan the spec for placeholders
  (`[TBD]`, `???`, `TODO`, `fill in`). If found, refuse to plan until they're
  resolved.
- **`/plan-check`** — before handoff to execution, validate every task has
  concrete code blocks, exact file paths, expected output. No vague steps.
- **`/test-check`** — before declaring tests complete, verify every `@rules`
  anchor has at least one test case referencing it.

The principle: *"AI cannot silently skip them."* Gates are hard blocks,
not reminders. If a gate fails, stop and surface what's missing —
never paper over.

For the existing customink-tests project, the `npm run check:drift` is an
example of a hard gate (CI step that fails the PR when doc § ↔ test
mapping has drift).

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Overil si v repe každú cestu, rozsah riadkov a príkaz, ktoré plán menuje — teda `Expected:` je predpoveď o REÁLNE spustiteľnom príkaze, nie exaktnosť vyrobená zákazom písať „TBD"?
