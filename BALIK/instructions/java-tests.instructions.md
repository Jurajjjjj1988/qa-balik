---
applyTo: "**/src/test/**/*.java"
---

# Pravidlá pre testovací kód

## Zakázané — bez výnimky

- **`Mockito.mockStatic`** — je thread-local; na vlákne bez registrácie nevyhodí chybu,
  vráti `null` a spustí sa **skutočná** statická metóda. Tento kód používa async executor.
- **`Thread.sleep`** a akékoľvek tvrdé čakanie.
- **`LocalDate.now()`, `new Date()`, `System.currentTimeMillis()`, `Math.random()`,
  `UUID.randomUUID()`** v teste — použi fixný vstup.
- **Očakávaná hodnota vypočítaná volaním testovanej metódy.**
- **`allMatch` / `allSatisfy` / `anySatisfy` bez predchádzajúceho tvrdenia o veľkosti** —
  nad prázdnou kolekciou prejdú vákuovo a nechytia nič.

## Povinné

- Každá testovacia trieda má **`@Tag("spec")`** alebo **`@Tag("char")`**.
- **`@Tag("char")` musí mať v komentári riadok `ORAKUL:`** — odkiaľ pochádza očakávaná
  hodnota, alebo výslovne „zatiaľ nikto, je to len záznam dnešného správania".
- **Statický stav prežije test.** Ak trieda číta statické pole alebo singleton,
  `@BeforeEach` musí nastaviť **všetko**, čo test potrebuje.
  Nespoliehaj sa na upratovanie v `@AfterEach` a nikdy nepredpokladaj,
  že hodnota, ktorú tento test nenastavil, je prázdna.
- **Jeden test = jedna vlastnosť.** Jeden dôvod, prečo môže spadnúť.
- Názov testu hovorí **správanie**, nie názov metódy.

## Konštrukcia objektov

Konštruktory tu často prijmú `null` pre všetky spolupracovníkov — použi to.
**Spring kontext v unit testoch nespúšťaj.**

⚠️ Ale pozor: konštrukcia „na skúšku" vie naplniť statické polia cez `@PostConstruct`
a znečistiť JVM ďalšiemu testu.

## Než test odovzdáš

**Musíš ho vidieť sčervenieť.** Obráť assert, over, že padne, vráť späť.
Test, ktorý si nevidel padnúť, sa počíta ako **0**.


---

# Doplnené — druhé kolo

## Než test odovzdáš — musíš ho vidieť sčervenieť

**Obrátený assert nestačí.** Dokazuje len to, že sa assert vyhodnotil.
**Silnejšia sonda:** v `src/main` nahraď telo testovanej metódy návratom náhradnej hodnoty (`null`, `0`, prázdny zoznam) — **test MUSÍ sčervenieť.** Tu je to rozhodujúce: **296 miest** má `catch`, ktorý vracia presne takú hodnotu, a `assertNotNull`, `assertDoesNotThrow` aj `isNotEmpty()` na nej **prejdú** — taký test nechytí nič.
**Rebrík sily:** obrátený assert < vygutované telo metódy < **vrátená oprava** (pri oprave chyby vráť opravu späť, over červenú, oprav znova — najsilnejší variant).
**Vygutované telo hneď vráť a pred commitom prečítaj `git diff`.** Mutant zabudnutý v `src/main` je horší než chýbajúci test.
Test, ktorý si nevidel padnúť na vygutovanom tele, sa počíta ako **0**.
