# AI Doc Smell Patterns — Reference List

This is the long-form reference for `SKILL.md`. The skill body is the 300-line scannable version; this file holds the full pattern catalogue with grep recipes and additional examples lifted from real AI-generated specs.

Format borrowed from `ai-test-smell-detector/SKILL.md`: name, signal, why, before/after, severity. The 15 detectors below match the SKILL.md ordering.

---

## 1. Em-dash bombing — the rhythm fingerprint

**Threshold**: > 1 em-dash per 5 lines of prose (excluding code blocks and tables).

**Grep**:

```bash
# Em-dash density per file
EM=$(grep -cE '—' "$FILE")
LINES=$(wc -l < "$FILE")
echo "$FILE: $EM em-dashes / $LINES lines = $(echo "scale=2; $EM/$LINES" | bc) per line"
```

**Sub-patterns**:

- **In-sentence parenthetical**: "The header — and this matters — is two tags." Smelly when stacked.
- **List-introducer em-dash**: "Tests must — at minimum — assert visibility, href, and accessible name." Replace with colon.
- **End-of-sentence em-dash**: "Don't include `/cart` here — see §3." Tolerable once; smelly when every section has one.

**False positives**: dialogue (`"I think — no, I'm sure — it broke"`), quoted titles, code samples containing em-dashes.

**Severity: Major.** The volume — not the presence — is the signal.

---

## 2. `&nbsp;·&nbsp;` decorations — the Notion-paste fingerprint

**Grep**:

```bash
grep -nE '&nbsp;|·' "$FILE"
```

**Why it stinks**: No human types `&nbsp;` by hand. The pattern appears when AI mimics Notion / Confluence rendered output, where the platform inserts non-breaking spaces as visual separators. Plain markdown does not need this.

**Variants seen in the wild**:

- `&nbsp;·&nbsp;` (middle dot, U+00B7)
- `&nbsp;•&nbsp;` (bullet, U+2022)
- `&nbsp;|&nbsp;` (pipe, ASCII)
- `&nbsp;—&nbsp;` (em-dash with NBSP padding — double-smell)

**Rewrite recipes**:

- Status lines: collapse to a single sentence (`Last reviewed 2026-05-21.`)
- Section dividers: use `---` on its own line
- Inline separators: replace with `, ` or `. `

**Severity: Critical.** Replace globally.

---

## 3. Over-articulated metadata blocks — the dashboard fingerprint

**Signal**: A blockquote with 4+ `**Field:** value` pairs separated by dots / pipes / NBSPs.

**Why it stinks**: Real specs carry one or two metadata fields. The full template (`Status / Version / Owner / Last reviewed / Last observed / Next review`) is a Notion-database export shape, not a working-doc shape.

**Rewrite**: Pick the one or two fields a reader needs at the top of a spec. Leave version history to git.

```text
# BEFORE
> **Status:** Stable · **Version:** 1.1 · **Owner:** QA / Test Suite ·
> **Last reviewed:** 2026-05-21 · **Last observed against staging:** 2026-05-21

# AFTER
> Last reviewed: 2026-05-21 (Juraj). Next: quarterly or on POM change.
```

**Severity: Major.**

---

## 4. Symmetric tier hierarchies — the framework fingerprint

**Signal**: P1 / P2 / P3, Must / Should / Could, Critical / Important / Nice-to-have used as top-level structure when content is lumpy.

**Why**: MoSCoW and RICE are real prioritisation frameworks. AI uses them as default organisation even when the content does not split into balanced tiers. Real triage is "these four are P1; the rest is whenever".

**Rewrite**: Inline the priority into a sentence. Drop the tier headings.

**Severity: Minor alone / Major when stacked.**

---

## 5. Closing pithy lines — the blog-conclusion fingerprint

**Signal**: A section or doc ending with one of:

- `When in doubt, X.`
- `In other words: Y.`
- `TL;DR: Z.` (at the END — leading TL;DR is fine)
- `Remember: ...`
- `Bottom line — ...`
- `The takeaway: ...`

**Grep**:

```bash
grep -nEi '^(when in doubt|in other words:|tl;?dr:|remember:|bottom line|the takeaway)' "$FILE"
```

**Why**: Blog posts close with an aphorism for engagement. Specs do not need to. The pithy line is rhetorical sugar.

**Severity: Minor.** Delete.

---

## 6. Rhetorical question dressing — the pseudo-Socratic fingerprint

**Signal**:

- Block quotes ending in `?` ("If a journey can't articulate _'what bug would slip...'_")
- "Why does this matter?" / "What does this mean for tests?" headings
- Mid-paragraph "But what about edge cases?" framing

**Why**: AI uses rhetorical questions to engage. Spec readers want assertions. Every rhetorical question gets answered by the AI in the next paragraph — wasted lines.

**Rewrite**: State the answer directly. The question was scaffolding; remove it.

```text
# BEFORE
> If a journey can't articulate _"what bug would slip if I deleted me?"_
> it does not belong in this surface.

# AFTER
> Every journey must name the bug class it guards against. Delete the ones
> that can't.
```

**Severity: Major** in block quotes; **Minor** mid-paragraph.

---

## 7. Tables-for-prose — the false-structure fingerprint

**Heuristic**: A table earns its syntax cost when there are ≥ 3 rows AND ≥ 3 columns AND a reader wants to scan across.

**Smells**:

- 1-row table (it's a sentence)
- 2-row 2-column table (it's two sentences)
- N-row 2-column table where the second column is one phrase (it's a definition list at best, prose at worst)

**Rewrite**:

```text
# BEFORE
| Trigger              | Effect                |
| -------------------- | --------------------- |
| Click `signInLink`   | Navigate to /sign_in  |

# AFTER
Clicking `signInLink` navigates to `/sign_in`.
```

**Tables that are NOT smells**:

- Variants matrix: 5 columns × 8 rows of cross-state assertions. Use the table.
- Element inventory: locator × accessible name × per-state column. Use the table.
- Bug-class × test-file × describe-name traceability. Use the table.

**Severity: Minor.** Optional cleanup.

---

## 8. Bullet lists with bolded leading phrase

**Signal**: 5+ consecutive bullets all shaped `- **Phrase:** description.`

**Why**: Definition-list-as-bullet is fine in moderation. Used as the default list shape it produces visual rhythm without content rhythm — every list looks the same.

**Rewrite**: Convert flat lists to prose; keep the definition shape only when the bolded phrase is a genuine term being defined.

**Severity: Minor (alone) / Major (whole-doc default).**

---

## 9. Defensive hedging transitions

**Grep**:

```bash
grep -nEi "it'?s worth noting|^notably,|^importantly,|^of note,|^as a side note|^one thing to note" "$FILE"
```

**Why**: Throat-clearing. AI was trained to soft-land assertions because direct claims trigger more "are you sure?" follow-ups in chat. In specs, direct claims are correct.

**Rewrite**: Delete the transitional phrase; keep the fact.

**Severity: Minor.** Each instance is small; the cumulative effect is large.

---

## 10. Buzzword stuffing — the marketing-prose fingerprint

**Full blacklist** (ordered by smelliness in technical docs):

| Word               | Smelly? | Use instead                                  |
| ------------------ | ------- | -------------------------------------------- |
| `leverage`         | Yes     | use                                          |
| `utilize`          | Yes     | use                                          |
| `facilitate`       | Yes     | help, enable, make easier                    |
| `comprehensive`    | Yes     | covers X, Y, Z (be specific)                 |
| `robust`           | Yes     | doesn't break on X (be specific)             |
| `seamless`         | Yes     | (delete; it adds nothing)                    |
| `production-ready` | Yes     | tested at scale, in prod since YYYY-MM       |
| `first-class`      | Yes     | supported, well-tested                       |
| `cutting-edge`     | Yes     | (delete or name the technology)              |
| `state-of-the-art` | Yes     | (delete or cite the paper)                   |
| `delve into`       | Yes     | go into, look at                             |
| `streamline`       | Yes     | simplify, shorten                            |
| `holistic`         | Yes     | end-to-end, across all of X (be specific)    |
| `ensure`           | Maybe   | "make sure" or just assert the fact          |
| `validate`         | Maybe   | "check" (OK in test contexts: "assert that") |
| `verify`           | Maybe   | "check" (OK in test contexts)                |

**Grep**:

```bash
grep -nEi 'leverage|utilize|facilitate|comprehensive|robust|production-ready|first-class|seamless|cutting-edge|delve into|streamline|holistic' "$FILE"
```

**Severity: Major.** Each instance lowers credibility one notch.

---

## 11. Acronym then full form — the audience-mismatch fingerprint

**Signal**: `POM (Page Object Model)`, `API (Application Programming Interface)`, `WCAG (Web Content Accessibility Guidelines)` when audience clearly knows.

**Rewrite**: Expand once at first use in a doc aimed at mixed audiences (onboarding, public README). Drop the expansion in specs aimed at the team.

**Severity: Minor.**

---

## 12. "In other words" restating

**Grep**:

```bash
grep -nEi 'in other words|put differently|to put it another way|that is to say|stated differently' "$FILE"
```

**Why**: Repeating the same idea in different shape because the AI is hedging on the first phrasing. If the first sentence works, drop the restatement. If it doesn't, fix the first sentence.

**Severity: Minor.**

---

## 13. Anticipating reader's question

**Signal**: `You might wonder...`, `One might ask...`, `The reader may be asking...`, `A natural question is...`.

**Why**: Mind-reading. Either the question is real (just answer it) or imagined (don't invent it).

**Severity: Minor.** Same family as Detector 6.

---

## 14. Three balanced bullets / three-of-everything

**Signal**: Every list has exactly 3 items. Every paragraph has 3 sentences. Every section has 3 subsections.

**Why**: The rule of three is a real writing pattern, but AI **only** uses three. Humans write 2 when there are 2 things, 5 when there are 5, 7 when they got carried away.

**Diagnostic**: Count list lengths across the file. If 80%+ are exactly 3, the doc was generated.

**Severity: Minor (instance) / Major (whole-doc).**

---

## 15. Sterile lack of names / dates / incidents — the strongest cluster signal

**Negative grep** (count hits — low count = smell):

```bash
grep -cE '(INK|INV|LINEAR|JIRA|TICKET)-[0-9]+|PR #[0-9]+|broke prod|flagged|noticed|2026-[0-9]{2}-[0-9]{2}.*incident' "$FILE"
```

**Why**: Real engineering docs anchor in events. AI has no incident history; it produces timeless, contextless prose.

**What real anchors look like**:

- `Roman flagged this in INK-1842`
- `we tried X on 2026-04-12 and it broke prod`
- `PR #2391 added the regression test`
- `Juraj noticed during the Investown audit`
- `as of 2026-05-21 the value changed from 844 to 855`
- `the 2026-Q3 hydration refactor introduced this`

**What sterile prose looks like**:

- `Tests should ensure robust handling of edge cases`
- `The component leverages a comprehensive approach`
- `It is important to note that proper validation is required`

**Severity: Critical** when combined with detectors 1–4 and 10. Sterility alone is not proof of AI; sterility + em-dash bombing + buzzwords + symmetric structure is.

---

## Combined cluster heuristic

A doc that hits **5 or more** of these is almost certainly AI-generated:

1. `&nbsp;·&nbsp;` anywhere
2. > 1 em-dash per 5 lines
3. Metadata block with 4+ fields
4. P1/P2/P3 used as headings (not inline)
5. Two or more buzzwords from Detector 10 list
6. Two or more rhetorical questions in block quotes
7. Zero ticket / PR / incident references in a 200+ line doc
8. Three-of-everything pattern (verify by counting)
9. Closing pithy line on more than 30% of sections
10. Acronym expansions in a team-internal spec

5+ hits = heavy smell. 3–4 = moderate. 0–2 = clean (or carefully edited).

---

## Real-world case study — `customink-tests/docs/components/header.md`

Used as the canonical test case for this skill. Findings:

- **Detector 1**: 60+ em-dashes in ~530 lines (density ≈ 1 per 9 lines). Major smell.
- **Detector 2**: `&nbsp;·&nbsp;` appears 25+ times. Critical smell.
- **Detector 3**: Top metadata block has 5 fields (Status, Version, Owner, Last reviewed, Last observed). Major smell.
- **Detector 4**: P1 / P2 / P3 priority block in §5.5. Minor (it's a real priority signal, but the symmetric shape is suspicious).
- **Detector 6**: Block-quote rhetorical question in §1 ("If a journey can't articulate..."). Major smell.
- **Detector 9**: "Importantly" / "Notably" / "Notes:" recurring throughout. Minor x N.
- **Detector 10**: Some "comprehensive" usage; mostly clean of pure buzzwords. Minor.
- **Detector 14**: Many three-bullet sub-lists (TL;DR has 3, variants have 3 axes, etc.). Inconclusive — could be content-driven.
- **Detector 15**: **Zero ticket numbers, zero PR links, zero named people** in 527 lines. The 2026-05-21 dates anchor it slightly, but no actual incidents are referenced. Critical when combined with above.

**Estimated smell score**: ~65 / 100. Verdict: **heavy AI-shaping**, though the underlying engineering content (variants matrix, traceability table) is solid. Recommendation: keep the matrix tables, strip the `&nbsp;·&nbsp;` decorations, replace 60% of em-dashes, add real ticket / PR / incident anchors.

This is a productive case: the doc has real signal (matrix structure, observation dates, version drift notes) but is wrapped in AI-shaped chrome. Smell removal would make it more credible without losing engineering content.
