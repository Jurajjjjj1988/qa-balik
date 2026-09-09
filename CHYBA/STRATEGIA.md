# Testovacia stratégia — fázy a poradie

> **Čísla v tomto súbore zámerne nie sú.** Sú v `~/Cat-knowledge/measurements/`
> na tomto stroji. Keď potrebuješ číslo, **prečítaj ho odtiaľ** — nikdy si ho nepamätaj
> a nikdy ho neodhaduj. Ak tam nie je, zmeraj ho a ulož.

---

## Fáza 0 — SPÚŠŤAČ, nie testy *(prvý týždeň)*

**Prvý merateľný výstup nie je test.** Je to doložený beh, v ktorom
**pull request neprešiel, lebo test sčervenel.**

Dôvod: testy, ktoré nikto nespúšťa, sú do troch mesiacov mŕtve.

### 🔴 Vec, ktorú musíš vedieť skôr, než pošleš prvý PR

Testovací krok je vo všetkých repozitároch **už zapojený do buildu**. Nespúšťa nič,
lebo testovacie zdroje neexistujú. **Prvý commit s testom mu ich dá** — a tým sa
z neexistujúcej brány stane brána, ktorá môže zastaviť nasadenie.

**Nikde to nebude vidieť ako diff.** Reviewer schváli „add unit tests" — vecne správne.

> Zavedenie brány je **organizačný akt**. Nesmie sa spraviť potichu.

**PR s prvým testom to musí povedať v názve aj v popise.**

### Poradie — tri kroky, nie jeden

| | kde testy bežia | červená znamená |
| --- | --- | --- |
| **0a** | samostatná pipeline vo vlastnom repozitári | spätná väzba, **nikoho neblokuje** |
| **0b** | povinná kontrola na pull requeste | blokuje zlúčenie |
| **0c** | testy v repozitári služby | **môže zastaviť nasadenie** |

**0c sa nerobí, kým 0a nebeží a 0b nie je odsúhlasené.**

### Brána musí vedieť povedať DIERA

- rešpektuje exit kód — **žiadne `|| true`, žiadne `-i` / `--continue`**
- **nula nájdených výsledkových XML → exit 3 = DIERA**, nie PASS
- počet vykonaných testov porovnaj s podlahou; **podlaha smie len rásť**
- **musí odlíšiť pád testu od pádu statického analyzátora v tom istom kroku**

### Tri sondy — bez nich brána neexistuje

| | očakávanie |
| --- | --- |
| **P1** triviálny PR | zelená, a v behu **nie je žiadny deployment job** |
| **P2** obrátený assert | **zlúčenie zablokované** |
| **P3** zmazaný testovací súbor | **červená z podlahy** |

**P3 je tá rozhodujúca.** Brána, ktorú si nevidel padnúť, nie je brána.

### Prežitie po odchode

Odkaz na beh je URL, ktoré **hnije**. Preto týždenná naplánovaná pipeline:
1. **meta-test** — pusti bránu nad dvoma commitnutými fixtúrami:
   zdravá → `exit 0`, s vymazanými testami → `exit ≠ 0`
2. **obojsmerná kontrola**, že každý repozitár zo zoznamu má povinnú kontrolu —
   a že neexistuje kontrola bez záznamu v zozname

---

## Fáza 1 — unit testy bez náhrad *(týždne 2–4)*

**Rozsah zásoby si prečítaj z `~/Cat-knowledge/measurements/` — nepamätaj si ho a neodhaduj.**
Sú tam tri čísla: koľko je verejných metód, koľko z nich nevolá nič vonku, a koľko je
v nich rozhodovacích vetiev. ⚠️ Je to počet **kandidátov podľa pravidla**, nie hotových
testov — ver poradiu, nie presnému číslu.

Zásoba: verejné metódy, ktoré **nevolajú nič vonku**. Nepotrebuje prostredie ani prístupy.

### Výber

**„Bez závislostí" je filter TESTOVATEĽNOSTI, nie rizika.**
Zoraď: **skóre = vetvy × riziko / náklad**, kde riziko obsahuje aj
**churn zo `git log`** — *mená klamú, história nie*.

**Pracuj po TRIEDACH, nie po metódach** — príprava vstupu sa amortizuje.

### Zoznam práce sa GENERUJE, nie udržiava

Ručný zoznam je deň po odchode autora zamrznutý. Skript commitni a generuj v pipeline,
s **obojsmernou** kontrolou:
- riadok, ktorého metóda už neexistuje → **červená**
- metóda bez závislostí, ktorá v zozname nie je → **červená**
- riadok `DONE` bez testu v zdrojáku → **červená**
- **prázdny výstup → DIERA, nie PASS**

### Orákul — štvorstupňový rebrík

| | zdroj pravdy |
| --- | --- |
| 1 | ručne spočítaný literál |
| 2 | autorita JDK alebo knižnice |
| 3 | metamorfný vzťah |
| 4 | charakterizácia *(záznam dnešného správania)* |

**Používaj JEDEN zoznam značiek** — `@Tag("spec")` alebo `@Tag("char")`.
`char` **musí** mať riadok `ORAKUL:`.
⚠️ Dva rôzne zoznamy značiek sa vždy rozídu a skener potom skontroluje **prázdnu množinu**.

### Priznaj cenu

Sú to prevažne formátovače, validátory a mapre. **Pokryje sa veľa kódu a málo rizika.**
Peňažná logika sem nespadá, lebo tie metódy závislosti majú.
→ Do reportu patrí riadok **„riziková plocha, ktorej sa suita dotkla: 0 %"** — kým to tak je.

---

## Fáza 2 — API testy *(týždne 3–6, súbežne)*

### Suita žije vo VLASTNOM repozitári

Kritérium: **väzba na ZDROJ vs väzba na NASADENIE.**
Unit testy sú viazané na zdroj → patria k službe. API testy sú viazané na nasadenie
→ vlastný repozitár + vlastná spúšťacia pipeline.

### Prístup do QA — prvý krok, 20 minút

Commitni `access.yaml`: `principal_kind` *(osobný / servisný)* · vlastník na strane klienta ·
dátum expirácie. A **`preflight` ako prvý stage**, na ktorom suita visí cez `dependsOn`.
**Placeholder alebo prázdne pole = DIERA, nie PASS.**

*Bez toho suita zomrie v deň, keď odíde človek, na koho účet je viazaná.*

### Runner beží na ALLOWLIST, nikdy na blocklist

Endpoint, ktorý **nie je výslovne povolený, sa nezavolá.**
❌ Blocklist na regex názvu chytí `SendReport` a **nechytí `ProcessQueue`, ktorý posiela e-maily.**

**Sonda:** lokálny listener, ktorý dokáže, že **sa nič neodoslalo**.

### Klasifikácia má ŠTYRI stavy

`BEZPEČNÝ` / `MENÍ STAV` / `UNKNOWN` / **`ÚČINOK ASYNCHRÓNNY`**

- **`UNKNOWN` je viditeľné číslo, nie ticho.** Endpoint bez záznamu **nie je bezpečný.**
- Pri **asynchrónnom** účinku je `2xx` dôkaz o **PRIJATÍ**, nie o účinku.
  *„Ešte nedošlo"* je nerozlíšiteľné od *„nestalo sa"*.
  → povolené sú len tvrdenia s **ohraničeným pollovaním do dohodnutého SLA**
  nad **druhým pozorovacím bodom**. Bez SLA sa negatívny test nedá napísať.

### 🔴 Stavový kód NIE JE spoľahlivý orákul

V tomto kóde je veľa miest, kde `catch` vráti náhradnú hodnotu.
**Chyba sa neprejaví ako 5xx — prejaví sa ako `200` s prázdnym telom.**

Platné tvrdenia namiesto toho:
- **efekt sa naozaj stal** — overený na **druhom pozorovacom bode**
- **chybová cesta vráti chybu, nie prázdno**
- rovnaký request dvakrát dá rovnakú odpoveď *(idempotencia)*
- neautorizovaný prístup je odmietnutý

### Testovacie dáta nie sú naše

Databáza je **kópia**; pravda žije v systémoch tretích strán a vracia sa dávkovým synchronizačným
behom. Stav, ktorý test použije ako predpoklad, môže **cez noc prepísať niekto mimo nášho dosahu**.

A druhý mechanizmus: **zápisové cesty nad zdieľanou testovacou personou** si prepisujú
navzájom **moje vlastné paralelné testy**.

→ Veď si **zoznam zdieľaných mutovateľných entít** a nad nimi bež **sériovo alebo pod vlastnou identitou.**

---

## Fáza 3 — jednoduché náhrady

**Kritérium „nerozbije sa" = kto vlastní tú hranicu:**

| hranica | náhrada |
| --- | --- |
| externý dodávateľ | ✅ **prijateľná** |
| susedný tím | ❌ rozbije sa pri ich premenovaní |
| vnútro vlastnej triedy | ❌❌ zamrazí implementáciu |

⚠️ **Pred fázou 3 over jednu vec:** volá tá služba dodávateľov **sama**,
alebo len **preposiela ďalej**? Ak preposiela, môže ísť o systém, ktorý sa nahrádza —
a potom je celá fáza investíciou do kódu, ktorý sa vypína.

---

## Fáza 4 — kritické cesty

**Autorizácia** — sonda na endpoint: viac identít × vlastný / cudzí objekt.

**Vstupná podmienka celého riadku je POZITÍVNA KONTROLA:** ak sonda nevie potvrdiť
prípad, kde autorizácia **preukázateľne funguje**, riadok sa **nemeria**.
*Bez toho si vyrobíš vlastnú tichú zelenú.*

**Antivzory, ktoré zabijú výsledok:**
- assertovať len stavový kód
- považovať `400`/`422` za „odmietnuté" — **validácia bežala PRED autorizáciou**
- testovať na neexistujúcom ID — **`404` zamaskuje chýbajúcu kontrolu**

**Výstup je trojstavový so súčtovým invariantom:**
odmietnuté + prešlo + **nezmerané** = celkový počet.
Endpoint bez dát sa **musí objaviť**. Chýbajúci ≠ 0 %.

**Peniaze** — bez doménového orákula sa dá tvrdiť len invariant:
súčet položiek = celok · žiadna suma nie je záporná · determinizmus ·
konzistentné zaokrúhlenie · **peňažné pole nie je `double`**.

⚠️ **Skôr než sa služba stane cieľom, over, či sa vôbec nasadzuje.**


---

# Doplnené z overených postupov

### Sonda musí ležať tam, kam runner naozaj siaha

**Prvá sonda je zároveň prvým testom v estate — nemáš teda vzor, ku ktorému ju priložiť.** O to viac platí, že jej zber musíš **dokázať z výstupu behu, nie z konfigurácie**: po spustení nájdi jej meno vo výpise, výsledkové XML v `build/test-results/test/` a preloženú triedu v `build/classes/java/test/`. To isté pri kompilácii — **over počet preložených testovacích tried, nie vetu v `build.gradle`**. Sonda v adresári, ktorý runner nezbiera, spraví z funkčnej brány **falošné obvinenie**; to je horšie než chýbajúca kontrola, lebo po druhom takom začneš celú sekciu preskakovať.

*Prečo tu: V estate sú dve @Test metódy na 22 repozitárov, takže nikde nevieš zo skúsenosti, kam Gradle sourceSet a testovací task naozaj dosiahnu. Prvá sonda bude zároveň prvým testom.*

**Každá sonda potrebuje TRI behy, nie jeden.** Ten istý súbor: (1) prechádzajúci assert → zelená,
(2) obrátený assert → červená, (3) späť prechádzajúci → zelená. Bez tretieho behu neodlíšiš bránu
od farby, ktorá sleduje POČET BEHOV (Gradle cache, `UP-TO-DATE` task, zámok) — pred každým behom
cache vyčisti.
**Červená musí v logu MENOVAŤ súbor sondy.** Krok tu spája statickú analýzu s testami, takže červená
bez mena sondy je DIERA, nie PASS — rovnako červená, ktorá prišla len z toho, že súbor existuje.

*Prečo tu: Fáza 0 má tri sondy P1–P3, ale každá je jedna červená. Krok v týchto repozitároch spája statickú analýzu s testami, takže červená bez menovania sondy nehovorí nič o tom, či brána vidí padajúci test.*


---

# Doplnené — druhé kolo

**Prielom dokazuje identifikujúce pole, nie stavový kód.** Za „prešlo" rátaj len odpoveď, v ktorej **vidíš pole patriace cudzej identite** (id vlastníka, číslo zmluvy, meno).
To pole si najprv pomenuj tak, že **necháš objekt prečítať jeho vlastníka** a zapíšeš si jeho odpoveď — bez tejto referencie nevieš, čo tam malo byť, a nemáš čo porovnať.
⚠️ Pole musí niesť hodnotu, ktorú **tvoja identita nemá kde vidieť**. Ak je rovnaká u oboch, nedokazuje nič.
`200` s prázdnym telom **aj** `200` s prázdnym zoznamom patria do stavu **NEZMERANÉ**, nikdy do „odmietnuté" — mohol to odfiltrovať dotaz alebo prehltnutý `catch`, nie kontrola oprávnení.

*Prečo tu: 403 zo 417 endpointov nemá kontrolu na vstupnom bode a 296 miest vracia z `catch` náhradnú hodnotu — bez identifikujúceho poľa je „prešlo" len iný názov pre „nemeral som".*

### `200` s prázdnym telom v autorizačnej sonde patrí do stĺpca NEZMERANÉ

- Prázdna odpoveď hovorí naraz tri veci: **kontrola zamietla · `catch` vrátil náhradu · objekt neexistuje.** Nezapisuj ju do „odmietnuté" ani do „prešlo".
- Rozlíšiš ju jediným spôsobom: tá istá cesta **pod vlastníkom objektu musí vrátiť NEPRÁZDNE telo.** Kým to nemáš, endpoint zostáva nezmeraný.
- Rovnaké prázdne telo pod vlastnou aj cudzou identitou **nie je dôkaz o zamietnutí** — je to dôkaz, že sonda nemeria.
- **„Neviem" sa nikdy nesmie zlepiť** na definitívnu odpoveď: ani na „bezpečné", ani na „diera".

### Autorizačný riadok zoraď podľa expozície, nie podľa počtu

- Skôr než spustíš prvú sondu, daj každému endpointu **dva stĺpce**: odkiaľ je dosiahnuteľný *(bez tokenu · s tokenom ľubovoľnej role · len z vnútornej siete)* a aké dáta drží *(osobné údaje · peniaze · konfigurácia · nič)*.
- **Dosiahnuteľnosť zmeraj volaním bez tokenu**, nečítaj ju z konfigurácie gateway — a len nad allowlistom, lebo časť `GET` mení stav.
- Meraj **zhora**: bez tokenu × osobné údaje alebo peniaze ako prvé.
- **Nezaradený endpoint patrí do najvyššieho pásma, nie do najnižšieho** — inak sa „neviem" ticho stane „bezpečné".

*Prečo tu: 403 zo 417 endpointov sa za dva mesiace nesondovať nedá celé; preberajúci tím potrebuje poradie, nie zoznam.*
