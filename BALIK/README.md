# Balík pre prácu na tomto projekte

## Kam čo patrí

| súbor | kam |
| --- | --- |
| `ZACNI-TU.md` | **vlož do chatu na začiatku každej session** |
| `PRAVIDLA-QA.md` · `PRAVIDLA-DB.md` · `PRAVIDLA-API.md` · `PRAVIDLA-KRITIK.md` | do QA repozitára; odkáž na ne v primeri |
| `ANTIVZORY.md` | **tabuľka tried chýb na vyhľadávanie** — sem sa pozeraj, keď niečo vyzerá podozrivo |
| `STRATEGIA.md` | do QA repozitára |
| `instructions/java-tests.instructions.md` | do `.github/instructions/` v repozitári, kde píšeš testy |
| `prompty/*.md` | jeden po druhom do chatu, keď na ne príde rad |

## Prečo sa primer vkladá ručne

Copilot si medzi sessionami nič nepamätá. Súbor v `.github/instructions/` sa aplikuje
automaticky, ale **len na cesty, ktoré sedia s `applyTo`** — a my pracujeme naprieč
repozitármi, kde ho nemáme kde položiť.

Preto: **primer ručne, inštrukcie strojovo.**

## Čo v tomto balíku ZÁMERNE nie je

**Čísla.** Sú v `~/Cat-knowledge/measurements/` na pracovnom stroji, kam patria.
Balík nesie **metódu, nie materiál** — preto sa dá prenášať bez obáv.

## Čo Copilot vie a čo nie

**Vie:** čítať kód vo všetkých repozitároch, spúšťať skripty, merať, ukladať výsledky.

**Nevie:** pamätať si predchádzajúcu session · odlíšiť odvodenie od merania,
ak mu to nepovieš · vedieť, že `GET` môže meniť stav.

**Preto sú tie pravidlá napísané tak natvrdo.**
