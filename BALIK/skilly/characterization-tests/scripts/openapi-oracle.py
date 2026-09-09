#!/usr/bin/env python3
"""Nezávislý orákul: čo hovorí OpenAPI vs. čo robí služba.

Charakterizačný test zaznamená SÚČASNÉ správanie a potom kontroluje, či sa
nezmenilo. Je to ten istý tvar ako round-trip: **porovnáva výstup kódu s výstupom
toho istého kódu**, takže je slepý na chybu, ktorá je v oboch rovnaká. Ak služba
odpovedá zle, charakterizácia to zaznamená ako pravidlo a odteraz stráži chybu.

Aby charakterizácia niečo dokazovala, potrebuje tvrdenie, ktoré na overenie služby
tú službu NEPOUŽÍVA. Pri REST API je najlacnejší taký orákul **publikovaná OpenAPI
schéma**: vzniká nezávisle od behu a hovorí, čo má byť prijaté.

Tento skript porovná obe strany a rozdiel pomenuje:

  spec HOVORÍ platné + služba PRIJALA   -> zhoda
  spec HOVORÍ neplatné + služba ODMIETLA -> zhoda
  spec HOVORÍ platné + služba ODMIETLA   -> 🔴 ŠPECIFIKÁCIA KLAME
  spec HOVORÍ neplatné + služba PRIJALA  -> 🔴 CHÝBAJÚCA VALIDÁCIA

Úmyselne bez závislostí a úmyselne neúplný: pokrýva kľúčové slová, ktoré nesú
constraints (type, required, enum, pattern, min/maxLength, minimum/maximum).
Nie je to plný JSON Schema validátor — `$ref`, `oneOf`, `allOf` a spol. NEVYHODNOCUJE
a nahlási ich ako nepokryté, nie ako platné. Kontrola, ktorá nevie odlíšiť
"čisté" od "nepozrel som sa", musí hlásiť dieru.

Použitie:
  openapi-oracle.py <openapi.json> <SchemaName> <payload.json>
  openapi-oracle.py <openapi.json> <SchemaName> -   # payload zo stdin
"""
import json
import re
import sys

UNSUPPORTED = ("$ref", "oneOf", "anyOf", "allOf", "not",
               "additionalProperties", "patternProperties")


def check(schema, payload):
    """Vráti (chyby, nepokryté). Chyba = payload porušuje deklarovaný constraint."""
    errors, uncovered = [], []

    for kw in UNSUPPORTED:
        if kw in schema:
            uncovered.append(f"schéma používa '{kw}' — nevyhodnocujem")

    for field in schema.get("required", []):
        if field not in payload:
            errors.append(f"chýba povinné pole '{field}'")

    props = schema.get("properties", {})
    for name, value in payload.items():
        spec = props.get(name)
        if spec is None:
            uncovered.append(f"pole '{name}' schéma nepopisuje")
            continue

        for kw in UNSUPPORTED:
            if kw in spec:
                uncovered.append(f"'{name}': schéma používa '{kw}' — nevyhodnocujem")

        want = spec.get("type")
        if want == "string" and not isinstance(value, str):
            errors.append(f"'{name}': má byť string, je {type(value).__name__}")
            continue
        if want == "integer" and not isinstance(value, int):
            errors.append(f"'{name}': má byť integer, je {type(value).__name__}")
            continue

        if isinstance(value, str):
            pat = spec.get("pattern")
            # OpenAPI používa ECMA-262; \p{L} Python re nepozná -> priznaj dieru,
            # nevyhlás to za platné.
            if pat:
                try:
                    if not re.search(pat, value):
                        errors.append(f"'{name}': nevyhovuje pattern {pat!r}")
                except re.error:
                    uncovered.append(f"'{name}': pattern {pat!r} sa v Pythone nedá skompilovať")
            if "minLength" in spec and len(value) < spec["minLength"]:
                errors.append(f"'{name}': dĺžka {len(value)} < minLength {spec['minLength']}")
            if "maxLength" in spec and len(value) > spec["maxLength"]:
                errors.append(f"'{name}': dĺžka {len(value)} > maxLength {spec['maxLength']}")

        if isinstance(value, (int, float)) and not isinstance(value, bool):
            if "minimum" in spec and value < spec["minimum"]:
                errors.append(f"'{name}': {value} < minimum {spec['minimum']}")
            if "maximum" in spec and value > spec["maximum"]:
                errors.append(f"'{name}': {value} > maximum {spec['maximum']}")

        if "enum" in spec and value not in spec["enum"]:
            errors.append(f"'{name}': {value!r} nie je v enum {spec['enum']}")

    return errors, uncovered


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    spec_path, schema_name, payload_path = sys.argv[1:4]

    doc = json.load(open(spec_path))
    schemas = doc.get("components", {}).get("schemas", {})
    if schema_name not in schemas:
        print(f"Schéma '{schema_name}' v dokumente nie je. Dostupné: {sorted(schemas)[:20]}")
        return 2

    raw = sys.stdin.read() if payload_path == "-" else open(payload_path).read()
    payload = json.loads(raw)

    errors, uncovered = check(schemas[schema_name], payload)

    for u in uncovered:
        print(f"  NEPOKRYTÉ: {u}")
    if errors:
        print("ŠPECIFIKÁCIA HOVORÍ: NEPLATNÉ")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("ŠPECIFIKÁCIA HOVORÍ: PLATNÉ" + (" (s nepokrytými miestami vyššie)" if uncovered else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
