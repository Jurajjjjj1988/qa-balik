# Prompt 4 — volá tá služba dodávateľov sama, alebo len preposiela?

**Prečo:** od toho závisí, či má celá jedna fáza zmysel. Ak služba len preposiela ďalej,
môže ísť o systém, ktorý sa nahrádza — a testovať ho by bola investícia do kódu,
ktorý sa vypína.

> Nič nemeň. Výsledok ulož do `~/Cat-knowledge/measurements/odosielanie.md`.
>
> V službe, ktorá rieši notifikácie, nájdi miesta, kde sa **naozaj odosiela** —
> volania na e-mailového a push dodávateľa.
>
> Pre každé odpovedz: **volá sa knižnica dodávateľa priamo** *(a teda tá služba
> odosiela sama)*, alebo sa robí **HTTP volanie na inú internú službu**
> *(a teda len preposiela)*?
>
> Vypíš názov triedy, metódu a jeden riadok volania. Bez hodnôt, bez kľúčov.
>
> Ak sú tam obe cesty, povedz **ktorá je na živej ceste** a ktorá vyzerá ako mŕtvy kód.
