# Triedy chýb — tabuľka na vyhľadávanie

> Každý riadok je chyba, ktorá **reálne nastala a stála čas**. Nie hypotéza.
> Keď niečo vyzerá podozrivo, hľadaj tvar tu — väčšina „nových" chýb je stará trieda.

---

## A. Kontrola, ktorá mlčí

| príznak | čo to naozaj je | čo to dokáže | čo to zabije |
| --- | --- | --- | --- |
| build zelený, ale testy nikde | **prázdna množina** — nie sú zdroje, task hlási `NO-SOURCE` | počet vykonaných testov | nula výsledkových súborov → **exit 3 = DIERA** |
| kontrola existuje, nikdy nesčervenala | **žiadny spúšťač** — nič ju nevolá | pusti ju ručne | spusti sondu; červená musí **menovať** ten súbor |
| stage môže zlyhať, ale nič sa nestane | **odpojená vetva** — nikto od neho nezávisí | `dependsOn` naprieč stage-mi | pripoj **až keď** vieš, že vie sčervenieť |
| chybný vstup vráti `200` s prázdnym telom | **prehltnutá chyba** — `catch` vracia `null`/`0`/`false` | inventár `catch` blokov | tvrď **efekt na druhom pozorovacom bode** |
| report hlási `EXIT: 0`, hoci to spadlo | 🔴 **rúra zožrala exit kód** — `cmd \| tail; echo $?` vypíše stav `tail` | nezávislý beh bez rúry | `set -o pipefail` alebo `${PIPESTATUS[0]}` |
| pokrytie 100 %, mutácia 100 % | **nula meraných vecí** — nástroj hodnotí prázdno ako dokonalé | *koľko vecí som zmeral* | pri nule hlás **DIERU**, nie PASS |
| priemer je nad prahom | **agregát odpovedá na inú otázku** | rozpad per súbor | **per-file podlaha**, nie priemer |
| súbor je v pokrytí, ale nemá vlastnú podlahu | **meraný ≠ chránený** — priemer pohltí aj úplnú stratu | zmaž jeho test | vlastná podlaha na každú hodnotnú vec |

## B. Test, ktorý nič nechytí

| príznak | čo to naozaj je | čo to zabije |
| --- | --- | --- |
| round-trip prejde, mutanty prežijú | **porovnávaš dva výstupy toho istého kódu** | nezávislý orákul — tvrdenie, ktoré tú transformáciu nepoužíva |
| test proti špecifikácii generovanej z kódu | to isté, o poschodie vyššie — **mapa, nie sudca** | orákul mimo kódu: DDL, akceptačné kritérium, človek |
| metamorfný vzťah prejde, mutant prežije | **obe strany dedia ten istý default** → prevrátenie sa vykráti | pýtaj sa: *čo je na oboch stranách rovnaké, a teda neviditeľné?* |
| assert nad prázdnou kolekciou | `allMatch` / `allSatisfy` prejdú **vákuovo** | najprv tvrdenie o veľkosti |
| test prejde sám, padne v suite | **statický stav prežil predchádzajúci test** | `@BeforeEach`, ktorý nastaví **všetko**; vypni paralelizmus v konfigurácii |
| mutant „prežil", ale nespustil ani jeden test | **hodnota postavená mimo `it()`** zhodí zber testov | počítaj vnútri `@Test` |
| charakterizačný test bráni oprave | **zaznamenal si chybu a povýšil ju na pravidlo** | `@Tag("char")` + riadok `ORAKUL:` + nález do `NALEZY.md` |

## C. Invariant, ktorý chráni len jednu cestu

| príznak | čo to naozaj je | čo to zabije |
| --- | --- | --- |
| „guard tam je" | **čítaš katalóg, neskúšaš operáciu** | spusti tú operáciu a pozri, či ju odmietne |
| kontrola je v tele metódy | **iná cesta ju obíde** — service vrstva, brána, dávka | vypíš **všetky cesty k účinku**, nie guardy |
| autorizácia „je centralizovaná" | ak nie je filter chain, **nie je do čoho** | spustený request s cudzou identitou |
| ochrana sa vypína `UPDATE`-om v tabuľke | **cesta nevedie cez kód**, takže kontrola nad kódom ju nevidí | kontroluj tie dáta, nie len kód |
| jedna vrstva stačí | pri peniazoch a cudzích dátach **nestačí** | dve nezávislé vrstvy |

## D. Java a Spring — konkrétne pasce

| príznak | čo to naozaj je |
| --- | --- |
| `mockStatic` „funguje", ale e-mail sa naozaj odošle | **je thread-local** — na inom vlákne ticho spustí skutočnú statiku |
| `@Autowired` pole je `null` a nič nespadne | trieda **nie je Spring bean** (vzniká cez `new`) |
| zapol som `useJUnitPlatform()` a testy zmizli | **ticho vypol JUnit 4**, keď chýba vintage engine |
| JUnit 5 testy sa nespúšťajú, build zelený | **chýba `useJUnitPlatform()`** — nula XML |
| async úloha zlyhá a nikto sa to nedozvie | výnimka v `submit()` **nikde nevyskočí** |

## E. Ja sám — chyby v uvažovaní, nie v kóde

| príznak | čo to naozaj je | čo to zabije |
| --- | --- | --- |
| „našiel som defekt, pozri riadok 42" | **prečítaný ≠ dokázaný** — vyvrátenie býva tam, kde si nečítal | spusti to; ak nevieš, označ **NEOVERENÉ** |
| „je ich štrnásť" | **počet je tvrdenie o tom, kde si sa pozeral** | uveď rozsah: cez čo, s vylúčením čoho |
| záver z jedného repozitára platí pre všetky | **záver prenesený cez hranicu** | zmeraj vzorku z viacerých |
| fakt z iného projektu použitý tu | **nameraný cez hranicu, na ktorej sa nemeral** | zmeraj to znova tu |
| pri prepise do zhrnutia zmizlo „nezmerané" | **kvalifikátor vypadol pri prenose** | prenášaj vetu aj s výhradou, alebo ju neprenášaj |
| sonda vrátila prekvapivý výsledok | **sonda môže klamať o sebe** | najprv nech dokáže, že jej vlastné spojenie je v poriadku |
| pokrytie rastie, nálezy nie | **testuješ tam, kde je to lacné, nie kde je riziko** | rizikovú os pridaj z histórie zmien, nie z názvov |
| „to už je hotové" | **hotové ≠ overené** | ukáž červený **aj** zelený beh |

## F. Prevádzka

| príznak | čo to naozaj je |
| --- | --- |
| kontrola pribudla a nikto ju neschválil | **brána sa ozbrojila ako vedľajší účinok** — v diffe to nevidno |
| červená z cudzej príčiny | brána meria **krok, ktorý robí tri veci** |
| test zelený dnes, červený o týždeň bez zmeny kódu | **dáta nie sú tvoje** — prepíše ich synchronizácia alebo iný test |
| „2xx, takže sa to stalo" | pri asynchrónnom účinku je to **dôkaz o prijatí**, nie o účinku |
| dlhé meranie spadlo | **stroj nebol tichý** — zabitý beh nie je výsledok |
| `npx nástroj` mimo repozitára | siahol po **cudzom balíku** z cache; over, že bežal z `node_modules` |

---

## Pravidlo, ktoré je nad všetkými

> **Prázdny výsledok nie je čistý výsledok.**
> Keď kontrola nenašla nič, sú dve možnosti: naozaj tam nič nie je, alebo
> **si sa nemal na čo pozerať**. Tie dve sa musia dať odlíšiť — inak to nie je kontrola.
>
> Vždy vypíš **menovateľ**: koľko vecí som skutočne skontroloval.
