#!/usr/bin/env bash
# gate-audit.sh — audits the QUALITY GATES themselves, not the code.
#
# A gate you have never seen fail is indistinguishable from a gate that does nothing. Everything
# here asks one question: does the protection actually protect, right now, in this repository?
#
#   A1  the gate exists, is executable, and is wired to a hook
#   A2  the gate is green today (otherwise every check below is meaningless)
#   A3  LIVENESS — inject a deliberate defect and prove the gate goes RED (opt-in, --liveness)
#   A4  critical-scope drift — money/auth files the gate's own thresholds do not cover
#   A5  local-vs-CI parity — a command in the local gate that CI never runs
#   A6  secrets in git HISTORY — a working-tree scan cannot see what was committed and removed
#
# WHAT THIS WRITES INTO YOUR REPOSITORY — the complete list, per flag:
#   (no flag), --no-run   nothing at all
#   --liveness            exactly one file: <dir holding the most unit tests>/
#                         __gate_liveness_probe__.<test|spec>.<ext> — created, the gate is run
#                         against it, then deleted
# A2/A3 also EXECUTE your own .claude/test-gate.sh: whatever that writes (coverage, mutation
# reports) is its doing, not this script's — but if it lands somewhere committable the fence below
# reports it as a breach, because from your commits' point of view the run still left it there.
# Everything else here goes to a mktemp directory outside the repository.
#
# That list is not a promise but a measurement: the shared write-fence fingerprints
# `git status --porcelain` around the run and fails the audit if anything commit-visible changed
# that was not declared first. --liveness additionally refuses to start on a dirty tree, so
# `git checkout`/`git clean` can always undo a cleanup that did not happen.
#
# usage: gate-audit.sh [--liveness] [--no-run]
# Exit: 0 all proved · 1 blocker OR write-fence breach · 2 undecided holes remain (NOT a pass)
#       3 refused (--liveness on a dirty tree, or outside a repo) · 64 bad argument.
set -uo pipefail

# The fence is what makes the paragraph above checkable. Without the library the audit still runs —
# a missing helper is no reason to refuse to look at the gate — but it then measures nothing, and
# says so where the user reads it rather than here at load time.
SAFETY_LIB="$HOME/.claude/skills/_lib/safety.sh"
if [ -r "$SAFETY_LIB" ]; then
  . "$SAFETY_LIB"; FENCED=1
else
  FENCED=0
  fence_begin() { :; }; fence_declare() { :; }; fence_end() { return 0; }
  # NOT a no-op — see the note in release-gate.sh. --liveness writes a probe into the repository and
  # the clean-tree guard is the only reason a failed cleanup is recoverable.
  require_clean_tree() {
    printf '  ✗ refusing: %s is missing, so the clean-tree guard cannot run.\n' "$SAFETY_LIB" >&2
    printf '    Use --no-run, which writes nothing.\n' >&2
    return 1
  }
fi

LIVENESS=0
RUNGATE=1
for a in "$@"; do
  case "$a" in
    --liveness) LIVENESS=1 ;;
    --no-run) RUNGATE=0 ;;
    -h|--help) sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 64 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 64
GATE="$ROOT/.claude/test-gate.sh"
TMPD="$(mktemp -d)"
PROBE=""
cleanup() { [ -n "$PROBE" ] && rm -f "$PROBE"; rm -rf "$TMPD"; }
# A signal must ABORT, not clean up and carry on: continuing after Ctrl-C during A2 reported a
# blocker about a gate the user had merely interrupted. HUP is trapped too — without it, closing the
# terminal left the A3 probe file sitting in the repository.
trap cleanup EXIT
trap 'cleanup; printf "\n  aborted (SIGINT) — nothing below this line was checked\n" >&2; exit 130' INT
trap 'cleanup; printf "\n  aborted (SIGTERM) — nothing below this line was checked\n" >&2; exit 143' TERM
trap 'cleanup; exit 129' HUP

blockers=0; holes=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; blockers=$((blockers+1)); }
hole() { printf '  HOLE  %s\n' "$1"; holes=$((holes+1)); }
info() { printf '  ....  %s\n' "$1"; }
head2(){ printf '\n== %s\n' "$1"; }

printf '# gate-audit — %s — %s\n' "$(basename "$ROOT")" "$(date '+%Y-%m-%d %H:%M')"

if [ "$FENCED" -eq 0 ]; then
  hole "$SAFETY_LIB is missing — this run is UNVERIFIED: nothing measures what it touched, and
        --liveness is not held back from a dirty tree. The audit below is unaffected; the guarantee is."
fi
fence_begin
# A probe file is a write, so it gets the write-mode treatment: on a dirty tree a failed cleanup is
# indistinguishable from the user's own work.
if [ "$LIVENESS" -eq 1 ] && ! require_clean_tree "--liveness writes a probe test file into the repository"; then
  exit 3
fi

# ---------------------------------------------------------------- A1 present and wired
head2 "A1  the gate exists and is wired"
if [ ! -f "$GATE" ]; then
  # Not .claude/test-gate.sh — but this repo may gate through another mechanism. Accusing a project of
  # having NO gate when it gates via husky/lefthook/Makefile/CI is a false blocker (measured 2026-08-04
  # on a husky repo: exit 1) and trains the reader to ignore the audit — the "taking over a project"
  # use-case is exactly when foreign conventions appear. gate-audit can only RUN/probe .claude/test-gate.sh,
  # so any other gate is UNAUDITED here: report it as a HOLE, keep the hard FAIL only when nothing gates.
  other=""
  { [ -d "$ROOT/.husky" ] && ls "$ROOT/.husky" 2>/dev/null | grep -qvE '^_'; } && other="$other .husky"
  { [ -f "$ROOT/lefthook.yml" ] || [ -f "$ROOT/lefthook.yaml" ] || [ -f "$ROOT/.lefthook.yml" ]; } && other="$other lefthook"
  [ -f "$ROOT/.pre-commit-config.yaml" ] && other="$other pre-commit"
  [ -d "$ROOT/.githooks" ] && other="$other .githooks"
  hp="$(git config core.hooksPath 2>/dev/null || true)"; [ -n "$hp" ] && other="$other core.hooksPath=$hp"
  { [ -f "$ROOT/Makefile" ] && grep -qiE '^(test|check|ci)[[:space:]]*:' "$ROOT/Makefile" 2>/dev/null; } && other="$other Makefile"
  ls "$ROOT/.github/workflows/"*.y*ml >/dev/null 2>&1 && other="$other .github/workflows"
  [ -f "$ROOT/.gitlab-ci.yml" ] && other="$other .gitlab-ci.yml"
  { [ -f "$ROOT/.circleci/config.yml" ] || [ -f "$ROOT/.circleci/config.yaml" ]; } && other="$other .circleci"
  { [ -f "$ROOT/azure-pipelines.yml" ] || [ -f "$ROOT/azure-pipelines.yaml" ]; } && other="$other azure-pipelines"
  [ -f "$ROOT/bitbucket-pipelines.yml" ] && other="$other bitbucket-pipelines"
  ls "$ROOT/.git/hooks/"* 2>/dev/null | grep -qvE '\.sample$' && other="$other git-hooks"
  other="${other# }"
  if [ -n "$other" ]; then
    hole "no .claude/test-gate.sh, but this project gates elsewhere: $other. gate-audit can only run and
        probe .claude/test-gate.sh, so that gate is UNAUDITED here — inspect it directly, or point a
        .claude/test-gate.sh at the same command so A2/A3 liveness can measure it."
  else
    fail "no .claude/test-gate.sh, and no gate this audit recognizes (husky / lefthook / pre-commit /
        .githooks / git-hooks / Makefile / GitHub / GitLab / CircleCI / Azure / Bitbucket CI) — as far as
        this audit can tell, nothing gates this project. If it gates some other way, say so."
  fi
elif [ ! -x "$GATE" ]; then
  fail ".claude/test-gate.sh exists but is not executable — the hook silently skips it"
else
  pass ".claude/test-gate.sh present and executable"
fi
# "the substring test-gate appears somewhere in a settings file" is not wiring: it matches a
# permission rule, a disabled block, or a comment. Parse the JSON and require an actual
# hooks[<event>][].hooks[].command — and check that the script that command names still exists.
# $ROOT/.claude/settings.local.json was missing from this list although Claude Code loads it.
: > "$TMPD/wired"
for s in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" \
         "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
  [ -f "$s" ] || continue
  node -e '
    const fs = require("fs"), file = process.argv[1];
    let raw = "", j = null;
    try { raw = fs.readFileSync(file, "utf8"); j = JSON.parse(raw); }
    catch (e) { console.log("UNPARSED\t" + file); process.exit(0); }
    const out = [];
    const hooks = (j && j.hooks) || {};
    for (const ev of Object.keys(hooks))
      for (const grp of [].concat(hooks[ev] || []))
        for (const h of [].concat((grp && grp.hooks) || []))
          if (/test-gate/.test(String((h && h.command) || "")))
            out.push("HOOK\t" + file + "\t" + ev + "\t" + String(h.command));
    if (out.length) out.forEach(o => console.log(o));
    else if (/test-gate/.test(raw)) console.log("MENTION\t" + file);
  ' "$s" >> "$TMPD/wired" 2>/dev/null
done
grep '^HOOK' "$TMPD/wired" > "$TMPD/wired.hooks" 2>/dev/null
if [ -s "$TMPD/wired.hooks" ]; then
  while IFS="$(printf '\t')" read -r _ sfile ev cmd; do
    scr="$(printf '%s\n' "$cmd" | grep -oE '[^ "'"'"']*test-gate[^ "'"'"']*' | head -1)"
    case "$scr" in
      /*) sp="$scr" ;;
      ~/*) sp="$HOME/${scr#~/}" ;;
      *)  sp="$ROOT/$scr" ;;
    esac
    if [ -n "$scr" ] && [ ! -f "$sp" ]; then
      fail "$ev hook in $(basename "$sfile") runs '$scr' — that file does not exist, so the hook is a no-op"
    elif [ ! -f "$GATE" ] && [ "${sp#$HOME/.claude/hooks/}" != "$sp" ]; then
      # A global ~/.claude runner (our Stop hook) is wired for EVERY repo, but it `[ -x $gate ] || exit 0`s
      # when the project has no .claude/test-gate.sh. Reporting it as a protective PASS next to the A1
      # "no gate" FAIL is the contradiction the reviewer flagged — say plainly it gates nothing here yet.
      hole "$ev hook in ${sfile#$HOME/} runs $scr — but that GLOBAL runner no-ops (exit 0) until THIS project adds its own .claude/test-gate.sh, so it gates nothing here yet"
    else
      pass "$ev hook in ${sfile#$HOME/} runs $scr"
    fi
  done < "$TMPD/wired.hooks"
elif grep -q '^MENTION' "$TMPD/wired"; then
  hole "'test-gate' appears in $(grep '^MENTION' "$TMPD/wired" | cut -f2 | tr '\n' ' ')but in no hooks[].command — it is NOT wired"
else
  # `grep -c ... || echo 0` vyrobi dvojriadkove "0\\n0" (grep -c vypise 0 A vrati 1) a [ ] potom
  # hlasi chybu. Ta ista pasca, ktoru tento autor uz raz opravoval v seam-map.sh.
  unparsed="$(grep -c '^UNPARSED' "$TMPD/wired" 2>/dev/null)"; : "${unparsed:=0}"
  if [ "${unparsed:-0}" -gt 0 ]; then
    hole "no hook references test-gate; $unparsed settings file(s) could not be parsed as JSON, so this is 'did not look', not 'clean'"
  else
    hole "no hook references test-gate — the gate runs only when someone remembers to type it"
  fi
fi

# ---------------------------------------------------------------- A2 green today
head2 "A2  the gate is green today"
GREEN=0
if [ ! -x "$GATE" ]; then
  hole "skipped — no runnable gate"
elif [ "$RUNGATE" -eq 0 ]; then
  hole "skipped (--no-run) — a gate whose current state you did not check proves nothing"
elif "$GATE" >"$TMPD/gate.log" 2>&1; then
  GREEN=1; pass "gate exits 0"
else
  fail "gate is RED right now — fix that before trusting anything below"
  tail -n 15 "$TMPD/gate.log" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- A3 liveness
head2 "A3  liveness — can the gate actually fail?"
if [ "$LIVENESS" -eq 0 ]; then
  hole "not run — pass --liveness to prove the gate can go RED (writes one temporary test file)"
elif [ "$GREEN" -ne 1 ]; then
  hole "cannot probe: the gate is not green to begin with, so RED proves nothing"
else
  # Put the probe BESIDE an existing test, never in a guessed directory. Runners restrict collection
  # with include globs (ekoplant-web: 'lib/**/*.test.ts'), so a probe dropped at the repo root is
  # never run — and the audit then reports a perfectly good gate as broken.
  #
  # But "beside a test" is not enough either, and the previous claim that a sibling is "collected by
  # construction" was false: the alphabetically-first test file is often an e2e/Playwright spec, and
  # the FAST gate does not run that suite at all. Two filters, in order:
  #   · drop suites a fast gate normally delegates elsewhere (e2e, playwright, cypress, integration);
  #   · of what remains, take the directory holding the MOST tests — the one the runner demonstrably
  #     collects in bulk, rather than whatever sorts first.
  # Collection is still not assumed: it is verified afterwards from the gate's own output.
  git ls-files 2>/dev/null | grep -E '\.(test|spec)\.(ts|tsx|js|jsx)$' > "$TMPD/tests" || true
  grep -viE '(^|/)(e2e|e2e-tests|integration|playwright|cypress|browser|smoke)(/|$)' "$TMPD/tests" > "$TMPD/tests.unit" || true
  [ -s "$TMPD/tests.unit" ] || cp "$TMPD/tests" "$TMPD/tests.unit"
  probedir="$(sed -e 's#[^/]*$##' -e 's#/$##' -e 's#^$#.#' "$TMPD/tests.unit" | sort | uniq -c | sort -rn | head -1 | sed 's/^ *[0-9]* //')"
  sibling="$(awk -v d="$probedir" '{ p=$0; sub(/[^\/]*$/,"",p); sub(/\/$/,"",p); if (p=="") p="."; if (p==d) { print; exit } }' "$TMPD/tests.unit")"
  if [ -z "$sibling" ]; then
    hole "no existing test file to sit beside — cannot place a probe the runner is likely to collect"
  else
    # Detect the runner so the probe speaks its dialect (2026-08-04): a vitest-syntax probe (it/expect)
    # under `node --test` fails to parse — it/expect are undefined — so the control run looks "ALREADY
    # RED" for a reason unrelated to the gate, a FALSE result on every non-vitest runner. Prefer the gate
    # script's own text (what A2/A3 actually run), then package.json test-script + dependency names.
    ga_hay="$(cat "$GATE" 2>/dev/null; [ -f "$ROOT/package.json" ] && node -e 'try{const p=require(process.argv[1]);const d={...(p.dependencies||{}),...(p.devDependencies||{})};process.stdout.write(" "+((p.scripts&&p.scripts.test)||"")+" "+Object.keys(d).join(" "))}catch(e){}' "$ROOT/package.json")"
    case "$ga_hay" in
      *"node --test"*|*"node:test"*) RUNNER=node ;;
      *vitest*) RUNNER=vitest ;;
      *jest*)   RUNNER=jest ;;
      *mocha*)  RUNNER=mocha ;;
      *" ava"*) RUNNER=ava ;;
      *)        RUNNER=unknown ;;
    esac
    if [ "$RUNNER" = unknown ]; then
      hole "liveness: could not tell which test runner the gate uses (looked in .claude/test-gate.sh and
        package.json for node --test / vitest / jest / mocha / ava). Skipping — a probe in the wrong dialect
        would fail to parse and the control run would then look RED for a reason unrelated to the gate."
    else
    ext="${sibling##*.}"; kind="test"
    case "$sibling" in *.spec.*) kind="spec" ;; esac
    PROBE="$(dirname "$sibling")/__gate_liveness_probe__.$kind.$ext"
    # Declared BEFORE it exists, so the fence can tell this file apart from anything unintended.
    # A scratch worktree would be stronger isolation, but it cannot host this probe: a worktree
    # checks out TRACKED files only, and node_modules is gitignored in every project here — the gate
    # would die on a missing runner and the audit would report a working gate as broken. Measured,
    # not assumed: see the worktree check in this skill's verification notes.
    fence_declare "$PROBE"
    # ONE run cannot prove liveness, and requiring the probe's NAME in the output does not rescue it.
    # Measured 2026-08-01 by an adversarial reviewer: a gate consisting of `npm test || true` followed
    # by a leftover-probe scan — the very scan this project's own CLAUDE.md prescribes — goes red AND
    # prints the probe's name, for a reason that has nothing to do with a test failing. The old code
    # certified that dead gate as "the gate protects".
    #
    # So: a CONTROL run first, with the probe PASSING. Every stray-file effect (formatter, leftover
    # scan, coverage dip) is present in both runs and cancels out; only the assertion differs. The
    # proof is the DELTA green→red, never a single red.
    # ESM vs CJS: mirror the sibling the runner already collects, so `import` vs `require` matches it.
    if grep -qE '^[[:space:]]*(import|export)[[:space:]]' "$sibling" 2>/dev/null; then psm=esm
    elif grep -qE 'require\(' "$sibling" 2>/dev/null; then psm=cjs
    elif grep -q '"type"[[:space:]]*:[[:space:]]*"module"' "$ROOT/package.json" 2>/dev/null; then psm=esm
    else psm=cjs; fi
    hdr='// TEMPORARY probe written by gate-audit. If you find this in a commit, the audit crashed — delete it.'
    write_probe() { # $1 = the value 1 is asserted to equal: 1 passes, 2 fails
      { printf '%s\n' "$hdr"
        case "$RUNNER" in
          node)
            if [ "$psm" = cjs ]; then printf '%s\n' "const { test } = require('node:test'); const assert = require('node:assert');"
            else printf '%s\n' "import { test } from 'node:test';" "import assert from 'node:assert';"; fi
            printf '%s\n' "test('__gate_liveness_probe__ liveness', () => { assert.strictEqual(1, $1); });" ;;
          mocha)
            if [ "$psm" = cjs ]; then printf '%s\n' "const assert = require('node:assert');"
            else printf '%s\n' "import assert from 'node:assert';"; fi
            printf '%s\n' "it('__gate_liveness_probe__ liveness', () => { assert.strictEqual(1, $1); });" ;;
          ava)
            printf '%s\n' "import test from 'ava';" "test('__gate_liveness_probe__ liveness', t => { t.is(1, $1); });" ;;
          jest)  # jest exposes it/expect as globals — no import
            printf '%s\n' "it('__gate_liveness_probe__ liveness', () => { expect(1).toBe($1); });" ;;
          *)     # vitest (and safe default): importing is harmless even under globals:true
            printf '%s\n' "import { it, expect } from 'vitest';" "it('__gate_liveness_probe__ liveness', () => { expect(1).toBe($1); });" ;;
        esac
      } > "$PROBE"
    }
    info "probe placed at $PROBE (beside $sibling)"
    info "liveness runs your gate twice more (control, then defect) on top of A2, and a third time to
        confirm determinism if the first two look like a pass — three or four runs in total"
    write_probe 1
    "$GATE" >"$TMPD/probe-control.log" 2>&1; crc=$?
    cseen=0; grep -q '__gate_liveness_probe__' "$TMPD/probe-control.log" && cseen=1
    write_probe 2
    "$GATE" >"$TMPD/probe.log" 2>&1; prc=$?
    seen=0; grep -q '__gate_liveness_probe__' "$TMPD/probe.log" && seen=1

    if [ "$crc" -ne 0 ]; then
      hole "control run is ALREADY RED with a PASSING probe present. Whatever the failing probe does
        next proves nothing, because the redness comes from the file EXISTING — a formatter, a
        leftover-probe scan, a coverage dip. Liveness is not measurable this way:"
      tail -n 8 "$TMPD/probe-control.log" | sed 's/^/        /'
    elif [ "$cseen" -eq 0 ] && [ "$seen" -eq 0 ]; then
      # Neither run mentions the probe: it was never collected. That proves nothing about the gate —
      # reporting it as a failure would be a false accusation.
      hole "probe was never collected by the runner (check its include globs) — liveness NOT proved"
    elif [ "$prc" -ne 0 ] && [ "$seen" -eq 1 ]; then
      # A green-then-red delta is still not enough on its own. A gate whose colour depends on the RUN
      # COUNT rather than on the assertion — a cache that fills, a lock that accumulates, a step that
      # trips on the third invocation — produces exactly this delta while being stone dead. Measured
      # 2026-08-01: a reviewer built one and it was certified; a deliberately random gate was
      # certified in 2 of 12 runs.
      #
      # So the passing probe is run ONE more time and must come back GREEN again. The extra run is
      # paid only here, on the path that would otherwise hand out a false certificate; every FAIL and
      # every HOLE above returns without it.
      write_probe 1
      "$GATE" >"$TMPD/probe-confirm.log" 2>&1; krc=$?
      if [ "$krc" -ne 0 ]; then
        hole "control GREEN, defect RED — but running the PASSING probe again went RED as well. This
        gate's colour does not follow the assertion; it follows something that changes between runs
        (a cache, a lock, an accumulating counter, or plain flakiness). Liveness NOT proved:"
        tail -n 8 "$TMPD/probe-confirm.log" | sed 's/^/        /'
      else
        pass "GREEN with a passing probe, RED naming the probe when it failed, GREEN again when it
        passed once more — the delta follows the assertion and it repeats"
      fi
    elif [ "$prc" -ne 0 ]; then
      hole "gate went RED but its output never mentions __gate_liveness_probe__ — the RED may come from
        the stray file offending a linter or a leftover-file scan, not from the failing test. NOT proved:"
      tail -n 8 "$TMPD/probe.log" | sed 's/^/        /'
    else
      fail "gate stayed GREEN although it ran a failing test — it is not protecting anything"
    fi
    rm -f "$PROBE"; PROBE=""
    fi
  fi
  if git status --porcelain 2>/dev/null | grep -q '__gate_liveness_probe__'; then
    fail "probe file survived — remove it by hand before committing:"
    git status --porcelain 2>/dev/null | grep '__gate_liveness_probe__' | sed 's/^/        /'
  fi
fi

# ---------------------------------------------------------------- A4 critical-scope drift
head2 "A4  critical-scope drift — money/auth logic the gate does not cover"
if [ ! -f "$GATE" ]; then
  hole "no gate to compare against"
else
  # THRESHOLD SOURCES. A gate script almost never holds the thresholds itself — it says
  # `npm run test:cov` and the globs live in vitest.config.ts / stryker.config.json / a per-file
  # money-gate script reached through a package.json script. Reading only the shell script therefore
  # accused SprayFlow's best-protected modules (src/domain/pricing.ts, billing.ts, vat.ts — all inside
  # stryker `mutate: src/domain/*.ts` at break 90) of being ungated. Collect what the gate delegates to.
  : > "$TMPD/srcs"
  printf '%s\n' "$GATE" >> "$TMPD/srcs"
  git ls-files 2>/dev/null \
    | grep -E '^[^/]*(vite|vitest|jest|stryker|karma)[^/]*\.(ts|js|mjs|cjs|json)$|^\.nycrc' >> "$TMPD/srcs" || true
  [ -f "$ROOT/package.json" ] && printf 'package.json\n' >> "$TMPD/srcs"
  { cat "$GATE" 2>/dev/null
    node -e 'try{const s=require(process.cwd()+"/package.json").scripts||{};console.log(Object.values(s).join("\n"))}catch(e){}' 2>/dev/null
  } | grep -oE '[A-Za-z0-9_][A-Za-z0-9_./-]*\.(mjs|cjs|js|ts|tsx|json|sh)' | sort -u \
    | grep -E '^(scripts|tools|config|bin|\.config|\.claude)/|^[^/]+$' \
    | grep -vE '(^|/)tsconfig|\.(test|spec)\.' \
    | while read -r p; do [ -f "$ROOT/$p" ] && printf '%s\n' "$p"; done >> "$TMPD/srcs"
  sort -u "$TMPD/srcs" -o "$TMPD/srcs"
  info "threshold sources read: $(sed "s#^$ROOT/##" "$TMPD/srcs" | tr '\n' ' ')"
  # Files that look like money / auth / safety logic by path or by content.
  git ls-files -- '*.ts' '*.tsx' 2>/dev/null \
    | grep -vE '(\.test\.|\.spec\.|/tests?/|/e2e/)' > "$TMPD/src" || true
  # Two tiers on purpose. Generic money words match every product card, and `role` matches every
  # ARIA attribute in every TSX file — on ekoplant-web the one-tier version flagged 27 of 30 files,
  # including SiteFooter. A pointer list that large is one you learn to scroll past.
  : > "$TMPD/crit"; : > "$TMPD/crit2"
  if [ -s "$TMPD/src" ]; then
    xargs grep -lEi 'payroll|\bmzd|salary|wage|invoice|faktur|\bvat\b|\bdph\b|refund|storno|rateCard|cenn[ií]k|password|bcrypt|argon|\bjwt\b|signIn|signOut|createSession|authoriz|authenticat|permission' \
      < "$TMPD/src" 2>/dev/null | sort -u > "$TMPD/crit" || true
    xargs grep -lEi 'price|\bcena|\brate\b|amount|\btotal\b|currency|\btax\b|\btoken\b' \
      < "$TMPD/src" 2>/dev/null | sort -u | grep -vxF -f "$TMPD/crit" > "$TMPD/crit2" 2>/dev/null || true
  fi
  n2="$(wc -l < "$TMPD/crit2" 2>/dev/null | tr -d ' ')"
  [ "${n2:-0}" -gt 0 ] && info "$n2 further file(s) merely mention money words (display, most likely) — not flagged"
  ncrit="$(wc -l < "$TMPD/crit" | tr -d ' ')"
  if [ "$ncrit" -eq 0 ]; then
    info "no file looks like money/auth logic by this heuristic"
  else
    # Match by PATH PATTERN, not by "some >=4-char token of the basename appears in the gate text".
    # That old rule counted `src/lib/pool.ts` as gated because the word "pool" sat in a COMMENT, and
    # it had no way to see a glob at all. Now: comments are stripped from every threshold source,
    # include/exclude globs and path-shaped regex literals are extracted, and a file is judged
    # against them. Excludes are honoured — a file the gate deliberately puts OUT of scope
    # (`exclude: ['src/ui/**']`) is a hole to know about, not a pass.
    node -e '
      const fs = require("fs");
      const srcs  = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean);
      const files = fs.readFileSync(process.argv[2], "utf8").split("\n").filter(Boolean);
      const EXKEY = /^(exclude|excludes|excluded|ignore|ignored|ignorePatterns|coveragePathIgnorePatterns|testPathIgnorePatterns|omit|skip)$/i;
      // Comments must go — a glob quoted inside a comment is not a threshold — but a regex cannot do
      // it: /\/\*[\s\S]*?\*\// eats the `/**/` in the single most common glob there is. `src/**/*.ts`
      // came out as `src *.ts`, usable() then discarded it, and A4 reported correctly-gated money
      // modules as "named nowhere" — the exact false accusation this check exists to remove.
      // Measured 2026-08-01: firestop-app/vitest.config.ts lost ALL its patterns, SprayFlow 5 of 7.
      // So: one pass tracking state, and characters inside a string literal are never touched.
      // Length is preserved (comments become spaces, newlines survive) because the key/offset
      // arithmetic further down indexes into this exact string.
      const strip = (t, p) => {
        const hash = /\.(sh|bash|zsh)$/.test(p) || !/\.[a-z]+$/i.test(p);
        const out = t.split("");
        const blank = (a, b) => { for (let k = a; k < b; k++) if (out[k] !== "\n") out[k] = " "; };
        const eol = (i) => { const e = t.indexOf("\n", i); return e < 0 ? t.length : e; };
        let i = 0, prev = "";
        // A `/` starts a REGEX LITERAL only where a value is expected. Tracking that is the whole
        // reason this variable exists: without it, `const Q = /["\x27]/` opens a "string" at the
        // double quote that runs to the next one somewhere far below, swallowing every glob in
        // between. An unpaired quote inside a character class is ordinary in lint and config
        // helpers, so this is not a corner case.
        const valueExpected = () => prev === "" || "(,=:[!&|?{};+-*%~^<>".includes(prev);
        while (i < t.length) {
          const c = t[i];
          if (c === "\x22" || c === "\x27" || c === "`") {          // string literal: skip it whole
            const q = c; i++;
            while (i < t.length && t[i] !== q) { if (t[i] === "\\") i++; i++; }
            i++; prev = q; continue;
          }
          // Regex literal: skip to the terminating unescaped `/`, and remember that `/` inside a
          // [...] class does NOT terminate it — `/[a-z/]/` is one literal, not two.
          if (c === "/" && t[i+1] !== "/" && t[i+1] !== "*" && valueExpected()) {
            let j = i + 1, cls = false, closed = false;
            while (j < t.length) {
              const d = t[j];
              if (d === "\\") { j += 2; continue; }
              if (d === "\n") break;                                  // unterminated: it was division
              if (cls) { if (d === "]") cls = false; }
              else if (d === "[") cls = true;
              else if (d === "/") { j++; closed = true; break; }
              j++;
            }
            if (closed) { i = j; prev = "/"; continue; }
          }
          // `\/` is an escaped slash inside a regex literal, not the start of a block comment.
          if (c === "/" && t[i-1] !== "\\" && t[i+1] === "*") {
            const e = t.indexOf("*/", i + 2); const end = e < 0 ? t.length : e + 2;
            blank(i, end); i = end; continue;
          }
          if (c === "/" && t[i+1] === "/" && t[i-1] !== ":") {       // not the // in an http:// URL
            const e = eol(i); blank(i, e); i = e; continue;
          }
          if (hash && c === "#" && (i === 0 || /\s/.test(t[i-1]))) { // not ${#arr} in shell
            const e = eol(i); blank(i, e); i = e; continue;
          }
          if (!/\s/.test(c)) prev = c;
          i++;
        }
        return out.join("");
      };
      const globRe = (g) => {
        let out = "^";
        for (let i = 0; i < g.length; i++) {
          const c = g[i];
          if (c === "*") {
            // `**` is a globstar ONLY when it is a whole path segment. Written mid-segment —
            // `src/domain/**.ts` — every glob implementation treats it as an ordinary `*`, but this
            // function expanded it to `.*` and so matched ACROSS directory separators.
            // Measured 2026-08-01 against picomatch (the matcher vitest itself uses):
            //   src/domain/**.ts  ×  src/domain/sub/deep/pricing.ts   ours=true, vitest=false
            // A4 therefore printed PASS for a money file that no threshold covers — a false GREEN,
            // and the "measured is not protected" class arriving through the matcher itself. With the
            // segment rule the two agree on 12 of 12 patterns; before it, 11 of 12.
            const segStart = i === 0 || g[i-1] === "/";
            if (g[i+1] === "*" && segStart && (g[i+2] === "/" || i + 2 === g.length)) {
              if (g[i+2] === "/") { out += "(?:.*\\/)?"; i += 2; } else { out += ".*"; i += 1; }
            } else if (g[i+1] === "*") { out += "[^/]*"; i += 1; }
            else out += "[^/]*";
          } else if (c === "?") out += "[^/]";
          else if (c === "{") { const j = g.indexOf("}", i); if (j < 0) { out += "\\{"; } else { out += "(?:" + g.slice(i+1, j).split(",").map(s => s.replace(/[.+^${}()|[\]\\]/g, "\\$&")).join("|") + ")"; i = j; } }
          else out += c.replace(/[.+^${}()|[\]\\]/g, "\\$&");
        }
        return new RegExp(out + "$");
      };
      const usable = (p) => p && !/^[\/~]/.test(p) && !/^https?:/.test(p) && p.includes("/")
        && (p.includes("*") || /\.[a-z0-9]+$/i.test(p)) && !/[\\()|$^\s]/.test(p);
      const inc = [], exc = [], rex = [], names = new Set();
      let read = 0;
      for (const s of srcs) {
        let raw; try { raw = fs.readFileSync(s, "utf8"); } catch (e) { continue; }
        read++;
        const t = strip(raw, s);
        const keys = [...t.matchAll(/([A-Za-z_][A-Za-z0-9_]*)["\x27]?\s*:/g)].map(m => ({ i: m.index, k: m[1] }));
        const keyAt = (i) => { let k = ""; for (const e of keys) { if (e.i < i) k = e.k; else break; } return k; };
        const add = (txt, idx) => {
          let p = txt.trim(), neg = false;
          if (p.startsWith("!")) { neg = true; p = p.slice(1); }
          p = p.replace(/^\.\//, "");
          // Bare basename, e.g. "pricing.ts". The extension must be a SOURCE extension: the previous
          // `\.[a-z0-9]+$` accepted "1.0.0" — the version string every package.json carries — which
          // inflated the pattern count and so silenced the "no pattern found anywhere, report a HOLE
          // rather than accuse" guard. A guard that any repo disables by existing is not a guard.
          if (/^[A-Za-z0-9_.-]+\.(ts|tsx|js|jsx|mjs|cjs|vue|svelte)$/i.test(p)) names.add(p);
          if (!usable(p)) return;
          (neg || EXKEY.test(keyAt(idx)) ? exc : inc).push(p);
        };
        for (const m of t.matchAll(/(["\x27`])((?:\\.|(?!\1).)*?)\1/g)) add(m[2], m.index);
        for (const m of t.matchAll(/[A-Za-z0-9_.@*-][A-Za-z0-9_.@*\/-]*\/[A-Za-z0-9_.@*\/-]*/g)) add(m[0], m.index);
        // Path-shaped regex literals: civis-ai keeps its coverage floor as /(crypto\/(aead|vault)|access-code)\.ts$/
        for (const m of t.matchAll(/[=(,\s]\/((?:\\.|\[[^\]]*\]|[^\/\n\\])+)\/[gimsuy]*/g)) {
          const b = m[1];
          if (!/\\\//.test(b) && !/\.(ts|tsx|js|jsx|mjs|cjs)\b/.test(b)) continue;
          try { rex.push(new RegExp(b)); } catch (e) {}
        }
      }
      const incRe = inc.map(p => ({ p, re: globRe(p) })), excRe = exc.map(p => ({ p, re: globRe(p) }));
      console.log("SOURCES\t" + read + "\t" + inc.length + "\t" + exc.length + "\t" + rex.length + "\t" + names.size);
      for (const f of files) {
        const base = f.split("/").pop();
        const e = excRe.find(x => x.re.test(f));
        if (e) { console.log("EXCLUDED\t" + f + "\t" + e.p); continue; }
        const i = incRe.find(x => x.re.test(f));
        if (i) { console.log("NAMED\t" + f + "\t" + i.p); continue; }
        if (rex.some(r => r.test(f))) { console.log("NAMED\t" + f + "\tregex"); continue; }
        if (names.has(base)) { console.log("NAMED\t" + f + "\tbasename " + base); continue; }
        console.log("UNNAMED\t" + f);
      }
    ' "$TMPD/srcs" "$TMPD/crit" > "$TMPD/a4" 2>/dev/null || : > "$TMPD/a4"
    npat="$(awk -F'\t' '/^SOURCES/{print $3+$4+$5+$6}' "$TMPD/a4")"
    nnamed="$(grep -c '^NAMED'    "$TMPD/a4" 2>/dev/null | tr -d ' \n')"
    nexcl="$( grep -c '^EXCLUDED' "$TMPD/a4" 2>/dev/null | tr -d ' \n')"
    nunc="$(  grep -c '^UNNAMED'  "$TMPD/a4" 2>/dev/null | tr -d ' \n')"
    nnamed="${nnamed:-0}"; nexcl="${nexcl:-0}"; nunc="${nunc:-0}"
    if [ ! -s "$TMPD/a4" ] || [ "${npat:-0}" -eq 0 ]; then
      # No pattern extracted at all: this rung LOOKED and found nothing to compare against. Listing
      # every critical file as "ungated" here would be an accusation manufactured out of ignorance.
      hole "no include/exclude pattern found in any threshold source — A4 cannot tell covered from uncovered here ($ncrit critical-looking file(s) unjudged)"
    else
      info "$ncrit file(s) look money/auth-critical: $nnamed inside a gate pattern, $nexcl explicitly excluded, $nunc named nowhere"
      nbase="$(grep -c '	basename ' "$TMPD/a4" 2>/dev/null | tr -d ' \n')"
      # Weakest tier, so it is declared rather than folded into the count: a per-file money gate lists
      # bare basenames ('pricing.ts'), which cannot tell two same-named files in different folders apart.
      [ "${nbase:-0}" -gt 0 ] && info "of those, $nbase matched only by BASENAME (a bare 'x.ts' in a threshold list) — ambiguous if the name repeats across folders"
      if [ "${nexcl:-0}" -gt 0 ]; then
        hole "$nexcl critical-looking file(s) match an EXCLUDE pattern — deliberately outside the gate's thresholds:"
        # Grouped by the pattern that excluded them: 25 lines saying "src/ui/**" is a list you scroll
        # past; one line saying "src/ui/** excludes 25 critical-looking files" is a decision.
        grep '^EXCLUDED' "$TMPD/a4" | awk -F'\t' '{ n[$3]++; if (!(($3) in ex)) ex[$3]=$2 }
          END { for (p in n) printf "        %-24s excludes %s critical-looking file(s), e.g. %s\n", p, n[p], ex[p] }' | sort
      fi
      if [ "${nunc:-0}" -gt 0 ]; then
        hole "$nunc critical-looking file(s) match NO pattern in any threshold source — confirm each is covered, or add it:"
        grep '^UNNAMED' "$TMPD/a4" | cut -f2 | head -n 15 | sed 's/^/        /'
        [ "$nunc" -gt 15 ] && printf '        … and %s more\n' "$((nunc - 15))"
      fi
      [ "${nexcl:-0}" -eq 0 ] && [ "${nunc:-0}" -eq 0 ] && \
        pass "every critical-looking file falls inside an include pattern of a threshold source"
    fi
  fi
  printf '        (a pattern match says the file is IN SCOPE of some threshold; it does not say the\n'
  printf '         threshold value is high enough, nor that the step runs. Read the config.)\n'
fi

# ---------------------------------------------------------------- A5 local vs CI parity
head2 "A5  local-vs-CI parity — locally green is not remotely green"
CID="$ROOT/.github/workflows"
if [ ! -d "$CID" ]; then
  hole "no .github/workflows — nothing re-checks this on a clean machine"
elif [ ! -f "$GATE" ]; then
  hole "no local gate to compare"
else
  cat "$CID"/*.yml "$CID"/*.yaml 2>/dev/null > "$TMPD/ci" || true
  # Compare TOOLS, not command strings. The local gate may call `npx vitest` directly while CI calls
  # `npm run test:cov`, whose package.json body runs vitest — the same protection through a different
  # spelling. String comparison calls that a gap and is simply wrong.
  node -e '
    const fs = require("fs");
    const gate = fs.readFileSync(process.argv[1], "utf8");
    const ci   = fs.readFileSync(process.argv[2], "utf8");
    let scripts = {};
    try { scripts = JSON.parse(fs.readFileSync(process.argv[3], "utf8")).scripts || {}; } catch (e) {}
    // Two different texts, two different rules — conflating them breaks the check in both directions.
    //  · shell scripts and CI YAML: only npx/npm invocations count. Extracting bare first tokens here
    //    would harvest rm, grep, tail from the gate script and report every project as failing.
    //  · npm script BODIES: binaries are invoked bare (scripts.test = "vitest run"), so the bare
    //    token is the whole point. Missing it accused firestop-app of a CI with no unit tests.
    const WRAPPERS = /^(cross-env|env|node|npm|npx|pnpm|yarn|bash|sh|set|echo|cd|rimraf|wait-on|concurrently)$/i;
    const NPMVERBS = ["ci", "install", "i", "audit", "exec", "cache", "config", "prune", "dedupe"];
    const addInvocations = (text, tools, seen) => {
      for (const m of text.matchAll(/npx\s+(?:--?[A-Za-z][\w-]*(?:=\S+)?\s+)*([a-z0-9@/._-]+)/gi)) tools.add(m[1].replace(/^@[^/]+\//, ""));
      // Flags between `npm run` and the script name must be SKIPPED, not treated as the name.
      // `npm run --silent typecheck` used to yield the script name "--silent", which was then
      // discarded — SprayFlow`s gate resolved to {biome, vitest} and its typecheck, DB-schema,
      // determinism and mutation steps were never compared against CI at all, under a PASS.
      for (const m of text.matchAll(/npm\s+(?:run\s+|run-script\s+)?(?:--?[A-Za-z][\w-]*(?:=\S+)?\s+)*([a-z0-9:._-]+)/gi)) {
        const name = m[1];
        if (name.startsWith("-") || name.startsWith(".")) continue;
        if (NPMVERBS.includes(name)) { tools.add("npm:" + name); continue; }
        if (seen.has(name)) continue;
        seen.add(name);
        const body = scripts[name];
        if (body) addBody(body, tools, seen); else tools.add("script:" + name);
      }
    };
    const addBody = (body, tools, seen) => {
      addInvocations(body, tools, seen);
      for (const seg of body.split(/&&|\|\||;|\n/)) {
        for (const tok of seg.trim().split(/\s+/)) {
          if (!tok || tok.includes("=") || tok.startsWith("-")) continue;
          if (WRAPPERS.test(tok)) continue;
          if (/^[a-z0-9@/._-]+$/i.test(tok)) tools.add(tok.replace(/^@[^/]+\//, ""));
          break;
        }
      }
    };
    // The CI half of the comparison must be built from COMMANDS, not from the whole YAML. Job names,
    // `name:` labels, env vars and comments are prose: SprayFlow`s CI carries `- run: npm run lint
    // # biome (format + lint)`, so the word "biome" was "found in CI" even if the step were deleted.
    // A PASS that a comment can satisfy is not falsifiable. Only `run:` bodies count.
    const runText = (() => {
      const lines = ci.split("\n"), out = [];
      for (let i = 0; i < lines.length; i++) {
        const m = lines[i].match(/^(\s*)(-\s+)?run:\s*(.*)$/);
        if (!m) continue;
        const indent = m[1].length + (m[2] ? m[2].length : 0);
        const head = m[3].trim();
        if (head && !/^[|>][-+]?$/.test(head)) out.push(head);
        for (let j = i + 1; j < lines.length; j++) {
          if (!lines[j].trim()) { continue; }
          if (lines[j].match(/^\s*/)[0].length <= indent) break;
          out.push(lines[j].trim()); i = j;
        }
      }
      // strip trailing shell comments so a comment inside a run: step cannot satisfy the check either
      return out.map(l => l.replace(/(^|\s)#.*$/, "$1")).join("\n");
    })();
    const expand = (text) => { const t = new Set(); addInvocations(text, t, new Set()); return t; };
    const g = expand(gate), c = expand(runText);
    // Safety net, and the reason it exists: a CI step may invoke a tool in a spelling this resolver
    // does not model (`- run: tsc`, a composite action, a matrix). Three false accusations came from
    // asserting a gap on resolver output alone — taleapp and civis-ai were both fine. So a bare name
    // still counts — but only when it appears inside a run: command, never anywhere in the file.
    const esc = s => s.replace(/[.*+?^${}()|[\]\\/]/g, "\\$&");
    const loose = [], missing = [];
    for (const t of g) {
      if (c.has(t)) continue;
      if (new RegExp("\\b" + esc(t) + "\\b").test(runText)) loose.push(t); else missing.push(t);
    }
    console.log("GATE\t" + [...g].sort().join(" "));
    console.log("CI\t" + [...c].sort().join(" "));
    if (!runText.trim()) console.log("NORUN\t1");
    for (const l of loose) console.log("LOOSE\t" + l);
    for (const m of missing) console.log("MISSING\t" + m);
  ' "$GATE" "$TMPD/ci" "$ROOT/package.json" | grep -v '^$' > "$TMPD/missing" 2>/dev/null
  grep '^GATE' "$TMPD/missing" | cut -f2- | sed 's/^/        gate: /'
  grep '^CI'   "$TMPD/missing" | cut -f2- | sed 's/^/        CI:   /'
  if grep -q '^LOOSE' "$TMPD/missing"; then
    info "matched only as a bare name inside a CI run: step, not resolved through a script: $(grep '^LOOSE' "$TMPD/missing" | cut -f2- | tr '\n' ' ')"
  fi
  if grep -q '^NORUN' "$TMPD/missing"; then
    hole "no 'run:' step found in .github/workflows — the workflows may use composite/reusable actions this check cannot read; NOTHING was compared"
  elif ! grep -q '^MISSING' "$TMPD/missing"; then
    pass "every tool the local gate runs is named in a CI run: step"
  else
    hole "run by the local gate, name absent from CI entirely — confirm by eye before believing it:"
    grep '^MISSING' "$TMPD/missing" | cut -f2- | sed 's/^/        /'
  fi
fi

# ---------------------------------------------------------------- A6 secrets in history
head2 "A6  secrets in git HISTORY"
# gitleaks exits 0 for "clean" AND for "I scanned nothing" — outside a git repo it prints
# `fatal: not a git repository`, reports `0 commits scanned.` and still exits 0. Verified on
# gitleaks 8.30.1. So the exit code alone cannot tell clean from did-not-look, and this rung used to
# announce "no secret in the entire history" after reading zero commits. The scanned-commit count it
# prints itself is the evidence; without a positive count this is a HOLE.
ncommits="$(git rev-list --count --all 2>/dev/null || echo 0)"
if ! command -v gitleaks >/dev/null 2>&1; then
  hole "gitleaks not installed — history was NOT scanned (brew install gitleaks)"
elif [ "${ncommits:-0}" -eq 0 ]; then
  hole "no commits in this repository (or not a git repo) — there is no history to scan, so 'no secrets found' would mean nothing"
elif gitleaks detect --no-banner --redact --report-format json --report-path "$TMPD/leaks.json" >"$TMPD/gl.log" 2>&1; then
  scanned="$(sed 's/\x1b\[[0-9;]*m//g' "$TMPD/gl.log" | grep -oE '[0-9]+ commits scanned' | grep -oE '^[0-9]+' | tail -1)"
  if [ -z "$scanned" ]; then
    hole "gitleaks exited 0 but never reported a scanned-commit count — cannot tell 'clean' from 'did not look'. Run it by hand: gitleaks detect --no-banner"
  elif [ "$scanned" -eq 0 ]; then
    hole "gitleaks scanned 0 commits although this repo has $ncommits — it looked at NOTHING. Its own output:"
    sed 's/\x1b\[[0-9;]*m//g' "$TMPD/gl.log" | tail -n 5 | sed 's/^/        /'
  else
    pass "gitleaks scanned $scanned commit(s) of $ncommits and found no secret"
  fi
else
  # A key whose NAME is prefixed public is public by design — reporting it as a leak is a false
  # blocker, and two of those teach you to skip the whole section. Same rule as release-gate G4.
  node -e '
    const fs = require("fs");
    let r = []; try { r = JSON.parse(fs.readFileSync(process.argv[1], "utf8")) || []; } catch (e) {}
    const pub = /(^|[^A-Z_])(NEXT_PUBLIC_|VITE_|PUBLIC_|REACT_APP_|EXPO_PUBLIC_|GATSBY_)/;
    const real = [], byDesign = [];
    for (const f of Array.isArray(r) ? r : []) (pub.test(String(f.Match || "")) ? byDesign : real).push(f);
    const line = f => "        " + (f.RuleID || "?") + "  " + (f.File || "?") + "  commit " + String(f.Commit || "?").slice(0, 8);
    console.log("REAL " + real.length + " BYDESIGN " + byDesign.length);
    for (const f of real.slice(0, 8)) console.log(line(f));
    if (byDesign.length) { console.log("--BYDESIGN--"); for (const f of byDesign.slice(0, 5)) console.log(line(f)); }
  ' "$TMPD/leaks.json" > "$TMPD/leaks.txt" 2>/dev/null
  nreal="$(awk 'NR==1{print $2}' "$TMPD/leaks.txt")"; nbyd="$(awk 'NR==1{print $4}' "$TMPD/leaks.txt")"
  if [ "${nreal:-0}" -eq 0 ] && [ "${nbyd:-0}" -eq 0 ]; then
    # Non-zero exit with an empty report is gitleaks ERRORING, not gitleaks finding nothing.
    hole "gitleaks exited non-zero but produced no findings — it failed rather than passed; history NOT scanned:"
    sed 's/\x1b\[[0-9;]*m//g' "$TMPD/gl.log" | tail -n 5 | sed 's/^/        /'
  elif [ "${nreal:-0}" -gt 0 ]; then
    fail "$nreal secret(s) in git history — rotating the key is the fix; deleting the file is not"
    sed -n '2,/--BYDESIGN--/p' "$TMPD/leaks.txt" | grep -v -- '--BYDESIGN--'
  else
    pass "no non-public secret in the entire history ($(sed 's/\x1b\[[0-9;]*m//g' "$TMPD/gl.log" | grep -oE '[0-9]+ commits scanned' | tail -1) of $ncommits)"
  fi
  if [ "${nbyd:-0}" -gt 0 ]; then
    hole "$nbyd hit(s) are public-by-design keys (NEXT_PUBLIC_/VITE_ prefix) — safe only to the extent RLS holds:"
    sed -n '/--BYDESIGN--/,$p' "$TMPD/leaks.txt" | grep -v -- '--BYDESIGN--'
  fi
fi

# ---------------------------------------------------------------- verdict
head2 "verdict"
# Last measurement before the verdict: a breach outranks every PASS above it, because a script that
# left something behind has already disproved the only thing it was trusted about.
fence_end || breach=1
printf '  blockers: %s   ·   holes: %s\n' "$blockers" "$holes"
cat <<'EOF'

  A gate audit does not improve the code. It answers whether the things you believe are protecting
  the code are switched on, reachable, currently green, and capable of failing. Everything else in
  your quality stack rests on that answer.
EOF
[ "${breach:-0}" -eq 1 ] && exit 1
[ "$blockers" -gt 0 ] && exit 1
[ "$holes" -gt 0 ] && exit 2
exit 0
