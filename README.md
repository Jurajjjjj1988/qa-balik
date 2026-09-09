# Doplnenie k balíku, ktorý už máš stiahnutý

**Rozbaľ to cez existujúci `~/BALIK/`.** Prepíše 5 vecí a pridá 20 skillov.
Zvyšok necháva tak.

```bash
curl -sL https://raw.githubusercontent.com/Jurajjjjj1988/qa-balik/main/chyba.tar.gz | tar -xz --strip-components=1 -C ~/BALIK/
```

## Čo príde

| | |
| --- | --- |
| **`POSTUP.md`** | 🆕 pracovná slučka — 8 krokov, každý s podmienkou, ktorá sa nedá predstierať |
| `ZACNI-TU.md` | slučka **priamo v primeri**, aby sa vkladala každú session |
| `STRATEGIA.md` | fáza 1 odkazuje na nameraný rozsah v `~/Cat-knowledge/measurements/` |
| `skilly/qa-matrices-and-docs/` | skrátené · popis **1 680 → 1 450** *(orezával sa na 1 536)* |
| `skilly/sql-validation-mysql-mssql/` | 🆕 sekcia **„Spusti"** s exit kódmi · popis **1 793 → 1 470** |
| **+ 20 nových skillov** | zoznam nižšie |

## Prečo tie dva popisy

Strop v listingu skillov je **1 536 znakov**. Oba boli nad ním, takže sa **orezávali už
pri načítaní**. `sql-validation-mysql-mssql` prichádzal o **11 zo 14 spúšťacích fráz**
a o vetu *„nepoužívaj na SQL Server vs PostgreSQL"* — teda presne o to, čo bráni tomu,
aby vystrelil namiesto správneho skillu.

## Dvadsať nových skillov

`ai-doc-smell-detector` · `test-strategy` · `test-driven-development` · `review-code` ·
`requesting-code-review` · `reality-check` · `generate-documentation` ·
`generate-test-data` · `generate-ci-pipeline` · `finishing-a-development-branch` ·
`writing-plans` · `executing-plans` · `comment-discipline` · `ubiquitous-language` ·
`plan-migration` · `deep-module-refactor` · `using-git-worktrees` · `go-live-gate` ·
`docx` · `xlsx`

**Po rozbalení máš 46 skillov.**

## Prvé tri veci

1. Otvor `priklad/CategoryAssemblerTest.java` — vzor, ktorý má Copilot **kopírovať**
2. Vlož `ZACNI-TU.md` do prvej session *(je v ňom aj slučka)*
3. Pusti `prompty/01-verzia-gradle.md` — dve minúty, zavrie otvorený rozpor
