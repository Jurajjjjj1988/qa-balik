# Prompt 2 — kde beží statická analýza a či vie zhodiť build

**Prečo:** jeden bezpečnostný sken je odpojený (nikto od neho nezávisí), ale ďalšie dva
bežia **vnútri** kroku, ktorý spúšťa testy — teda v ceste, ktorá blokuje nasadenie.
Moja brána musí vedieť odlíšiť pád testu od pádu analyzátora.

> Nič nemeň. Výsledok ulož do `~/Cat-knowledge/measurements/staticka-analyza.md`.
>
> **1.** Vo **všetkých** repozitároch v `~/work` nájdi v definíciách pipeline všetky kroky,
> ktoré spúšťajú **statickú analýzu kódu alebo bezpečnostný sken** — akýkoľvek nástroj,
> nielen ten, na ktorý si spomeniem.
> Tabuľka: repozitár · názov nástroja · v ktorom stage · v ktorom kroku.
>
> **2.** Pre každý z nich zisti, či môže zhodiť build: má `continueOnError`?
> má stage `condition:`? závisí od neho nejaký iný stage?
>
> **3.** Zisti, či beží v **tom istom kroku**, ktorý spúšťa testy.
> Ak áno, vypíš ten krok celý.
>
> Na záver: **ktoré analyzátory vedia zastaviť nasadenie a ktoré nie.**
> Kde sa to z YAML nedá zistiť, napíš **NEZMERANÉ** — nie „asi nie".
