# Prompt 3 — čo sa naozaj spustí pri pull requeste

**Prečo:** mechanizmus závisí od toho, kde je kód hostovaný, a ja som to raz už odvodil zle.
Toto musí byť **pozorovanie, nie čítanie dokumentácie.**

> Nič nemeň. Výsledok ulož do `~/Cat-knowledge/measurements/co-bezi-na-pr.md`.
>
> **1.** Kde sú repozitáre hostované? `git remote -v` v každom.
>
> **2.** Vypíš obsah `.github/workflows/` v každom repozitári — názvy workflowov
> a ich `on:` sekcie. Ktoré z nich bežia na `pull_request`?
>
> **3.** Má niektorý `azure-pipelines.yml` blok `pr:`? V koľkých z koľkých?
>
> **4.** Na záver odpovedz na jednu vetu: **čo presne sa spustí, keď niekto otvorí
> pull request** — menovite, po jednotlivých kontrolách. A čo z toho **spúšťa testy**.
>
> Ak sa niečo z toho zo súborov zistiť nedá, napíš **NEZMERANÉ** a povedz, kde by sa to zistilo.
