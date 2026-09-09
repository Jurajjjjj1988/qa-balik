#!/usr/bin/env bash
# bru-gate-probe.sh — dokáž, že Bruno brána naozaj hryzie.
#
# Namieriš na ĽUBOVOĽNÚ Bruno kolekciu a odpovie na otázku, ktorú `bru run`
# sám nezodpovie: "keby bola v API chyba, sčervenela by táto pipeline?"
#
# Zdrojovú kolekciu NIKDY nemení — sonda beží výhradne na kópii v temp.
#
# Exit kódy (rozlišuj "čisté" od "nepozrel som sa"):
#   0  všetko DOKÁZANÉ
#   2  BRÁNA NEVIE PADNÚŤ  <- najnebezpečnejší stav, zelená znamená nič
#   3  DIERA — nedalo sa pozrieť (0 requestov, chýbajúca podmienka)
#   1  chyba použitia / prostredia
set -uo pipefail

usage() {
  cat <<'USAGE'
Použitie:
  bru-gate-probe.sh <cesta-ku-kolekcii> [-- <argumenty, ktoré používa vaša CI>]

Príklady:
  bru-gate-probe.sh ./collections/Users
  bru-gate-probe.sh ./collections -- --env staging --tests-only
  bru-gate-probe.sh ./collections -- --env ci --tags smoke

Argumenty za `--` sa posielajú do `bru run` NEZMENENÉ, aby sonda merala
presne ten príkaz, ktorý beží vo vašej pipeline — nie iný.
USAGE
}

[ $# -ge 1 ] || { usage; exit 1; }
case "$1" in -h|--help) usage; exit 0;; esac

COLLECTION="$1"; shift
CI_ARGS=()
if [ "${1:-}" = "--" ]; then shift; CI_ARGS=("$@"); fi

[ -d "$COLLECTION" ] || { echo "CHYBA: '$COLLECTION' nie je priečinok"; exit 1; }
COLLECTION="$(cd "$COLLECTION" && pwd)"

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; BLD=$'\033[1m'; OFF=$'\033[0m'
ok()   { printf '%s  PASS%s  %s\n' "$GRN" "$OFF" "$*"; }
bad()  { printf '%s  FAIL%s  %s\n' "$RED" "$OFF" "$*"; }
hole() { printf '%s  DIERA%s %s\n' "$YEL" "$OFF" "$*"; }
info() { printf '        %s\n' "$*"; }
hdr()  { printf '\n%s%s%s\n' "$BLD" "$*" "$OFF"; }

VERDICT=0            # 0 ok, 2 gate-cannot-fail, 3 hole
# 🔴 OPRAVA 2026-09-07: `demote` bral číselné maximum, lenže 3 („diera") je číselne VYŠŠIE
# než 2 („brána nevie padnúť"), pričom je MENEJ závažné. Kolekcia, ktorá aj (a) nevie padnúť,
# aj (b) spustí ktorúkoľvek neskoršiu kontrolu diery, sa tak hlásila ako diera — a keďže
# reálne kolekcie skoro vždy nesú Authorization hlavičku, verdikt 2 bol v praxi nedosiahnuteľný.
# Kto si napísal `if [ $rc -eq 2 ]; then blokuj; fi`, mal bránu, ktorá nikdy neblokuje.
GATE_CANNOT_FAIL=0
demote() {
  [ "$1" -eq 2 ] && GATE_CANNOT_FAIL=1
  [ "$VERDICT" -lt "$1" ] && VERDICT="$1"
  # 2 dominuje nad 3 vždy — je to horší stav, nech príde v akomkoľvek poradí
  [ "$GATE_CANNOT_FAIL" -eq 1 ] && VERDICT=2
  return 0
}

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ---------------------------------------------------------------- T0 pôvod nástroja
hdr "T0 — Pôvod nástroja (beží bru z TOHTO repa?)"
# Hľadaj najbližší node_modules/.bin/bru smerom hore od kolekcie.
BRU=""
probe_dir="$COLLECTION"
while [ "$probe_dir" != "/" ]; do
  if [ -x "$probe_dir/node_modules/.bin/bru" ]; then BRU="$probe_dir/node_modules/.bin/bru"; break; fi
  probe_dir="$(dirname "$probe_dir")"
done
if [ -n "$BRU" ]; then
  ok "bru z node_modules repa: $BRU"
else
  BRU="$(command -v bru || true)"
  if [ -z "$BRU" ]; then
    bad "bru sa nenašiel ani v node_modules, ani v PATH."
    info "Nainštaluj LOKÁLNE do repa: npm install --save-dev @usebruno/cli"
    info "Globálne/npx riskuje, že v CI pobeží ÚPLNE INÁ verzia než tu."
    exit 1
  fi
  hole "bru je GLOBÁLNY ($BRU) — nie z node_modules tohto repa."
  info "Verzia v CI sa tak môže ticho líšiť od verzie, na ktorej si to overil."
  info "Odporúčanie: npm install --save-dev @usebruno/cli a commitni package-lock.json"
  demote 3
fi
BRU_VERSION="$("$BRU" --version 2>&1 | head -1)"
info "verzia: $BRU_VERSION"

# ---------------------------------------------------------------- inventúra kolekcie
hdr "T1 — Inventúra kolekcie (koľko je tam vôbec kontrol?)"
# bash 3.2 (macOS default) nepozná mapfile — plníme pole cez while-read.
# Do inventúry patria len REQUESTY. Súbory prostredí (environments/*.bru),
# collection.bru a folder.bru requesty nie sú — počítať ich znamená obviniť
# kolekciu z diery, ktorú nemá, a poslať človeka opravovať zdravý súbor.
# ZMERANÉ 2026-09-07: od Bruna v3.1.0 sú NOVÉ kolekcie v OpenCollection YAML, nie .bru
# (zakladateľ to potvrdil: „after two years of lived experience, I was wrong").
# Request v YAML = súbor s `info:` a `type: http` (priečinok má `type: folder`).
# Kľúče kontrol sa medzi formátmi LÍŠIA — overené v @usebruno/schema:
#     .bru  →  assert { … }   /  tests { … }
#     .yml  →  assertions:    /  tests:
# Bez tejto vetvy by sonda na novej kolekcii ohlásila „0 requestov", čo sa číta ako
# „tvoja kolekcia je prázdna" — hoci je to diera v NÁSTROJI, nie nález o kolekcii.
if [ -f "$COLLECTION/opencollection.yml" ]; then FMT="OpenCollection YAML"; else FMT=".bru"; fi

# ⚠️ node_modules a .git MUSIA von. Tento skill sám odporúča inštalovať bru lokálne do repa,
# takže vnútri kolekcie bežne LEŽÍ node_modules — a v ňom sú testovacie fixtures samotného
# Bruna, .bru aj .yml. Bez tejto výnimky sonda nameria desiatky cudzích „requestov bez
# kontroly" a obviní kolekciu z diery, ktorú nemá. Bruno má na to vlastný `ignore` zoznam
# v bruno.json aj opencollection.yml — defaultne presne node_modules a .git.
# ⚠️ POZOR: komentáre s nepárovou zátvorkou sa NESMÚ dostať dovnútra `<( … )` —
# bash 3.2 tam zátvorky počíta aj v komentároch a padne na „bad substitution".
BRU_FILES=()
while IFS= read -r line; do BRU_FILES+=("$line"); done < <(
  {
    find "$COLLECTION" -name '*.bru' -type f \
      ! -path '*/node_modules/*' ! -path '*/.git/*' \
      ! -name 'collection.bru' ! -name 'folder.bru' ! -path '*/environments/*'
    find "$COLLECTION" -name '*.yml' -type f \
      ! -path '*/node_modules/*' ! -path '*/.git/*' \
      ! -name 'opencollection.yml' ! -name 'folder.yml' ! -path '*/environments/*' \
      -exec grep -lE '^[[:space:]]*type:[[:space:]]*http[[:space:]]*$' {} +
  } 2>/dev/null | sort -u
)
N_FILES=${#BRU_FILES[@]}
N_WITH_ASSERT=0; N_WITH_TESTS=0; N_NAKED=0
NAKED_LIST=()
for f in "${BRU_FILES[@]}"; do
  has_a=0; has_t=0
  case "$f" in
    *.yml)
      grep -qE '^[[:space:]]*assertions[[:space:]]*:' "$f" && has_a=1
      grep -qE '^[[:space:]]*tests[[:space:]]*:'      "$f" && has_t=1 ;;
    *)
      grep -qE '^[[:space:]]*assert[[:space:]]*\{' "$f" && has_a=1
      grep -qE '^[[:space:]]*tests[[:space:]]*\{'  "$f" && has_t=1 ;;
  esac
  [ $has_a -eq 1 ] && N_WITH_ASSERT=$((N_WITH_ASSERT+1))
  [ $has_t -eq 1 ] && N_WITH_TESTS=$((N_WITH_TESTS+1))
  if [ $has_a -eq 0 ] && [ $has_t -eq 0 ]; then
    N_NAKED=$((N_NAKED+1)); NAKED_LIST+=("${f#$COLLECTION/}")
  fi
done
info "requestov:                    $N_FILES  (formát: $FMT)"
info "s assert blokom:             $N_WITH_ASSERT"
info "s tests blokom:              $N_WITH_TESTS"
info "BEZ akejkoľvek kontroly:     $N_NAKED"
if [ "$N_FILES" -eq 0 ]; then
  hole "V '$COLLECTION' nie je ani jeden request (hľadal som .bru aj OpenCollection .yml)."
  demote 3
elif [ "$N_NAKED" -eq "$N_FILES" ]; then
  bad "ŽIADNY request nemá assert ani tests → 'bru run' prejde na AKÚKOĽVEK odpoveď."
  info "Toto nie je testovacia suita, je to zoznam requestov. Zelená nedokazuje nič."
  demote 2
elif [ "$N_NAKED" -gt 0 ]; then
  hole "$N_NAKED z $N_FILES requestov nemá žiadnu kontrolu — tie sú v behu len dekorácia."
  for n in "${NAKED_LIST[@]:0:10}"; do info "  · $n"; done
  [ "$N_NAKED" -gt 10 ] && info "  … a ďalších $((N_NAKED-10))"
  demote 3
else
  ok "Každý request má aspoň jednu kontrolu."
fi

# ---------------------------------------------------------------- pracovná kópia
cp -R "$COLLECTION" "$WORK/copy"
COPY="$WORK/copy"

run_bru() { # $1=cwd  $2=json-out  zvyšok=args ; vracia exit kód bru
  local cwd="$1" jsonout="$2"; shift 2
  ( cd "$cwd" && "$BRU" run -r "$@" "${CI_ARGS[@]+"${CI_ARGS[@]}"}" --reporter-json "$jsonout" ) >"$WORK/out.log" 2>&1
  return $?
}

jq_summary() { # $1=json file  $2=kľúč
  python3 - "$1" "$2" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception:
    print("NA"); sys.exit(0)
tot=0
for it in (d if isinstance(d,list) else [d]):
    tot += (it.get("summary") or {}).get(sys.argv[2], 0)
print(tot)
PY
}

# ---------------------------------------------------------------- T2 zelený základ
hdr "T2 — Zelený základ (beží to vôbec, a koľko toho beží?)"
run_bru "$COPY" "$WORK/base.json"; BASE_EXIT=$?
BASE_REQ="$(jq_summary "$WORK/base.json" totalRequests)"
BASE_ASSERT="$(jq_summary "$WORK/base.json" totalAssertions)"
BASE_SKIP="$(jq_summary "$WORK/base.json" skippedRequests)"
info "exit=$BASE_EXIT  requestov=$BASE_REQ  preskočených=$BASE_SKIP  assertov=$BASE_ASSERT"

# totalRequests > 0 NESTAČÍ: pri syntaktickej chybe v jednom .bru súbore Bruno
# napočíta všetky requesty, VŠETKY ich preskočí a skončí kódom 0 so Status PASS.
# (Namerané na 4.1.0: totalRequests 5, skippedRequests 5, exit 0.)
if [ "$BASE_SKIP" != "NA" ] && [ "$BASE_SKIP" -gt 0 ] 2>/dev/null; then
  if [ "$BASE_SKIP" = "$BASE_REQ" ]; then
    bad "VŠETKÝCH $BASE_SKIP requestov bolo PRESKOČENÝCH — a beh skončil kódom $BASE_EXIT."
    info "Typicky syntaktická chyba v .bru súbore (Bruno ju hlási len ako Warning)."
    info "Suita prestala testovať a pipeline o tom mlčí. Skontroluj výstup behu:"
    grep -i "invalid file\|Expected end of input" "$WORK/out.log" 2>/dev/null | head -3 | sed 's/^/        /'
    demote 2
  else
    hole "$BASE_SKIP z $BASE_REQ requestov bolo preskočených — tie nič netestujú."
    grep -i "invalid file" "$WORK/out.log" 2>/dev/null | head -3 | sed 's/^/        /'
    demote 3
  fi
fi

if [ "$BASE_REQ" = "NA" ] || [ "$BASE_REQ" -eq 0 ] 2>/dev/null; then
  hole "Beh spracoval NULA requestov — a napriek tomu skončil kódom $BASE_EXIT."
  info "Toto je presne tichá zelená brána: preklep v --tags, prázdny priečinok"
  info "alebo filter, ktorý nič nematchuje, vyzerá v CI identicky ako úspech."
  info "Do pipeline pridaj kontrolu POČTU: totalRequests > 0, inak zhoď build."
  demote 3
  printf '\n%sVERDIKT: DIERA — nedalo sa dokázať nič, lebo sa nič nespustilo.%s\n' "$BLD" "$OFF"
  exit 3
fi

if [ "$BASE_REQ" -lt "$N_FILES" ]; then
  hole "Spustilo sa $BASE_REQ z $N_FILES requestov — beh je TICHO ZÚŽENÝ."
  info "Vinníkom býva --tests-only (preskočí requesty bez kontroly) alebo --tags."
  info "Rozdiel: $((N_FILES-BASE_REQ)) requestov CI nikdy nespustí, a nepovie to."
  demote 3
else
  ok "Spustilo sa $BASE_REQ requestov (súborov: $N_FILES) — nič sa ticho nevynechalo."
fi

if [ "$BASE_EXIT" -ne 0 ]; then
  bad "Základ nie je zelený (exit=$BASE_EXIT) — červeno/zelenú sondu nemá zmysel púšťať."
  info "Najprv nech kolekcia prejde proti tomuto prostrediu, potom spusti sondu znova."
  info "Posledné riadky behu:"; tail -15 "$WORK/out.log" | sed 's/^/        /'
  exit 1
fi
ok "Základ je zelený (exit 0)."

if [ "$BASE_ASSERT" != "NA" ] && [ "$BASE_ASSERT" -eq 0 ] 2>/dev/null; then
  bad "Beh nevykonal ANI JEDEN assert — zelená je bezobsažná."
  demote 2
fi

# ---------------------------------------------------------------- T2b stabilita
hdr "T2b — Stabilita (dá tá istá kolekcia ten istý výsledok?)"
STABILITY_N="${GATE_PROBE_STABILITY_N:-5}"
FLAKY=0
EXITS="$BASE_EXIT"
SANDBOX_ERR=0
i=2
while [ "$i" -le "$STABILITY_N" ]; do
  run_bru "$COPY" "$WORK/s$i.json"; e=$?
  EXITS="$EXITS,$e"
  [ "$e" -ne "$BASE_EXIT" ] && FLAKY=1
  grep -q "newContext\|Error executing the script" "$WORK/out.log" 2>/dev/null && SANDBOX_ERR=1
  i=$((i+1))
done
info "exit kódy $STABILITY_N behov: $EXITS"
if [ "$FLAKY" -eq 1 ]; then
  bad "Tá istá kolekcia dala RÔZNE výsledky — brána je nestabilná."
  info "Flaky brána je pokazená brána: tím sa naučí červenú odklikávať a prehliadne"
  info "aj tú pravú. Toto vyrieš PRED tým, než ju niekomu ukážeš."
  demote 3
else
  ok "$STABILITY_N behov, zhodný výsledok — brána je stabilná."
fi
if [ "$SANDBOX_ERR" -eq 1 ]; then
  hole "V behu sa objavila chyba Brunovho JS sandboxu ('newContext')."
  info "Namerané na @usebruno/cli 4.1.0 / node 20 / macOS arm64: default sandbox"
  info "'safe' padal 21 z 75 behov (~28 %), '--sandbox developer' 0 z 55."
  info "Skús pridať --sandbox developer a premeraj to na SVOJOM agentovi."
  demote 3
fi

# ---------------------------------------------------------------- T3 červená sonda
hdr "T3 — Červená sonda (VIE tá brána vôbec padnúť?)"
TARGET=""
for f in "${BRU_FILES[@]}"; do
  if grep -qE '^[[:space:]]*assert[[:space:]]*\{' "$f"; then TARGET="$COPY/${f#$COLLECTION/}"; MODE=assert; break; fi
done
if [ -z "$TARGET" ]; then
  for f in "${BRU_FILES[@]}"; do
    if grep -qE '^[[:space:]]*tests[[:space:]]*\{|^[[:space:]]*tests[[:space:]]*:' "$f"; then TARGET="$COPY/${f#$COLLECTION/}"; MODE=tests; break; fi
  done
fi

if [ -z "$TARGET" ]; then
  bad "Niet kam vložiť poruchu — kolekcia nemá assert ani tests blok."
  info "Bez kontroly nemôže brána sčervenieť NIKDY, nech je API akokoľvek pokazené."
  demote 2
else
  info "mutujem: ${TARGET#$COPY/}  (blok: $MODE)"
  python3 - "$TARGET" "$MODE" <<'PY'
import re,sys
p,mode=sys.argv[1],sys.argv[2]
s=open(p).read()
if mode=="assert":
    inject="\n  res.status: eq 99999\n"
    s=re.sub(r'(^[ \t]*assert[ \t]*\{)', r'\1'+inject, s, count=1, flags=re.M)
else:
    inject='\n  test("GATE-PROBE vynutene zlyhanie", function() { expect(1).to.equal(2); });\n'
    s=re.sub(r'(^[ \t]*tests[ \t]*\{)', r'\1'+inject, s, count=1, flags=re.M)
open(p,"w").write(s)
PY
  run_bru "$COPY" "$WORK/red.json"; RED_EXIT=$?
  RED_FAILED_A="$(jq_summary "$WORK/red.json" failedAssertions)"
  RED_FAILED_T="$(jq_summary "$WORK/red.json" failedTests)"
  info "exit=$RED_EXIT  padnutých assertov=$RED_FAILED_A  padnutých testov=$RED_FAILED_T"
  if [ "$RED_EXIT" -eq 0 ]; then
    bad "Vložil som zaručenú poruchu a brána zostala ZELENÁ (exit 0)."
    info "Táto brána nechráni nič. Kým nesčervenie, nepokladaj ju za bránu."
    demote 2
  else
    ok "Brána sčervenela na vloženej poruche (exit $RED_EXIT) — vie padnúť."
  fi

  # ------------------------------------------------------------ T4 zelený návrat
  hdr "T4 — Zelený návrat (bola tá červená naozaj z mojej poruchy?)"
  rm -rf "$COPY"; cp -R "$COLLECTION" "$COPY"
  run_bru "$COPY" "$WORK/green.json"; GRN_EXIT=$?
  info "exit=$GRN_EXIT"
  if [ "$GRN_EXIT" -eq 0 ]; then
    ok "Po odstránení poruchy je zase zelená — červená bola JEJ dôsledok."
  else
    bad "Bez poruchy je stále červená (exit $GRN_EXIT) — sonda nič nedokázala."
    if [ "$FLAKY" -eq 1 ] || [ "$SANDBOX_ERR" -eq 1 ]; then
      info "T2b už ukázal nestabilitu — táto červená je najskôr tá istá príčina,"
      info "nie dôsledok mutácie. Najprv odstráň flakiness, potom sonduj znova."
    else
      info "Prostredie sa medzi behmi zmenilo, alebo je kolekcia flaky. Zisti to skôr,"
      info "než sa na túto bránu spoľahneš."
    fi
    demote 3
  fi
fi

# ---------------------------------------------------------------- T5 čo uvidí CI
hdr "T5 — Čo z toho naozaj uvidí CI (JUnit report)"
( cd "$COPY" && "$BRU" run -r "${CI_ARGS[@]+"${CI_ARGS[@]}"}" --reporter-junit "$WORK/r.xml" ) >/dev/null 2>&1
JUNIT_EXIT=$?
if [ ! -f "$WORK/r.xml" ]; then
  hole "JUnit report sa nevytvoril (exit $JUNIT_EXIT) — CI nebude mať čo publikovať."
  demote 3
else
  N_TC="$(python3 - "$WORK/r.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
try:
    print(len(list(ET.parse(sys.argv[1]).getroot().iter('testcase'))))
except Exception:
    print(0)
PY
)"
  info "testcase elementov v reporte: $N_TC"
  if [ "$N_TC" -eq 0 ]; then
    bad "Report je prázdny (<testsuites/>) — a je to VALIDNÝ súbor."
    info "PublishTestResults@2 má failTaskOnMissingResultsFile aj failTaskOnFailedTests"
    info "defaultne FALSE. Súbor existuje → 'chýbajúci' nespadne; testy žiadne →"
    info "'padnuté' nespadne. ADO ohlási úspech nad NULOU testov."
    demote 2
  else
    ok "Report obsahuje $N_TC testcase — ADO má čo publikovať."
  fi
fi

# ---------------------------------------------------------------- T6 únik do artefaktu
hdr "T6 — Únik dát do reportu (report sa v CI publikuje ako artefakt)"
LEAK="$(python3 - "$WORK/base.json" <<'PY'
import json,sys
SENS={"authorization","cookie","set-cookie","x-api-key","api-key","proxy-authorization","x-auth-token"}
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
hits=set(); bodies=0
for it in (d if isinstance(d,list) else [d]):
    for r in it.get("results",[]) or []:
        for side in ("request","response"):
            h=(r.get(side) or {}).get("headers") or {}
            for k in h:
                if k.lower() in SENS: hits.add(k.lower())
        if (r.get("response") or {}).get("data") not in (None,"",{},[]): bodies+=1
print(",".join(sorted(hits)) + "|" + str(bodies))
PY
)"
LEAK_HDRS="${LEAK%%|*}"; LEAK_BODIES="${LEAK##*|}"
info "citlivé hlavičky v reporte: ${LEAK_HDRS:-žiadne}"
info "odpovedí s telom v reporte: ${LEAK_BODIES:-0}"
if [ -n "$LEAK_HDRS" ]; then
  hole "Report nesie hlavičky: $LEAK_HDRS — publikovaním artefaktu ich rozšíriš."
  info "Zmierni: --reporter-skip-all-headers"
  demote 3
fi
if [ "${LEAK_BODIES:-0}" -gt 0 ]; then
  info "⚠ Telá odpovedí sú v reporte. Ak prostredie NIE JE anonymizované, publikovanie"
  info "  artefaktu je šírenie tých dát. Zmierni: --reporter-skip-response-body"
fi

# ---------------------------------------------------------------- verdikt
hdr "VERDIKT"
case "$VERDICT" in
  0) printf '%sVŠETKO DOKÁZANÉ%s — brána beží, vie padnúť, a CI to uvidí.\n' "$GRN" "$OFF" ;;
  2) printf '%sBRÁNA NEVIE PADNÚŤ%s — zelená z nej nič nedokazuje. Neopieraj sa o ňu.\n' "$RED" "$OFF" ;;
  3) printf '%sDIERA%s — časť sa dokázať nedala. Vyššie je vypísané ktorá a prečo.\n' "$YEL" "$OFF" ;;
esac
exit "$VERDICT"
