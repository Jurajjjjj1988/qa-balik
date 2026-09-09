---
name: bruno-api-suite
description: >-
  Use when Bruno (`.bru` or OpenCollection YAML collections, `bru run`, @usebruno/cli) is the API
  testing tool — putting a collection into CI, turning a hand-run collection into a real suite,
  writing or reviewing requests, wiring `bru run` into Azure DevOps / GitHub Actions with JUnit
  results, or answering "our Bruno pipeline is green, does that mean anything". Triggers on "Bruno",
  "bru run", ".bru", "bruno collection", "bruno CLI", "bruno in CI", "opencollection".
  Carries MEASURED behaviour of @usebruno/cli 4.1.0, not documentation: NINE independent ways
  `bru run` exits 0 having tested nothing — empty tag set, silently skipped files, requests with no
  assertion, an undefined exit constant from a typo in Bruno's own source, empty data files,
  `bru run .` not recursing where bare `bru run` does, `~`-disabled asserts, an unresolvable
  `vars:secret` sent as an empty string, and a silently-failing external secret manager. Also: the
  `safe` sandbox flake traced to a WASM load race that hits `assert` blocks but NOT `tests` blocks
  and gets worse the faster the API answers; `--tags` is OR despite docs saying ALL; report masking
  is name-based so a runtime-minted token lands in CI artifacts in plaintext; and `.bru` is now
  DEPRECATED — the founder conceded the DSL was a mistake and new collections default to
  OpenCollection YAML since v3.1.0. Ships a probe that points at ANY collection and proves whether
  its gate can actually fail. Do not use for Postman/Newman, or for browser/UI tests — that is
  layered-playwright-suite.
---

# Bruno ako testovacia suita (nie ako zoznam requestov)

## Prečo tento skill existuje

Tímy používajú Bruno ako **API klienta**: kolekcia requestov, ktorú niekto občas ručne prepustí.
To nie je suita, je to manuálne testovanie s krajším UI. Prechod na suitu vyzerá lacno — `bru run`
má CLI a nenulový exit kód — a **práve preto sa naň dá naletieť**: `bru run` vracia nulu aj vtedy,
keď netestoval nič.

Čísla nižšie sú troch druhov a **rozlišujem ich**, lebo plošné „všetko je namerané" by bola lož:
`ZMERANÉ` = spustil som to na tomto stroji · `PREČÍTANÉ` = zo zdrojáku alebo dokumentácie ·
`CUDZIE MERANIE` = niekto iný to nameral a ja to preberám (napr. čísla z issue trackera). Prostredie merania:
`@usebruno/cli 4.1.0`, node v20.20.2, macOS 15 arm64, lokálny HTTP cieľ. Na inej platforme,
inej verzii alebo pod záťažou CI agenta **premeraj to znova** — čísla sú z jedného stroja.

## Namerané exit kódy

| Situácia | Requestov | Status | Exit |
|---|---|---|---|
| assert prejde | n | ✓ PASS | 0 |
| assert padne | n | ✗ FAIL | **1** |
| preklep v ceste k priečinku | — | `Path not found` | **5** |
| beh mimo koreňa kolekcie | — | `You can run only at the root of a collection` | **4** |
| výstupný priečinok reportu neexistuje | — | `No such file or directory` | **4** |
| **`--tags` s preklepom** | **0** | **✓ PASS** | **0** |
| **syntaktická chyba v `.bru`** | n, všetky SKIPPED | **✓ PASS** | **0** |
| requesty bez assertov | n | ✓ PASS | 0 |

Bruno chráni proti preklepu v **ceste** (exit 5), ale nie proti preklepu v **tagu** (exit 0).
Tú asymetriu treba poznať — inak sa spoľahneš na ochranu, ktorá pokrýva len jeden z dvoch preklepov.

**`bru run` musí bežať z koreňa kolekcie** (tam, kde je `bruno.json`). Volanie
`bru run <podpriecinok>` z nadradeného adresára končí **exit 4**, a to aj s absolútnou cestou.
V CI to znamená `workingDirectory` na kolekciu, nie cestu v argumente — inak prvý beh spadne
na niečom, čo vyzerá ako chyba konfigurácie pipeline. **Reportér si výstupný priečinok
nevytvorí sám**; `mkdir -p` musí byť pred behom (tiež exit 4).

## 🔴 DEVÄŤ ciest k tichej zelenej (bolo „tri" — doplnené 2026-09-07)

Všetky merané na `@usebruno/cli` **4.1.0** (stále najnovšia, od 1. 9. nič nevyšlo), vždy s
**negatívnou kontrolou** — zámerne padajúci assert dá exit 1, takže tieto sú reálne diery, nie
pokazená sonda.

| # | Cesta | Ako to vyzerá |
| --- | --- | --- |
| 1 | preklep v `--tags` | `Requests 0`, ✓ PASS, exit 0 |
| 2 | syntaktická chyba v `.bru` | request TICHO preskočený, ✓ PASS, exit 0 |
| 3 | request bez `assert`/`tests` | **HTTP 500 sa spočíta ako „1 Passed"** |
| 4 | **preklep v zdrojáku Bruna** | `run.js:1449` volá `EXIT_STATUS.ERROR_INFINTE_LOOP` (chýba `I`) → `undefined` → `process.exit(undefined)` = **exit 0**. Poistka proti nekonečnému cyklu skončí zeleno. |
| 5 | **prázdny alebo len-hlavičkový CSV/JSON** | `iterationCount = 0` → `Requests 0`, ✓ PASS, exit 0, JUnit je doslova `<testsuites/>` |
| 6 | **`bru run .` nie je `bru run`** | holé `bru run` si vynúti `recursive = true`, explicitná cesta NIE. Merané: **4 vs 2 requesty**, oba exit 0 |
| 7 | **`~` pred assertom** | jeden znak vypne kontrolu; s `--tests-only` sa request z behu úplne stratí. Oboje ✓ PASS |
| 8 | **`vars:secret`, ktorý CLI nevie rozriešiť** | pošle sa **prázdny reťazec**, beh prejde. Nedeklarovaná `{{x}}` sa pošle doslovne (viditeľne rozbité) — **deklarovanie premennej ako tajnej mení hlučné zlyhanie na tiché** |
| 9 | **nedostupný externý secret manager** | chyba sa loguje **len pod `--verbose`** a nikdy sa nevyhodí → requesty odídu neautentizované a suita môže zostať zelená |

> **Trieda, ktorá to spája:** `bru run` skončí nenulovo **len keď je nejaké počítadlo zlyhaní > 0**.
> Nikde neoveruje, že sa vôbec niečo spustilo. Preto `totalRequests > 0` **a** `skippedRequests == 0`
> **a** `errorRequests == 0` musia byť vlastná brána nad reportom, nie viera v exit kód.

**Vyvrátené (nešír to ďalej):** preklep v operátore assertu **nie je** tichá cesta. Neznámy operátor
spadne na `{ operator: 'eq', value: '<celý reťazec>' }`, takže `res.status: equals 200` sa zmení na
`eq "equals 200"` a **padne nahlas**. `res.status: 200` bez operátora funguje (default `eq`).

## 🔴 Nestabilita `safe` sandboxu — mechanizmus, a je falzifikovaný

Predtým tu bolo len „~28 % flaky". Teraz je známa **príčina** aj **čo ju zhoršuje**:

- Zdroj (`@usebruno/js/src/sandbox/quickjs/index.js`): WASM modul sa načítava **asynchrónne**
  (`loader().then(mod => QuickJSModule = mod)`), ale `executeQuickJsVm` je **synchrónna** a nikdy naň
  nečaká. Je to **preteky**.
- Prejaví sa ako `TypeError: Cannot read properties of undefined (reading 'newContext')`, ale navonok
  ako **falošná ČERVENÁ**: `expected undefined to equal 200`. Tím to diagnostikuje ako chybu API.
- **Falzifikovateľná predpoveď, potom overená: čím RÝCHLEJŠIE API odpovedá, tým častejšie padá.**
  Tá istá kolekcia, menená len latencia odpovede: **0 ms → 5/20 pádov · 400 ms → 0/20.**
  Čiže lokálny stub a mock sú **exponovanejšie** než pomalé staging prostredie.
- ⭐ **Zasahuje cestu cez `assert` blok, NIE cez `tests` blok** — `tests { }` dalo **0/25** na tom
  istom setupe. To je najlacnejšie obídenie: **presuň kontroly z `assert` do `tests`.**
- Druhá možnosť je `--sandbox developer`, ale ⚠️ **default sa vo v3 preklopil na `safe`** — vlastný
  blog Bruna píše, že to *„will silently break CI/CD pipelines"*.

## 🔴 `.bru` je odteraz LEGACY formát

Migračná príručka Bruna doslova: *„Starting with Bruno v3.1.0, new and imported collections use
**OpenCollection YAML by default**"* a *„**A collection cannot mix `.bru` and `.yml` files.**
Migration is available in Bruno v4.1.0 and higher."* Ďalej: migrácia **zmaže pôvodné `.bru` súbory**,
a skripty volajúce `bru.runRequest()` s `.bru` cestou treba prepísať na `.yml`.
`bru import openapi` navyše generuje **YAML defaultne**.

**Zakladateľ to priznal verejne.** Diskusia #360 („Why a domain specific language?", otvorená 2023)
má dnes hore banner *„We are migrating away from .bru and moving to YAML"*, a posledný komentár od
Anoopa M D (tvorca Bruna, 6. 1. 2026) znie doslova:
> *„So after two years of lived experience, I was wrong. YAML is the answer here."*

Jeho zdôvodnenie v RFC #6634 menuje presne tú výhradu, ktorú kritici roky opakovali:
*„while a custom syntax works well for simple use cases, it quickly becomes difficult to maintain as
the schema grows… **one of the most common pieces of feedback we've received is the lack of tooling
around the existing DSL**."*

**Presnosť:** `.bru` je **deprecated, nie odstránené** — *„We will be maintaining both Bru Format and
YAML format for the foreseeable future"* (13. 7. 2026). Netreba panikáriť, treba plánovať.

**`.http` Bruno podporovať NEBUDE** — issue #1537 zavretá ako NOT_PLANNED (11. 7. 2026):
*„the schema has grown far beyond what can be reliably serialized to and deserialized from the .http
format without losing information."* Takže cesta von z Bruna nevedie cez `.http`.

⚠️ **A náhradný formát je „otvorený štandard" len na papieri:** repo `opencollection-dev/opencollection`
má **všetkých top prispievateľov z Bruna** (`helloanoop`, `sachin-bruno`, `sundram-bruno`, …) a v koreni
**nemá LICENSE súbor** (sub-balík `@opencollection/converters` MIT má). Migračné nástroje boli
v dokumentácii vedené ako *„planned for a future release"* s odporúčaním konvertovať ručne.

**Dôsledok:** čokoľvek postavené nad `.bru` (linter, generátor, konvencia, tento skill) potrebuje
YAML vetvu a povedaný dátum, odkedy platí. Nové kolekcie u nich už `.bru` nebudú.

**Jedna dobrá správa proti argumentu o zamknutí:** `@usebruno/lang` je **MIT** a publikovaný na npm
(v0.39.0, 1. 9. 2026), takže `.bru` sa dá parsovať aj mimo Bruna. Konverzia von existuje
(`kulala-fmt` → `.http`), ale jej údržbár upozorňuje, že **pri konverzii sa strácajú tajomstvá**
a že zmena formátu mu konverziu rozbila.

## 🔴 Tajomstvá: maskovanie je dieravé a v divočine to uniká

- Maskuje sa podľa **mena hlavičky** (19-položkový zoznam: `authorization`, `x-api-key`, `cookie`, …)
  alebo podľa **známej hodnoty**. Token, ktorý si suita **vyrobí prihlásením za behu**, nie je ani
  v jednom z tých dvoch — merané: `Authorization: Bearer ********`, ale `X-Custom-Auth` s tým **istým**
  tokenom **plaintextom**, a telo login odpovede tiež plaintextom.
- `--reporter-skip-body --reporter-skip-all-headers` funguje (overené), ale **URL sa nestriháva nikdy**
  → token v query stringu prežije.
- V divočine: **7 336 `.bru` súborov na GitHube obsahuje `eyJ`** (prefix JWT). Konkrétny prípad:
  verejné repo commitlo **živý RS256 JWT** v obyčajnom `vars {}` bloku, s expiráciou v budúcnosti.
- ⚠️ **Otvorená bezpečnostná issue #8230**: čítanie ľubovoľného lokálneho súboru a jeho exfiltrácia
  cez path traversal v `body:file` — **v defaultnom sandboxe**.

## ⭐ Čo skopírovať z divočiny (a čo nie)

Prieskum 141 reálnych GitHub Actions workflowov, ktoré púšťajú `bru run`:

**Kopíruj — post-run brána nad JSON reportom.** Repo `sydlexius/stillwater` má samostatný krok
„Gate on transport health": prečíta `--reporter-json` a **padne, ak report chýba, ak
`totalRequests == 0`, alebo ak `errorRequests != 0`** — s komentárom, prečo: *„against the (rare) case
where every request hits a connection failure but Bruno still exits 0"*. Plus `set -o pipefail`
a `timeout`.

**Kopíruj — nezávislý orákul.** Repo `elmohq/elmo` validuje **každú zaznamenanú odpoveď** proti
OpenAPI schéme cez Ajv, s `unevaluatedProperties: false`, ako **samostatný CI krok**. Bruno kontroluje
správanie, schéma kontroluje tvar — dva rôzne zdroje pravdy, takže sa chyba v jednom nevykráti.

**Kopíruj — fail-closed prihlásenie.** `collection.bru` pre-request, ktorý `throw`-ne, keď chýba
API kľúč. Inak dostaneš suitu zelenkavých 401.

**Kopíruj — presné pinovanie.** `"@usebruno/cli": "4.0.0"` bez `^`, alebo `npm ci` s commitnutým
lockfilom. ⚠️ **129 zo 141 workflowov inštaluje `npm install -g` bez verzie** — vrátane vlastného
ADO dema od dodávateľa. Pri regresii pamäte (#8137: 300 MB → **1,4 GB** medzi 3.3.0 a 3.4.2) a pri
preklopení sandbox defaultu je plávajúca verzia živé riziko.

**Neveir kroku, ktorý si nečítal.** Namerané v tých 141 workflowoch: **39×** `|| true`, **15×**
`continue-on-error`, dve repá majú Bruno krok **úplne zakomentovaný** — a v súbore to stále vyzerá
ako brána.

**Neasertuj len `res.status: in [200, 201]`.** Jedno repo má 2 084 vygenerovaných súborov a **každý**
nesie presne tento jediný assert. Prežije skoro každú regresiu.

## Pôvodné tri cesty — detail a reprodukcia


Každá vyrobí `exit 0` a `Status ✓ PASS` bez toho, aby čokoľvek otestovala. Zvonku sa nedajú
odlíšiť od úspechu.

1. **Prázdna množina.** `bru run --tags smoke-typo` → `totalRequests: 0`, PASS, exit 0.
   Nula meraní nie je nulová chyba.
2. **Ticho preskočené súbory.** Chybná syntax v jednom `.bru` (napr. `#` komentár na najvyššej
   úrovni — Bruno komentáre nemá, dokumentácia patrí do bloku `docs { }`) → `Warning: Skipping
   invalid file`, `skippedRequests` rastie, exit 0. Namerané: jeden pokazený súbor odstavil
   **všetkých 5** requestov kolekcie, `totalRequests: 5, skippedRequests: 5, passedRequests: 0`,
   Status PASS, **exit 0**.
   → **`totalRequests > 0` ako brána NESTAČÍ.** Requesty „boli", len ani jeden nebežal.
3. **Requesty bez kontroly.** `.bru` bez bloku `assert` ani `tests` prejde na akúkoľvek odpoveď.
   V kolekciách používaných ako API klient je to väčšina súborov.

## 🔴 Reťazec do Azure DevOps — obe vrstvy mlčia naraz

1. beh nad prázdnou množinou → exit 0 *(namerané)*
2. JUnit report je `<testsuites/>` — **validný, existujúci** súbor *(namerané)*
3. `PublishTestResults@2` má `failTaskOnFailedTests`, `failTaskOnMissingResultsFile` aj
   `failTaskOnFailureToPublishResults` **default `false`** *(dokumentácia Microsoftu)*
4. → súbor existuje, takže „chýbajúci" nespadne; testy žiadne, takže „padnuté" nespadne
   → **pipeline zelená nad nulou testov**

Vždy nastav všetky tri na `true`. Aj tak to nestačí — prázdny report je pre task korektný vstup,
takže nad ním musí byť **vlastná brána na počty**.

## 🔴 Default sandbox je nestabilný

| sandbox | zlyhaní |
|---|---|
| `safe` (default) | **21 / 75** (~28 %) |
| `--sandbox developer` | **0 / 55** |

Chyba: `Error executing the script! TypeError: Cannot read properties of undefined (reading 'newContext')`
na **nezmenenej** kolekcii proti lokálnemu cieľu — teda ani sieť, ani API.

⚠️ **Najprv zisti, kto tú hlášku vypísal.** `newContext()` je aj kanonické **Playwright** API
(`browser.newContext()`), takže ak v tom istom jobe beží UI suita, dostaneš **identický text**
z úplne iného procesu. Rozlišovací znak je prefix **`Error executing the script!`** — ten pochádza
z Bruna. Bez neho hľadaj Playwright krok a tento oddiel zahoď.

Flaky brána je pokazená brána: tím sa naučí červenú odklikávať a prehliadne aj tú pravú.
A pri prvom zavedení CI je náhodná červená politicky drahšia než žiadne CI — potvrdí každému,
kto bol proti, že „tie testy aj tak nefungujú".

→ Pridaj `--sandbox developer` a **premeraj na svojom agentovi** (aspoň 40 behov, spočítaj zlyhania).

## 🔴 Report je nádoba na dáta

JSON report obsahuje **request headers** (teda `Authorization`, `Cookie`, `X-API-Key`) a **celé telá
odpovedí**. V CI sa publikuje ako artefakt — čím sa obsah šíri ďalej, aj po zmazaní zdroja.

```
--reporter-skip-all-headers      # hlavičky preč
--reporter-skip-request-body     # telo requestu preč
--reporter-skip-response-body    # telo odpovede preč
```

Ak prostredie **nie je** anonymizované, toto nie je kozmetika ale povinnosť — a v regulovanom
prostredí to býva viazané ohlasovacou lehotou. Zisti pravidlo skôr, než prvý report publikuješ.

## Ako na to prakticky

### Prvý deň s cudzou kolekciou — sonduj, nestavaj

```bash
tools/bru-gate-probe.sh <kolekcia> -- <presne tie argumenty, ktoré má bežať v CI>
```

Sonda beží **na kópii**, zdroj nikdy nemení. Vráti:
`0` dokázané · `2` **brána nevie padnúť** · `3` diera (nedalo sa pozrieť).

Odpovie na to, čo `bru run` nepovie: koľko z requestov má vôbec kontrolu, koľko sa ich naozaj
spustilo, či beh dáva opakovane ten istý výsledok, či brána sčervenie na vloženej poruche,
a čo z toho uvidí CI.

### Inštalácia patrí do repa, nie do `-g`

```bash
npm install --save-dev @usebruno/cli    # verzia v package-lock.json
```

`npm install -g` stiahne najnovšiu verziu v deň behu — pipeline sa tak zmení bez commitu.
A `npx bru` mimo repa siahne po balíku z npx cache, ktorý s tým projektom nemá nič spoločné.
Vždy over, že bežal binárny súbor z `node_modules` toho repa.

### Reportéry: obe syntaxe platia

V 4.1.0 existujú paralelne — nie je to nezhoda v dokumentácii:
```bash
bru run -r --reporter-junit out.xml --reporter-json out.json
bru run -r --format junit --output out.xml
```

### Tvar `.bru`, ktorý sa dá testovať

```
meta { name: 10-create-owner
       type: http
       seq: 2 }

post { url: {{baseUrl}}/api/owners
       body: json }

body:json { { "firstName": "Skeleton", "telephone": "5550100999" } }

assert {
  res.status: eq 201
  res.body.id: isNumber
}

vars:post-response {
  ownerId: res.body.id
}

docs {
  Komentár patrí sem. `#` na najvyššej úrovni je syntaktická chyba
  a Bruno ju hlási len ako Warning — request sa ticho preskočí.
}
```

- **Dáta si test vyrobí sám** cez API a po sebe upratuje (`DELETE` na konci). Spoliehať sa, že
  dáta v prostredí „sú", je najčastejší dôvod flaky testov.
- **Reťazenie cez `vars:post-response`**, nie cez natvrdo zapísané id.
- **Žiadne reálne osobné údaje** v `body:json`.

### Brána nad behom — povinná

```bash
tools/check-bru-run.py reports/results.json --min-assertions 10
```

Kontroluje `totalRequests > 0`, `skippedRequests == 0` a podlahu počtu vykonaných assertov.
Podlaha smie **len rásť**. Púšťaj ten istý príkaz lokálne aj v CI — brána, ktorá platí len v CI,
sa pred commitom nedá overiť.

## Čo je charakterizačný test (a kedy je namieste)

Keď je legacy jediná existujúca špecifikácia, zachytávaj **súčasné** správanie, nie správne —
a povedz to nahlas priamo v súbore. Nameraný príklad zo `spring-petclinic-rest`:

`telephone` dĺžky 1, 5, 9, 11, 15 → **HTTP 500**; dĺžky presne 10 → **201**.
OpenAPI pritom deklaruje `minLength: 1, maxLength: 20, ^[0-9]*$`.

Dve chyby naraz: **špecifikácia nesedí s implementáciou** (klient vygenerovaný zo Swaggeru posiela
payloady, ktoré služba odmieta) a **klientská chyba sa hlási ako 500**, takže v monitoringu vyzerá
ako výpadok servera a triedi sa ako incident.

Charakterizačný test na to asserta `500` **s poznámkou, že správne je 400**. Keď to niekto opraví,
test zámerne sčervenie — to je jeho účel: zmena správania sa nesmie stať ticho. Vtedy sa prepíše,
nie zmaže.

⚠️ Charakterizačný test **fixuje chybu ako keby bola pravidlo**. Sám o sebe nedokazuje správnosť —
je to poistka proti tichej zmene, nie orákulum. Ku každému patrí veta, čo by bolo správne.

## Anti-vzory

- **„Pipeline je zelená" ako dôkaz.** Kým si nevidel túto konkrétnu bránu sčervenieť, nevieš nič.
- **`|| true` na kroku brány.** Buď smie zhodiť build, alebo to nie je brána.
- **`npm install -g @usebruno/cli` v pipeline.** Nepripnutá verzia = pipeline sa mení bez commitu.
- **`totalRequests > 0` ako jediná kontrola.** Preskočené requesty sa počítajú tiež.
- **Publikovanie reportu bez `--reporter-skip-*`** z neanonymizovaného prostredia.
- **Prepisovanie cudzích kolekcií na začiatku.** `bru run` ich pustí bez zmeny — to je tá lacná
  prvá výhra. Prepisovať začni až tam, kde sonda ukázala dieru.

## Skripty

- `scripts/bru-gate-probe.sh` — namieri na ľubovoľnú kolekciu a dokáže, či jej brána vie padnúť.
- `scripts/check-bru-run.py` — brána nad behom pre CI aj lokál.
- `scripts/selftest.sh` — dôkaz, že sonda hryzie: prípady, kde MUSÍ povedať nie.

### Ako selftest spustiť (jednorazová príprava)
```bash
cd <cesta>/bruno-api-suite/scripts
npm init -y && npm install @usebruno/cli      # bru MUSÍ byť tu, nie globálne
bash selftest.sh                              # čakaj: SELFTEST ZELENÝ, 6/6
```
⚠️ **Globálny `bru` ani `PATH` nestačí, a je to zámer.** T0 sondy overuje pôvod nástroja a pri
globálnej inštalácii zníži verdikt na dieru — takže by sčervenel každý prípad a červená by
nehovorila o sonde, ale o prostredí. Bez tej prípravy selftest skončí kódom **4** a povie prečo.

**Overené 2026-09-07:** `@usebruno/cli` je stále **4.1.0** (od merania 1. 9. nevyšla ani jedna
novšia verzia), selftest po správnej príprave **6/6 zelený**, sonda nad zdravou kolekciou prejde
T0–T5 vrátane červenej sondy (vložená porucha → exit 1 → po odstránení zase 0).

## 🔴 v3 preklopil DEFAULT na ten sandbox, ktorý je nestabilný

Doplnené 2026-09-07. Blog *„Bruno v2 → v3: Breaking Changes"* (7. 1. 2026) doslova:
*„The Bruno CLI now defaults to **Safe Mode** (`--sandbox=safe`) for script execution, rather than
Developer Mode."*

**Prečo to mení váhu merania vyššie:** nestabilita, ktorú tento skill nameral pod `safe`
(21/75 padnutých behov vs 0/55 pod `developer`), **už nie je vec, do ktorej sa treba dostať —
je to východzí stav.** `--sandbox developer` teda nie je optimalizácia, ale vedomé vystúpenie
z defaultu, a treba to v CI napísať explicitne.

Safe Mode je QuickJS skompilovaný do WASM: *„cannot access the filesystem, cannot execute system
commands"* a **npm balíky nie sú dostupné**. Otvorená nekompatibilita: issue #5156 — novší
`crypto-js` stojí na API, ktoré QuickJS nemá. Ak sa v skriptoch podpisuje alebo hashuje, over to.

**Druhá breaking zmena v3, ktorá ticho zmení význam suity:** skripty sa už **nezreťazujú do jedného
bloku** — každý beží vo vlastnom async IIFE, takže premenné medzi collection/folder/request skriptami
**už nepretekajú**. Kód, ktorý sa na to spoliehal, nespadne — len začne pracovať s `undefined`.
Prenos hodnôt musí ísť cez `bru.setVar()` / `bru.getVar()`.

**Pôvod sandboxu (kontext, prečo to nie je len otravné):** Bruno bežal na `vm2`, ktorý bol v júli 2023
opustený kvôli neopraviteľným únikom z izolácie. Náhrada QuickJS/WASM prišla v 1.26.0.

## 🔴 Paralelizmus v CLI je slabina — a má číslo

Issue **#8638** (otvorená 15. 7. 2026, **stále otvorená**), namerané používateľom:
tri priečinky cez `bru run` = **~70 s**, tie isté tri ako samostatné procesy na pozadí v shelli
(`&` + `wait`) = **~30 s**. A dôvod: *„`--parallel` appears to parallelize requests/iterations
within a single run rather than distributing execution across the folder arguments."*

Čiže **`--parallel` neparalelizuje to, čo CI potrebuje paralelizovať** (priečinky/súbory), ale
iterácie vnútri jedného behu. V CI to je ~2,3× dlhší wall-clock oproti obyčajnému for-cyklu v shelli.

⚠️ A pozor na súvisiacu pascu z #3296: 3 requesty × 1000 riadkov CSV alokovalo **všetkých 3000
iterácií naraz** — *„over 5GB of memory"* a *„3000 ports"*.

**Dokumentácia si v tomto protirečí** (trieda „dva zoznamy, ktoré sa rozídu"): `docs.usebruno.com`
`--parallel` popisuje aj s príkladom, kým plná referencia flagov na druhom doc mirrori ho
**neuvádza vôbec** — rovnako ako `--iteration-count` a `--csv-file-path`. Ak staviaš bránu na
`--parallel`, **over jeho správanie spustením**, nie čítaním.

## Kedy Bruno NIE JE správna voľba

Nie je to odporúčanie odísť — je to zoznam vecí, ktoré Bruno nemá, aby sa nesľubovali.

| Potreba | Bruno | Kto to má |
| --- | --- | --- |
| paralelizmus na úrovni súboru v CI | ❌ (#8638) | **Hurl** — *„Each Hurl file is executed in its own worker thread"*, a v `--test` móde je paralelný **defaultne** (od 5.0.0) |
| assert na TLS certifikát, `sha256`/`md5`, byte-exact telo, XPath | ❌ nedokumentované | **Hurl** — a to je presne tvar nezávislého orákula |
| validácia celej vnorenej odpovede jedným výrazom (tvar + typy + voliteľnosť) | ❌ (N samostatných assertov, ktoré sa dajú zabudnúť) | **Karate** — `match` s fuzzy matchermi (`#string`, `#uuid`, `#[3]`, `##string`) |
| tie isté testy ako záťažové | ❌ | **Karate** + `karate-gatling` (⚠️ default ~30 RPS, `throttle` nepodporovaný) |
| mock/stub server z tej istej definície | ❌ | **Karate** (HTTP/gRPC/MQ) |
| **JSON Schema ako prvotriedny assert** | ✅ `jsonSchema` (Ajv) | ❌ Hurl nemá ekvivalent |
| gRPC / WebSocket / GraphQL | ✅ (gRPC od 2.10.0) | ❌ Hurl je len HTTP |
| GUI pre netechnických členov tímu | ✅ | ❌ ani jeden z tých dvoch |

Hurl **nemá skriptovanie a nebude ho mať** — údržbár: *„Because it's hard, and it opens security
issue, we don't want to do this now."* To je stanovisko, nie backlog.

## MCP — stav k 2026-09-07 (pýtali sa; odpoveď je „ešte nie")

**Oficiálny Bruno MCP server NEEXISTUJE.** `usebruno/bruno-mcp` v oficiálnej organizácii je
**prázdne repo** — jeden commit („add: readme"), veľkosť 0, iba `README.md`, žiadny kód, žiadna
licencia. Na npm nie je ani `@usebruno/mcp`, ani `@usebruno/bruno-mcp`. Údržbár v issue #4806
(2026-09-01): *„MCP support is actively being built. **Before we lock the tool surface** …"* —
tvar nástrojov ešte nie je uzavretý.

**Všetkých päť komunitných serverov je opustených** (najlepší má 44 hviezd, žiadnu licenciu a
posledný commit spred ~13 mesiacov). Postaviť na nich prácu teraz znamená prepisovať ju neskôr.

**Copilot a MCP:** funguje **len v agent móde** (VS Code 1.99+, GA v 1.102), v ask/edit móde sa
nástroje neobjavia — a vyzerá to ako pokazený setup. Pre Copilot **Business/Enterprise** existuje
politika *„MCP servers in Copilot"*, ktorá je **defaultne VYPNUTÁ**, plus druhá
*„Restrict MCP access to registry servers"*. **Overiť politiku PRED akýmkoľvek pilotom** — inak
sa ladí konfigurácia, ktorá sa nemala ako načítať.

> Zhrnutie pre tím: **nie je čo adoptovať.** A urgentný problém aj tak nie je MCP — je to to,
> že `bru run` vie ohlásiť úspech bez toho, aby čokoľvek otestoval. Kým to beží ručne, chráni vás
> človek, ktorý číta výstup. V CI ten človek zmizne.

## Súvisiace

`gate-audit` (brána vs kód) · `check-api-contract` (OpenAPI vs implementácia) ·
`real-testing-patterns` (chytajú testy chyby?) · `layered-playwright-suite` (UI vrstva)

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Dokázal si sondou, že táto kolekcia vie sčervenieť, a sedí počet REÁLNE spustených a assertovaných requestov s tým, čo si čakal?
