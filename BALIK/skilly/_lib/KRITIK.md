# Kritik — povinný krok pred každým výstupom

> Kanonické znenie. Skilly naň **odkazujú**, nekopírujú ho.
> Kópia v osemdesiatich súboroch sa do pol roka rozíde — to je trieda
> „dva zoznamy, ktoré sa musia zhodovať".

---

## Pravidlo

**Žiadny návrh, odporúčanie, výsledok ani zmena sa neukáže používateľovi skôr,
než prejde kritickým pohľadom.** Nie na požiadanie — vždy.

Platí to aj na **VÝSLEDKY**, nielen na návrhy. Zelené číslo zvádza k záveru
rovnako ako dobre znejúci plán.

Ak si to neurobil, **povedz to nahlas** namiesto toho, aby si výstup vydal ako hotový.

---

## Štyri otázky, ktoré musia zaznieť

1. **Aké INÉ vysvetlenie by dalo ten istý príznak — a vylúčil som ho MERANÍM?**
2. **Čo je DOKÁZANÉ a čo ODVODENÉ?** Odlíš to v texte, nie v hlave.
3. **Nevyrábam niečo, čo VYZERÁ ako ochrana a nič nechytí?**
4. **Prežije to, keď odídem?** Ak to drží len moja prítomnosť, nie je to opatrenie.

---

## Prečítaný defekt nie je dokázaný defekt

Cesta môže byť konkrétna, citovateľná podľa čísla riadku — **a napriek tomu nesprávna**,
lebo to, čo ju vyvracia, je niekde, kde si nečítal.

> **Ak to nevieš spustiť, nález sa vydáva označený ako NEOVERENÝ — nikdy ako nález.**
> A návrh, ktorý na ňom stojí, sa **stiahne**, nie zmäkčí.

## Počet je tvrdenie o tom, KDE si sa pozeral

Vždy uveď rozsah: cez čo si hľadal, čo si vylúčil. Bez toho je číslo dekorácia.

## Prázdny výsledok nie je čistý výsledok

Keď kontrola nenašla nič, sú dve možnosti — naozaj tam nič nie je, alebo
**si sa nemal na čo pozerať.** Musia sa dať odlíšiť. Pri nule hlás **DIERU**.

---

## Kritik má DVE osi — chytajú rôzne veci

Vyššie uvedené otázky sú **os 1: je to PRAVDA?**
Existuje druhá, nezávislá os — **os 2: nie je to SLOP?** — a prvá os ju nechytí.

> **Nebezpečné nie je, keď niečo vyzerá zle. Nebezpečné je, keď chýba červená vlajka.**
> Namerané *(METR)*: vývojári boli s AI **o 19 % pomalší**, ale verili, že sú o 20 % rýchlejší.
> **Ver meraniu, nie pocitu.** Pocit správnosti nekoreluje so správnosťou —
> a preto je tento krok povinný, nie voliteľný.

### Smerovanie podľa ARTEFAKTU, nie podľa témy

| čo si vyrobil | pusti na to |
| --- | --- |
| **produkčný kód** | `anti-ai-slop` |
| **testy** | `ai-test-smell-detector` *(sken tvaru)* · `real-testing-patterns` *(katalóg)* |
| **text, dokument, špecifikácia** | `ai-doc-smell-detector` |
| **prah, hook, krok v CI** | `gate-audit` |

### Príznaky osi 2 — keď platí ktorýkoľvek, os 1 nestačí

- všetko zelené, ale **nikdy si nevidel padnúť** test na chybu, ktorú „pokrýva"
- pokrytie je vysoké, **mutačné skóre nepoznáš**
- lookup vracia `0` alebo default namiesto toho, aby chýbajúcu vec **priznal**
- duplikovaný blok namiesto použitia existujúcej funkcie
- abstrakcia pridaná na problém, ktorý mal päť riadkov
- **„cíti sa to hotové"** bez akceptačného kritéria napísaného dopredu
- invariant je vynútený len na klientovi, **nie na hranici dôvery**
- 🔴 **ty sám si prešiel svoj vlastný diff a nič si nenašiel** — korelované slepé miesta

⚠️ **Posledný bod je dôvod, prečo kritik nesmie byť ten istý pohľad, čo písal.**
Ak si autor aj recenzent, os 2 je z definície slepá — vtedy sa musí spustiť ten sken.

---

## Rebrík sily opatrení

> typ / lint pravidlo **>** kontrola v bráne **>** test **>** veta v dokumente

Veta v dokumente je **posledná** možnosť. Ak ju navrhuješ, zdôvodni, prečo sa to nedá dať stroju.

---

## Kedy sa tento krok NEROBÍ

Aby sa nestal obradom, ktorý sa naučíš odklikávať:

- **preklad formátu** *(dokument → iný dokument, dáta → tabuľka)*
- **obal nad nástrojom**, kde výstup určuje ten nástroj, nie úsudok
- **čisto mechanická operácia** — premenovanie, presun, formátovanie

Všade inde platí. A **keď váhaš, patrí tam.**
