---
name: ai-doc-smell-detector
description: Quick-scan checklist for detecting AI-generated markdown / spec documents. Sibling to ai-test-smell-detector but targets prose, not tests. Detects 15 telltale patterns - em-dash bombing, &nbsp; decorations, symmetric tier hierarchies, pseudo-Socratic framing, buzzword stuffing, sterile lack of names/dates. Use when reviewing AI-written specs, README files, ADRs, or any doc that "feels symmetric".
argument-hint: [markdown file to scan]
allowed-tools: Read, Grep, Bash
---

# AI Doc Smell Detector

## TL;DR

- **Look for clusters, not items.** One em-dash is taste. Five em-dashes per ten lines + `&nbsp;·&nbsp;` decorations + three balanced bullets + rhetorical questions in block quotes = AI-shaped. The smells co-occur. The cluster is the tell.
- **Identify, do not rewrite the soul.** This skill points at lines and proposes terse fixes. It does NOT inject personality, stylize tone, or rewrite the doc end-to-end. It only removes machine signatures.
- **Sterile = suspicious.** A 500-line spec with zero ticket numbers, zero dated incidents, zero named people, zero PR links is almost always AI. Humans anchor docs in the concrete.

## Background — why this is measurable, not vibes

Em-dash frequency emerged as a reliable AI marker after late-2022 instruction-tuned models. The pattern is well-documented enough that [SALT.agency catalogued the debate](https://salt.agency/blog/in-defence-of-the-em-dash-what-the-ai-writing-debate-gets-wrong/) and a 2025 paper [arXiv 2502.12064](https://arxiv.org/abs/2502.12064) measured GLTR-based detection accuracy. The original [GLTR tool from MIT-IBM Watson + HarvardNLP](http://gltr.io/) showed that machine-generated prose clusters in the top-10 most-likely token positions far more than human prose does.

The Stanford detector study (cited widely 2023–2025) found GPT detectors misclassified 19.8% of non-native-English human essays as AI — a reminder that **single-signal detection is unreliable, but cluster-detection is robust**. This skill leans into the cluster.

Companion skill `ai-test-smell-detector` does the same for test code (arXiv 2410.10628 measured 99.85% Magic-Number-Test smell incidence on GPT-3.5). This skill applies the same discipline to prose.

CEE reviewers (SK/CZ/PL) reject this stuff flatly as "vyslovene strojové" — the regional preference for terse, opinionated prose makes the AI cluster especially conspicuous in markdown spec files.

---

## The 15 detectors

Each detector: **signal**, **why**, **severity**. Extended before/after examples live in `patterns.md`.

### 1. Em-dash bombing — Major

**Signal:** > 1 em-dash (`—`) per 5 lines of prose, used as in-sentence parenthetical separator.
**Why:** The strongest correlational tell. Humans use em-dashes for real parentheticals or dialogue; AI uses them as a default rhythm device. Volume is the signal, not presence. Replace 60% with commas, colons, periods.

```text
BEFORE: The header is not one component — it's a family — parameterised on two axes — and tests must pick.
AFTER:  The header is a family parameterised on two axes. Tests must pick the right cell.
```

### 2. `&nbsp;·&nbsp;` decorations — Critical

**Signal:** Literal `&nbsp;·&nbsp;` (or `&nbsp;|&nbsp;`, `&nbsp;•&nbsp;`) in headings or status blocks.
**Why:** No human types `&nbsp;` by hand. Notion / Confluence-paste artefact AI reproduces because it makes status lines look "polished". Visual fingerprint of machine output.

```text
BEFORE: > **Status:** Stable &nbsp;·&nbsp; **Version:** 1.1 &nbsp;·&nbsp; **Owner:** QA
AFTER:  > Last reviewed 2026-05-21 (Juraj). See git log for history.
```

### 3. Over-articulated metadata blocks — Major

**Signal:** Blockquote with 4+ `**Field:** value` pairs (Status / Version / Owner / Last reviewed / Last observed).
**Why:** Real specs have one or two metadata fields. The full template is a Notion-dashboard export shape, not a working-doc shape. Keep one field; let git carry the rest.

### 4. Symmetric tier hierarchies — Minor / Major when stacked

**Signal:** P1 / P2 / P3, Must / Should / Could, Critical / Important / Nice-to-have used as top-level headings.
**Why:** AI defaults to three balanced tiers because the corpus is full of MoSCoW / RICE frameworks. Real triage is lumpy. Inline tier in a sentence is fine; stacked tier headings are not.

### 5. Closing pithy lines — Minor

**Signal:** Sections ending with `When in doubt, X.`, `In other words: Y.`, trailing `TL;DR: Z.`, `Remember: ...`, `Bottom line — ...`.
**Why:** AI mimics blog-post conclusion patterns. Specs do not need an aphorism. Leading TL;DR is house style; trailing aphorism is the smell.

### 6. Rhetorical question dressing — Major

**Signal:** Pseudo-Socratic framing in block quotes ("If a journey can't articulate _'what bug would slip...?'_"), "Why does this matter?" headings.
**Why:** AI uses rhetorical questions for engagement. Spec readers want assertions. The question always gets answered next paragraph — wasted lines. Especially smelly in block-quote form.

### 7. Tables-for-prose — Minor

**Signal:** Single-row tables, 2x2 tables, N-row 2-column tables where the second column is one phrase.
**Why:** Tables earn their cost at ≥ 3 rows AND ≥ 3 columns AND real cross-comparison. A two-cell table is a sentence with extra syntax.

### 8. Bullet lists with bolded leading phrase — Minor / Major when default

**Signal:** 5+ consecutive bullets shaped `- **Phrase:** description.`
**Why:** Definition-list-as-bullet is fine in moderation. Used as the default list shape it produces visual rhythm without content rhythm — every list looks the same.

### 9. Defensive hedging transitions — Minor

**Signal:** `It's worth noting that...`, `Notably,...`, `Importantly,...`, `Of note,...`, `As a side note,...`.
**Why:** Throat-clearing. AI was trained to soft-land assertions. Humans say the thing or don't.

### 10. Buzzword stuffing — Major

**Signal:** `leverage`, `utilize`, `facilitate`, `comprehensive`, `robust`, `production-ready`, `first-class`, `seamless`, `cutting-edge`, `delve into`, `streamline`, `holistic`.
**Why:** Vocabulary the writer would never use in Slack. AI inserts them because the corpus is heavy with marketing prose. Each instance lowers credibility one notch.

### 11. Acronym then full form — Minor

**Signal:** `POM (Page Object Model)`, `API (Application Programming Interface)` when audience knows.
**Why:** Defensive expansion. Onboarding docs may expand; team-internal specs should not.

### 12. "In other words" restating — Minor

**Signal:** `In other words: ...`, `Put differently, ...`, `To put it another way, ...`, `That is to say, ...`.
**Why:** AI hedges by repeating the same idea in different shape. Say it well once or trust the reader.

### 13. Anticipating reader's question — Minor

**Signal:** `You might wonder why...`, `One might ask...`, `The reader may be asking...`, `A natural question is...`.
**Why:** Mind-reading the reader. If the question is real, just answer it; if imagined, don't invent it. Same family as Detector 6.

### 14. Three balanced bullets / three-of-everything — Minor / Major as whole-doc pattern

**Signal:** Every list = 3 items. Every paragraph = 3 sentences. Every section = 3 subsections.
**Why:** AI normalizes to 3. Humans write 2 when there are 2 things, 5 when there are 5. Count list lengths across the file; if 80%+ are exactly 3, the doc was generated.

### 15. Sterile lack of names / dates / incidents — Critical (when clustered)

**Signal:** A 200+ line spec with **zero** occurrences of: a person's name, ticket reference (`INK-1234`, `INV-5678`), PR link, dated incident (`broke prod on 2026-04-12`), or git SHA.
**Why:** Real engineering docs anchor in events ("Roman flagged this in INK-1842 after the 2026-04-12 hydration refactor"). AI has no incident history; it produces timeless, contextless prose. Sterility alone is not proof of AI; sterility + em-dash bombing + buzzwords + symmetric structure is.

```text
BEFORE: The cart click is sometimes intercepted. Tests should assert on href rather than navigation.
AFTER:  Roman flagged this in INK-1842 — the <ci-cart> flyout swallowed clicks after the 2026-04-12 hydration refactor. PR #2391 added the regression test.
```

---

## Detection workflow

```
1. Open the file. Read the first three sections + the metadata block.
2. Run the grep one-liners (see below) for a 30-second triage.
3. Apply the 15-detector checklist, line by line.
4. Score:
   - 0–4 smells   → human-written (or AI with disciplined editing)
   - 5–9 smells   → AI-assisted (accepted suggestions without trimming)
   - 10+ smells   → AI-generated, untouched (or trivially edited)
5. Order findings by severity:
   - Critical first: Detectors 2, 3, 15 (visual fingerprints + sterility)
   - Major next:    Detectors 1, 4, 6, 10 (rhythm + buzzwords)
   - Minor last:    Detectors 5, 7, 8, 9, 11, 12, 13, 14 (taste)
6. Output rewrites per smell — concrete before/after, not abstract advice.
7. End with the verdict: clean / moderate / heavy smell + score / 100.
```

### The "would the author defend this line?" gate

After the 15 detectors, run the **causal check**:

> "Can the author defend each paragraph in 60 seconds, without saying 'best practice', 'industry standard', or 'comprehensive'?"

If no, the paragraph is AI-shaped regardless of the score. The defendability gate subsumes all correlational tells.

---

## Quick scan — grep one-liners

Run these in the file under review for a 30-second triage:

```bash
FILE="$1"

# Detector 1 — em-dash density (rough; raw count, normalize by line count)
echo "em-dashes: $(grep -c '—' "$FILE") / lines: $(wc -l < "$FILE")"

# Detector 2 — &nbsp; decorations
grep -n '&nbsp;' "$FILE"

# Detector 5 — closing pithy lines
grep -nEi 'when in doubt|in other words|bottom line|tl;?dr:' "$FILE"

# Detector 6 + 13 — rhetorical questions in prose / blockquotes
grep -nE '(^>.*\?$|you might wonder|one might ask|a natural question)' "$FILE"

# Detector 9 — defensive hedging
grep -nEi "it'?s worth noting|^notably,|^importantly,|of note,|as a side note" "$FILE"

# Detector 10 — buzzword blacklist
grep -nEi 'leverage|utilize|facilitate|comprehensive|robust|production-ready|first-class|seamless|cutting-edge|delve into|streamline|holistic' "$FILE"

# Detector 11 — acronym-with-expansion
grep -nE '\b[A-Z]{2,5} \([A-Z][a-z]+ [A-Z][a-z]+' "$FILE"

# Detector 12 — restating-marker
grep -nEi 'in other words|put differently|to put it another way|that is to say' "$FILE"

# Detector 15 — sterility check (high-signal NEGATIVE — fewer matches = more smell)
grep -cE 'INK-[0-9]+|INV-[0-9]+|LINEAR-[0-9]+|PR #[0-9]+|broke prod|flagged' "$FILE"
```

Three or more hits on Detector 2 OR ten or more on Detector 1 OR zero on Detector 15 (in a 200+ line doc) = open the file with intent.

---

## Output format — what the skill produces

When invoked on a markdown file, produce:

```text
File: <absolute path>
Lines scanned: <N>

Smell score: <X> / 100   (0 = clean human, 100 = wholly AI)
Verdict: <clean | moderate | heavy>

Findings (sorted by severity):

  [Critical] Detector 2 — &nbsp; decorations
    Line 3:   > **Status:** Stable &nbsp;·&nbsp; **Version:** 1.1 ...
    Rewrite:  > Last reviewed 2026-05-21. See git log for history.

  [Major] Detector 1 — em-dash bombing (47 em-dashes / 527 lines = 1 per 11)
    Highest density: lines 78–95 (8 em-dashes in 17 lines)
    Rewrite:  replace 60% with commas, colons, or periods.

  [Major] Detector 6 — rhetorical question dressing
    Line 42:  > If a journey can't articulate _"what bug would slip..."_
    Rewrite:  > Every journey must name the bug class it guards against.

  [Minor] Detector 5 — closing pithy lines
    Line 483: When in doubt: assert what the user can **do**, not what...
    Rewrite:  Assert href patterns and aria-expanded toggling, not labels.

  [Critical] Detector 15 — sterile lack of incidents
    Doc has 527 lines and ZERO references to: ticket ID, PR, person name,
    dated incident. Add 3-5 concrete anchors (e.g. "Roman flagged in INK-1842
    after the 2026-04-12 hydration refactor").

Total findings: <N>
```

---

## What this skill does NOT do (anti-patterns)

These would push the skill from useful to harmful:

- **Does NOT rewrite the doc.** Identifies smells and proposes fixes. The author chooses.
- **Does NOT inject "personality" or stylize tone.** No "add a bit of voice", no "make it punchier" advice. Smell removal only.
- **Does NOT flag legitimate em-dashes** in citations, dialogue, quoted strings, or code blocks. Only counts em-dashes in plain prose.
- **Does NOT flag legitimate tables** with 3+ rows and 3+ columns of cross-comparison. Tables-for-prose only flags single-row or 2x2 tables.
- **Does NOT confuse house style with smell.** If a project uses Diátaxis or has a doc-template convention, those conventions are not smells. The skill flags the AI default, not the human choice.
- **Does NOT chase false positives on rare em-dashes.** Single em-dash in a 200-line file = noise, not signal. The threshold is density-based (> 1 per 5 lines of prose).
- **Does NOT replace human review.** A senior reader catches things this skill misses (e.g. logical inconsistencies, factual errors, missing edge cases). The skill speeds up the cluster-detection step that takes a senior 5 minutes; it does not replace the other 25 minutes of real review.

---

## What's NOT a smell (false positives to ignore)

- **One em-dash for actual parenthesis** — like Sam Saffron's blog title "Your vibe-coded slop PR is not welcome — and here's why" — is fine. Density matters, not presence.
- **Tables in a true matrix doc.** A 5-column 8-row variants matrix (page context × user state × etc.) is the right shape. Tables flag only when prose would be shorter.
- **Definition-style bullets in a glossary.** `- **POM:** Page Object Model.` is fine in a glossary section. Smelly when used as the default list shape across a whole doc.
- **Closing TL;DRs at the top of the doc.** A leading `## TL;DR` is house style. A trailing "In conclusion..." paragraph is the smell.
- **Acronym expansion in a doc aimed at juniors / mixed audiences.** Onboarding docs legitimately expand `POM`. Spec docs aimed at the team do not.
- **Three bullets when there are exactly three things.** The rule of three is real; just do not force-fit it.
- **Bilingual / multilingual quotations** (`vyslovene strojové`, `delve into`) used to make a point about regional preference. The doc is _about_ the smell, not exhibiting it.

---

## Connection to other skills

- **`ai-test-smell-detector`** — sibling skill, same cluster-detection discipline for test code. This skill is for prose; that one is for test bodies.
- **`comment-discipline`** — shared philosophy: comments / prose carry _why_, not _what_. Restating-the-code (in comments) and restating-the-spec (in prose) are the same smell.
- **`review-code`** — when the AI-doc-smell shows up in PR descriptions or in markdown changes, that skill carries the broader review checklist.
- **`generate-documentation`** — the generator. This is the detector. Run the detector on the generator's output before committing.
- **`readme-test-repo-pattern`** — for README-shaped docs specifically, that skill carries the multi-angle pivot tables / bug-class column conventions. This skill catches the AI smells that pollute the README format.

This skill is the **first-pass detector**. The fix-it skills are downstream.

---

## Sources

- [arXiv 2502.12064 — AI-generated Text Detection with a GLTR-based Approach (2025)](https://arxiv.org/abs/2502.12064) — GLTR-based detection accuracy measured on contemporary LLMs.
- [GLTR (MIT-IBM Watson + HarvardNLP)](http://gltr.io/) — original visual tool showing machine-generated prose clusters in top-10 most-likely tokens.
- [SALT.agency — In Defence of the em-dash: What the AI Writing Debate Gets Wrong](https://salt.agency/blog/in-defence-of-the-em-dash-what-the-ai-writing-debate-gets-wrong/) — catalogues the em-dash-as-AI-marker debate.
- [arXiv 2410.10628 — On the Diffusion of Test Smells in LLM-Generated Unit Tests](https://arxiv.org/abs/2410.10628) — companion measurement for test code (sibling skill).
- [Stenberg — Death by a thousand slops](https://daniel.haxx.se/blog/2025/07/14/death-by-a-thousand-slops/) — the defendability gate; reviewer mental model.
- [Sam Saffron — Your vibe coded slop PR is not welcome](https://samsaffron.com/archive/2025/10/27/your-vibe-coded-slop-pr-is-not-welcome) — asymmetry and slop-PR signals.
- Internal: `patterns.md` (in this skill folder) — full pattern reference list with examples lifted from real AI-generated specs.
- Internal: `/Users/kapusansky/.claude/skills/ai-test-smell-detector/SKILL.md` — sibling skill, same methodology applied to test code.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Merala sa hustota len nad PRÓZOU (mimo kódových blokov, tabuliek, citátov, glosára) — a pri verdikte „čisto" vieš doložiť, že detektory na tento dokument vôbec dosiahli (že regex sterility pozná jeho prefixy tiketov), nie že nemali čo nájsť?
