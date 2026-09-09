---
name: characterization-tests
description: >-
  Use when putting tests around legacy code whose correct behaviour nobody knows — a system with no
  specification, whose authors have left, that is being frozen, replaced, or rewritten, and where the
  existing code IS the only specification of the replacement. Covers characterization tests (also
  called golden master, approval, snapshot, or record-and-replay tests): capturing CURRENT behaviour
  as a safety net before refactoring, and doubling that capture as the requirements document for the
  team building the new version. Triggers on "characterization test", "golden master", "approval
  test", "snapshot test", "legacy has no tests", "safety net before refactor", "legacy is the spec",
  "we're rewriting this and nobody knows what it does". Centres on the failure that makes these tests
  dangerous: they compare the code's output against the code's own recorded output, so they are blind
  to any bug that is present in both, and they silently promote existing bugs to enforced rules. Ships
  an independent-oracle script and the protocol for pairing every capture with one. Do not use for
  writing tests where the correct behaviour IS known — that is test-driven-development or write-tests.
---

# Charakterizačné testy

## Čo to je a kedy sa oplatí

Charakterizačný test zaznamená, **čo systém dnes robí** — nie čo má robiť — a odteraz stráži,
aby sa to nezmenilo nepozorovane. Termín je Feathersov (*Working Effectively with Legacy Code*);
to isté sa volá golden master, approval alebo snapshot test.

Oplatí sa presne v jednej situácii: **správne správanie nikto nepozná**, ale zmena správania by
bolela. Typicky legacy pred refaktorom, zmrazením alebo prepisom.

**Dvojitý výnos, kvôli ktorému je to lacné:** keď je legacy jedinou existujúcou špecifikáciou
novej verzie, tá istá záchranná sieť je zároveň **zadaním pre tím, čo píše náhradu**. Jedna
investícia, dva výnosy — a rieši to migračný problém, ktorý inak nemá vlastníka.

## 🔴 Trieda, kvôli ktorej je tento skill hlavne varovaním

**Charakterizačný test porovnáva výstup kódu s výstupom TOHO ISTÉHO kódu.**
Je to ten istý tvar ako round-trip: `inverzia(dopredná(x)) === x` platí aj vtedy, keď je dopredná
transformácia nesprávna — stačí, aby bola tá istá chyba v oboch smeroch.

Z toho plynú dva dôsledky, ktoré sa v praxi podceňujú:

1. **Zelený charakterizačný test nedokazuje správnosť.** Dokazuje NEZMENENOSŤ. To je iné tvrdenie.
2. **Zaznamenaním chyby ju povýšiš na pravidlo.** Odteraz ju suita chráni. Keď ju niekto opraví,
   tvoj test sčervenie a ďalší človek to „opraví" späť — lebo test predsa hovorí, že to má byť tak.

> Vždy sa pýtaj: *čo je na oboch stranách porovnania rovnaké, a teda pre tento test neviditeľné?*

### Nameraná ukážka tej slepoty

`spring-petclinic-rest`, `POST /api/owners`, pole `telephone` (merané 2026-09-01):

| telephone | OpenAPI hovorí | služba vracia | |
|---|---|---|---|
| dĺžka 1, 5, 9, 11 | PLATNÉ | **HTTP 500** | 🔴 špecifikácia klame |
| dĺžka 10 | PLATNÉ | HTTP 201 | zhoda |
| dĺžka 21 | NEPLATNÉ (`maxLength: 20`) | HTTP 400 | zhoda |

Charakterizačný test by zapísal všetkých šesť riadkov ako „správanie" a bol by úplne spokojný.
Nevidel by ani jedno z toho, čo tam v skutočnosti je:

- **špecifikácia nesedí s implementáciou** — klient vygenerovaný zo Swaggeru posiela payloady,
  ktoré služba odmieta;
- **klientská chyba sa hlási ako 500**, takže v monitoringu vyzerá ako výpadok servera a triedi
  sa ako incident;
- služba má **dve validačné vrstvy** — jedna vracia korektné 400 podľa schémy, druhá, hlbšia,
  o ktorej schéma mlčí, padá na 500.

Rozdiel odhalil až **nezávislý orákul** — publikovaná OpenAPI schéma, ktorá vzniká mimo behu.

## Nezávislý orákul: tvrdenie, ktoré na overenie nepoužíva testovanú vec

Ku každej charakterizácii patrí aspoň jeden:

- **publikovaný kontrakt** — OpenAPI/Swagger, WSDL, protobuf, DB schéma, DDL constrainty;
- **doménový/fyzikálny fakt** — súčet položiek sa rovná celku, saldo nesmie byť záporné,
  dátum ukončenia nie je pred začiatkom;
- **druhá nezávislá implementácia** — starý report vs nový, Excel od používateľa, kalkulačka;
- **autoritatívna knižnica** alebo ručne spočítaný známy prípad;
- **človek, ktorý doménu pozná** — najlacnejší orákul, ak je ešte dostupný. Zaznamenaj odpoveď
  písomne, kým neodíde.

```bash
scripts/openapi-oracle.py <openapi.json> <SchemaName> <payload.json>
```

Povie, či **špecifikácia** payload pripúšťa. Postav to vedľa toho, čo vráti **služba**, a rozdiel
pomenuj:

| spec | služba | znamená |
|---|---|---|
| platné | prijaté | zhoda |
| neplatné | odmietnuté | zhoda |
| platné | odmietnuté | 🔴 **špecifikácia klame** |
| neplatné | prijaté | 🔴 **chýbajúca validácia** |

Skript **nie je** plný JSON Schema validátor — `$ref`, `oneOf`, `allOf` a ECMA-262 pattern
s `\p{L}` nevyhodnocuje a hlási ich ako **nepokryté**, nie ako platné. Kontrola, ktorá nevie
odlíšiť „čisté" od „nepozrel som sa", musí hlásiť dieru.

## Protokol

### 1. Vyber, čo charakterizovať — podľa RIZIKA
Nie podľa pokrytia. Kandidáti: peňažná a mzdová matematika · to, čo píše do dát, ktoré prežijú
migráciu · exporty a doklady, ktoré vidí zákazník alebo úrad · to, čo sa naposledy pokazilo
v produkcii. Legacy UI, ktoré ide do koša, charakterizovať netreba.

### 2. Dokáž, že záznam vie sčervenieť
Zaznamenaný výstup, ktorý nikdy nepadol, nechráni nič. Zmeň vstup o jeden znak a over, že test
padne. Bez tohto kroku nevieš, či test vôbec pozerá na to, čo si myslíš.

### 3. Ku každému záznamu napíš, čo by bolo SPRÁVNE
Priamo v súbore s testom. Toto je celý rozdiel medzi charakterizáciou a zabetónovaním chyby:

```
# CHARAKTERIZÁCIA — zachytáva SÚČASNÉ správanie, NIE správne.
# Namerané 2026-09-01: telephone dĺžky != 10 -> HTTP 500.
# OpenAPI pritom deklaruje minLength 1, maxLength 20.
# SPRÁVNE by bolo HTTP 400 s popisom poľa.
# Keď to niekto opraví, tento test ZÁMERNE sčervenie — vtedy sa PREPÍŠE, nie zmaže.
assert { res.status: eq 500 }
```

Bez tej vety je test o rok na nerozoznanie od požiadavky — a chyba sa stane funkciou.

### 4. Nálezy hlás oddelene od testov
Rozpor nájdený pri charakterizácii je **bug report**, nie dôvod meniť test. Test drží realitu;
bug ide do tiketu. Zmiešať to znamená, že buď stratíš nález, alebo si rozbiješ sieť.

### 5. Zmena záznamu je ROZHODNUTIE, nie údržba
Keď záznam padne, sú tri možnosti a treba povedať, ktorá to je:
oprava (aktualizuj a zapíš prečo) · regresia (vráť kód) · **záznam bol od začiatku zlý**.
Hromadné „prepíš všetky snapshoty" tento rozdiel zmaže — a s ním celú hodnotu suity.

## Ako záznam robiť, aby nebol krehký

- **Normalizuj nedeterminizmus** pred porovnaním: časy, id, poradie kolekcií, UUID, cesty, hostname.
  Nezaznamenaný čas urobí test flaky; **potichu zamaskovaný** čas urobí test slepým na chybu v čase.
  Maskuj úzko a menovite, nie regexom cez celý výstup.
- **Malé, adresné záznamy** namiesto jedného obrieho snapshotu. Obrí snapshot nikto nečíta, každý
  ho pri páde prepíše — a pád jedného poľa vyzerá rovnako ako pád päťsto polí.
- **Záznam patrí do gitu a do review.** Snapshot, ktorý sa needituje cez PR, nie je test.
- **Vstupy si vyrob sám**, nespoliehaj sa na dáta v prostredí. A žiadne reálne osobné údaje —
  záznam sa commituje a tým sa šíri ďalej.

## Anti-vzory

- **Charakterizácia bez orákula.** Zapíše chybu ako pravidlo a tvári sa ako dôkaz správnosti.
- **Charakterizovať všetko.** Cena je v údržbe; hodnota je len tam, kde by zmena bolela.
- **Zaznamenať a nikdy neoveriť, že padá.** To je vanity-green v inom obale.
- **Hromadné prepísanie snapshotov po červenej.** Zmaže rozdiel medzi opravou a regresiou.
- **Charakterizovať UI, ktoré ide do koša.** Investícia do niečoho s dvojročnou životnosťou;
  charakterizuj backend, ktorý migráciu prežije.
- **Vydávať charakterizáciu za akceptačné kritérium.** Hovorí, čo systém robí — nie, čo má robiť.

## Súvisiace

`test-driven-development` (keď správne správanie POZNÁŠ) · `check-api-contract` (kontrakt vs realita)
· `gate-audit` (vie tá kontrola padnúť?) · `plan-migration` · `bruno-api-suite`

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Má každý záznam nezávislý orákul a napísanú vetu „čo by bolo SPRÁVNE" — alebo si zabetónoval súčasné správanie aj s chybou a voláš to sieťou?
