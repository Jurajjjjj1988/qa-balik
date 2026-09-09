---
name: generate-ci-pipeline
description: Generates a CI/CD pipeline YAML — GitHub Actions, GitLab CI or Azure DevOps — with lint, type-check, test, build, security-scan and deploy stages, caching, parallelization, SHA-pinned actions and least-privilege permissions; validates the output. Use when creating or updating a CI workflow file. Triggers on "CI pipeline", "GitHub Actions", "GitLab CI", "Azure DevOps", "azure-pipelines.yml", "ADO pipeline", "PublishTestResults", "workflow YAML", "CI/CD". Do not use for running an existing pipeline or for build-tooling config (Makefile, npm scripts).
argument-hint: [project type]
allowed-tools: Read, Grep, Glob, Bash(npx yaml-lint *), Bash(npm install *)
---

Before starting:
```
npx --yes yaml-lint --version 2>/dev/null || true   # npx fetches transiently; no global install
```

Generate CI/CD pipeline:

Stages: Install → Lint → Type Check → Test → Build → Security scan → Deploy

Rules:
- **Least privilege:** top-level `permissions: {}`, elevate per-job only what's needed (the default token is broad-write).
- **Pin actions to a full commit SHA, never a tag** — a hijacked tag (tj-actions/changed-files, Mar 2025) exfiltrated `GITHUB_TOKEN`.
- **Caching:** do NOT cache `node_modules`; use `actions/setup-node` with `cache: 'npm'` keyed on the lockfile + `npm ci`. Cache Playwright browsers separately (`~/.cache/ms-playwright`).
- **Keyless deploy:** OIDC to the cloud provider instead of long-lived secrets; other secrets via env, never hardcoded.
- **Security stage:** SAST + dependency/SCA scan + secret scan as required checks.
- Parallel jobs where possible; fail fast (lint/type-check before tests); headless tests.

## Azure DevOps (`azure-pipelines.yml`)

Rovnaké fázy, ale tri veci sú inak — a všetky tri tichnú namiesto toho, aby padli.

- 🔴 **`PublishTestResults@2` defaultne NEZHODÍ build.** `failTaskOnFailedTests`,
  `failTaskOnMissingResultsFile` aj `failTaskOnFailureToPublishResults` sú **default `false`**
  (dokumentácia Microsoftu). Padnuté testy sa teda len zobrazia a pipeline je zelená.
  Nastav všetky tri na `true` — a **aj tak to nestačí**: prázdny report (`<testsuites/>`) je pre
  task korektný vstup, takže nad ním musí byť **vlastná brána na počty** (spustených testov > 0).
- 🔴 **Tasky sa nedajú pinovať na SHA**, len na major verziu (`@2`). Na rozdiel od GitHub Actions
  tu ekvivalent SHA-pinu neexistuje — priznaj to ako zvyškové riziko, nepredstieraj ochranu.
  Pri kritických krokoch radšej `script:` s vlastným príkazom než cudzí task.
- **Least privilege inak:** ADO nemá `permissions:` blok. Ekvivalent je *Project Settings →
  Pipelines → Settings*: vypnúť „Allow scripts to access the OAuth token" tam, kde netreba,
  obmedziť *Pipeline permissions* na service connections a obmedziť rozsah `System.AccessToken`.
- **Tests tab ≠ Test Plans.** Tests tab v behu naplní `PublishTestResults@2` z JUnit/TRX.
  **Azure Test Plans sa nespoja samy** — treba mapovanie test case ID na automatizovaný test.
  Nesľubuj „výsledky budú v Test Plans", kým to mapovanie neexistuje.
- **Secrety:** variable group napojená na Key Vault, alebo secret variables. **Nikdy PAT v YAML.**
  Pozor na časovanie expanzie: `${{ }}` sa vyhodnotí pri kompilácii, `$(var)` za behu,
  `$[ ]` pri spustení — secret vložený cez `${{ }}` skončí v logu.
- **Artefakty nesú dáta.** Playwright trace, screenshoty a JSON reporty API klientov obsahujú
  telá odpovedí a hlavičky (teda aj `Authorization`). Ak prostredie nie je anonymizované,
  publikovanie artefaktu je šírenie tých dát — filtruj pri generovaní, nie až pri publikovaní.
- **Self-hosted agent ≠ hosted.** Ráta s tým, že nemá internet, ide cez proxy alebo má TLS
  inšpekciu. `npm install -g` a `npx` z verejného registra tam zlyhajú alebo siahnu inam;
  inštaluj z locku (`npm ci`) a nástroje pripni verziou.
- **Žiadne `|| true` ani `continueOnError: true` na kroku brány.** Buď smie zhodiť build,
  alebo to nie je brána a nesmie sa tak volať v dokumentácii.

## Brána musí vedieť padnúť — dokáž to

Vygenerovaná pipeline nie je hotová, kým si ju nevidel sčervenieť. Zámerne pokaz jeden test,
pusti beh, over červenú, vráť to, over zelenú. Brána, ktorá nikdy nepadla, nechráni nič —
a od funkčnej sa zvonku nedá odlíšiť.

After generating, validate:
```
npx yaml-lint .github/workflows/*.yml       # GitHub Actions
npx yaml-lint azure-pipelines.yml           # Azure DevOps
```

Fix if invalid. Pozn.: yaml-lint overí len syntax YAML, nie schému pipeline —
platný YAML s neplatným vstupom tasku prejde. Schému overí až skutočný beh.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Videl som tento pipeline sčervenieť na zámerne pokazenom teste v SKUTOČNOM behu — alebo len prejsť cez `yaml-lint`?
