---
name: gate-audit
description: >-
  Use when the question is whether a CHECK is real, not whether the code is correct: a suite green for
  suspiciously long, a step nobody has ever seen go red, a `|| true` or a swallowed exit code, a hook
  you are not certain is wired, a threshold someone may have lowered without saying, tests that moved
  out from under the runner's include globs, a money or auth module no threshold names, two config
  files setting the same limit to different values, `npm test` passing locally while CI runs something
  else, or a key that was rotated but still sits in git history. Also when taking over a project and
  asking which of its checks can be trusted, when adding a gate, before relying on one at go-live, or
  when someone wants proof rather than reputation — "show me that deleting this test would break the
  build". Proves each gate exists, is wired, is green today, and above all CAN FAIL: it writes a
  PASSING probe, then the same probe failing, and accepts the gate only if it went red for the second
  and not the first. Also finds money/auth files no threshold names, local gate commands CI never
  runs, and secrets buried in history a working-tree scan cannot see. Triggers on "gate audit", "is
  the gate working", "are our checks real", "does the gate actually fail", "can the gate fail", "never
  seen it fail", "quality gates", "test-gate", "coverage thresholds", "mutation gate", "secrets in git
  history", "CI parity", "|| true". Do not use to find defects in application code — that is
  adversarial-review, seam-review or go-live-gate.
---

# Gate audit — a gate you have never seen fail is indistinguishable from no gate

## The class

Every other quality instrument you own rests on one unexamined assumption: **that the gate works.**
Nothing checks that assumption, and its failure is silent by construction — a broken gate and a
satisfied gate produce exactly the same output, which is nothing.

The failure modes are mundane and none of them announces itself:

- the hook was never wired, so the gate runs only when someone types it
- the runner's `include` globs no longer reach the folder the tests moved to
- a threshold was lowered during a bad afternoon and nobody wrote it down
- the gate's money-file regex names three modules and the fourth was added last month
- CI runs a different set of commands than the local gate, so *locally green* and *remotely green*
  are two different claims
- a key was committed, then deleted in a later commit — gone from the working tree, permanent in
  history
- **the floor was set to today's score, so the ratchet never turns.** Recording debt at the current
  value is honest bookkeeping and a dead gate: `pct < floor` can only catch a *decrease*, never the
  existing hole. Measured 2026-08-02: a repo whose per-file mutation gate exited 0 while **219
  mutants went unkilled** (125 survived + 94 never covered — and *no coverage* is a bigger hole than
  *survived*, not a smaller one) — 113 in penetration logic, 55 in the coordinate math that decides where a
  marker sits on a fire-safety drawing. Green there means "nothing got worse", not "this is tested".
  A floor with no plan to raise it is a number, not a gate.
- **the gate's typecheck cannot see the test tree.** `npm run typecheck` uses the app tsconfig
  (`include: ["src"]`), which compiles **zero** files from `tests/` and `helper/` — verified with
  `--listFiles`, not read from the config. So the local gate stays green on a type error that turns
  CI red, and *locally green* is once again a different claim from *remotely green*. Any repo with a
  second tsconfig for tests needs that command in the gate too.
- **a pipe ate the exit code.** `run_gate | tail -30; echo "EXIT: $?"` reports *tail's* status, not
  the gate's — so a red gate gets written down as green by the very command written to check it.
  Measured 2026-08-08: a gate that failed on 43 lint errors was recorded as `EXIT: 0`, and only an
  independent hook run revealed it. Anything shaped `cmd | anything` needs `set -o pipefail` or
  `${PIPESTATUS[0]}`, and the number you report must be the one you acted on.
- **the gate threw the evidence away.** A gate that runs its suite as `vitest run … >/dev/null 2>&1`
  can say *something is wrong* but not *what* — exit 1 over a log where every other line is green.
  On a suite that takes minutes, the cost of a second run is what teaches people to click past red.
  Redirect to a file and print a bounded tail on failure; the gate's job is to be actionable, not terse.
- **the new check broke an older gate.** A check is judged not only by what it finds but by what it
  does to the instruments already in place. Measured 2026-08-08: a contract test added to catch a
  real defect read its sources via `import.meta.glob(…, { query: '?raw', eager: true })`. That
  registered every globbed file in the v8 coverage report with **zero statements** — and
  `percent(0, 0)` is 100 %. Five money modules **with no tests at all** jumped from 0 % to 100 % and
  the per-file money coverage gate passed on them; proven by running the suite with and without that
  single file. Structural checks that must read source belong in a standalone script beside the other
  gate scripts, never among the measured tests. **After adding any check, re-run the OTHER gates and
  compare their numbers** — a check that silences a gate is worse than no check.

This is the same argument as mutation testing, one level up. **A surviving mutant means a missing
test; a gate that cannot go red means a missing gate.**

## The vacuous pass — a transfer gate that has only ever run on an empty payload

A sibling of "never seen it fail", and harder to spot because the gate is *craftsmanship-good*: it
really decrypts, really restores into a throwaway Postgres, really compares the counts. It has just
never seen a single row. Its comparison is `0 == 0`, and `0 == 0` is true for **every** reason at
once — so the green cannot tell them apart:

- the source is genuinely empty (fine)
- `SUPABASE_DB_URL` points at the wrong or an empty database
- the schema is wrong, or the restore step re-creates its own schema on the target so a dump from
  the *wrong* source restores into a *correct* target and still shows zero
- the pipeline silently dropped the data (bad `--exclude`, encryption mismatch, truncated stream)
- the thing that was supposed to fill the source — a sync, an ETL — is dead

All five produce the same three zeros and the same ✓. Measured 2026-08-02, firestop DB backup:
`penetrations=0 projects=0 payroll=0`, restore `0`, `0==0 ✓` — and the restore applies its own
`000+001` schema to the throwaway target, so the count comparison sees **nothing** about source
identity. The photo mirror the same day: `✓ Fotky (Supabase 0, R2 0)` — it copied nothing and called
it proof. **`aws s3 ls` on an empty prefix even exits 1 with no stderr**, so "empty" and "broken"
share an exit code there too.

The rule is the mutation rule again: **a comparison with nothing to compare is a HOLE, not a PASS.**
Any gate that verifies a **transfer or round-trip** — backup/restore, mirror, sync, export→import,
migration — must prove two things that do **not** depend on how much domain data exists:

1. **Identity.** It is looking at the intended source. A schema *fingerprint* (assert the exact
   expected table set is present — a wrong DB is missing them) or a known identity marker. Wrong
   target → red.
2. **A non-trivial round-trip.** A guaranteed-non-zero **canary** artifact survives the whole
   pipeline byte-exact. Write a fresh per-run token into a dedicated `backup_canary` row (or a known
   storage key) *before* the dump; assert **that exact token** comes back after restore. Now the ✓
   means "the right database was reached and a real row survived encryption and restore", and the
   domain tables are free to be legitimately empty — reported as *"empty; identity + round-trip
   proven"*, never a blanket ✓.

**Prove it can bite (the probe, same shape as A3):** point the gate at a wrong/empty source, and
separately delete or corrupt the canary — each MUST turn it red. A gate that stays green on either is
vacuous, no matter how real its decrypt-and-restore looks. The canary table must be **created by the
restore procedure** (so `pg_restore --data-only` has a target) and **not** excluded from the dump —
the opposite of a keepalive/heartbeat table, which is excluded precisely because the restore does not
create it. Keep it out of the client sync (no publication, no client schema, RLS on, zero grants).

## Run it

```bash
bash ~/.claude/skills/gate-audit/scripts/gate-audit.sh              # measure
bash ~/.claude/skills/gate-audit/scripts/gate-audit.sh --liveness   # + prove the gate can fail
bash ~/.claude/skills/gate-audit/scripts/gate-audit.sh --no-run     # skip running the gate (fast)
```

Exit: `0` all proved · `1` blocker **or write-fence breach** · `2` undecided holes remain — **and `2`
is not a pass** · `3` refused (`--liveness` on a dirty tree or outside a git repo) · `64` bad argument.
Ctrl-C, `kill`, or a closed terminal aborts the run and removes the probe: it never cleans up and
then carries on reporting on rungs it did not measure.

## What it writes into your repository

| Mode | Files written into the repo |
| --- | --- |
| *(no flag)*, `--no-run` | **none** |
| `--liveness` | exactly one: `<dir holding the most unit tests>/__gate_liveness_probe__.<test\|spec>.<ext>` — created, gate run, deleted |

Everything else — gate logs, gitleaks report, intermediate lists — goes to a `mktemp` directory
outside the repository. `--liveness` is the only writing mode, and it is also the reason for the
next two paragraphs.

Any mode that runs the gate (A2, A3) **executes your own `.claude/test-gate.sh`**; coverage and
mutation output it produces is the gate's doing, not this script's. If it lands somewhere
committable the fence still reports it, because from your commits' point of view the run left it
there.

That table is not a promise you have to take on faith. The script fingerprints
`git status --porcelain` before and after itself, declares the probe path in advance, and compares:
anything commit-visible that changed without being declared is printed as **WRITE-FENCE BREACHED**
and the run exits `1` no matter how many rungs passed — a script that left something behind has
already disproved the only thing it was trusted about. Ignored paths are outside the fence by
design; they cannot reach a commit. If the shared library `~/.claude/skills/_lib/safety.sh` is
missing, the audit still runs but reports a HOLE saying the run is **unverified** — the checks are
unaffected, the guarantee is gone.

`--liveness` refuses to start on a dirty tree (exit `3`). Not bureaucracy: if the cleanup failed you
could not tell the script's leftovers from your own edits, and `git checkout` would be useless. Use
`--no-run` on a dirty tree; it writes nothing.

A scratch worktree would be stronger isolation than a fence, and it was measured rather than
assumed: a worktree checks out **tracked** files only, `node_modules` is gitignored in every project
here, and the gate dies there with `ERR_MODULE_NOT_FOUND` — turning a healthy gate into a reported
failure. So the probe stays in the real tree, behind the fence and the clean-tree guard.

`--liveness` writes one temporary test file, runs the gate, and deletes it. It is placed **beside an
existing test**, never in a guessed directory: runners restrict collection with include globs, and a
probe dropped somewhere uncollected makes a perfectly good gate look broken. Measured on
ekoplant-web, where a root-level probe produced exactly that false accusation.

Beside *which* test matters, and being a sibling proves nothing on its own: the alphabetically first
test file is routinely an e2e spec, and the fast gate does not run that suite at all. The probe goes
to the directory holding the most tests **outside** e2e/integration/playwright/cypress — and even
then collection is not assumed, it is read back out of the gate's own output.

**One run cannot prove this, and naming the probe does not rescue it.** A gate of
`npm test || true` followed by a leftover-probe scan — the scan this project's own rules prescribe —
goes red *and* prints the probe's name, for a reason that has nothing to do with a test failing. That
dead gate was certified as "the gate protects" until 2026-08-01, when running it proved otherwise.

So liveness costs **two further gate runs** — three in total, because A2 has already run your gate
once — and a **fourth** when the first three look like a pass. On a five-minute gate that is twenty
minutes, and that cost is the reason it is opt-in.

The same file is written first with a **passing** assertion, then with a failing one. Every
stray-file effect is present in both and cancels; only the assertion differs. But a delta alone is
still not proof: a gate whose colour follows the RUN COUNT — a cache that fills, a lock that
accumulates, a step that trips the third time — produces the same green-then-red and is stone dead.
A reviewer built one and it was certified; a deliberately random gate was certified in 2 runs out of
12. So on the pass path only, the passing probe is run once more and must come back **green again**.

The evidence is the **repeating delta**, never a single red:

| Control run (probe passes) | Defect run (probe fails) | Confirm run (probe passes again) | Verdict |
| --- | --- | --- | --- |
| GREEN | RED, names the probe | GREEN | the gate protects |
| GREEN | RED, names the probe | **RED** | **HOLE** — the colour follows the run count, not the assertion |
| **RED** | anything | — | **HOLE** — the gate reddens from the file merely *existing*; liveness is not measurable this way |
| GREEN | RED, probe not named | — | **HOLE** — the red may be a linter or a leftover-file scan, not the test |
| GREEN, probe named in neither run | GREEN | — | **HOLE** — never collected, so nothing was proved |
| GREEN | GREEN, probe named | — | **FAIL** — the gate watched a test fail and passed anyway |

## What the checks mean

**A1 wired.** An executable gate nothing invokes is a script, not a gate. Wiring means an actual
`hooks[<event>][].hooks[].command` in one of the four settings files Claude Code loads (user and
project, `settings.json` and `settings.local.json`) whose script still exists on disk — not the
string `test-gate` appearing somewhere in a file, which a permission rule satisfies just as well.

**A2 green today.** If the gate is red now, every judgement below it is about a broken instrument.

**A3 liveness.** The only check here that produces knowledge rather than reassurance.

**A4 critical-scope drift.** Gates name their protected modules explicitly — a coverage regex, a
mutation glob. Those lists are written once and the code keeps moving. The failure is a new payroll
or auth module that no threshold mentions: fully tested by appearance, ungated in fact.

The thresholds are almost never in the gate script; it says `npm run test:cov` and the globs live in
`vitest.config.ts`, `stryker.config.json`, or a per-file money gate reached through a package.json
script. So A4 reads those too, strips their comments, extracts include/exclude globs and path-shaped
regexes, and matches whole paths. Three verdicts per file: **inside an include pattern**, **matched
by an EXCLUDE pattern** (a real hole — deliberately outside the thresholds, e.g. `exclude:
['src/ui/**']`), or **named nowhere**. Reading the shell script alone, and calling a file covered
because a four-letter fragment of its name appeared *in a comment*, accused SprayFlow's most heavily
mutated modules of being ungated — the exact false accusation that trains you to skip the section.
A pattern match still says only *in scope of some threshold*, never *the threshold is high enough*.

**A5 local-vs-CI parity.** A command that exists only in the local gate protects only your laptop.
Tools are resolved through package.json scripts, so `npx vitest` locally and `npm run test:cov` in CI
count as the same protection. The CI side is built from `run:` step bodies **only** — a tool name in
a job title, an env var or a comment does not count as CI running it, or the PASS would be
unfalsifiable. The reverse case is worse and this check cannot see it: a CI step nobody runs locally
means you discover breakage after the push.

**A6 secrets in history.** Deleting a committed key changes nothing — history keeps it and clones
carry it. **Rotation is the fix.** Keys whose names are prefixed public (`NEXT_PUBLIC_`, `VITE_`)
are public by design and are reported separately; treating them as leaks trains you to skip the
section. Their safety is exactly the safety of your row-level policies, no more.

gitleaks exits `0` both when the history is clean and when it read nothing at all — outside a git
repo it prints `fatal: not a git repository`, reports `0 commits scanned.` and still exits `0`
(verified on 8.30.1). A PASS here therefore requires its **scanned-commit count**, quoted in the
output; no count, or a count of zero, is a HOLE. A non-zero exit with an empty report is gitleaks
*failing*, not gitleaks finding nothing, and is reported as a hole too.

## Anti-patterns

- **Adding a gate without ever watching it fail.** Then you own a belief, not a gate.
- **Weakening a threshold to get green.** The only honest moves are fixing the code or recording an
  accepted risk with a name against it.
- **Reading a skipped check as a pass.** A rung that could not run proved nothing; that is why holes
  are counted separately and why exit code 2 exists.
- **Trusting a transfer gate that has only ever run on an empty payload.** `0 == 0` passes for the
  right-but-empty source and the wrong source alike; require an identity fingerprint and a non-zero
  canary that survives the round-trip byte-exact.
- **Auditing gates instead of writing tests.** This finds nothing in your application. It tells you
  whether the things that find defects are switched on.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Prešla sonda celý cyklus zelená → červená MENUJÚCA sondu → znova zelená, a bežala pritom TOU cestou, ktorú reálne spúšťa hook/CI (nie ručným príkazom či tieňovým configom)?
