---
name: executing-plans
description: "Use when you have a written implementation plan to execute in a separate session with review checkpoints — loads the plan, reviews it critically, then runs tasks with verification. Triggers on \"execute the plan\", \"run the plan\", \"implement this plan\". Do not use when subagents are available — prefer subagent-driven-development; reserve this for when subagents are unavailable or a short single-session run."
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Routing gate:** In Claude Code, subagents ALWAYS exist — prefer `subagent-driven-development` (fresh-context execution + per-task review) over this skill. Use this skill only when subagents are unavailable or the plan is a short single-session run.

## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns: Create TodoWrite and proceed

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- **Evidence before "done"** — paste the real verification command output before marking a task complete; never assert success
- **Re-baseline on drift** — if the codebase has diverged from the plan, stop and update the plan before continuing
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent

## Integration

**Required workflow skills:**
- **superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **superpowers:writing-plans** - Creates the plan this skill executes
- **superpowers:finishing-a-development-branch** - Complete development after all tasks

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Overil som v REPE, že súbory a rozhrania, ktoré plán menuje, naozaj takto existujú — alebo som začal vykonávať a čakám, že sa nesúlad prejaví sám?
