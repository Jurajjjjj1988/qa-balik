#!/usr/bin/env bash
# release-gate.sh — mechanical half of the `go-live-gate` skill.
#
# Checks the things a human should never spend attention on before a release:
# env parity, secrets in the shipped bundle, source maps, .only, lockfile drift, prod build.
# It decides NOTHING that needs judgment — the judgment classes live in SKILL.md.
#
# WHAT IT WRITES — the complete list, per flag, so "read-only" never has to be taken on trust:
#   --fast        nothing inside the repository except an --out record you aimed there yourself.
#                 Its own scratch files live in $TMPDIR and are deleted on exit.
#   --out FILE    the release record, at FILE and nowhere else. Point FILE outside the repository and
#                 the repository stays untouched; inside it, the path is declared to the fence.
#   full run      additionally runs two commands that write wherever THEY choose:
#                   G7 `npm run build`        → the build tree: dist/ build/ .next/ out/ .svelte-kit/
#                   G8 `.claude/test-gate.sh` → whatever your gate emits: coverage/ reports/
#                                               .stryker-tmp/ playwright-report/ test-results/
#                 In most projects those are gitignored and git never sees them; where they are NOT
#                 ignored they are declared in advance so they cannot enter a commit unannounced.
#                 Because a full run writes, it refuses to start on a dirty working tree, or outside
#                 a git repository where nothing it wrote could be undone. Use --fast in both cases.
#
# None of that is a promise: every run ends with a write-fence line that MEASURES it, by diffing
# `git status --porcelain` around the whole run. A breach outranks the verdict — undeclared
# commit-visible change makes the script exit non-zero even when every check passed.
#
# Exit: 0 = every check proved · 1 = at least one blocker, or a write-fence breach · 2 = no blockers,
#       undecided HOLES remain. 2 IS NOT A PASS. An unproved item stays visible on purpose.
set -uo pipefail

# The fence is what turns the list above from a claim into a measurement. If the shared library is
# missing the run still happens — refusing would be worse than an unverified answer — but it says so.
_SAFETY_LIB="$HOME/.claude/skills/_lib/safety.sh"
if [ -r "$_SAFETY_LIB" ]; then
  . "$_SAFETY_LIB"
  FENCED=1
else
  FENCED=0
  fence_begin()   { :; }
  fence_declare() { :; }
  fence_end()     { :; }
  # NOT a no-op. The fence may degrade to "unverified" and say so, but the clean-tree guard is what
  # makes a botched cleanup recoverable with `git checkout`. Silently succeeding here is `|| true` on
  # a gate step: the write mode would proceed on a dirty tree with nothing to undo it.
  require_clean_tree() {
    printf '  ✗ refusing: %s is missing, so the clean-tree guard cannot run and a failed cleanup\n' "$_SAFETY_LIB" >&2
    printf '    could not be told from your own work. Use --fast, which writes nothing.\n' >&2
    return 1
  }
fi

FAST=0
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fast) FAST=1 ;;
    --out)  shift; OUT="${1:-}"; [ -n "$OUT" ] || { echo "--out needs a path" >&2; exit 64; } ;;
    -h|--help)
      sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'
      echo; echo "usage: release-gate.sh [--fast] [--out FILE]"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
  shift
done

ROOT="$(pwd)"
blockers=0
holes=0

# A full run hands the repository to `npm run build` and to your own test-gate; neither is under this
# script's control. On a dirty tree you could not afterwards tell their output from your own work, so
# the writing mode refuses rather than making a mess that git cannot undo.
if [ "$FAST" -eq 0 ]; then
  require_clean_tree "a full run executes 'npm run build' (G7) and .claude/test-gate.sh (G8), which write into this repository" || exit 1
fi

pass()  { printf '  PASS  %s\n' "$1"; }
fail()  { printf '  FAIL  %s\n' "$1"; blockers=$((blockers + 1)); }
hole()  { printf '  HOLE  %s\n' "$1"; holes=$((holes + 1)); }
info()  { printf '  ....  %s\n' "$1"; }
head2() { printf '\n== %s\n' "$1"; }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
FILES="$TMPD/files"       # NUL-separated: every source file in the repo (9 code extensions)
SHIP="$TMPD/ship"         # NUL-separated: only the files that actually ship to production
ALL="$TMPD/all"           # NUL-separated: EVERY path in the repo, any extension (G5 only)
REFS="$TMPD/refs"         # env var names referenced in source

# Run a grep over a NUL-separated file list. Guarded: an EMPTY list must never reach xargs,
# because xargs would then run grep with no file operands and it would block on stdin.
sgrep()  { [ -s "$FILES" ] || return 1; xargs -0 grep "$@" < "$FILES" 2>/dev/null; }
pgrep_() { [ -s "$SHIP" ]  || return 1; xargs -0 grep "$@" < "$SHIP"  2>/dev/null; }
agrep()  { [ -s "$ALL" ]   || return 1; xargs -0 grep -I "$@" < "$ALL" 2>/dev/null; }

# Values that look like configuration, not credentials, must not be reported as leaked secrets.
# `eu-central-1` is 12 chars and appears in every AWS bundle; a false blocker teaches you to click through.
looks_secret() {
  v="$1"
  [ "${#v}" -ge 24 ] && return 0
  if [ "${#v}" -ge 16 ] \
     && printf '%s' "$v" | grep -q '[a-z]' \
     && printf '%s' "$v" | grep -q '[A-Z]' \
     && printf '%s' "$v" | grep -q '[0-9]'; then return 0; fi
  return 1
}

main() {
printf '# release-gate — %s — %s\n' "$(basename "$ROOT")" "$(date '+%Y-%m-%d %H:%M')"

[ "$FENCED" -eq 1 ] || hole "write-fence library missing at $_SAFETY_LIB — this run is UNVERIFIED: nothing measures what it wrote into your repository"
fence_begin
# Declared BEFORE anything can write them. The build and gate trees are gitignored in most projects
# and then invisible to the fence anyway; declaring them costs nothing and covers the projects that
# track them, where an undeclared write would otherwise land in a commit.
[ -n "$OUT" ] && fence_declare "$OUT"
if [ "$FAST" -eq 0 ]; then
  for d in dist build .next out .svelte-kit .turbo .vercel coverage reports .stryker-tmp playwright-report test-results; do
    fence_declare "$d"; fence_declare "$d/"
  done
fi

# ---------------------------------------------------------------- source inventory
# Scan everything the repository actually contains — never "the first of src/ app/ lib/", which
# under-scans silently: a Next.js app keeps env reads in lib/ and components/, and the gate then
# reports "no variables referenced" while six exist. Confirmed on ekoplant-web, 2026-07-31.
#
# Ask GIT for the file list, not the filesystem. A blocklist of generated directories is a game you
# lose: `.stryker-tmp` sandboxes and a second `dist-sync/` build tree produced phantom findings on
# firestop-app that could not even be reproduced afterwards, because the directories were gone by
# then. `--cached --others --exclude-standard` is exactly "tracked, plus new files not ignored".
# Quoted array, never a bare string: an unquoted "*.ts *.tsx …" is glob-expanded by the SHELL before
# git ever sees it, so it silently collapses to whatever matches in the current directory.
# That regression cut civis-ai from 122 files to 16 while still reporting success. 2026-07-31.
EXTS=( '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.vue' '*.svelte' '*.astro' )
PRUNE=( -name node_modules -o -name .git -o -name 'dist*' -o -name build -o -name .next -o -name out
        -o -name coverage -o -name .turbo -o -name .vercel -o -name .svelte-kit -o -name vendor
        -o -name '.stryker-tmp' -o -name playwright-report -o -name test-results -o -name .venv )
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$ROOT" ls-files -z --cached --others --exclude-standard -- "${EXTS[@]}" > "$FILES" 2>/dev/null
else
  find "$ROOT" \
    \( "${PRUNE[@]}" \) -prune -o \
    -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' \
       -o -name '*.cjs' -o -name '*.vue' -o -name '*.svelte' -o -name '*.astro' \) -print0 \
    > "$FILES" 2>/dev/null
fi
nfiles="$(tr -dc '\0' < "$FILES" | wc -c | tr -d ' ')"

# A leaked credential does not live in a .ts file. It lives in service-account.json, in a committed
# .env.production, in a .pem, in a CI yaml. The nine-extension list above is structurally blind to
# every one of those, so G5 gets its OWN list: every path the repo contains, ANY extension, minus
# lockfiles (megabytes of integrity hashes, no credentials) and binaries. `grep -I` in agrep() is the
# second guard: anything that is actually binary is skipped rather than matched as noise.
BINPAT='\.(png|jpe?g|gif|webp|avif|ico|bmp|tiff?|pdf|zip|gz|tgz|bz2|xz|7z|rar|woff2?|ttf|otf|eot|mp3|mp4|m4a|mov|webm|wav|wasm|node|so|dylib|dll|exe|bin|db|sqlite3?|xlsx?|docx?|pptx?|heic|jar|class|pack|idx)$'
LOCKPAT='(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?|Cargo\.lock|poetry\.lock|composer\.lock|Gemfile\.lock|uv\.lock)$'
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  git -c core.quotepath=false -C "$ROOT" ls-files --cached --others --exclude-standard 2>/dev/null
else
  find "$ROOT" \( "${PRUNE[@]}" \) -prune -o -type f -print 2>/dev/null
fi | grep -viE "$BINPAT" | grep -vE "$LOCKPAT" | tr '\n' '\0' > "$ALL"
nall="$(tr -dc '\0' < "$ALL" | wc -c | tr -d ' ')"

# Tests, e2e and dev scripts are scanned (a .only there is exactly what must be caught) but they are
# NOT deployed. Demanding their env vars in .env.example produces a false blocker — confirmed on
# civis-ai, where CIVIS_EVAL_DIR lives only in tests/ and scripts/. Classify; never narrow silently.
# `(^|/)` on every directory prefix, NOT a leading slash: git ls-files emits repo-RELATIVE paths, so
# a pattern requiring `/scripts/` never matches the root-level `scripts/` that most repos actually
# have — the whole tooling tree then counted as shipped code and its env vars as deployment vars.
TOOLING='((^|/)(tests?|e2e|scripts|__tests__|cypress|playwright|mocks|fixtures|stories)/|\.test\.|\.spec\.|\.eval\.|\.stories\.|\.config\.)'
tr '\0' '\n' < "$FILES" | grep -vE "$TOOLING" | tr '\n' '\0' > "$SHIP"
nship="$(tr -dc '\0' < "$SHIP" | wc -c | tr -d ' ')"

# NEVER "the first directory that exists". A stale `dist/` left next to a live `.next/` made G4 scan
# the wrong tree and print PASS while the secret sat in the artifact that actually ships. Collect ALL
# of them and scan ALL of them; more than one build tree is a question this script cannot answer, so
# it is declared as a hole rather than resolved by guessing.
# Only part of a build tree is served to browsers. `.next/server` is server code; reporting a value
# found there as "ships to every browser" is simply false. Narrow to the client-served subtree.
# A function, because G7 rebuilds the artifact and the answer changes: a tree that did not exist, or
# did not contain the secret, before the build may contain it after.
discover_builds() {
  BUILDS=(); CLIENTS=()
  for d in dist build .next out .svelte-kit/output; do
    [ -d "$ROOT/$d" ] || continue
    BUILDS[${#BUILDS[@]}]="$ROOT/$d"
    c="$ROOT/$d"
    for s in "$ROOT/$d/static" "$ROOT/$d/client" "$ROOT/$d/_app"; do [ -d "$s" ] && { c="$s"; break; }; done
    CLIENTS[${#CLIENTS[@]}]="$c"
  done
  nbuild="${#BUILDS[@]}"
}
discover_builds

ENVEX=""
for f in .env.example .env.sample .env.template .env.local.example; do
  [ -f "$ROOT/$f" ] && { ENVEX="$ROOT/$f"; break; }
done

head2 "G0  what was scanned  (a gate must declare its own coverage)"
info "source files (9 code extensions): $nfiles  (of which shipped: $nship · tooling/tests: $((nfiles - nship)))"
[ "$nfiles" -eq 0 ] && hole "no source files found — every source-based check below is meaningless"
info "all repo paths, any extension, minus lockfiles/binaries (G5 scans these): $nall"
if [ "$nbuild" -eq 0 ]; then
  info "build output: <none>"
else
  i=0
  while [ "$i" -lt "$nbuild" ]; do
    info "build output: ${BUILDS[$i]}   (browser-served subtree: ${CLIENTS[$i]})"
    i=$((i + 1))
  done
  [ "$nbuild" -gt 1 ] && hole "$nbuild build trees exist — WHICH ONE SHIPS? all are scanned in G4, but a stale tree passing does not clear the live one; delete the dead tree and re-run"
fi
info "env template: ${ENVEX:-<none>}"

# ---------------------------------------------------------------- G1 repo state
head2 "G1  repository state"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  info "branch $(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?') @ $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
  dirty="$(git -C "$ROOT" status --porcelain | wc -l | tr -d ' ')"
  if [ "$dirty" -eq 0 ]; then
    pass "working tree clean — the record names a reproducible commit"
  else
    fail "$dirty uncommitted path(s): you cannot say later WHAT you released"
    git -C "$ROOT" status --porcelain | head -n 10 | sed 's/^/        /'
  fi
  ahead="$(git -C "$ROOT" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '')"
  [ -n "$ahead" ] && info "$ahead commit(s) ahead of upstream" || info "no upstream branch (local-only release)"
else
  hole "not a git repository — no version identity for the release record"
fi

# ---------------------------------------------------------------- G2 dependencies
head2 "G2  dependencies"
lock=""
for l in package-lock.json pnpm-lock.yaml yarn.lock bun.lockb bun.lock; do [ -f "$ROOT/$l" ] && { lock="$l"; break; }; done
if [ -n "$lock" ]; then
  if git -C "$ROOT" ls-files --error-unmatch "$lock" >/dev/null 2>&1; then
    pass "$lock present and tracked"
  else
    fail "$lock is NOT tracked by git — CI installs different versions than you tested"
  fi
else
  hole "no lockfile found — installs are not reproducible"
fi

if [ -f "$ROOT/package.json" ]; then
  # Run the auditor that matches the LOCKFILE. `npm audit` in a pnpm/yarn/bun repo exits 1 with
  # ENOLOCK — it audited nothing — and the old code read that non-zero exit as "high/critical found"
  # and printed a release blocker with no evidence lines under it, for CVEs nobody had looked for.
  case "$lock" in
    pnpm-lock.yaml) audcmd="pnpm audit --prod --audit-level high" ;;
    yarn.lock)      audcmd="yarn npm audit --severity high" ;;
    bun.lockb|bun.lock) audcmd="bun audit" ;;
    *)              audcmd="npm audit --omit=dev --audit-level=high" ;;
  esac
  aud="$($audcmd 2>&1)"; rc=$?
  # A non-zero exit is not evidence. Only a line that NAMES a high/critical finding is evidence;
  # anything else (ENOLOCK, missing binary, unparsed output) is a hole, quoting what came back.
  SEVPAT='[0-9]+[[:space:]]+(high|critical)|(high|critical)[[:space:]]+severity|severity["'"'"':[:space:]]+[0-9]*[[:space:]]*(high|critical)'
  if printf '%s' "$aud" | grep -qiE 'ENOTFOUND|ECONNREFUSED|network|offline|EAI_AGAIN'; then
    hole "$audcmd could not reach the registry — CVE status unknown"
  elif [ $rc -eq 0 ]; then
    pass "$audcmd: no high/critical in production dependencies"
  elif printf '%s' "$aud" | grep -qiE "$SEVPAT"; then
    fail "$audcmd reports high/critical in production dependencies"
    printf '%s\n' "$aud" | grep -iE 'severity|vulnerabilit' | head -n 8 | sed 's/^/        /'
  else
    hole "$audcmd exited $rc but named no high/critical finding — this is NOT a clean audit, nothing was checked:"
    printf '%s\n' "$aud" | grep -v '^[[:space:]]*$' | head -n 3 | sed 's/^/        /'
  fi
fi

# ---------------------------------------------------------------- G3 env parity
head2 "G3  environment variable parity"
# TWO forms are visible to a grep: dotted access and bracket access with a STRING literal. A dynamic
# key (`process.env[k]`) and destructuring (`const { A } = process.env`) cannot be resolved this way —
# they are reported as a hole below, and every message in G3 names the two forms it actually saw.
ENVDOT='(import\.meta\.env|process\.env)\.[A-Za-z_][A-Za-z0-9_]*'
ENVBR="(import\.meta\.env|process\.env)\[[[:space:]]*['\"][A-Za-z_][A-Za-z0-9_]*['\"]"
env_names() {   # $1 = sgrep (all source) | pgrep_ (shipped only)
  {
    "$1" -hoE "$ENVDOT" | sed -E 's/.*\.([A-Za-z_][A-Za-z0-9_]*)$/\1/'
    "$1" -hoE "$ENVBR"  | sed -E "s/^.*\\[[[:space:]]*['\"]//; s/['\"]\$//"
  } | grep -E '^[A-Za-z_][A-Za-z0-9_]*$'   # never let a mis-parse become a blank "missing variable"
}
env_names pgrep_ | sort -u > "$REFS"
env_names sgrep  | sort -u > "$REFS.all"
opaque="$(pgrep_ -lE "(process|import\.meta)\.env\[[[:space:]]*[A-Za-z_\$\`]|(const|let|var)[[:space:]]*\{[^}]*\}[[:space:]]*=[[:space:]]*(process|import\.meta)\.env" || true)"
# Injected by the runtime or the platform — you never set these in a deployment, and demanding
# them in .env.example produces a false blocker. Confirmed on civis-ai (VERCEL), 2026-07-31.
PLATFORM='^(NODE_ENV|MODE|DEV|PROD|SSR|BASE_URL|CI|PORT|TZ|HOME|PATH|PWD|USER|VERCEL|VERCEL_.*|NETLIFY|NETLIFY_.*|NEXT_RUNTIME|NEXT_PHASE|GITHUB_.*|npm_.*|AWS_LAMBDA_.*|RENDER|RENDER_.*|FLY_.*|ANALYZE|DEBUG|npm_package_.*)$'
grep -vE "$PLATFORM" "$REFS" > "$REFS.app" || true
n="$(wc -l < "$REFS.app" | tr -d ' ')"
nplat="$(grep -cE "$PLATFORM" "$REFS" | tr -d ' ')"
[ "$nplat" -gt 0 ] && info "$nplat platform/runtime-injected variable(s) ignored (CI, VERCEL, NODE_ENV, …)"
toolonly="$(comm -13 "$REFS" "$REFS.all" | grep -vE "$PLATFORM" || true)"
if [ -n "$toolonly" ]; then
  info "referenced ONLY from tests/scripts — CI needs these, the deployment does not:"
  printf '%s\n' "$toolonly" | sed 's/^/        /'
fi

if [ -n "$opaque" ]; then
  hole "env access this scan CANNOT resolve — a dynamic key, or destructuring of process.env. The names below are invisible to every check in G3; read these files by hand:"
  printf '%s\n' "$opaque" | head -n 8 | sed 's/^/        /'
fi

if [ "$n" -eq 0 ]; then
  if [ "$nfiles" -eq 0 ]; then
    hole "no source scanned, so 'no variables referenced' proves nothing"
  else
    info "no variable referenced as process.env.X or process.env['X'] in shipped code"
  fi
else
  info "$n variable(s) the deployment must supply:"
  sed 's/^/        /' "$REFS.app"
  if [ -n "$ENVEX" ]; then
    missing=""
    while read -r v; do
      grep -qE "^[[:space:]]*(export[[:space:]]+)?$v=" "$ENVEX" || missing="$missing$v
"
    done < "$REFS.app"
    if [ -z "$missing" ]; then
      pass "every variable referenced as process.env.X / process.env['X'] is documented in $(basename "$ENVEX")"
    else
      fail "referenced in code but absent from $(basename "$ENVEX") — nobody deploying knows to set them:"
      printf '%s' "$missing" | sed 's/^/        /'
    fi
  else
    hole "no .env.example — the deployment variable list exists only in your head"
  fi
  # This used to be an UNCONDITIONAL hole, which made exit 2 permanent for every app that reads a
  # single variable — and a status that can never be cleared stops carrying information. The
  # deployment's own variable list is not visible from this machine at all: that comparison is a
  # human step (class 1), so it is an instruction, not an unproved check of this script's.
  info "the hosting provider is not visible from here — put the list above side by side with the deployment's ACTUAL variables by hand (SKILL.md class 1, probes.md §7)"
  # This one IS a real, detected condition: these variables are readable by every visitor's browser.
  pub="$(grep -E '^(VITE_|NEXT_PUBLIC_|PUBLIC_|REACT_APP_|EXPO_PUBLIC_|GATSBY_)' "$REFS.app" || true)"
  if [ -n "$pub" ]; then
    hole "client-exposed variable(s) — the VALUE ships to every browser; write one line per variable saying why that is safe (an anon key is safe only once probes.md §3b has been run):"
    printf '%s\n' "$pub" | sed 's/^/        /'
  fi
fi

# The reverse direction, and the reason it exists: a variable consumed by a LIBRARY is never written
# as process.env.X in your code — `new Anthropic()` reads ANTHROPIC_API_KEY itself, a driver reads
# PGHOST itself. G3 is structurally blind to those. Anything in the template that no code mentions is
# either dead config or exactly such a variable; you must decide which, one line at a time.
if [ -n "$ENVEX" ]; then
  orphan="$(grep -oE '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=' "$ENVEX" \
    | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//; s/=$//' | sort -u \
    | comm -23 - "$REFS.all" | grep -vE "$PLATFORM" || true)"
  if [ -n "$orphan" ]; then
    hole "in $(basename "$ENVEX") but referenced nowhere in code — dead config, or read by a library (G3 cannot see those):"
    printf '%s\n' "$orphan" | sed 's/^/        /'
  fi
fi

# Vite exposes only VITE_-prefixed variables to client code; the rest are silently undefined at runtime.
if [ -f "$ROOT/vite.config.ts" ] || [ -f "$ROOT/vite.config.js" ] || [ -f "$ROOT/vite.config.mts" ]; then
  unprefixed="$(pgrep_ -hoE 'import\.meta\.env\.[A-Za-z_][A-Za-z0-9_]*' \
    | sed -E 's/.*\.//' | grep -vE '^VITE_' | grep -vE "$PLATFORM" | sort -u || true)"
  if [ -z "$unprefixed" ]; then
    pass "every import.meta.env reference carries the VITE_ prefix"
  else
    fail "import.meta.env without the VITE_ prefix — Vite leaves these undefined in the browser:"
    printf '%s\n' "$unprefixed" | sed 's/^/        /'
  fi
fi

# ---------------------------------------------------------------- G4 secrets in the shipped bundle
# Runs TWICE when a build happens. Measured 2026-08-01: with a stale `dist/` lying around from a
# previous release, G4 scanned that OLD artifact, passed, and G7 then rebuilt it with a freshly added
# secret baked in — the run ended `blockers: 0  holes: 0`, exit 0, "everything proved", while the key
# sat in the bundle served to every browser. Scanning an artifact that the same run is about to
# replace answers a question nobody asked.
scan_shipped() {
head2 "G4  secrets in the browser-served artifact"
if [ "$nbuild" -eq 0 ]; then
  hole "no build output — run the production build, then re-run this check"
else
  # EVERY .env* file, not just .env. Reading only `.env` meant a repo whose real secrets live in
  # .env.production got a PASS off the harmless values in .env — a positive claim about values the
  # check never saw. Measured 2026-08-01. Templates are excluded because they hold names, not values.
  ENVFILES=()
  for e in "$ROOT"/.env "$ROOT"/.env.*; do
    [ -f "$e" ] || continue
    case "${e##*/}" in *.example|*.sample|*.template|*.dist) continue ;; esac
    ENVFILES[${#ENVFILES[@]}]="$e"
  done
  if [ "${#ENVFILES[@]}" -eq 0 ]; then
    hole "no .env* file to compare against — cannot prove no secret VALUE was baked into any build tree"
  else
  info "env files compared against the artifact: $(for e in "${ENVFILES[@]}"; do printf '%s ' "${e##*/}"; done)"
  b=0
  while [ "$b" -lt "$nbuild" ]; do
    BUILD="${BUILDS[$b]}"; CLIENT="${CLIENTS[$b]}"; b=$((b + 1))
    leaked=0; checked=0; skipped=0
    for ENVF in "${ENVFILES[@]}"; do
    while IFS= read -r line || [ -n "$line" ]; do
      # CRLF first, before anything else looks at the line. A .env pasted from Windows, Notion or
      # Slack carries \r into the VALUE, grep then searches the bundle for "secret\r", never finds it,
      # and G4 prints "1 value tested, none present" — a false PASS that makes a positive claim.
      line="${line%$'\r'}"
      case "$line" in \#*|'') continue ;; esac
      key="${line%%=*}"; val="${line#*=}"
      [ "$key" = "$line" ] && continue
      key="${key# }"; key="${key#export }"
      val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
      case "$key" in VITE_*|NEXT_PUBLIC_*|PUBLIC_*|REACT_APP_*|EXPO_PUBLIC_*|GATSBY_*) continue ;; esac
      # Short values are skipped because a 6-character string matches half the bundle by accident, and
      # a check that cries wolf gets switched off. But the number is NAMED: a silent skip inside a
      # section that then prints PASS is a claim about values nobody looked at. Short PINs, numeric
      # codes and 8-character passwords live in this blind spot.
      if [ "${#val}" -lt 12 ]; then skipped=$((skipped + 1)); continue; fi
      checked=$((checked + 1))
      if grep -rqF -- "$val" "$CLIENT" 2>/dev/null; then
        if looks_secret "$val"; then
          fail "value of non-public \$$key is in $CLIENT — it ships to every browser"
          leaked=$((leaked + 1))
        else
          hole "value of \$$key appears in $CLIENT but looks like configuration, not a credential — decide by hand"
          leaked=$((leaked + 1))
        fi
      fi
    done < "$ENVF"
    done
    if [ "$checked" -eq 0 ]; then
      info "no non-public values long enough to test in .env"
    elif [ "$leaked" -eq 0 ]; then
      pass "$checked non-public value(s) tested, none present in $CLIENT"
    fi
    [ "$skipped" -gt 0 ] && hole "$skipped non-public value(s) were UNDER 12 characters and never tested — too short to search for without false matches; check those by hand"
    [ "$CLIENT" != "$BUILD" ] && info "server-side output under $BUILD was NOT scanned — it is not served to browsers"

    maps="$(find "$CLIENT" -name '*.map' 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$maps" -eq 0 ]; then pass "no source maps in $CLIENT"
    else fail "$maps source map(s) in $CLIENT — your full source is downloadable"; fi
  done
  fi
fi
}
scan_shipped

# ---------------------------------------------------------------- G5 credentials in source
head2 "G5  credentials committed to source"
SCOPE5="$nall file(s): every path git tracks, plus untracked-and-not-ignored, ANY extension, minus lockfiles and binaries"
if [ "$nall" -gt 0 ]; then
  # No leading quote on the JWT pattern: requiring '"eyJ' missed every single-quoted, backticked,
  # YAML- and .env-embedded token, i.e. most of the places a token is actually pasted.
  keyhits="$(agrep -lE -- '-----BEGIN [A-Z ]*PRIVATE KEY|sk_live_[A-Za-z0-9]{10,}' || true)"
  jwthits="$(agrep -lE -- 'eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{10,}' || true)"
  if [ -z "$keyhits" ] && [ -z "$jwthits" ]; then
    pass "no private key, sk_live_ key or literal JWT found — scanned $SCOPE5"
  else
    fail "credential-shaped literal, in $SCOPE5:"
    printf '%s\n%s\n' "$keyhits" "$jwthits" | grep -v '^$' | sed 's/^/        /'
  fi
  info "NOT scanned: git-ignored files (a local .env is invisible here — G4 tests its values against the bundle instead) and git HISTORY (use gate-audit for that)"
fi
if [ "$nfiles" -gt 0 ]; then
  srhits="$(sgrep -lE 'service_role|SERVICE_ROLE' || true)"
  if [ -n "$srhits" ]; then
    hole "'service_role' appears in the $nfiles code file(s) — confirm by hand each is a comment, not a client-side key:"
    printf '%s\n' "$srhits" | sed 's/^/        /'
  fi
fi

# ---------------------------------------------------------------- G6 debug leftovers
head2 "G6  debug leftovers in shipped code"
if [ "$nfiles" -gt 0 ]; then
  only="$(sgrep -lE '\b(describe|it|test)\.only[[:space:]]*\(' || true)"
  if [ -z "$only" ]; then
    pass "no .only() — the suite you consider green actually ran in full"
  else
    fail ".only() present: most of the suite never ran, and it still reported green:"
    printf '%s\n' "$only" | sed 's/^/        /'
  fi
  skipped="$(sgrep -lE '\b(describe|it|test)\.(skip|todo)[[:space:]]*\(|\bxit[[:space:]]*\(' || true)"
  [ -n "$skipped" ] && hole "skipped/todo tests present — confirm none of them covers a release-critical path:" \
    && printf '%s\n' "$skipped" | head -n 8 | sed 's/^/        /'
  dbg="$(sgrep -lE '^[[:space:]]*debugger[[:space:]]*;?[[:space:]]*$' || true)"
  if [ -z "$dbg" ]; then pass "no debugger statements"
  else fail "debugger statement ships to users:"; printf '%s\n' "$dbg" | sed 's/^/        /'; fi
  logs="$(sgrep -c 'console\.log' | awk -F: '$NF>0 {s+=$NF} END {print s+0}')"
  info "console.log occurrences in source: $logs (judgment: noise, or user data in the console?)"
fi

# ---------------------------------------------------------------- G7 production build
head2 "G7  production build"
if [ "$FAST" -eq 1 ]; then
  hole "skipped (--fast) — the prod build is a DIFFERENT compilation from dev; it must be proved"
elif [ -f "$ROOT/package.json" ] && grep -qE '"build"[[:space:]]*:' "$ROOT/package.json"; then
  if npm run build >"$TMPD/build.log" 2>&1; then
    pass "npm run build succeeded"
    # The artifact G4 examined no longer exists. Re-discover and re-scan; whatever this second pass
    # says is the verdict about what actually ships, and it is the one that counts.
    info "the build replaced the artifact G4 scanned — re-scanning it now, this second result is the one that counts"
    discover_builds
    scan_shipped
  else
    fail "npm run build FAILED — dev working proves nothing about what ships"
    tail -n 20 "$TMPD/build.log" | sed 's/^/        /'
  fi
else
  hole "no build script in package.json — cannot prove the shipped artifact compiles"
fi

# ---------------------------------------------------------------- G8 project test gate
head2 "G8  project test gate"
if [ "$FAST" -eq 1 ]; then
  hole "skipped (--fast) — run .claude/test-gate.sh before the release record is final"
elif [ -x "$ROOT/.claude/test-gate.sh" ]; then
  if bash "$ROOT/.claude/test-gate.sh" >"$TMPD/gate.log" 2>&1; then
    pass ".claude/test-gate.sh green"
  else
    fail ".claude/test-gate.sh RED"
    tail -n 25 "$TMPD/gate.log" | sed 's/^/        /'
  fi
else
  hole "no .claude/test-gate.sh — this project has no automated correctness gate at all"
fi

# ---------------------------------------------------------------- verdict
head2 "verdict"
printf '  blockers: %s\n  holes:    %s\n' "$blockers" "$holes"
cat <<'EOF'

  This half proves nothing about the judgment classes: config parity in the DEPLOYMENT · first run
  on empty production · a restore actually performed · migration against a copy of prod data ·
  privileges under the REAL role · the second person writing at the same time · operational
  blindness · the way back · the irreversible-operation inventory · legal and retention duties.
  Those are in SKILL.md and reference/probes.md. A gate that stops here checked the easy half.
EOF

# Last measurement, and it outranks the verdict: a gate that quietly changed your repository is not
# trustworthy about anything else it just told you.
fence_end || return 1

[ "$blockers" -gt 0 ] && return 1
[ "$holes" -gt 0 ] && return 2
return 0
}

if [ -n "$OUT" ]; then main | tee "$OUT"; exit "${PIPESTATUS[0]}"; else main; exit $?; fi
