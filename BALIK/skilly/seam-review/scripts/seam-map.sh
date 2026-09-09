#!/usr/bin/env bash
# seam-map.sh — mechanical half of the `seam-review` skill.
#
# Finds WHERE to look when reviewing an accumulated range of commits, so the retrospective review
# stops being "read everything" and becomes "read these seams, in this order".
#
# Six signals; the first four are always on. THREE of those carry published evidence for the
# mechanism they exploit, S4 does not and is labelled a heuristic wherever it appears, and S5/S6
# are opt-in because each downloads a tool and is slow:
#   S1 co-change violation  — Zimmermann et al., ICSE 2004 (ROSE): mined co-change rules put a
#                             correct further location in the top 3 suggestions >70% of the time.
#   S2 churn ranking        — Nagappan & Ball, ICSE 2005: relative churn predicts defect density.
#                             Hassan, ICSE 2009: entropy of changes predicts faults.
#   S3 divergent duplicate  — Juergens et al., ICSE 2009: 52% of clones were changed inconsistently
#                             and 15% of those inconsistent changes caused a fault.
#   S6 orphaned export      — an unused export IS a seam: its last caller left inside this range,
#                             in another file. Opt-in (--dead), scoped to the range so the report
#                             stays short enough to actually read.
#   S4 unmoved test         — HEURISTIC, no supporting study. (It used to cite McIntosh et al.,
#                             EMSE 2016; that paper measures human REVIEW coverage/participation
#                             against post-release defects, not whether a test file changed
#                             alongside source. Different quantity — the citation was wrong.)
#
# WHAT THIS WRITES — every path, under every flag
#   Into your repository: NOTHING. No flag creates, edits or deletes a file in the working tree.
#   Outside it: one `mktemp -d` scratch directory, removed on exit; with --clones, jscpd's JSON
#   report inside that same scratch directory, plus npm's own cache when it first fetches jscpd;
#   with --dead the same for knip, which also caches its compiled config under
#   node_modules/.cache/jiti/ — VCS-ignored, so it cannot reach a commit, but it IS a write.
#   You do not have to take that on trust. A write-fence fingerprints commit-visible state before
#   and after and prints its verdict every run; a BREACHED verdict is a defect in this script.
#
# usage: seam-map.sh [<base-ref>] [--top N] [--clones] [--dead]
#        default base = upstream if the branch has one, else HEAD~10
#        --clones  block-level clone detection via jscpd  (slow, downloads on first use)
#        --dead    exports this range left with no caller, via knip  (slow, downloads too)
set -uo pipefail

# The fence is what turns "read-only" from a claim you cannot check into a measurement printed on
# every run. If the library is missing the review still runs — but it must stop making the claim.
if [ -r "$HOME/.claude/skills/_lib/safety.sh" ]; then
  . "$HOME/.claude/skills/_lib/safety.sh"
else
  printf '  HOLE: %s/.claude/skills/_lib/safety.sh is missing — the write-fence is NOT active.\n' "$HOME" >&2
  printf '        This run is UNVERIFIED: nothing measured what the script touched.\n' >&2
  fence_begin()   { :; }
  fence_declare() { :; }
  fence_end()     { return 0; }
fi

BASE=""
TOP=12
CLONES=0
DEAD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --top) shift; TOP="${1:-12}" ;;
    --clones) CLONES=1 ;;
    --dead) DEAD=1 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) BASE="$1" ;;
  esac
  shift
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64
# Nothing below is declared: this script intends no write into the repository at all, so ANY
# commit-visible change the fence sees is a defect, including one made by jscpd under --clones.
fence_begin

if [ -z "$BASE" ]; then
  BASE="$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || true)"
  [ -z "$BASE" ] && BASE="HEAD~10"
fi
git rev-parse --verify "$BASE" >/dev/null 2>&1 || { echo "cannot resolve base ref: $BASE" >&2; exit 64; }

TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
RANGE="$TMPD/range"      # source files changed in the range
HIST="$TMPD/hist"        # commit/file stream of the whole history

EXTS='\.(ts|tsx|js|jsx|mjs|cjs|vue|svelte|astro)$'
# (^|/) not / — a repo-ROOT tests/ or e2e/ directory has no leading slash in a git path, and
# treating those fixtures as production code made S3 mine them and S4 report them as untested.
ISTEST='(\.test\.|\.spec\.|\.eval\.|(^|/)(tests?|e2e|__tests__|cypress)/)'

ncommits="$(git rev-list --count "$BASE"..HEAD 2>/dev/null || echo 0)"
git diff --name-only "$BASE"...HEAD 2>/dev/null | grep -E "$EXTS" | sort -u > "$RANGE"
nrange="$(wc -l < "$RANGE" | tr -d ' ')"

printf '# seam-map — %s — range %s..HEAD\n' "$(basename "$ROOT")" "$BASE"
printf '  %s commit(s), %s source file(s) changed\n' "$ncommits" "$nrange"
if [ "$ncommits" -eq 0 ] || [ "$nrange" -eq 0 ]; then
  printf '\n  Nothing accumulated against %s — no seams to review.\n' "$BASE"
  fence_end || exit 1
  exit 0
fi

# ---------------------------------------------------------------- S1 co-change violation
# The single highest-value signal: two files have changed together many times, and this time only
# one of them did. That is precisely a seam — no individual commit looks wrong.
printf '\n== S1  co-change violations — its usual partner did NOT change this time\n'
printf '       (ROSE, ICSE 2004: mined co-change rules find a correct further location in the top 3 >70%% of the time)\n\n'

git log --no-merges --pretty=format:'@%H' --name-only -n 4000 2>/dev/null \
  | grep -E "^@|$EXTS" > "$HIST"

awk -v MINSUP=3 -v MINCONF=0.55 -v ISTEST="$ISTEST" -v STATS="$TMPD/s1stats" '
  FNR==NR { inrange[$0]=1; next }
  /^@/    { flush(); next }
  NF      { if (n < 60) f[++n]=$0; next }
  END     { flush(); report() }

  function flush(   i,j,a,b,t) {
    # Commits touching a great many files are merges, renames and sweeps: they couple everything to
    # everything and drown the signal. Standard practice is to drop them from the mining.
    if (n >= 2 && n <= 20) {
      mined++
      for (i = 1; i <= n; i++) {
        support[f[i]]++
        for (j = i+1; j <= n; j++) {
          a = f[i]; b = f[j]
          if (a > b) { t = a; a = b; b = t }
          pair[a "\t" b]++
        }
      }
    } else if (n == 1) support[f[1]]++
    n = 0
  }
  function emit(x, y, c,   conf) {
    if (c < MINSUP) return
    conf = c / support[x]
    if (conf < MINCONF) return
    # Count every rule that CLEARED the thresholds, whether or not it is violated here. Without this
    # the empty case cannot tell "rules existed and all held" from "no rule could be mined at all".
    rules++
    if (!inrange[x] || inrange[y]) return
    printf "%.3f\t%s\t%s\t%d\t%d\n", conf, x, y, c, support[x]
  }
  function report(   p, ab) {
    for (p in pair) {
      split(p, ab, "\t")
      emit(ab[1], ab[2], pair[p])
      emit(ab[2], ab[1], pair[p])
    }
    printf "%d\t%d\n", mined+0, rules+0 > STATS
  }
' "$RANGE" "$HIST" | sort -rn | head -n "$TOP" > "$TMPD/s1"

s1mined=0; s1rules=0
if [ -f "$TMPD/s1stats" ]; then
  IFS="$(printf '\t')" read -r s1mined s1rules < "$TMPD/s1stats"
fi
shown=0; hidden=0
while IFS="$(printf '\t')" read -r conf a b c sup; do
  if [ ! -f "$b" ]; then hidden=$((hidden + 1)); continue; fi   # deleted partners are noise
  pct="$(awk -v c="$conf" 'BEGIN{printf "%d", c*100}')"
  printf '  %s\n' "$a"
  printf '     └─ %s\n' "$b"
  printf '        co-changed %s of %s times (%s%%) — NOT changed in this range\n\n' "$c" "$sup" "$pct"
  shown=$((shown + 1))
done < "$TMPD/s1"
if [ "$shown" -eq 0 ]; then
  # "Nothing printed" has two very different causes and they must not read the same.
  if [ "${s1rules:-0}" -eq 0 ]; then
    printf '  HOLE: %s commit(s) were mineable (2–20 source files each), but NO file pair reached\n' "${s1mined:-0}"
    printf '        support>=3 and confidence>=0.55 — there was no rule here to violate. S1 checked\n'
    printf '        nothing; treat this as "did not look", not as "clean".\n'
  else
    printf '  %s co-change rule(s) cleared the thresholds (support>=3, confidence>=0.55) over %s mined\n' "$s1rules" "${s1mined:-0}"
    printf '  commit(s); none of them is violated in this range.\n'
    [ "$hidden" -gt 0 ] && printf '  (%s violation(s) not shown: the partner file no longer exists)\n' "$hidden"
  fi
fi

# ---------------------------------------------------------------- S2 churn ranking
printf '\n== S2  churn ranking — read in this order, not alphabetically\n'
printf '       (Nagappan & Ball, ICSE 2005: relative churn predicts defect density)\n\n'
: > "$TMPD/s2"
while read -r f; do
  [ -f "$f" ] || continue
  cm="$(git rev-list --count "$BASE"..HEAD -- "$f" 2>/dev/null || echo 0)"
  ln="$(git diff --numstat "$BASE"...HEAD -- "$f" 2>/dev/null | awk '{print $1+$2}')"
  [ -z "$ln" ] && ln=0
  printf '%s\t%s\t%s\n' "$cm" "$ln" "$f" >> "$TMPD/s2"
done < "$RANGE"
sort -rn -k1,1 -k2,2 "$TMPD/s2" | head -n "$TOP" \
  | awk -F'\t' '{printf "  %2d commits  %5d lines  %s\n", $1, $2, $3}'

# ---------------------------------------------------------------- S3 divergent duplicate
printf '\n== S3  the same name declared in two places, and only one side changed\n'
printf '       (Juergens, ICSE 2009: 52%% of clones were changed inconsistently; 15%% of those caused a fault)\n\n'
# Same extension list as EXTS — listing only .ts/.js left S3 structurally dead (and silent about it)
# in a .vue/.svelte/.astro repository.
git ls-files 2>/dev/null | grep -E "$EXTS" | grep -vE "$ISTEST" > "$TMPD/prod" || true
if [ ! -s "$TMPD/prod" ]; then
  printf '  HOLE: no non-test file matched the source extensions — S3 inspected NOTHING here.\n'
  printf '        This is not a clean result; the corpus was empty.\n'
else
  # Key on the WHOLE normalised declaration, never on the name alone. Matching by name flags every
  # local called `layers` or `records` and the list becomes noise you learn to skip — measured on
  # SprayFlow, where name-matching produced one true seam (a duplicated MS_PER_HOUR) and several
  # false ones. Identical declaration text is what "the same thing written twice" actually means.
  xargs grep -HnE '^[[:space:]]*(export[[:space:]]+)?(default[[:space:]]+)?(async[[:space:]]+)?(function|const|class)[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]{3,}' \
    < "$TMPD/prod" 2>/dev/null \
    | awk '
      # Split off the grep "file:line:" prefix HERE rather than with sed + a TAB separator: the old
      # form inserted a TAB and then split on TAB, so every TAB-INDENTED declaration in the repo was
      # silently dropped (its own indentation became the field separator).
      {
        i = index($0, ":");          if (i == 0) next
        file = substr($0, 1, i - 1); rest = substr($0, i + 1)
        j = index(rest, ":");        if (j == 0) next
        d = substr(rest, j + 1)
        gsub(/\t/, " ", d)
        gsub(/^ +| +$/, "", d); gsub(/  +/, " ", d)
        if (length(d) < 18) next
        if (!isdecl(d)) next
        print file "\t" d
      }
      # A DECLARATION defines something: a signature, or an initializer that is itself a definition
      # (literal / object / array / function / arrow). `const role = kioskLayerToRole(layer)` is a
      # CALL SITE — one shared helper called from two components is not a duplicated declaration, and
      # reporting it as one was about half of this section on two real repositories.
      function isdecl(s,   e, rhs) {
        if (s ~ /^(export )?(default )?(async )?function /) return 1
        if (s ~ /^(export )?(default )?class /)             return 1
        e = index(s, "=")
        if (e == 0) return 0
        rhs = substr(s, e + 1); gsub(/^ +/, "", rhs)
        if (rhs ~ /^-?[0-9]/)                                   return 1   # numeric literal
        if (rhs ~ /^['"'"'"`]/)                                 return 1   # string / template literal
        if (rhs ~ /^(true|false|null|undefined)([^A-Za-z0-9_$]|$)/) return 1
        if (rhs ~ /^[{[]/)                                      return 1   # object / array literal
        if (rhs ~ /^(async )?function[ (]/)                     return 1
        if (s ~ /=>/ && rhs ~ /^(async )?[(<]/)                 return 1   # arrow with a param list
        if (rhs ~ /^[A-Za-z_$][A-Za-z0-9_$]* *=>/)              return 1   # single-param arrow
        return 0
      }' \
    | sort -u > "$TMPD/decl"

  awk -F'\t' '
    NR==FNR { inrange[$0]=1; next }
    { if (!seen[$2 "\t" $1]++) { files[$2] = files[$2] "\n" $1; cnt[$2]++ } }
    END {
      for (d in cnt) {
        if (cnt[d] < 2 || cnt[d] > 6) continue
        n = split(files[d], arr, "\n")
        touched = 0; untouched = 0; tl = ""; ul = ""
        for (i = 1; i <= n; i++) {
          if (arr[i] == "") continue
          if (inrange[arr[i]]) { touched++;   tl = tl "        changed:     " arr[i] "\n" }
          else                 { untouched++; ul = ul "        NOT changed: " arr[i] "\n" }
        }
        if (touched >= 1 && untouched >= 1)
          printf "  %s\n     identical in %d files, %d changed in this range\n%s%s\n", d, touched+untouched, touched, tl, ul
      }
    }
  ' "$RANGE" "$TMPD/decl" > "$TMPD/s3"
  # `grep -c` prints 0 AND exits 1 when there is no match, so `$(grep -c … || echo 0)` yielded the
  # two-line string "0\n0": both [ ] tests below then errored out and the reassurance line never
  # printed, making a clean S3 indistinguishable from a broken one.
  nrec="$(grep -c 'identical in' "$TMPD/s3" 2>/dev/null)" || nrec=0
  ndecl="$(wc -l < "$TMPD/decl" | tr -d ' ')"
  if [ "$nrec" -eq 0 ]; then
    printf '  %s declaration(s) keyed across %s file(s): none is written identically in both a changed\n' \
      "$ndecl" "$(wc -l < "$TMPD/prod" | tr -d ' ')"
    printf '  and an unchanged file.\n'
  else
    # Truncate on whole records, never mid-entry, and say so — a silently cut list reads as complete.
    awk -v top="$TOP" 'BEGIN{RS=""; ORS="\n\n"} NR<=top' "$TMPD/s3"
    [ "$nrec" -gt "$TOP" ] && printf '  … and %s more (raise --top to see them)\n' "$((nrec - TOP))"
  fi
  printf '  (keyed only on declarations that DEFINE something — a signature, or a literal / object /\n'
  printf '   array / arrow initializer. `const x = helper(a)` is a call site, not a duplicate, and is\n'
  printf '   deliberately excluded. A duplicated function BODY that has drifted is invisible here.)\n'
fi

# ---------------------------------------------------------------- S4 unreviewed surface
printf '\n== S4  changed, but no test moved with it\n'
printf '       (HEURISTIC — unlike S1–S3 this signal has NO published evidence behind it. It reports\n'
printf '        an absence, not a measured defect predictor; weigh it below the three above.)\n\n'

# The old code matched the source BASENAME as an unanchored regex against the whole PATH of every
# changed test file, so a file was DROPPED from the report whenever some unrelated module's test path
# merely contained the substring — measured on civis-ai, where all 13 `app/api/**/route.ts` files
# vanished because `tests/unit/intake-route.test.ts` contains "route".
# Now: compare whole TOKENS of the two basenames (split on . - _), never a raw substring, and never
# against directories. `auth-password.test.ts` still covers `auth/password.ts`; `intake-route.test.ts`
# no longer covers `admin/logout/route.ts`. For basenames that carry no identity of their own
# (route/index/page/…) the test must additionally name the parent directory.
grep -E "$ISTEST" "$RANGE" > "$TMPD/chtests"
grep -vE "$ISTEST" "$RANGE" > "$TMPD/prodrange"
git ls-files 2>/dev/null | grep -E "$ISTEST" > "$TMPD/alltests" || true

# TF, not FNR==NR: when no test changed at all, chtests is empty and FNR==NR would then be true for
# the FIRST record of the second file, swallowing a source file into the test list.
awk -v GENERIC=' route index page layout handler main mod ' -v TF="$TMPD/chtests" '
  FILENAME == TF {
    t = $0; sub(/.*\//, "", t); sub(/\.(test|spec|eval)\..*$/, "", t); sub(/\.[^.]+$/, "", t)
    t = tolower(t); gsub(/[.\-_]+/, " ", t)
    testtok[++ntest] = " " t " "
    next
  }
  {
    b = $0; sub(/.*\//, "", b); sub(/\.[^.]+$/, "", b)
    p = $0; sub(/\/[^\/]*$/, "", p); sub(/.*\//, "", p); p = tolower(p)
    b = tolower(b); gsub(/[.\-_]+/, " ", b)
    ns = split(b, st, " ")
    if (ns == 0) next
    allgen = 1
    for (i = 1; i <= ns; i++) if (index(GENERIC, " " st[i] " ") == 0) allgen = 0
    for (k = 1; k <= ntest; k++) {
      ok = 1
      for (i = 1; i <= ns; i++) if (index(testtok[k], " " st[i] " ") == 0) { ok = 0; break }
      if (ok && allgen && index(testtok[k], " " p " ") == 0) ok = 0
      if (ok) next
    }
    print
  }
' "$TMPD/chtests" "$TMPD/prodrange" > "$TMPD/s4cand"

: > "$TMPD/s4"
while read -r f; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"; base="${base%.*}"
  # does any test in the repo even mention it? -w so `Kiosk` does not match `KioskFooter`
  if [ -s "$TMPD/alltests" ] \
     && tr '\n' '\0' < "$TMPD/alltests" | xargs -0 grep -lqwF "$base" 2>/dev/null; then
    note='tests exist but none changed with it'
  else
    note='NO test in the repo mentions it'
  fi
  ln="$(awk -F'\t' -v f="$f" '$3 == f { print $2 }' "$TMPD/s2")"
  printf '%s\t%s\t%s\n' "${ln:-0}" "$f" "$note" >> "$TMPD/s4"
done < "$TMPD/s4cand"

nfound="$(wc -l < "$TMPD/s4" | tr -d ' ')"
if [ "$nfound" -eq 0 ]; then
  printf '  every changed source file has a changed test whose filename names it\n'
else
  # Ranked by churn and honouring --top: the whole point of the script is WHERE to look first.
  sort -rn -k1,1 "$TMPD/s4" | head -n "$TOP" \
    | awk -F'\t' '{ printf "  %5d lines  %s  — %s\n", $1, $2, $3 }'
  [ "$nfound" -gt "$TOP" ] && printf '  … and %s more (raise --top to see them)\n' "$((nfound - TOP))"
fi
printf '  (matched on FILENAMES only: a test that covers this file under an unrelated name — an\n'
printf '   integration or e2e spec — counts as "no test moved". Confirm before acting.)\n'

# ---------------------------------------------------------------- S5 block clones (opt-in)
# S3 only ever sees a single identical line. A duplicated BLOCK that has already drifted is the
# more dangerous case and needs a real clone detector. jscpd is opt-in because the first run
# downloads it — a review script must not reach the network behind your back.
printf '\n== S5  duplicated BLOCKS straddling the change boundary\n'
if [ "$CLONES" -eq 0 ]; then
  printf '  not run — pass --clones to include block-level clone detection (downloads jscpd on first use)\n'
elif ! command -v npx >/dev/null 2>&1; then
  printf '  HOLE: npx unavailable, block-level clones were NOT checked\n'
else
  # NOT "the half S3 cannot see". Measured 2026-08-01 on purpose-built type-1/2/3 fixtures: jscpd (4
  # and 5 alike) reports the exact copy and NOTHING for a renamed identifier or two inserted
  # statements. A drifted body is invisible to this rung too — and it is the dangerous kind, so the
  # line that used to promise it was the worst sort of wrong: reassuring.
  printf '       (exact and near-exact copies only — a body that has DRIFTED is invisible to jscpd,\n'
  printf '        which is the more dangerous case and stays unmeasured. See Limits in SKILL.md.)\n\n'
  # `.git/**` MUST be ignored, and not for speed: git ships ~778 lines of sample hooks in every repo,
  # jscpd counted them in the DENOMINATOR, and the repo-wide duplication figure this script then holds
  # up against GitClear's 12% came out at 2.67% where the real number was 48.89%. Measured 2026-08-01.
  # Same reasoning for build output: generated code is not duplication a human can act on.
  if npx --yes jscpd@4 . --min-lines 8 --min-tokens 60 --reporters json --output "$TMPD/jscpd" \
        --ignore "**/.git/**,**/node_modules/**,**/dist/**,**/build/**,**/coverage/**,**/.next/**,**/*.test.*,**/*.spec.*,**/e2e/**" --silent >/dev/null 2>&1 \
     && [ -f "$TMPD/jscpd/jscpd-report.json" ]; then
    node -e '
      const fs = require("fs");
      const range = new Set(fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean));
      const rep = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
      const norm = p => String(p).replace(/^\.\//, "");
      const seen = new Set(), out = [];
      for (const d of rep.duplicates || []) {
        const a = norm(d.firstFile?.name), b = norm(d.secondFile?.name);
        if (!a || !b || a === b) continue;
        const ia = range.has(a), ib = range.has(b);
        if (ia === ib) continue;                       // both changed, or neither: not a seam
        const changed = ia ? a : b, unchanged = ia ? b : a;
        const key = [changed, unchanged].join("|");
        if (seen.has(key)) continue;
        seen.add(key);
        out.push({ changed, unchanged, lines: d.lines || 0 });
      }
      out.sort((x, y) => y.lines - x.lines);
      const top = Number(process.argv[3]) || 12;
      if (!out.length) { console.log("  no duplicated block with one side changed and one side not"); }
      for (const c of out.slice(0, top)) {
        console.log("  " + c.lines + "-line block duplicated");
        console.log("        changed:     " + c.changed);
        console.log("        NOT changed: " + c.unchanged + "\n");
      }
      if (out.length > top) console.log("  … and " + (out.length - top) + " more");
      const s = rep.statistics?.total;
      if (s) console.log("  repo-wide duplication: " + (s.percentage ?? "?") + "% of lines (GitClear industry copy/paste ≈ 12%)");
    ' "$RANGE" "$TMPD/jscpd/jscpd-report.json" "$TOP"
  else
    printf '  HOLE: jscpd did not produce a report (offline, or install failed) — block clones NOT checked\n'
  fi
fi

# ---------------------------------------------------------------- S6 orphaned exports (opt-in)
# WHY THIS LIVES IN SEAM-REVIEW and not in a "run every static analyser" skill: an unused export is a
# seam by construction. Nobody writes an export nobody calls — it became unused when its last caller
# changed or left, in some commit inside this range, and almost always in a DIFFERENT file than the
# export itself. That is S1's co-change signal arriving from the opposite direction, and no per-commit
# review can see it: each commit on its own only deleted a call it no longer needed.
#
# The scoping matters as much as the tool. knip run repo-wide on a mature codebase reports hundreds of
# unused exports, and that report gets closed unread — worse than not running it. So findings are
# ordered by how strongly THIS RANGE is answerable for them:
#   1. the range removed the export's last mention   <- the actual seam
#   2. the range edited the file and left a dangling export
#   3. everything else                               <- counted, never listed
printf '\n== S6  exports this range left with no caller\n'
if [ "$DEAD" -eq 0 ]; then
  printf '  not run — pass --dead to look for orphaned exports (downloads knip on first use)\n'
elif ! command -v npx >/dev/null 2>&1; then
  printf '  HOLE: npx unavailable, orphaned exports were NOT checked\n'
else
  # knip exits non-zero when it FINDS things, so the exit code cannot tell "issues" from "crashed".
  # The JSON decides: parseable means it ran, unparseable means it did not, and that is a hole.
  npx --yes knip --reporter json > "$TMPD/knip.json" 2>"$TMPD/knip.err" || true
  # What the range DELETED and what it ADDED, as raw text. An identifier present among the removed
  # lines and absent from every added one lost its mention inside this range.
  git diff "$BASE"...HEAD 2>/dev/null | grep '^-' > "$TMPD/removed" || true
  git diff "$BASE"...HEAD 2>/dev/null | grep '^+' > "$TMPD/added" || true
  cat > "$TMPD/s6.js" <<'NODE'
const fs = require("fs");
const [, , jsonFile, rangeFile, removedFile, addedFile] = process.argv;
let r;
try { r = JSON.parse(fs.readFileSync(jsonFile, "utf8")); }
catch (e) { console.log("HOLE\tknip output was not JSON: " + e.message); process.exit(0); }
// Shape defence, carried over from analysis-ladder because it is the one thing there worth keeping:
// knip has NO top-level `files` key, and a reader that invents one counts 0 for every repo forever —
// a check that can never fire. An unrecognised shape is a HOLE, never a zero.
if (!r || !Array.isArray(r.issues)) {
  console.log("HOLE\tknip JSON has no `issues` array (top-level keys: " +
    Object.keys(r || {}).join(",") + ") — reporter shape changed, nothing was counted");
  process.exit(0);
}
const range = new Set(fs.readFileSync(rangeFile, "utf8").split("\n").filter(Boolean));
const removed = fs.readFileSync(removedFile, "utf8");
const added = fs.readFileSync(addedFile, "utf8");
const names = (v) => Array.isArray(v) ? v.map(x => (x && x.name) || String(x)) : null;
const word = (n) => new RegExp("\\b" + n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b");
const orphanedByRange = [], danglingInTouched = [];
let outside = 0, unusedFiles = 0;
const deadInRange = [];
for (const i of r.issues) {
  const file = i.file || "";
  for (const key of ["exports", "types"]) {
    if (!(key in i)) continue;
    const n = names(i[key]);
    if (n === null) { console.log("HOLE\tknip `" + key + "` is not an array — shape changed"); process.exit(0); }
    for (const name of n) {
      const w = word(name);
      // The strongest signal, and the reason this belongs to a RANGE review: the identifier is gone
      // from the lines this range deleted and appears nowhere in what it added. Its last caller left
      // here — in a commit that, read on its own, merely removed a call it no longer needed.
      if (w.test(removed) && !w.test(added)) orphanedByRange.push([file, name]);
      else if (range.has(file)) danglingInTouched.push([file, name]);
      else outside++;
    }
  }
  const f = names(i.files);
  if (f && f.length) { unusedFiles += f.length; for (const x of f) if (range.has(x)) deadInRange.push(x); }
}
// A repo whose entry points knip failed to resolve comes back with almost EVERY file "unused". That
// is a misconfigured run, not dead code, and listing it is the false accusation that teaches people
// to skip the section. Refuse to report rather than accuse.
if (range.size && unusedFiles >= Math.max(5, range.size * 0.6)) {
  console.log("HOLE\tknip calls " + unusedFiles + " file(s) unused against " + range.size +
    " changed in the range — it almost certainly did not resolve this project's entry points. " +
    "Give knip a config before believing any of this.");
  process.exit(0);
}
console.log(["OK", orphanedByRange.length, danglingInTouched.length, deadInRange.length, outside].join("\t"));
for (const [f, n] of orphanedByRange) console.log("SEAM\t" + f + "\t" + n);
for (const [f, n] of danglingInTouched) console.log("DANGL\t" + f + "\t" + n);
for (const f of deadInRange) console.log("FILE\t" + f);
NODE
  s6="$(node "$TMPD/s6.js" "$TMPD/knip.json" "$RANGE" "$TMPD/removed" "$TMPD/added" 2>/dev/null)"
  case "$(printf '%s' "$s6" | head -1 | cut -f1)" in
    OK)
      nseam="$(printf '%s' "$s6" | head -1 | cut -f2)"
      ndang="$(printf '%s' "$s6" | head -1 | cut -f3)"
      nfile="$(printf '%s' "$s6" | head -1 | cut -f4)"
      nout="$(printf '%s' "$s6"  | head -1 | cut -f5)"
      if [ "${nseam:-0}" -eq 0 ] && [ "${ndang:-0}" -eq 0 ] && [ "${nfile:-0}" -eq 0 ]; then
        printf '  none — every export reachable from the %s changed file(s) still has a caller\n' "$nrange"
      else
        [ "${nseam:-0}" -gt 0 ] && printf '  this range removed the last mention:\n'
        printf '%s\n' "$s6" | awk -F'\t' -v top="$TOP" '$1=="SEAM" && ++c<=top { printf "    %-42s %s\n", $2, $3 }'
        [ "${ndang:-0}" -gt 0 ] && printf '  changed here, and the export has no caller anywhere:\n'
        printf '%s\n' "$s6" | awk -F'\t' -v top="$TOP" '$1=="DANGL" && ++c<=top { printf "    %-42s %s\n", $2, $3 }'
        printf '%s\n' "$s6" | awk -F'\t' '$1=="FILE" { printf "    %-42s (whole file: nothing imports it)\n", $2 }'
      fi
      [ "${nout:-0}" -gt 0 ] && printf '        %s further unused export(s) elsewhere — pre-existing, not this range to answer for\n' "$nout"
      ;;
    HOLE) printf '  HOLE: %s\n' "$(printf '%s' "$s6" | head -1 | cut -f2)" ;;
    *)    printf '  HOLE: knip could not run — %s\n' "$(head -c 140 "$TMPD/knip.err" | tr '\n' ' ')" ;;
  esac
fi

cat <<'EOF'

  These are POINTERS, not findings. Each one says "a human never looked at this junction",
  never "there is a bug here". Take the top entries and apply the seam classes in SKILL.md;
  refute by default. A pointer you investigate and clear is a good outcome — record it so the
  next run does not re-raise it.
EOF

# A breach outranks the pointers above: whatever the report said, the run failed if the tree moved.
fence_end || exit 1
exit 0
