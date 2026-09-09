# Prompt 1 — verzia Gradle na hlavnej vetve

**Prečo:** mám dve rôzne merania tej istej veci a na jednom z nich stojí časť opatrení.
Kým to nie je zavreté, nesmiem ani jedno číslo použiť.

> Nič nemeň. Výsledok ulož do `~/Cat-knowledge/measurements/gradle-verzie.md`
> a doplň index `README.md`.
>
> Pre **každý** repozitár v `~/work` vypíš verziu Gradle z wrappera, a to **dvakrát**:
> raz z aktuálneho checkoutu a raz z hlavnej vetvy na serveri.
>
> ```
> grep distributionUrl gradle/wrapper/gradle-wrapper.properties
> git show origin/<hlavná-vetva>:gradle/wrapper/gradle-wrapper.properties | grep distributionUrl
> ```
>
> Tabuľka: repozitár · verzia v checkoute · verzia na hlavnej vetve · **líšia sa?**
> Na záver: koľko repozitárov má na hlavnej vetve verziu **staršiu než 7.0**.
