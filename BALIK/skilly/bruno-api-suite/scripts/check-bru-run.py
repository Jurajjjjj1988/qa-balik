#!/usr/bin/env python3
"""Brána nad Bruno behom: dokáž, že beh bol NETRIVIÁLNY.

`bru run` vracia nulu aj vtedy, keď netestoval nič. Namerané na
@usebruno/cli 4.1.0 tri nezávislé cesty k tichej zelenej:

  1. `--tags` s preklepom      -> totalRequests 0,  Status PASS, exit 0
  2. syntaktická chyba v .bru  -> requesty SKIPPED (len Warning), exit 0
  3. requesty bez assertov     -> beh prejde na akúkoľvek odpoveď

`PublishTestResults@2` ani jednu z nich nezachytí: failTaskOnMissingResultsFile,
failTaskOnFailedTests aj failTaskOnFailureToPublishResults sú default false,
takže prázdny <testsuites/> je preň úspech.

Tento skript volá pipeline AJ človek lokálne — rovnaký príkaz, rovnaký verdikt.
Brána, ktorá platí len v CI, sa nedá pred commitom overiť.

Použitie:
  check-bru-run.py <results.json> [--min-assertions N] [--expect-requests N]

Exit: 0 = beh bol netriviálny, 1 = brána zhadzuje build, 2 = chyba použitia.
"""
import argparse
import json
import sys


def load_summary(path):
    """Bruno píše pole iterácií; sčítaj summary cez všetky."""
    with open(path) as fh:
        data = json.load(fh)
    iterations = data if isinstance(data, list) else [data]
    agg = {}
    for it in iterations:
        for key, val in (it.get("summary") or {}).items():
            if isinstance(val, int):
                agg[key] = agg.get(key, 0) + val
    return agg


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("report")
    ap.add_argument("--min-assertions", type=int, default=1,
                    help="podlaha počtu vykonaných assertov; smie len rásť")
    ap.add_argument("--expect-requests", type=int, default=None,
                    help="presný očakávaný počet requestov, ak ho poznáš")
    args = ap.parse_args()

    try:
        s = load_summary(args.report)
    except FileNotFoundError:
        # Chýbajúci report NIE JE úspech. Rozlíš "čisté" od "nepozrel som sa".
        print(f"BRÁNA ZHADZUJE BUILD: report '{args.report}' neexistuje — "
              "beh sa buď nespustil, alebo písal inam.")
        return 1
    except (json.JSONDecodeError, OSError) as exc:
        print(f"BRÁNA ZHADZUJE BUILD: report '{args.report}' sa nedá prečítať: {exc}")
        return 1

    s_raw = s
    total = s.get("totalRequests", 0)
    skipped = s.get("skippedRequests", 0)
    failed = s.get("failedRequests", 0)
    errored = s.get("errorRequests", 0)
    asserts = s.get("totalAssertions", 0)
    failed_asserts = s.get("failedAssertions", 0)
    ran = total - skipped

    print(f"requestov={total} spustených={ran} preskočených={skipped} "
          f"padnutých={failed} chybných={errored} "
          f"assertov={asserts} (padnutých {failed_asserts})")

    problems = []

    # 🔴 OPRAVA 2026-09-07. Predtým sa `failed`, `errored` a `failed_asserts` iba PREČÍTALI
    # a VYPÍSALI, ale nikdy nepridali do `problems` — takže beh, v ktorom padol každý request
    # a každý assert, prešiel s hláškou „Brána OK". Presne tá trieda, pred ktorou tento skill
    # varuje, spáchaná jeho vlastnou bránou.
    if errored:
        problems.append(
            f"{errored} requestov skončilo CHYBOU (errorRequests). Typicky nedostupné "
            "prostredie — a `bru run` na to vie skončiť nulou.")
    if failed:
        problems.append(f"{failed} requestov PADLO (failedRequests).")
    if failed_asserts:
        problems.append(f"{failed_asserts} assertov PADLO (failedAssertions).")

    # Chýbajúci kľúč v reporte je DIERA, nie nula. `.get(kľúč, 0)` by pri premenovaní
    # v novej verzii Bruna bránu ticho OSLABIL — všetky počítadlá by boli nula a všetko by prešlo.
    expected_keys = ("totalRequests", "skippedRequests", "failedRequests",
                     "errorRequests", "totalAssertions", "failedAssertions")
    missing = [k for k in expected_keys if k not in s_raw]
    if missing:
        problems.append(
            "V summary reportu chýbajú kľúče: " + ", ".join(missing) +
            ". Nevyhodnocujem to ako nulu — je to zmena formátu reportu a brána "
            "nad ňou nemá čo tvrdiť.")

    if total == 0:
        problems.append(
            "Beh nespracoval ANI JEDEN request. Prázdna množina sa nedá zabiť — "
            "preklep v --tags, zlá cesta alebo filter, čo nič nematchuje, "
            "vyzerá v CI presne ako úspech.")
    if skipped:
        problems.append(
            f"{skipped} requestov bolo PRESKOČENÝCH. Bruno hlási chybnú syntax "
            "v .bru len ako Warning a beh napriek tomu skončí nulou.")
    if asserts < args.min_assertions:
        problems.append(
            f"Prebehlo {asserts} assertov, podlaha je {args.min_assertions}. "
            "Buď testy ubudli, alebo sa beh ticho zúžil.")
    if args.expect_requests is not None and total != args.expect_requests:
        problems.append(
            f"Čakal {args.expect_requests} requestov, beh spracoval {total}.")

    if problems:
        print("\nBRÁNA ZHADZUJE BUILD:")
        for p in problems:
            print("  -", p)
        return 1

    print("Brána OK: beh bol netriviálny.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
