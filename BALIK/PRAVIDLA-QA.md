# Pravidlá QA — triedy chýb, ktoré sa tu už stali

> Toto nie sú všeobecné rady. Každá položka je chyba, ktorá **v tomto estate
> alebo v inom mojom projekte reálne nastala** a stála čas.

---

## 1. Tri úrovne dôkazu — používaj ich v každej odpovedi

| značka | význam |
| --- | --- |
| **ZMERANÉ** | spustil som to a videl výstup |
| **PREČÍTANÉ** | je to v dokumentácii alebo konfigurácii |
| **ODVODENÉ** | úsudok, ktorý som neoveril |

**Odvodené sa nikdy nepíše ako zmerané.** Kde sa nemeralo, píše sa **DIERA**, nie mlčanie.

---

## 2. 🔴 Tichá zelená brána — najdrahšia trieda v tomto projekte

Brána nezlyháva tak, že povie „nie". Zlyháva tak, že **povie „áno" o niečom,
na čo sa nepozrela** — a od funkčnej brány sa to zvonku nedá odlíšiť.

Štyri spôsoby, všetky namerané:

| druh | ako mlčí |
| --- | --- |
| **prázdna množina** | testovací task nemá zdroje → `NO-SOURCE` → build zelený |
| **žiadny spúšťač** | kontrola existuje, ale nič ju nespúšťa |
| **odpojená vetva** | stage môže zlyhať, ale **nikto od neho nezávisí** |
| **prehltnutá chyba** | `catch` vráti `null`/`0`/`false` → chyba sa prejaví ako `200` s prázdnym telom |

**Pravidlo:** *Bránu sa treba pýtať, na čo sa NEPOZERALA.*
Agregát (priemer, celkové %) odpovedá na inú otázku, než ktorú kladieš.

**Dôsledky pre kód, ktorý píšeš:**
- Kontrola, ktorá nevie odlíšiť „čisté" od „nepozrel som sa", musí hlásiť
  **DIERU, nie PASS** — a mať pre to **vlastný exit kód**.
- **Nula nájdených položiek = DIERA**, nikdy nie 100 %.
  *(Stryker: `valid === 0 → 100`. Istanbul: `percent(0,0) → 100`. jscpd: 0 súborov = 0 % duplicity.)*
- **Žiadne `|| true`** na kroku brány. Buď smie zhodiť build, alebo to nie je brána.
- **Prah neznižuj.** Zapíš dlh s podlahou na dnešnej hodnote; podlaha smie **len rásť**.

---

## 3. 🔴 Test, ktorý porovnáva dva výstupy toho istého kódu, je slepý

Round-trip (`inverzia(dopredná(x)) === x`) platí aj vtedy, keď je dopredná transformácia
**nesprávna** — stačí, aby bola tá istá chyba v oboch smeroch.

**Namerané:** modul mal property round-trip cez 200 náhodných prípadov do `1e-9`
a napriek tomu **55 z 97 mutantov neprežilo zabitie**. Pridanie jedného testu
s nezávislým orákulom: 43 % → 83 %.

**Nezávislý orákul** = tvrdenie, ktoré na overenie transformácie tú transformáciu **nepoužíva**:
fyzikálny/geometrický fakt · druhá nezávislá implementácia · hodnota z autoritatívnej knižnice ·
ručne spočítaný známy prípad · byte-exact obsah.

⚠️ **Špecifikácia generovaná z kódu NIE JE nezávislý orákul.**
Je to **mapa** (čo existuje), nie **sudca** (aká hodnota je správna).

⚠️ **Databáza tiež nie je orákul.** Je to silnejší *pozorovací bod* než odpoveď API —
ukáže, čo naozaj zostalo — ale jej obsah je výstup toho istého kódu.

---

## 4. Obojstranná skúška trvanlivosti — obe otázky, vždy

1. **Keď sa test raz pokazí — bude to preto, že sa zmenilo správanie, ktoré stráži?
   Alebo preto, že niekto premenoval pole?** *(falošná červená = daň, nie strážny pes)*
2. **Akú zmenu vo svete tento test NEZAREGISTRUJE — a čo ju zaregistruje namiesto neho?**
   *(falošná zelená — na túto je prvá otázka slepá)*

---

## 5. Invariant sa testuje po CESTÁCH, nie po guardoch

Keď niečo „nesmie nikdy nastať", nezačínaj od guardu, ale od **účinku, ktorý zakazuješ** —
a vypíš si **všetky cesty, ktoré k nemu vedú**.

- **Skúšaj operáciu, nečítaj katalóg.** „Trigger existuje" nie je dôkaz;
  „DELETE bol odmietnutý" áno.
- Zoznam ciest patrí do **deklarácie, nad ktorou beží cyklus**, nie do ručne
  napísaného testu na jeden prípad.
- Pri strate dát, peniazoch alebo cross-tenant expozícii chce invariant **dve vrstvy**.

**Konkrétne tu:** absencia `hasRole()` v tele metódy **nie je výrok o autorizácii** —
je to výrok o tvare kódu. Dokáže to **jedine spustený request.**

---

## 6. Izolácia testov — statický stav prežije test

- Každý test prejde **sám aj v ľubovoľnom poradí**.
- **Statické pole a singleton prežijú test aj naprieč vláknami** (async executor).
  Riešenie nie je upratovanie v `@AfterEach`, ale **`@BeforeEach`, ktorý nastaví VŠETKO**.
- **Vypni paralelné spúšťanie testov v `build.gradle`**, ak sa statický stav zdieľa.
  Poistka patrí do konfigurácie, nie do vety v dokumente.
- Žiadny reálny čas — `Date.now()` → fixný vstup alebo fake timer.
- Žiadne tvrdé čakanie (`Thread.sleep`, `waitForTimeout`).
- Hodnoty počítaj **vnútri `it()` / `@Test`**, nie v tele `describe` —
  inak mutant zhodí ZBER testov a nástroj to vyhodnotí ako „prežil".

---

## 7. 🔴 Java-špecifické pasce, všetky namerané

- **`mockStatic` je thread-local.** Na vlákne bez registrácie **nevyhodí chybu** —
  vráti `null` a **spustí sa skutočná statická metóda**. S async executorom to znamená,
  že test odošle ozajstný e-mail a zostane zelený. **Nepoužívaj ho.**
- **`@Autowired` v triede, ktorú Spring nespravuje** (vzniká cez `new`), je natrvalo `null`.
  Anotácia je, mechanizmus nebeží, zlyhanie je ticho.
- **`useJUnitPlatform()` ticho vypne existujúce JUnit 4 testy**, ak je `junit:junit`
  na classpath a chýba vintage engine. Pred zapnutím over, či tam nejaké sú.
- **Chýbajúce `useJUnitPlatform()`** = JUnit 5 sa ticho nenájde, nula XML, build zelený.
- **AssertJ nad prázdnou kolekciou prejde vákuovo** — `allMatch`, `allSatisfy`, `anySatisfy`
  bez predchádzajúceho tvrdenia o veľkosti nechytia nič.

---

## 8. Peniaze

- **≥ 90 % pokrytie riadkov AND ≥ 90 % mutačné skóre**, per súbor, nie priemer.
- **Zaokrúhľovanie sa riadi TYPOM, nie enginom.** `double` v peňažnom poli je
  **nález sám o sebe**, aj keby testy prechádzali.
- Peňažná logika musí žiť tam, **kde platia brány** — nie v UI priečinku,
  ktorý je z pokrytia vylúčený.
- Bez doménového orákula sa dá tvrdiť len **invariant**: súčet položiek = celok ·
  žiadna suma nie je záporná · determinizmus · konzistentné zaokrúhlenie.

---

## 9. Chybové cesty sú súčasť „hotovo", nie extra

Pre každý modul: neplatný / záporný / prázdny / `NaN` vstup · prekročená hranica ·
výnimka z hlbšej vrstvy · poškodené uložené dáta — **a čo sa stane s už zapísanými
dátami, keď to zlyhá v polovici.**

⚠️ **Záporné číslo prejde cez `isFinite`, `?? 0` aj cez truthy guardy.**

---

## 10. Charakterizačné testy

Zapíšu, čo systém **dnes robí**. Sú nebezpečné, ak sú samé:
porovnávajú výstup kódu s výstupom toho istého kódu, a **zaznamenaním chyby ju
povýšia na pravidlo** — keď ju niekto opraví, test sčervenie a ďalší človek to „opraví" späť.

- Prefix `RECORDED_UNVERIFIED_` alebo `@Tag("char")`.
- Ku každému **riadok `ORAKUL:`** — odkiaľ pochádza očakávaná hodnota,
  alebo výslovne „zatiaľ nikto, je to len záznam".
- Hodnota, ktorá vyzerá zle, ide do **`NALEZY.md` ako kandidát na defekt**,
  nie do testu ako požehnané správanie.
- Pred prvým použitím: **spusti záznam dvakrát nad nezmeneným kódom
  a vyžaduj prázdny diff.** Bez toho nevieš, či nie je nedeterministický.


---

# Doplnené z overených postupov

**Rúra zožerie exit kód — piaty druh tichej zelenej.**
`./gradlew test | tail -30; echo "EXIT: $?"` vypíše stav `tail`, nie buildu. ZMERANÉ: brána padla na 43 lint chybách a report hlásil `EXIT: 0`; odhalil to až nezávislý beh.
- Kdekoľvek má príkaz tvar `cmd | čokoľvek`, daj `set -o pipefail` alebo čítaj `${PIPESTATUS[0]}`.
- Napíš to do tela skriptu — nespoliehaj sa na default shellu v ADO ani v GHA `run:`.
- Platí to aj vtedy, keď výstup len skracuješ, aby sa zmestil do chatu.
**Číslo, ktoré hlásiš, musí byť to, podľa ktorého si konal.** Sondy P2/P3 sa cez rúru vyhodnotiť nedajú.

*Prečo tu: Brána sa bude v 22 repozitároch reportovať skriptom cez ADO/GHA; tu sa vyrába piaty druh tichej zelenej — kontrola bežala, našla chybu, a report ju premenil na zelenú.*

### Prepísanie záznamu je ROZHODNUTIE, nie údržba

Keď `@Tag("char")` test sčervenie, do commitu napíš, ktorá z troch možností to je:
**(a)** niekto chybu opravil → záznam prepíš a napíš prečo · **(b)** regresia → vráť kód,
záznam nechaj · **(c)** záznam bol od začiatku zlý → prepíš a založ nález v `NALEZY.md`.
**Nikdy neprepisuj záznamy dávkovo** — žiadne „approve all", žiadne hromadné `.received` → `.approved`.
Jeden prepísaný záznam = **jeden commit, ktorý sa nedotýka ničoho iného** a v správe menuje (a)/(b)/(c).
Suitu preberá iný tím: bez tohto skončí prvý červený beh hromadným prepísaním a suita stratí hodnotu.

*Prečo tu: Suitu preberá o 2 mesiace iný tím, ktorý nebude vedieť, čo ktorý záznam znamená — bez tohto pravidla prvý červený beh skončí hromadným prepísaním.*

## 11. Log ako pozorovací bod sa najprv dokazuje

Ak sa chyba prejaví len v logu (`catch` vráti náhradu → `200` s prázdnym telom), je log **pozorovací bod — a ten sa overuje, nie predpokladá.**
- **Vyrob request, o ktorom vieš, že vnútri spadne, a nájdi jeho riadok.** Bez toho log ako dôkaz nepoužívaj.
- **Bez korelačného ID** (request/trace id) riadok nepriradíš — v QA beží nočný sync aj cudzia prevádzka nad zdieľanou personou a **pripíšeš si cudzí záznam.**
- Over, či je tá **úroveň logovania v danom prostredí vôbec zapnutá.**
- Chýba korelácia alebo zapnutá úroveň → napíš **DIERA**, nie „v logu to bude vidieť".

*Prečo tu: Keď stavový kód nie je orákul a chyba sa prejaví ako 200 s prázdnym telom, log býva jediné miesto, kde je zlyhanie vidieť — a zdieľaná testovacia persona plus nočný sync robia z nekorelovaného riadku dôkaz o nikom.*

## Inventár catch-miest predchádza testu endpointu

Než napíšeš test endpointu, prejdi `catch`-e v jeho kontroleri a v službách, ktoré volá,
a zapíš tri stĺpce: **MIESTO · NÁHRADNÁ HODNOTA · ZOSTANE STOPA?** *(log s korelačným ID / metrika / nič)*.
Bez druhého stĺpca nevieš napísať tvrdenie „chybová cesta vráti chybu, nie prázdno".
Bez tretieho nevieš odlíšiť úspech od prehltnutého zlyhania — **`catch`, po ktorom nezostane stopa nikde,
je kandidát na defekt do `NALEZY.md`, nie požehnané správanie do testu.**
Inventár **generuj skriptom** (`~/Cat-knowledge/scripts/`, výstup do `measurements/`); ručný zoznam je deň po odchode autora zamrznutý.

*Prečo tu: Počet prehltnutých chýb je zmeraný, ale bez rozpisu „čo vráti a kde po tom zostane stopa" sa nedá napísať ani jedno platné tvrdenie o chybovej ceste. A projekt sa o dva mesiace odovzdáva inému tímu.*

**Nikdy neassertuj hodnotu, ktorú vracia `catch`.** Očakávanie rovné náhradnej hodnote — prázdny
zoznam, `0`, `null`, `false`, prázdne telo — je zelené aj vtedy, keď pod ním spadlo úplne všetko.
*(Zmerané: 296 miest, 24 % kódu, má `catch` s náhradnou hodnotou.)*
Keď je prázdny výsledok legitímny, potrebuješ **rozlišovací signál**: druhý pozorovací bod ·
korelovaný riadok v logu · alebo v tom istom teste prípad, kde tá istá cesta vráti **neprázdne** dáta.
Bez rozlíšenia sa test nepíše — hlás **DIERU**.

*Prečo tu: Zmerané: štvrtina miest v kóde má catch, ktorý vracia náhradnú hodnotu, takže chyba vyjde ako 200 s prázdnym telom. Assert na „prázdne" nevie odlíšiť správne prázdny výsledok od úplného zlyhania.*

**Odchádzajúce volanie bez timeoutu.** Ku každému volaniu von dohľadaj **connect aj read timeout** —
v konfigurácii klienta aj v `application.yml`, nielen v tele metódy. Bez timeoutu sa výpadok dodávateľa
neprejaví ako chyba, ale ako request, ktorý **visí**; žiadna výnimka nepríde, a keď sa nakoniec dočká,
`catch` nad ním vráti prázdno s `200`. K endpointu zapíš do meraní stĺpec
**volanie von · timeout ÁNO / NIE / NEZISTENÉ** a nájdenú hodnotu. `NEZISTENÉ` je viditeľné číslo, nie ticho.
Fasádu v teste nenahradíš (`mockStatic` je zakázaný) — timeout a `catch` sú jediné, čo o tom zlyhaní vieš dokázať.

*Prečo tu: Všetky odchádzajúce volania idú cez statické fasády, ktoré sa v teste nedajú nahradiť (mockStatic je zakázaný), takže jediné, čo o ich zlyhaní vieš povedať, je to, čo si o timeoute a o catch-i nad ním zmeral.*


---

# Doplnené — druhé kolo

**Po pridaní každej kontroly prepočítaj brány, ktoré už bežali, a porovnaj ich čísla pred a po.**
Kontrola sa hodnotí aj podľa toho, čo spraví s nástrojmi, ktoré bežia vedľa nej.
Tu je najzraniteľnejšia **podlaha počtu testov**: skript čítajúci zdrojáky (inventár `catch`-ov, zoznam metód, klasifikácia endpointov) pridaný ako `@Test` **zdvihne počet** — podlaha prejde, aj keby si zmazal skutočné testy.
Také kontroly drž v **samostatnom skripte vedľa brány, nikdy medzi meranými testami**.
Číslo pred aj po zapíš do `measurements/`; nevysvetlený rozdiel je **DIERA**, nie PASS.

*Prečo tu: Brány sa pridávajú postupne vo fázach 0–4 naprieč 22 repozitármi, vždy nad tie, ktoré už bežia — a jediná brána fázy 0 je POČET, ktorý sa dá nafúknuť práve tými skriptami, ktoré tento balík nariaďuje.*

**K spoločnej kontrole chybovej cesty pridaj deny-list nad telom odpovede.** Okrem stack trace (§ Trieda chyby) hľadaj v tele aj `at com.`, `SQLException`, fragment SQL, meno tabuľky či stĺpca a connection string — sú to ďalšie tvary toho istého úniku a jedna kontrola ich pokryje pre celý allowlist naraz.
Zgrepni k tomu `server.error.include-stacktrace` a `include-message` cez všetkých 22 repozitárov a nájdenú hodnotu zapíš do meraní; **nenájdené = DIERA**, nie „je to vypnuté".
**Tvrdenie meraj z odpovede, nie z konfigurácie** — config hovorí, čo je nastavené, telo hovorí, čo naozaj odišlo ku klientovi. Kde odpoveď vyrobil default handler a nie náš `@ControllerAdvice`, napíš to k nálezu.
Prostredie nie je anonymizované, takže únik z chybovej hlášky je zmluvná vec, nie kozmetika — nález ide do `NALEZY.md` hneď a s uvedeným endpointom, nie do backlogu.

**Injekciu nájdi grepom, potvrď VÝLUČNE čítacou sondou.**
- Zgrepuj cez **všetky** repozitáre skladanie dotazu reťazcom: `+` a `String.format` v `createQuery` / `createNativeQuery`, `@Query` s konkatenáciou, `ORDER BY` zložené z parametra requestu. Zásah z grepu je **kandidát do `NALEZY.md`**, nie nález. Nula zásahov = **DIERA**, nie čisto.
- Potvrdzuj **len payloadom, ktorý nič nemení**, a očakávaj **zmenu počtu vrátených riadkov** — nie chybovú hlášku: `catch` ju prehltne a von pošle `200` s prázdnym telom.
- Do **zápisových a DDL** ciest nedávaj **nič**. Databáza je zdieľaná, dáta sú cudzie a nočný sync ti ich nevráti.
- Sondu púšťaj len na endpoint **z allowlistu** (časť `GET` mení stav). Čo sa nedá dokázať čítaním, píš ako **NEOVERENÉ**, nikdy ako nález.

*Prečo tu: 296 miest s prehltnutou chybou znamená, že injekcia sa tu neprejaví ako chybová hláška ani 5xx — jediný použiteľný signál je počet riadkov. A dáta v QA nie sú naše: deštruktívna sonda je nevratná škoda, ktorú nočný sync neopraví.*
