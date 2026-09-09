# Skilly v tomto balíku

> **26 skillov + `_lib/KRITIK.md`.** Zo 79 dostupných.
> Rozhodnuté proti realite projektu: Java 21 + Spring Boot, Gradle, backend a API,
> MySQL lokálne + SQL Server v QA, jeden človek, odovzdanie o dva mesiace.

## ⚠️ Ako ich Copilotovi podať

**Copilot nemá systém skillov** — nevie si vybrať podľa popisu. Sú to preňho obyčajné
súbory, ktoré mu musíš dať prečítať.

❌ *„Máš tu 26 skillov, použi vhodný."* — **nevyberie si.**
✅ *„Než napíšeš prvý test, prečítaj `skilly/qa-matrices-and-docs/SKILL.md`.
Než mi dáš výsledok, prejdi `skilly/_lib/KRITIK.md`."*

**Dennú prácu pokrývajú destilované `PRAVIDLA-*.md` a `ANTIVZORY.md`.**
Skilly sú tam pre postupy, ktoré sa destilovať nedali.

---

## Tier 1 — jadro *(7, vždy)*

| | prečo |
| --- | --- |
| `_lib/KRITIK.md` | kanonický kritický krok; ostatné naň odkazujú |
| `critical-engineer` | postoj, nie zoznam — nedá sa destilovať |
| `anti-ai-slop` | Copilot píše kód |
| `ai-test-smell-detector` | Copilot píše testy; je to o **unit** testoch |
| `verification-before-completion` | „hotovo" ≠ overené |
| `gate-audit` | brány sú fáza 0 a najzradnejšia časť projektu |
| `qa-matrices-and-docs` | každý výstup projektu je tabuľka |

## Tier 2 — podľa fázy *(8)*

| | fáza | prečo |
| --- | :---: | --- |
| `check-error-handling` | 1–2 | **296 tichých zlyhaní** |
| `characterization-tests` | 1 | doménový orákul neexistuje |
| `seam-review` | 1, 3 | chyba MEDZI dvoma commitmi |
| `check-api-contract` | 2 | kontrakt sa dokazuje v oboch smeroch |
| `sql-validation-mysql-mssql` | 2, 4 | **náš presný pár enginov** + spustiteľná sonda |
| `bruno-api-suite` | 2 | **tím overuje cez Bruno** |
| `invariant-bypass-audit` | 4 | autorizácia sa testuje po cestách |
| `test-layers-money-critical` | 4 | peňažný kód |

## Tier 3 — keď na to príde *(5)*

`adversarial-review` · `receiving-code-review` *(cudzí tím ti bude recenzovať PR)* ·
`security-audit` · `readme-test-repo-pattern` · `systematic-debugging`

## Testovacie remeslo *(5)*

| | čo z toho platí |
| --- | --- |
| **`layered-playwright-suite`** | **referenčná implementácia** — spec, page objects, fixtures, helpers, `ARCHITECTURE.md`, `BLUEPRINT.md` |
| `write-tests` | uzavretý postup: bez úplných informácií sa nezačína |
| `test-organization` | pomenovanie a hierarchia |
| `real-testing-patterns` | katalóg antivzorov |
| `improve-tests` | tvrdenie existujúcich testov |

> ⚠️ **Sú to Playwright/TypeScript skilly a náš projekt je Java/JUnit.**
> **Neprenáša sa kód. Prenáša sa ŠTRUKTÚRA:**
> vrstvenie *(spec → objekty → fixtúry → helpery)* · zákaz god-class ·
> jeden zdroj importu · pomenovanie testu slovesnou frázou, nie podstatným menom ·
> maximálne dve úrovne zanorenia · značky namiesto prefixov v názve.
>
> `reference/` čítaj ako **ukážku tvaru**, nie ako kód na skopírovanie.

## Meta *(2)*

| | kedy |
| --- | --- |
| `brainstorming` | keď má rozhodnutie **viac ciest** — napr. kadiaľ zaviesť bránu do 22 repozitárov |
| `writing-skills` | keď budeš písať vlastný skill alebo inštrukcie pre tím |

---

# Čo v balíku NIE JE — a prečo

**Zlý stack** *(11)* — `check-dependencies` **(npm/Node, my sme Gradle)** ·
`db-review` *(Supabase/RLS)* · `sql-validation-mssql-pg` **(nesprávny pár enginov —
presne to, pred čím nový skill varuje)** · `modern-python` · `supabase` ·
`supabase-postgres-best-practices` · `powersync-supabase-setup` · `codeql` · `semgrep` ·
`ecommerce-testing-patterns` · `robust-stateful-frontend`

**UI, ktoré sa nedá preniesť** *(9)* — `playwright-skill` · `playwright-form-quirks` ·
`playwright-stealth` · `pom-design` · `check-selectors` · `check-accessibility` ·
`documenting-ui-components` · `fixture-architecture` · `api-mocking`

**Prevod formátu / obal nad nástrojom** *(6)* — `docx` · `pdf` · `pptx` · `xlsx` ·
`mcp-cli` · `sarif-parsing`

**Mimo rozsahu zákazky** *(12)* — `go-live-gate` · `plan-migration` · `design-schema` ·
`deep-module-refactor` · `benchmark-performance` · `performance-analysis` ·
`mail-catcher` · `sms-catcher` · `clean-room-reimplementation` ·
`secure-agent-architecture` · `subagent-driven-development` · `dispatching-parallel-agents`

**Už pokryté destilovanými pravidlami** *(8)* — `test-driven-development` ·
`test-strategy` · `review-code` · `requesting-code-review` · `generate-test-data` ·
`generate-documentation` · `comment-discipline` · `ubiquitous-language`

**Prevádzka** *(5)* — `writing-plans` · `executing-plans` · `using-git-worktrees` ·
`finishing-a-development-branch` · `reality-check` · `generate-ci-pipeline`

---

## Poznámka k `fixture-architecture` a `api-mocking`

Obidva som pôvodne zaradil a **obidva som vyradil až pri kontrole popisov.**
Sú písané pre Playwright (`page.route()`, `test/worker` scope) a do Java/JUnit
sa neprenášajú. Šiel som podľa toho, čo si o nich pamätám, nie podľa toho, čo v nich stojí —
tá istá chyba, ktorá predtým chytila `check-dependencies`.
