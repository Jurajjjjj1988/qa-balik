#!/usr/bin/env bash
# selftest.sh — sonda nad sondou.
#
# bru-gate-probe.sh tvrdí, že rozozná funkčnú bránu od tichej zelenej.
# Toto je dôkaz, že to tvrdenie platí: pustí ju na pripravené prípady,
# ktorých správnu odpoveď poznáme, a porovná SKUTOČNÝ exit kód.
#
# Kontrola, ktorá vždy prejde, je horšia než žiadna — preto sú tu aj
# prípady, kde sonda MUSÍ povedať NIE.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Dve rozloženia: repo (tools/ vedľa fixtures/) a balík skillu (všetko v scripts/).
# Skript musí fungovať v oboch, inak sa priložená kópia nedá spustiť.
if [ -d "$HERE/fixtures" ]; then
  LAB="$HERE"; PROBE="$HERE/bru-gate-probe.sh"
else
  LAB="$(cd "$HERE/.." && pwd)"; PROBE="$LAB/tools/bru-gate-probe.sh"
fi
STUB="$LAB/fixtures/stub-api.js"
PORT=9911

RED=$'\033[31m'; GRN=$'\033[32m'; BLD=$'\033[1m'; OFF=$'\033[0m'
FAILED=0

command -v node >/dev/null || { echo "CHYBA: node nie je v PATH"; exit 1; }
[ -x "$PROBE" ] || { echo "CHYBA: $PROBE nie je spustiteľný"; exit 1; }

# Chýbajúci nástroj NIE JE zlyhanie sondy. Bez tejto kontroly by selftest
# ohlásil päť "chýb" v sonde, hoci jediný problém je nenainštalovaný Bruno —
# a falošné obvinenie je horšie než chýbajúca kontrola: pošle ťa opravovať
# niečo, čo pokazené nie je.
found_bru=""
d="$LAB"
while [ "$d" != "/" ]; do
  [ -x "$d/node_modules/.bin/bru" ] && { found_bru="$d/node_modules/.bin/bru"; break; }
  d="$(dirname "$d")"
done
# ⚠️ ZÁMERNE sa NEberie globálny bru ani PATH. T0 sondy overuje pôvod nástroja a pri
# globálnej inštalácii zníži KAŽDÝ prípad na dieru — červená by potom nehovorila o sonde,
# ale o prostredí. Jedna podmienka na jednom mieste, zhodná s tým, čo kontroluje T0.
if [ -z "$found_bru" ]; then
  cat <<MSG
PREDPOKLAD NESPLNENÝ: @usebruno/cli nie je v node_modules nad fixtures.

Selftest sa nespustil — to NIE JE nález o sonde. Globálny bru ani PATH NESTAČÍ:
T0 sondy overuje pôvod nástroja a pri globálnej inštalácii zníži každý prípad
na dieru, takže by červená hovorila o prostredí, nie o sonde.

Sprav raz, v priečinku so skriptami:

    npm init -y && npm install @usebruno/cli

MSG
  exit 4
fi
printf 'bru: %s (%s)\n\n' "$found_bru" "$("$found_bru" --version 2>&1 | head -1)"

# --- stub hore ---------------------------------------------------------------
STUB_PID=""
if curl -s --max-time 2 "http://localhost:$PORT/health" >/dev/null 2>&1; then
  echo "stub už beží na $PORT — používam ho"
else
  node "$STUB" >/dev/null 2>&1 &
  STUB_PID=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    curl -s --max-time 1 "http://localhost:$PORT/health" >/dev/null 2>&1 && break
    sleep 0.3
  done
fi
cleanup() { [ -n "$STUB_PID" ] && kill "$STUB_PID" 2>/dev/null; return 0; }
trap cleanup EXIT

curl -s --max-time 2 "http://localhost:$PORT/health" >/dev/null 2>&1 || {
  echo "CHYBA: stub na $PORT nenaskočil"; exit 1; }

# --- prípady -----------------------------------------------------------------
check() { # $1=popis  $2=očakávaný exit  $3...=argumenty sondy
  local desc="$1" want="$2"; shift 2
  local log="${TMPDIR:-/tmp}/selftest-$$-$RANDOM.log"
  "$PROBE" "$@" >"$log" 2>&1
  local got=$?
  # Keď sa očakávanie nesplní, výstup sondy je jediné, čím sa to dá diagnostikovať.
  if [ "$got" -ne "$want" ] || [ -n "${SELFTEST_DEBUG:-}" ]; then
    sed 's/^/      | /' "$log"
  fi
  rm -f "$log"
  if [ "$got" -eq "$want" ]; then
    printf '%s  OK  %s%s (exit %s)\n' "$GRN" "$OFF" "$desc" "$got"
  else
    printf '%s  ZLE %s%s — čakal exit %s, dostal %s\n' "$RED" "$OFF" "$desc" "$want" "$got"
    FAILED=$((FAILED+1))
  fi
}

printf '%sSonda musí povedať ÁNO:%s\n' "$BLD" "$OFF"
# --sandbox developer je tu ZÁMERNE: default sandbox 'safe' je v @usebruno/cli
# 4.1.0 sám nestabilný (namerané 21/75 padnutých behov vs 0/55 s developer),
# a nestabilný nástroj by z tohto prípadu spravil hod mincou. Nestabilitu
# neschovávam — je predmetom vlastného prípadu nižšie.
check "zdravá kolekcia, každý request má assert" 0 "$LAB/fixtures/good" -- --sandbox developer

printf '\n%sSonda musí povedať NIE:%s\n' "$BLD" "$OFF"
check "kolekcia bez jediného assertu → brána nevie padnúť" 2 "$LAB/fixtures/naked" -- --sandbox developer
check "preklep v --tags → beh nad prázdnou množinou"       3 "$LAB/fixtures/good" -- --sandbox developer --tags neexistujuci-tag
check "striedavo 200/503 → brána je nestabilná"            3 "$LAB/fixtures/flaky" -- --sandbox developer
# Najzákernejší prípad: chybná syntax v .bru je pre Bruno len Warning.
# Request sa PRESKOČÍ, beh skončí kódom 0 a Status hlási PASS.
check "syntaktická chyba v .bru → request ticho preskočený" 3 "$LAB/fixtures/broken" -- --sandbox developer

printf '\n%sSonda nesmie zanechať mutanta v zdroji:%s\n' "$BLD" "$OFF"
if grep -rqE '99999|GATE-PROBE' "$LAB/fixtures/" 2>/dev/null; then
  printf '%s  ZLE %szdrojová kolekcia obsahuje mutanta zo sondy\n' "$RED" "$OFF"
  FAILED=$((FAILED+1))
else
  printf '%s  OK  %szdroj je čistý, mutácia žila len v kópii\n' "$GRN" "$OFF"
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf '%sSELFTEST ZELENÝ%s — sonda rozozná funkčnú bránu od tichej zelenej.\n' "$GRN" "$OFF"
  exit 0
fi
printf '%sSELFTEST ČERVENÝ%s — %s prípadov zlyhalo. Sonde sa nedá veriť, kým to nesedí.\n' "$RED" "$OFF" "$FAILED"
exit 1
