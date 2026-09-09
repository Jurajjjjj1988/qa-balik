# Probes — the runbooks for the judgment half

Every probe here has the same shape: **perform the operation, observe the result.** None of them is
satisfied by reading a config file, a migration, or a catalog table. Postgres/Supabase examples
because that is the common stack; the shape transfers.

---

## §1 First run on empty production (class 2)

The paths that execute exactly once. Your development database passed through them months ago and
will never do it again, so nothing local exercises them.

Run against the production stack, with a brand-new account:

1. Sign up / create the first user of a fresh tenant.
2. Create the first top-level entity (project · company · customer · shop).
3. Create the first child entity that references it.
4. Produce the first real output — invoice, export, payroll run, receipt.
5. Log out on that device, log in as a *second* user of the same tenant, confirm what they see.

**What this catches that nothing else does:** bootstrap that requires the row it is meant to create.
The classic instance: creating a project requires a membership row, the membership row is created by
the same transaction, and the policy guarding the insert reads the membership table — locally you
already had a membership, so it always worked.

Record: the actual sequence you performed and the ID of the first entity created. If step 4 was not
performed on production, class 2 is a HOLE, not a pass.

---

## §2 Restore, proven (class 3)

```bash
# 1. Take the most recent backup as it actually exists — not one you make specially for this test.
ls -la <backup location>          # note the age; a backup older than a day is its own finding

# 2. Restore into a scratch database. Never into anything real.
#    --exit-on-error / ON_ERROR_STOP=1 are NOT optional. Both tools default to "log the error and
#    carry on", then exit 0 — a dump that half-loaded reads as a successful drill, which is the exact
#    failure this section exists to prevent. Check the exit code before you believe anything.
createdb restore_drill
pg_restore --exit-on-error -d restore_drill --no-owner --no-privileges <backup>
echo "pg_restore exit: $?"          # must be 0; anything else means the drill FAILED, not "mostly worked"
# plain-SQL dump instead:
psql -v ON_ERROR_STOP=1 -d restore_drill -f dump.sql
echo "psql exit: $?"                # must be 0

# 3. Prove the DATA came back, not just the schema.
psql -d restore_drill -c "select relname, n_live_tup from pg_stat_user_tables order by n_live_tup desc limit 15;"

# 4. Boot the app against it and open one real record by hand.
# 5. Write down wall-clock time from step 1 to step 4.
```

**Findings this produces in practice:** the backup is schema-only; it restores but the app cannot
read it because roles/grants were not in the dump; the encryption key exists only on the machine
whose loss the backup was supposed to survive; the restore takes four hours and nobody knew.

`--no-owner --no-privileges` is right for the drill (the scratch DB has different roles) but note
that it means **the drill did not prove your grants survive** — that is a separate line in the
record, not something to gloss over.

---

## §3 Privileges under the REAL role (class 5)

As the owner you bypass RLS and prove nothing. Every probe below runs inside a transaction that is
rolled back, under the role your users actually have.

### 3a Exercise the write paths

```sql
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"<real-user-uuid>","role":"authenticated"}';  -- Supabase

-- one statement per write path the app performs. Observe refusal or success; do not infer it.
insert into projects (name) values ('probe');
insert into penetrations (project_id, ...) values (...);
update penetrations set ... where id = '<id>';
delete from inspections where id = '<id>';        -- must be REFUSED if the log is append-only

rollback;
```

Before trusting the claim-setting line above, check how this project's `auth.uid()` is actually
defined — implementations read `request.jwt.claim.sub` or `request.jwt.claims->>'sub'` depending on
version, and setting the wrong one gives you a silent NULL and a meaningless probe:

```sql
select prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'auth' and p.proname = 'uid';
```

### 3b Cross-tenant read — the one that matters

```sql
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"<user-of-tenant-A>","role":"authenticated"}';
select count(*) from <table> where tenant_id = '<tenant-B>';   -- MUST be 0, not an error, not a number
rollback;
```

A non-zero count here is a go-live blocker with no discussion.

### 3c Where drift comes from (read these, then go back to 3a)

```sql
-- RLS switched on but with no policy = table is closed to everyone; RLS off = open to everyone.
select c.relname, c.relrowsecurity, count(p.polname) as policies
from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  left join pg_policy p on p.polrelid = c.oid
where n.nspname = 'public' and c.relkind = 'r'
group by 1,2 order by 3, 1;

-- Grants that the migration did not write — platform default privileges land on top of yours.
select defaclrole::regrole, defaclnamespace::regnamespace, defaclobjtype, defaclacl
from pg_default_acl;

-- What anon/authenticated can actually do, regardless of what the migration intended.
-- NOT information_schema.role_table_grants: by SQL-standard definition that view shows only grants
-- where the grantor OR the grantee is a role the CURRENT session can enable. A grant made by the
-- platform (or by another superuser) to `anon` is therefore filtered out of your result — and an
-- empty result set is indistinguishable from "clean". Read the ACL off the catalog instead.
select c.relname,
       a.grantee::regrole::text as grantee,
       string_agg(a.privilege_type, ',' order by a.privilege_type) as privileges
from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
where n.nspname = 'public' and c.relkind in ('r','p','v','m')
  and a.grantee::regrole::text in ('anon','authenticated','public')
group by 1,2 order by 1,2;

-- Second opinion, asked of the server rather than parsed out of an ACL: this also folds in
-- membership (a privilege inherited through a role you did not grant directly still shows up here).
select c.relname, r.rolname, p.priv
from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE')) as p(priv)
  cross join (select rolname from pg_roles where rolname in ('anon','authenticated')) r
where n.nspname = 'public' and c.relkind in ('r','p')
  and has_table_privilege(r.rolname, c.oid, p.priv)
order by 1,2,3;

-- SECURITY DEFINER runs as its owner and steps around the caller's restrictions.
select n.nspname, p.proname, p.prosecdef
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname not in ('pg_catalog','information_schema') and p.prosecdef;
```

**Two traps worth stating outright.** `TRUNCATE` is not subject to RLS and does not fire row-level
triggers — an append-only guarantee built from either is bypassed by it. And a policy *expression*
runs with the **caller's** privileges: revoking a grant the policy quietly depended on breaks writes,
not reads, and the breakage shows up deep inside an unrelated feature. After any `revoke`, re-run
§3a in full. See `invariant-bypass-audit` for enumerating routes systematically.

---

## §4 Migration against a COPY of production data (class 4)

```bash
pg_dump <prod> > /tmp/prod-copy.sql
createdb migrate_drill
psql -v ON_ERROR_STOP=1 -d migrate_drill -f /tmp/prod-copy.sql   # without this, psql exits 0 after a
echo "load exit: $?"                                             # failed load and you migrate a HALF-
                                                                 # restored copy, i.e. you prove nothing

psql -d migrate_drill -c "select relname, n_live_tup from pg_stat_user_tables order by 1;" > /tmp/before.txt
<apply migrations against migrate_drill>
psql -d migrate_drill -c "select relname, n_live_tup from pg_stat_user_tables order by 1;" > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt          # every row-count change must be one you can explain

# boot the app against migrate_drill, open one real record
# then roll back, and boot again
```

An empty-schema migration always succeeds. `NOT NULL` on a column with existing nulls, a new FK
against orphans, a unique index over existing duplicates, an enum value that real rows already
violate — all of these are invisible until real rows are present.

**Rollback counts as proved only if the app boots afterwards.** A down-migration that runs cleanly
and leaves the app unable to start is not a rollback.

---

## §5 Operational blindness (class 7)

- Trigger one real error in production-like conditions. Where did it land? If the answer is "the
  user's browser console", you are blind.
- Name the place you will look on the morning after go-live, and confirm it contains today's data.
- Retention: how far back can you reconstruct an incident?
- **The watcher itself.** If the platform sleeps, throttles or expires on inactivity (free tiers do),
  then the keepalive job is production infrastructure. Confirm it ran within its own period — check
  the last successful run, not the schedule file. A cron that has been failing silently for three
  weeks looks exactly like a cron that works.
- Quotas that bite later, not at launch: storage, egress, row counts, monthly active users. Write
  down the current number and the ceiling.

---

## §6 The way back, and the irreversible inventory (class 8)

**The way back.** Name the previous good version, name the command that returns to it, and state how
long it takes. If a migration already rewrote data, code rollback alone is not a way back — say so.

**The irreversible inventory.** One table, filled in per app. An operation that cannot be undone and
has no idempotency key is a blocker, because a network timeout will eventually cause a retry.

| Operation | Undoable? | Idempotency key | What a duplicate costs |
| --- | --- | --- | --- |
| fiscal receipt / eKasa | no | | a second receipt in a legal record |
| card charge | compensating refund only | | |
| outbound e-mail | no | | |
| issued invoice number | no (only a credit note) | | |
| hard delete | no | n/a | |
| bulk export sent to a customer | no | n/a | |

Two rules the inventory exists to enforce, both learned the hard way:

- **Look up before you create.** Before performing the irreversible call, look up whether this
  operation ID already succeeded. Retry-after-timeout is the normal case, not the edge case.
- **The critical write goes before the risky one.** Record the work first, then attempt the external
  effect — so a failure in the risky half cannot discard the half you already earned.

---

## §7 Config & secret parity, the manual half (class 1)

`release-gate.sh` prints every variable the code reads. That list is one half; the deployment's
actual variable list is the other. Put them side by side and account for each line in both
directions:

- **In code, absent from deployment** → white screen or a silent default on first load.
- **In deployment, absent from code** → dead config, usually a rename that half-landed.
- **Present in both** → is the *value* the production one? A staging URL that resolves is the worst
  case: nothing errors, and the data goes somewhere else.

For every client-visible variable (`VITE_*`, `NEXT_PUBLIC_*`), write one line saying why it is safe
to be public. "It's just the anon key" is acceptable **only** once §3b has been performed — the anon
key is safe exactly to the extent that RLS holds, and §3b is what proves that.

**The blind spot to close by hand.** `release-gate.sh` finds variables written as `process.env.X` /
`import.meta.env.X`. A variable consumed by a *library* — an SDK client reading its own API key, a
driver reading `PGHOST` — never appears that way and the script cannot see it. The script reports
template entries that no code references for exactly this reason: each one is either dead config or
an invisible dependency. Resolve every such line; do not skim past them.

---

## §8 The second person, and the second device (class 9)

You develop alone. Every concurrency defect is therefore invisible until the day two people work at
once — which is, by definition, go-live day.

1. **Simultaneous edit.** Two sessions open the same record. A edits and saves; B — who loaded before
   A saved — edits a *different field* and saves. Re-open. Are both changes present?
   A "last write wins" that overwrites the whole record silently deletes A's work, and the wider the
   record, the more it deletes. If the write is rejected, is the rejection *shown*?
2. **Append-only under two writers.** If a record contains a growing list (measurements, log entries,
   inspections), have both sessions append. Both entries must survive. A writer that saves the whole
   parent record will drop the other's entries without any error.
3. **Shared device, identity change.** Log out, log in as someone else, then query **storage** —
   "how many rows of the previous person remain" — not the screen. Online, a sync engine repairs the
   view and hides the leak; the honest question is what is on disk.
4. **Offline reconvergence** (only if the app works offline). Both devices offline, both write,
   reconnect. Nothing may vanish, and anything rejected must be visible to the person who wrote it.
5. **Unsent work at logout.** If sign-out clears local storage, prove it refuses while the outbound
   queue is non-empty — otherwise it deletes the only copy of work that never reached the server.

---

## §9 Legal, retention, and the clock (class 10)

Two lists and one arithmetic check. None is discoverable from code.

**Data.** Per category of personal or regulated data: where it is stored · who may read it · how long
it is kept · how it is erased on request · every third party that processes it (hosting, mail, LLM
API, error reporting — an error reporter that ships request bodies is a processor of whatever was in
them). A backup is storage too: a retention promise that the backups quietly break is not kept.

**Duties.** What the operator must have in place independent of the software: lawful basis, mandatory
notices, certification of a regulated output, statutory confidentiality of a channel, mandatory
retention that *forbids* deletion. Correctness of a regulated artifact is established by the
authority that certifies it, never by a passing test — record it as an accepted risk with a name
against it, or as a blocker.

**The clock.** One boundary case per legal period, computed and compared against the calendar a human
would use:

- work recorded at 23:30 local on the last day of the month — which month does payroll bill it to?
- a receipt at 00:15 — which fiscal day?
- the DST-shifted day: a duration crossing the change must not gain or lose an hour.
- a date typed by a user in local time, stored UTC, then *grouped by date* — grouping in the wrong
  zone moves entries across the boundary silently, forever, and only ever by a little.

If timestamps are stored UTC and any report groups by day, week or month, that report must convert
before grouping. Prove it with the 23:30 case; do not read the code and conclude it looks right.
