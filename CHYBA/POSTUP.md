# Postup — slučka, nie zoznam na odškrtnutie

> Zoznam sa odklikáva. **Slučka má výstupné podmienky, ktoré sa nedajú predstierať.**
> Pri každom kroku je napísané, čo ťa z neho pustí ďalej.

---

## 0 · Načítaj kontext

Vlož `ZACNI-TU.md`. **Bez toho pracuješ bez pravidiel a nedozvieš sa to.**

🚪 *Ďalej ideš, keď:* vieš povedať, kde je pravda o číslach *(`~/Cat-knowledge/measurements/`)*.

## 1 · Zisti, čo sa vlastne pýta

Napíš **jednou vetou**, čo má byť výsledok a **ako spoznáš, že je hotový**.
Ak to nevieš napísať, nemáš zadanie — **spýtaj sa**, nezačínaj.

🚪 *Ďalej:* akceptačné kritérium je napísané **PRED** prácou, nie po nej.

## 2 · Pozri sa, či to už nie je zmerané

```
ls ~/Cat-knowledge/measurements/
```
Ak tam ten súbor je a nie je starý — **prečítaj ho a nemeraj znova**.

🚪 *Ďalej:* vieš menovať súbor, ktorý si prečítal, alebo že tam nie je.

## 3 · Zmeraj, čo chýba

Nie prečítaj — **spusti**. Výstup ulož s **dátumom · príkazom · rozsahom**
*(cez čo si hľadal, čo si vylúčil)*.

🚪 *Ďalej:* existuje súbor, ktorý vie niekto iný zopakovať.
❌ *Neprejdeš, ak:* číslo máš „z pozerania sa na kód".

## 4 · Urob prácu

Najmenšia vec, ktorá spĺňa kritérium z kroku 1. **Nič navyše.**

🚪 *Ďalej:* nepridal si nič, čo v kroku 1 nebolo.

## 5 · 🔴 Dokáž, že to vie zlyhať

**Toto je krok, ktorý sa najčastejšie preskočí — a bez neho je zvyšok dekorácia.**

| čo si vyrobil | ako to dokážeš |
| --- | --- |
| test | **vyguti telo testovanej metódy** → musí sčervenieť → telo vráť |
| bránu | sonda: zelená → červená **menujúca sondu** → zelená |
| sken | pusti ho na prípad, o ktorom **vieš**, že tam nález je |

🚪 *Ďalej:* videl si **červenú aj zelenú** a vieš povedať kedy.
❌ *Obrátený assert NESTAČÍ* — na `catch`-i s náhradnou hodnotou prejde.

## 6 · Kritik

`skilly/_lib/KRITIK.md` + otázka na konci toho skillu, ktorý si použil.

Štyri otázky, ktoré musia zaznieť:
1. Aké **iné vysvetlenie** by dalo ten istý príznak — a vylúčil som ho **meraním**?
2. Čo je **dokázané** a čo **odvodené**?
3. Nevyrábam niečo, čo **vyzerá ako ochrana a nič nechytí**?
4. **Prežije to, keď odídem?**

🚪 *Ďalej:* v texte je odlíšené ZMERANÉ / ODVODENÉ.

## 7 · Povedz aj to, čo nevieš

Report obsahuje **NEZMERANÉ**. Keď nič nezostalo nezmerané, napíš to výslovne —
**nie mlčanie**.

🚪 *Hotovo, keď:* vieš povedať **menovateľ** — koľko vecí si skutočne skontroloval.

---

## Kedy sa slučka vracia

| stalo sa | vráť sa na |
| --- | --- |
| meranie odporuje zadaniu | **1** — zadanie bolo zlé, povedz to |
| krok 5 nesčervenal | **4** — nevyrobil si, čo si myslel |
| kritik našiel odvodenie vydané za fakt | **3** — zmeraj to |
| nevieš vyplniť menovateľa | **2** — nevieš, čo je celok |

---

## Prečo takto

**Toto nie je návod na dobré správanie. Je to zoznam miest, kde sa to už pokazilo.**

Za jednu noc na tomto projekte:
- test stage, na ktorom vraj závisí deploy — **neexistuje**
- „pull request nespustí nič" — pritom **bežia dva workflowy**
- sonda hlásila accent-sensitive — **klamala o vlastnom kódovaní**
- skill poslaný na Gradle projekt — je to **npm**

**Každú z nich chytilo spustenie, nie úvaha.** To je celý dôvod, prečo je krok 5 povinný.
