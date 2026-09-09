---
name: go-live-gate
description: >-
  Use before an app meets real users for the first time — go-live, production release, pilot,
  "skúšobná prevádzka", first paying customer, handing an app over to a client, first real invoice
  or payroll run. Audits the layer a diff review structurally cannot see: config/secret parity,
  first-run-on-empty-production paths, a restore that was actually performed, migration against a
  COPY of production data, privileges exercised under the REAL role, the built artifact, a second
  person writing at the same time, operational blindness, the way back, and the legal, retention and
  clock duties attached to the data. Produces a release record in which every item is PASS-with-evidence,
  FAIL, or a declared HOLE — never a silent pass. Triggers on "go live", "production release",
  "ready for users", "pilot", "release gate", "pre-production check", "hand over to the customer",
  "prod readiness", "skúšobná prevádzka", "pustiť do produkcie".
  Do not use to review a code change — that is adversarial-review / review-code.
---

# Go-live gate — the failures are not in the diff

## The class

Every review tool in this toolbox is **a function of a diff**: it is handed a change and asked
whether the change is correct. Go-live failures are **a function of state** — they live in the gap
between code that is correct and an environment, a dataset, and an operator that are not what the
code assumed. A diff review cannot see that gap, no matter how many times it runs.

Four confirmed instances, one project, none of which a code review found:

| What broke | Where the defect actually lived | Why review missed it |
| --- | --- | --- |
| Creating a project stopped working | a `revoke` on `project_members`; the RLS policy expression runs with the **caller's** rights | as owner you bypass RLS — locally it worked every time |
| Rows nobody could see | migrated data had no `project_members` row | schema was right, data was wrong; surfaced only in the live migration |
| A write vanished permanently | `42501` classified fatal → `transaction.complete()` drops it from the queue; UI still shows it | correct per-file logic, catastrophic per-system behaviour |
| Suite red locally, green in CI | Vitest inherits the developer's `.env`; CI has none | machine config, not code |

**The rule this skill enforces: a go-live check is a PROOF or it is a HOLE.** Reading a catalog, a
config file, or the source is not proof. Running the operation under the real identity is. An item
you did not prove is reported as a hole — never rounded up to green.

## What this skill deliberately does NOT do

Run these first; this gate assumes the code is already reviewed and the suite is green.

| Concern | Use instead |
| --- | --- |
| Is this code change correct? | `adversarial-review`, `review-code` |
| Can an invariant be walked around? | `invariant-bypass-audit` |
| Do the tests catch bugs, or just pass? | `anti-ai-slop`, `real-testing-patterns`, `test-layers-money-critical` |
| CVEs / stale dependencies | `check-dependencies` |
| Taint / injection paths in source | `semgrep`, `codeql`, `security-audit` |
| Does it match the requirement? | `reality-check`, `verification-before-completion` |

This gate asks one different question: **will it survive contact with a real environment, real data,
and a real person?**

## Step 0 — run the mechanical half

```bash
bash ~/.claude/skills/go-live-gate/scripts/release-gate.sh          # full run — see the warning below
bash ~/.claude/skills/go-live-gate/scripts/release-gate.sh --fast   # skip prod build + test-gate
bash ~/.claude/skills/go-live-gate/scripts/release-gate.sh --out docs/release-record.md
```

**A full run is not read-only.** Every path it can write, and under which flag:

| Flag | What it writes into your repository |
|---|---|
| `--fast` | nothing, except an `--out` record you aimed there yourself. Its scratch files live in `$TMPDIR` and are deleted on exit. |
| `--out FILE` | the release record, at `FILE` and nowhere else. Aim it outside the repository and the repository stays untouched. |
| full run (no `--fast`) | everything `npm run build` (G7) emits — `dist/` `build/` `.next/` `out/` `.svelte-kit/` — plus everything `.claude/test-gate.sh` (G8) emits: `coverage/` `reports/` `.stryker-tmp/` `playwright-report/` `test-results/`. Neither command is under the script's control, so that list is what it declares, not a guarantee of what your gate does. |

Most projects gitignore all of that, and git then never sees it. Where they are **not** ignored the
script declares them in advance to a write-fence, which diffs `git status --porcelain` around the
whole run and **fails the script if anything commit-visible changed that was not declared** — a
breach exits non-zero even when every check passed. The last line of every run is that measurement;
if the fence library is missing the run says so and marks itself UNVERIFIED rather than going quiet.

Because a full run writes, it **refuses to start on a dirty working tree**, or outside a git
repository where nothing it wrote could be undone. On someone else's repository, or when the tree
must stay pristine, use `--fast` and close G7/G8 by hand.

**Give it a 10-minute timeout** (`600000` ms). A full run compiles the production bundle and runs the
project's whole suite; at the default Bash timeout it is killed partway through and the record ends
mid-section, which reads exactly like a passing run that simply had less to say. If you only have a
short window, use `--fast` — that at least declares the two skipped steps as holes.

Exit codes: `0` everything proved · `1` at least one blocker · `2` no blockers but undecided holes
remain. **`2` is not a pass.** The run is complete only when the `== verdict` block has printed;
output that stops at a section header means the command was killed, not that the section passed. The script decides nothing that requires judgment; it only removes
the items a human should never spend attention on (env parity, secrets in the bundle, source maps,
`.only`, lockfile drift, prod build).

## The ten classes (judgment half)

For each: the question · what counts as proof · the shape of the failure.

**Not every class binds every app — but decide that out loud.** A local desktop/kiosk app has no
hosting variables (class 1 shrinks) yet still has classes 3, 8, 9. A read-only public site has no
class 9. An app with no personal data still has class 10 if it issues documents. A class you skip is
a line in the record saying why, not a class you quietly stop seeing.

### 1. Config & secret parity
*Every variable the code reads exists in the deployment, with the right value, and nothing secret is
readable by the browser.*
**Proof:** list from the script vs. the hosting provider's actual variable list, read side by side.
For each client-side variable, state why it is safe to be public.
**Failure shape:** white screen on first load, or `undefined` silently becoming a default. Nothing in
the code is wrong — the code is simply reading something that isn't there.

### 2. First run on empty production
*The paths that execute exactly once, on a database with no rows, by a user with no history.*
**Proof:** a fresh account creates the first tenant/project/customer, then the first real document,
on the production stack. Not seeded, not locally.
**Failure shape:** bootstrap requires the very row it is supposed to create. Local development never
exercises it because your DB already has that row from months ago.

### 3. Restore, proven
*The backup restores into a working app, and you know how long that takes.*
**Proof:** restore the most recent backup into a scratch database, boot the app against it, open one
real record. Write down the wall-clock time.
**Failure shape:** backup runs nightly for a year and turns out to be schema-only, or encrypted with
a key that lives only on the machine that died. "Netestovaná záloha = neexistuje" is a rule you
already have; this is the step that discharges it.

### 4. Migration against a COPY of production data
*Forward migration and rollback, on real rows — not an empty schema.*
**Proof:** dump prod → restore to scratch → migrate → the app boots and the counts match → roll back
→ the app still boots.
**Failure shape:** a `NOT NULL` or a new FK is fine on an empty table and impossible on real data.

### 5. Privileges under the REAL role
*Exercised as `authenticated`/`anon`, not as owner.*
**Proof:** `set local role authenticated;` then attempt each write path and each cross-tenant read,
inside a transaction you roll back. Refusal must be observed, not assumed.
**Failure shape:** you test as owner, bypass RLS, and prove nothing. Platform default privileges
grant on top of your migration. See `reference/probes.md` §3, and `invariant-bypass-audit` for the
route enumeration.

### 6. The built artifact
*What ships is not what you ran in dev.*
**Proof:** the production build boots and serves; no secret value appears in the bundle; no source
maps shipped; the service worker updates rather than pinning users to the old version forever.
**Failure shape:** `npm run dev` works for months; `npm run build` fails on the first strict error,
or ships a service worker that never hands users the new code.

### 7. Operational blindness
*When it breaks at the customer, how do you find out?*
**Proof:** deliberately trigger one error in production-like conditions and observe it arriving
somewhere you will look. Also: what is the retention, and who is on the other end?
**Failure shape:** you learn about the outage from an angry phone call, three days late, with no log
to reconstruct what happened.
**Free-tier corollary:** if the platform sleeps or throttles on inactivity, the keepalive job is now
load-bearing infrastructure. Prove it ran this week; nothing watches the watcher.

### 8. The way back, and the irreversible inventory
*Can you undo the release, and which operations can never be undone?*
**Proof:** name the previous good version and the command that returns to it, timed. Then list every
operation that cannot be taken back — fiscal receipt, sent e-mail, external payment, hard delete,
issued document — and for each, the idempotency key that makes a retry safe.
**Failure shape:** rollback exists for code but the migration already rewrote the data; or a retry
after a timeout issues a second real receipt.

### 9. The second person, and the second device
*Two humans on the same data at the same time — and one of them on shared hardware.*
**Proof:** two real sessions edit the same record concurrently; confirm neither side's work vanished.
On a shared device, log out and log in as the other person, then ask **storage** what remains, not the
screen. Offline-capable: take one device offline, write on both, reconnect, compare.
**Failure shape:** last-write-wins silently discards a colleague's work. This class cannot occur in
development, because you are one person. It has already occurred twice in this codebase family: a
second writer replaced a whole record and dropped the append-only book inside it; and a shared tablet
kept the previous user's rows after logout, because the module singleton outlived the identity change.

### 10. Legal, regulatory, and the clock
*The duties that attach to the data, and the boundaries the law counts in.*
**Proof:** name each category of personal or regulated data, where it is stored, how long it is kept,
and who may read it. For every legal period — payroll month, fiscal day, VAT period, retention
deadline — compute one boundary case and check it against the calendar a person would use.
**Failure shape:** timestamps stored in UTC and grouped by local date move an hour of work into the
wrong month, every month, forever — and that is a payroll error, not a rounding error. Or the
software is perfect and the operator has no lawful basis to run it.
**Triggers:** personal data (basis, retention, erasure, list of processors) · fiscal receipts and POS
· statutorily confidential channels · anything a professional authority certifies. Correctness of a
regulated output cannot be established by a test — only by the authority. Say so; do not paper over it.

## The gate is a sequence, not a point

The ten classes answer *is it ready*. They do not answer *how do we go*, and no amount of extra
checklist depth substitutes for that. Multi-tier approval boards are the usual answer and they are
theatre at this scale — depth you cannot finish gets clicked through, which is worse than no gate.
What is not theatre is spreading the launch across three moments.

**T-minus — rehearsal.** Perform the procedure once, in full, on a day that is not the day. Classes
3, 4 and 8 *are* the rehearsal: restore, migrate-on-a-copy, roll back. A launch step first attempted
live is a step you have never tested.

**T-zero — exposure, not a switch.** Do not hand it to everyone at once. One person, one project,
one day, with the previous process still running beside it. And write the **abort criteria before
you start** — the specific event or number that makes you roll back, decided while you are calm and
not while something is on fire. "We'll see how it goes" is not a criterion.

**T-plus — the watch window.** Name who is watching, for how long, and what they look at. The window
is not over on day two: the first month-end, the first invoice, the first fiscal close are each a
second launch, because class 10's period boundary does not arrive until then.

**Release #2 is not release #1.** Running all ten classes on every future release guarantees they
stop being run. Afterwards the gate is triggered by what the change touches: a migration → class 4 ·
a new or renamed variable → 1 · a new irreversible operation → 8 · a privilege change → 5 · a new
writer on shared data → 9. Everything else is the ordinary review gate, not this one.

## Blocker vs. accepted risk

Two outcomes only, and both are explicit:

- **Blocker** — go-live does not happen until it is closed. Data loss, cross-tenant exposure, money
  computed wrong, no proven restore, no way back.
- **Accepted risk** — written down in the release record with *what could happen*, *how you would
  notice*, and *who accepted it*. An accepted risk that isn't written down is just a hole.

Anything else — "probably fine", "we'll watch it" — is a hole. Report it as one.

## The release record

Output a single file the future you will actually read. Per item: `PASS` + the command and its
output, `FAIL` + what it costs, or `HOLE` + why it wasn't proved and what it would take.

```markdown
# Release record — <app> — <version/sha> — <date>

## Verdict: GO / NO-GO
Blockers open: N   ·   Declared holes: N   ·   Accepted risks: N

## Mechanical (release-gate.sh)
<paste the script output verbatim>

## 1. Config & secret parity — PASS
Evidence: <command + output, or the two lists compared>
...
## 8. Way back — HOLE
Not proved: rollback never rehearsed against migrated data.
To close: dump prod → migrate → roll back → boot. ~40 min.

## Accepted risks
- <risk> · impact <…> · detected by <…> · accepted by <name>, <date>
```

## Anti-patterns

- **Re-reviewing the code.** If you find yourself reading a component, you left the gate. The ten
  classes are about environment, data, identity, timing, and operations.
- **Proving from the catalog.** "The trigger exists" / "the policy is there" / "the variable is in
  `.env.example`" is not proof. Run the operation and observe the refusal or the success.
- **Testing as owner.** Guarantees a false pass on every permission item.
- **Empty-database drills.** Migration and first-run checks on an empty DB prove the happy path you
  already knew worked.
- **Rounding a hole up to green** because everything else passed. The gate's whole value is that an
  unproved item stays visible.
- **Running it once, at the end.** Classes 3, 4 and 8 take real time. Start them before the day you
  want to launch.

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Pochádza dôkaz pri KAŽDOM „PASS" z miesta, kde sa tá chyba vôbec MÔŽE stať — produkčný stack, kópia prod dát, druhá súbežná relácia, rola `authenticated`? (Lokálna seedovaná DB, jeden človek, vlastník alebo zabitý beh skriptu = DIERA, aj keď si operáciu naozaj spustil.)
