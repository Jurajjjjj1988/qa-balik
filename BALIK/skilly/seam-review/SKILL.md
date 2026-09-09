---
name: seam-review
description: >-
  Use when reviewing an ACCUMULATED range of commits rather than a single change — before a push,
  before a merge or PR, when unpushed work has piled up, before go-live, or when an app was built
  mostly by AI and no human has read it end to end. Catches the class that per-diff review
  structurally cannot: the defect that sits in the SEAM between separately-correct commits — a
  duplicate that only one side fixed, a file whose usual partner did not change with it, money logic
  that drifted out of the tested module, a guard added to one path only. Ships a git-mining script
  that ranks WHERE to look, so the retrospective review stops being "read everything".
  Triggers on "review before push", "review the whole branch", "accumulated changes", "spätný
  review", "nobody has read this", "we've got N unpushed commits", "seam", "review before merge".
  Do not use for a single commit or one feature's diff — that is adversarial-review / review-code.
---

# Seam review — the bug is not in any commit, it is between them

## The class

Per-diff review asks *is this change correct?* and each change **is** correct. The defect appears
only when you look at two of them together: commit A adds a second copy of a calculation, commit F
fixes the first copy, and nothing anywhere is wrong on its own. No reviewer of A or of F could have
caught it, because neither diff contained the contradiction.

This is why the retrospective pass over accumulated work finds a distinct class — and why it is the
step that gets skipped. It is the most expensive review you own and nothing alerts you to it.

**The economics are the whole problem, and this skill is built around them:** the value is not a
better method, it is a cheap pointer to *where* to spend the expensive attention.

Four signals, all mined from git history. Three rest on published evidence for the mechanism they
exploit; the fourth is an unbacked heuristic and is labelled as one everywhere it appears:

| Signal | What it means | Evidence |
| --- | --- | --- |
| **S1 co-change violation** | Two files have changed together many times. This time only one did. | Zimmermann et al., ICSE 2004 (ROSE): mined co-change rules put a correct further location in the top 3 suggestions >70% of the time |
| **S2 churn ranking** | Read in defect-probability order, not alphabetically | Nagappan & Ball, ICSE 2005: relative churn predicts defect density · Hassan, ICSE 2009: change entropy predicts faults |
| **S3 divergent duplicate** | The same declaration exists in several files; only some changed | Juergens et al., ICSE 2009: 52% of clones were changed inconsistently; **15% of those caused a fault** |
| **S4 unmoved test** | Source changed, no test moved with it | **None — heuristic.** It cites no study because none applies. (It used to cite McIntosh et al., EMSE 2016; that paper measures human *review* coverage and participation against post-release defects, which is a different quantity entirely.) Weigh S4 below the three above |

**Why this matters more for AI-written code.** GitClear's analysis of 211M changed lines (January
2020 – December 2024) found copy/pasted lines rose from 8.3% to 12.3% of changed lines between 2021
and 2024, while *moved* (refactored) lines fell from about 25% to under 10% over the same period.
2024 was the first year on record where copy/paste exceeded moved code. AI-assisted codebases sit
exactly in the regime where the Juergens fault mechanism operates: many duplicates, little
consolidation. S3 is the signal to read first in such a codebase.

## Run the map first

```bash
bash ~/.claude/skills/seam-review/scripts/seam-map.sh              # default: upstream..HEAD
bash ~/.claude/skills/seam-review/scripts/seam-map.sh HEAD~25      # explicit range
bash ~/.claude/skills/seam-review/scripts/seam-map.sh main --top 20
bash ~/.claude/skills/seam-review/scripts/seam-map.sh --clones --dead   # + jscpd and knip (slow, download on first use)
```

It prints **pointers, not findings** — "a human never looked at this junction", never "there is a
bug here". Work the top entries; a pointer you investigate and clear is a good outcome.

**What it writes, in full.** Into your repository: nothing, under any flag — there is no mode that
creates, edits or deletes a file in the working tree, so nothing is declared to the fence and every
commit-visible change is a defect. Outside it: one `mktemp -d` scratch directory, removed on exit;
with `--clones`, jscpd's JSON report inside that same scratch directory (`$TMPD/jscpd/`) plus npm's
cache when it first fetches jscpd; with `--dead`, the same for knip, which additionally caches its
compiled config under `node_modules/.cache/jiti/` — ignored by the VCS everywhere, so it cannot
reach a commit, but it is a write and this is the line that says so. That is a measurement, not a promise: a shared write-fence
fingerprints `git status --porcelain` before and after and closes every run with its verdict —

```
  ....  write-fence: clean — nothing commit-visible was changed.
```

A `✗ WRITE-FENCE BREACHED` line names the offending paths and forces a non-zero exit whatever the
report said. Two caveats worth knowing: the fence measures *commit-visible* state, so writes to
gitignored paths are outside it by design, and starting from an already-dirty tree it can only see
paths that were not already dirty. If `_lib/safety.sh` is missing the script still runs but says so
and drops the claim — an unfenced run is an unverified one.

## What to look for at each pointer

Take the seam classes in this order — the first three are where the real defects have been.

**1. Divergent duplicate (S3).** Two copies, one fixed. Ask: are the values still equal, and *what
happens the day one changes?* A duplicate that is identical today is not a defect but is a defect
generator. Specifically damning: a duplicate where one copy lives in a tested module and the other
in a folder excluded from coverage and mutation. That is money logic that walked out of its gate.
*Scope of the automated map:* S3 keys on IDENTICAL declaration text, so it surfaces the still-equal
duplicates (the generators). A single-line value that has ALREADY diverged (`0.2` vs `0.25`) no longer
pairs and the map goes quiet on it — there S2 churn is the likelier router, but only if the changed
file ranks by churn; a low-churn copy, or a divergence that predates the range, is caught by nothing
in-range, so read it yourself. A clean S3 means "no still-identical clones", not "no inconsistent copies".

**2. Co-change violation (S1).** The partner did not move. Only two explanations, and you must pick
one out loud: *this change genuinely did not need it*, or *it was forgotten*. The commonest real
instance is source-changed-test-unchanged: the test still passes, which is precisely why nobody
noticed it no longer tests what the code now does.

**3. Normalization split.** A value normalised (`trim` / `toLowerCase` / rounding / date parsing) on
the write path but not on the read or verify path. The two sides pass separate reviews and drift
apart; the difference surfaces on a user. One funnel, used by both sides, is the only fix.

**4. Contract drift across a serialisation boundary.** Types do not cross a database, JSON payload,
`localStorage`, sync message or export file. A producer changed shape in one commit, a consumer
still expects the old one, and the compiler is silent on both. Look wherever a shape is written in
one place and parsed in another.

**5. A guard added to one path only.** A new write path arrives in one commit, a guard in another,
and they do not meet. Hand this to `invariant-bypass-audit` — enumerate the routes to the effect,
not the guards.

**6. Two sources of truth for one derived value.** Two views over the same data computed by separate
filters. They agree today and contradict each other on a document later.

**7. Orphaned code.** A function whose only caller vanished three commits ago. Harmless until
somebody reads it and believes it is live.

## S6 — the export whose caller left (`--dead`)

An unused export is a seam by construction, and that is the whole reason this lives here rather than
in a "run every static analyser" skill. **Nobody writes an export nobody calls.** It went stale when
its last caller changed or disappeared — in some commit inside this range, and almost always in a
*different file* than the export itself. Per-commit review cannot see it: each commit, read alone,
merely deleted a call it no longer needed. It is S1's co-change signal arriving from the other side.

The scoping matters as much as the tool. `knip` run repo-wide on a mature codebase reports hundreds
of unused exports, and *that* report gets closed unread — which is worse than never running it. So
findings are ordered by how far **this range** is answerable for them:

| Bucket | Meaning | Listed? |
| --- | --- | --- |
| **this range removed the last mention** | the identifier is gone from the lines the range deleted, and appears in none it added | yes, first — this is the seam |
| **changed here, still no caller** | you edited the file and left a dangling export | yes |
| everything else | already dead before the range began | counted only, never listed |

Two refusals worth knowing, because both are the difference between a check people read and one they
learn to skip:

- If knip calls **most** of the changed files unused, it did not resolve your entry points. That is a
  misconfigured run, not dead code, and S6 reports a **HOLE** instead of listing anything. Give knip
  a config first.
- If knip's JSON is not the shape this parser understands, that is a **HOLE**, never a zero. knip has
  no top-level `files` key; a reader that invents one counts 0 for every repository forever — a check
  that can never fire.

The bucket assignment is textual: an identifier present among the range's removed lines and absent
from every added one. On a very common identifier that will occasionally be coincidence. These are
pointers, like everything else here.

## S7 — the drifted clone, read by a model

Every rung above keys on **text**. That is why the limits section below has to concede the type-3
clone: the copy somebody edited on one side, which is the copy that bites. No matcher reaches it. The
one instrument that does is a model reading the code — and the reason to distrust that instrument is
the reason to distrust any LLM finding: it is fluent about things it did not check.

So the rung is not "ask a model for duplicates". It is a bounded read-pass under four constraints,
each of them paid for by something that went wrong in the run that produced this section:

**1. Bound the slice — and slice on BOTH axes, because they find different defects.** An unbounded
pass returns a long list nobody reads, which is the same outcome as not running it, so bound it; what
you skipped is then a declared hole rather than a silent one. But *how* you bound it decides what you
can find at all, and one axis is not enough:

| Axis | Slice | What only this axis sees |
| --- | --- | --- |
| **by location** | a feature directory | the volume — a label map copied into three pages, one authorization predicate living under four different local names, money arithmetic inlined straight into JSX |
| **by intent** | every date function / every money transform / every guard, pooled across the whole tree | the *divergence between features* — two files that never share a directory and so are never read together |

On the one repository where both were tried, each axis missed things the other found. Location-sliced
passes missed a `toISOString()`-based "today" in one feature contradicting a local-calendar one in
another, and missed a module whose own docstring claimed membership in a gate it was absent from; an
intent-sliced pass put both pairs side by side and they were obvious. The intent-sliced pass in turn
missed most of the within-feature volume. **This was not a clean ablation** — the two runs also
differed in prompt wording, so some of that gap may be prompt, not axis. It is enough to justify
running both and not enough to claim a mechanism. Run location first for breadth, then at least one
intent pool over the values that must not drift — dates, money, identity, authorization.

Build the intent pool by grepping for the *concept* (`toLocale`, `toISOString`, `/ 100`, the role
names), not by extracting function declarations. A declaration extractor misses the copy that was
never wrapped in a function — an expression inlined in JSX, a non-exported arrow constant — and in
the measured run those were where the sharper divergences lived: a chart module quietly
reimplementing the gated currency formatter, and three date renderings pasted straight into markup.

**2. Force the schema, and make KEEP_SEPARATE a first-class verdict.** Each group returns `intent`,
`confidence` (HIGH/MEDIUM/LOW), `differences`, and an action of `CONSOLIDATE` / `INVESTIGATE` /
`KEEP_SEPARATE`, with the standing instruction *when in doubt, INVESTIGATE*. This is not
bureaucracy — it is the whole reason the pass does not cry wolf. Without a verdict that means "these
look identical and must stay apart", every port with five adapters behind it comes back as a
duplicate and the report loses its reader on the first page.

**3. Read the caller graph before you name a survivor.** The model ranks by how the code *looks*,
and nothing in a source file says which copy is the live one. Confidence is about sameness, never
about which side to delete.

**4. An empty result is a HOLE, not a clean bill — and this rung is the weakest link on that.**
Every other rung here comes from a script that either produces output or fails loudly. This one
returns whatever a model chose to write, and "no duplicate groups" is indistinguishable from "did not
look hard", "ran out of room", or "read three files and stopped". So record, per slice, *which files
were actually opened* and how many groups came back; a slice that reports zero without naming the
files it read is a slice that did not run. Same rule as everywhere else in this repository of
skills: a check that cannot tell clean from didn't-look must say HOLE.

**Evidence status of this rung: none published — a single observation.** S1–S3 above rest on cited
studies and S4 says plainly that it rests on nothing. S7 is in S4's category, not S1's: one
repository, one day, four slices, no re-run, no held-out set, no measure of how much of it reproduces.
Order of magnitude on cost, since the section would otherwise imply it is free: roughly a million
output tokens to cover a 251-file application twice. Weigh it accordingly, and if you run it on a
second codebase, correct this paragraph with what you see.

**What it found, and what it cost** (measured 2026-08-06, a 251-file React/TS POS app, 322 extracted
functions, four slices). Real defects, none of which any textual rung can reach, because none of them
is a matching pair of lines: a refund path wired to a *fake* payment adapter in production builds
while its sibling simulator is correctly `DEV`-guarded · a module whose own docstring claims
membership in the money mutation gate while appearing in neither the gate list nor the mutate list ·
a `today()` built from `toISOString()` (UTC) pre-filling a form field that every other date in the
app renders in local time · a sale-total formula whose JSDoc calls itself "the single source" while an
identical expression sits in a second file, both outside the money gate. False positives were
effectively zero: it held back on five fiscal adapters behind one port, on three same-shaped date
formatters with different roles, and on two upload helpers differing only in private-versus-public
bucket — *"swapping the outputs is exactly the kind of silent bug that escapes review"*.

**Where constraint 3 comes from.** Two independent passes over the same duplicated pair both chose
the module with **zero callers** as the consolidation home, and both wrote the rationale as though
the *live* copy were the redundant one. Here the move survives that mistake — the import is
re-pointed and the dead module comes back to life — but nothing in either output distinguished "this
copy is the one that runs" from "this copy reads better", because nothing in a source file says so.
Pick the home from the caller graph, then let the model argue about which body is nicer.

**Never run this pass unattended.** Its inputs arrive from background workers, and a file that exists
and parses is not a file that is finished — during the measured run the same intermediate output was
valid JSON with the full entry count at three different moments and three different groupings
(one bucket went 158 → 149 → 97). A completion check that counts entries cannot see that; only the
worker's own completion signal can. Unsupervised, the pass reads a half-written input and reports
confidently on it.

## Refute by default

Every pointer is a hypothesis. Demand a concrete path to a wrong outcome — real inputs, real state,
the actual line — before calling it a defect. "Could be null" is not a finding. For every confirmed
logical defect: **a failing test first, then the fix.** Then name the *class*, not the instance, and
write it into the project's CLAUDE.md — an S3 hit is never one duplicate, it is a habit.

Record cleared pointers (a gitignored `.adversarial-review/refuted.md` works) with the reason, so
the next run does not spend the same attention twice.

## Make it alert you

The reason this step gets skipped is that nothing raises a hand. Give that job to the machine —
paste into the project's `.claude/test-gate.sh`:

```bash
# Seam-review reminder: accumulated work hides defects that per-commit review cannot see.
unpushed="$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
if [ "$unpushed" -ge 10 ]; then
  echo "▲ $unpushed unpushed commits — run seam-review before pushing"
fi
```

A warning, not a failure: a gate that blocks on this gets weakened, and then it is gone.

## Anti-patterns

- **Reading the whole diff.** That is the expensive habit this replaces. Rank, then read.
- **Treating pointers as findings.** S1–S4 have no idea whether anything is wrong. Reporting them as
  bugs destroys trust in the list, and an ignored list is worth nothing.
- **Running it on a single commit.** There is no seam in one change; use `adversarial-review`.
- **Fixing the duplicate you found and stopping.** The habit produced it; the same habit produced
  others the script cannot see (S3 only matches single-line declarations, never drifted bodies).
- **Skipping it because the suite is green.** Green is what a seam defect looks like — both sides
  pass their own tests.

## Limits, stated plainly

**S5 does not find drifted clones, and nothing here does.** Measured 2026-08-01 on fixtures built for
it: given an exact copy, a copy with renamed identifiers, and a copy with two statements inserted,
jscpd (both 4 and 5) reports the exact copy and nothing else. PMD CPD behaves the same on TypeScript;
its `--ignore-identifiers` is documented for Java and C++ only. So the type-3 clone — the copy that
was edited on one side and is therefore the one that bites — is **outside every textual rung of this
skill**. Earlier wording called S5 "the half S3 cannot see", which promised exactly the capability
that does not exist. S7 is the only rung that reaches it, and it reaches it by *reading*, not by
matching: no recall guarantee, no reproducibility between runs, a real token cost, and a demonstrated
ability to name the wrong survivor with high confidence. Treat its output as pointers on the same
terms as S1–S4, never as a result.



S3 sees identical single-line declarations only, and only those that *define* something — a signature
or a literal / object / array / arrow initializer. `const x = helper(a)` is a call site, not a
duplicate, and is excluded on purpose: keying on every line starting with `const` made roughly half
of S3's output false on two real repositories. A duplicated *function body* that has already drifted
is invisible to it either way, and that is the more dangerous case. S4 matches on filenames only, so
a file covered by an integration or e2e spec under an unrelated name still shows up as "no test
moved". S1 needs history: a young repository or one squashed into few commits yields nothing — and
says so, rather than reporting a clean result. Nothing here understands semantics; for real
interference analysis the literature uses program dependence graphs and static analysis, which is a
different order of tooling. This is a cheap instrument aimed at the top few centimetres of the
problem — which is where the affordable wins are.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Pri každom signáli bez nálezu (S3/S6/S7): napísal si ho ako DIERU aj s tým, čo ten matcher principiálne nedosiahne — alebo ako „čisté"?
