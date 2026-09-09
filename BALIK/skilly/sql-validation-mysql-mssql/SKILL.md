---
name: sql-validation-mysql-mssql
description: >-
  Use when part of a system runs on MySQL and part on SQL Server — typically MySQL locally and
  Azure SQL Server in dev, QA and production — and something behaves differently without anything
  failing. Symptoms: a WHERE that finds a row locally but not in QA; a name with diacritics that
  matches on one engine and not the other; a duplicate check that passes in both environments
  while meaning opposite things; a second NULL silently accepted locally and rejected in QA; a
  money amount a cent different between environments; a paging query that runs locally and errors
  in QA. Also for SQL that validates what an API actually wrote, and for migrations between them. Load it because the confident
  answer here is usually wrong in a specific way, and because the differences that bite are not
  the ones people expect: NULL ordering and case sensitivity are NOT differences here — that lore
  comes from SQL Server versus PostgreSQL and must not be carried over. Ships a probe battery that
  MEASURES the real differences on your own instances and that first proves its own connection is
  not lying — a client with the wrong charset reports the opposite of the truth. Triggers on "MySQL", "SQL Server", "Azure SQL", "collation", "diacritics", "accent",
  "utf8mb4", "NO PAD", "UNIQUE NULL", "same query different result", "works locally fails in QA",
  "rounding differs", "OFFSET FETCH", "validate in the DB". Do not use for SQL Server versus
  PostgreSQL — that is sql-validation-mssql-pg.
---

# Validácia dát cez SQL naprieč MySQL a SQL Serverom

## Spusti — najprv sondu, potom čítaj

**Nečítaj zdroj sondy. Spusti ju s `--help` a potom naostro.**

```
scripts/mysql-mssql-probe.sh mysql-docker  <kontajner> <user> <heslo> [db]
scripts/mysql-mssql-probe.sh mssql-docker  <kontajner> <user> <heslo> [db]
scripts/mysql-mssql-probe.sh mysql  <host> <port> <user> <heslo> [db]
scripts/mysql-mssql-probe.sh mssql  <host,port> <user> <heslo> [db]
```

| exit | znamená |
| :---: | --- |
| **0** | zmerané — porovnaj oba výstupy vedľa seba |
| **1** | spojenie nefunguje |
| **2** | zlé argumenty *(vypíše návod)* |
| **3** | 🔴 **SONDA NEDÔVERYHODNÁ** — klient znetvoril diakritiku. **Celý zvyšok výstupu je na zahodenie.** |

**Spusti ju na OBOCH inštanciách.** Každý riadok, kde sa líšia, je miesto,
kde tá istá query znamená niečo iné.

## Prečo vôbec siahať do databázy z testu

Databáza je najsilnejší **pozorovací bod** pre API test: ukáže, čo naozaj ostalo,
nie čo o tom povedalo API. Test, ktorý overí odpoveď a potom to isté prečíta cez GET,
porovnáva výstup toho istého kódu — a je slepý na chybu, ktorá je v oboch.

⚠️ Pozorovací bod, **nie orákul**. Obsah databázy je stále výstup testovaného kódu.
O tom, či je hodnota SPRÁVNA, nehovorí nič.

## 🔴 Trieda, ktorá to celé kazí: tichý rozdiel

Tá istá validačná query dá na dvoch enginoch iný výsledok. **Nič nespadne** — len test
prestane chytať to, čo si myslíš. Zvonku sa to nedá odlíšiť od fungujúceho testu.

## 🔴 A trieda o poschodie vyššie: SONDA SAMA MÔŽE KLAMAŤ

**Namerané pri stavbe tohto skillu.** Prvý beh sondy nad MySQL 9.7.2 vrátil:

| test | prvý beh | po oprave |
| --- | --- | --- |
| `'Kovac' = 'Kováč'` | **0** *(vyzerá accent-sensitive)* | **1** *(je accent-insensitive)* |
| `'abc' = 'abc  '` | **1** *(vyzerá PAD SPACE)* | **0** *(je NO PAD)* |

**Obe hodnoty z prvého behu boli nesprávne.** Dva dôvody, oba tiché:

1. **Literál používa collation SPOJENIA, nie databázy.** Porovnanie dvoch literálov
   nemeria stĺpec, ale klienta.
2. **Klient bez `--default-character-set=utf8mb4` znetvorí diakritiku** skôr, než sa
   porovnanie vôbec vykoná.

> **Preto sonda musí najprv dokázať, že neklame** — a až potom sa jej výsledkom verí.
> Meraj **na stĺpcoch s výslovnou collation**, nikdy na dvoch literáloch.

Kontrola, ktorá to zachytí: `HEX('Kováč')` musí vrátiť **`4B6F76C3A1C48D`** (7 bajtov, 5 znakov).
Ak vráti niečo iné, **celý zvyšok výstupu je na zahodenie.**

---

## Čo je NAMERANÉ — MySQL 9.7.2 vs SQL Server 2022

Predvolené collation: `utf8mb4_0900_ai_ci` vs `SQL_Latin1_General_CP1_CI_AS`.

| | MySQL | SQL Server | bolí to? |
| --- | :---: | :---: | --- |
| `'abc' = 'ABC'` | **rovnaké** | **rovnaké** | nie — obidva CI |
| `'Kovac' = 'Kováč'` | **ROVNAKÉ** | **RÔZNE** | 🔴 **áno** |
| `'abc' = 'abc  '` | **RÔZNE** | **ROVNAKÉ** | 🔴 áno |
| `NULL` v `UNIQUE` stĺpci | **koľkokoľvek** | **presne jeden** | 🔴 áno |
| `NULL` v `ORDER BY ASC` | **prvé** | **prvé** | nie — zhodné |
| `ROUND(2.5)` na `DECIMAL` | 3 | 3 | nie |
| **`ROUND(2.5)` na `FLOAT`** | **2** | **3** | 🔴 **áno** |
| `ROUND(0.5)` na `FLOAT` | **0** | **1** | 🔴 áno |
| `OFFSET` bez `ORDER BY` | dovolené | **odmietnuté** | áno |
| `'' IS NULL` | nie | nie | nie |

### 🔴 Diakritika je tu ten najdrahší rozdiel

MySQL predvolene **`ai`** = accent-insensitive. SQL Server predvolene **`AS`** = accent-sensitive.

```sql
SELECT * FROM zakaznik WHERE priezvisko = 'Kovac';
```

Lokálne nájde **`Kováč`**. V QA **nenájde nič**. Pri slovenských dátach to nie je okrajový prípad —
je to väčšina mien, adries a názvov.

**Dôsledok, ktorý nikto nečaká:** test na duplicitné priezviská **prejde na oboch** —
lokálne preto, že duplicitu našiel, v QA preto, že ju nenašiel. Zelená v oboch prípadoch,
opačný význam.

### 🔴 `ROUND` na `FLOAT` je generátor peňažných chýb

**Namerané:** ten istý `ROUND` nad `FLOAT`/`DOUBLE`:

| hodnota | MySQL | SQL Server |
| --- | :---: | :---: |
| `2.5` | **2** *(bankárske, half-to-even)* | **3** *(half away from zero)* |
| `1.5` | 2 | 2 |
| `0.5` | **0** | **1** |

Ten istý peňažný stĺpec, tá istá query, **iný cent** — a to presne v polovici hraničných prípadov.
Na `DECIMAL` sa oba správajú rovnako *(half away from zero)*.

→ **Pri peniazoch najprv zisti TYP stĺpca, nie engine.** `FLOAT`/`DOUBLE` v peňažnom stĺpci
je **nález sám o sebe**, aj keby testy prechádzali.

### `UNIQUE` + `NULL`

MySQL dovolí `NULL` **koľkokoľvek**. SQL Server **presne jeden** — druhý skončí
`Violation of UNIQUE KEY constraint`.

→ Kód, ktorý sa spolieha na „viac NULLov je v poriadku", lokálne prejde a **v QA spadne**.
A migračný skript, ktorý lokálne naimportuje dáta, v QA na tom istom vstupe zlyhá.

---

## 🔴 Čo NEPRENÁŠAJ zo SQL Server ↔ PostgreSQL

Pri tej dvojici sú namerané rozdiely v **NULL ordering** a v **case sensitivity**.
**Tu ani jeden neplatí:**

- ❌ *„NULL ordering je opačný"* — namerané: **na oboch NULL prvé**
- ❌ *„jeden je case-sensitive"* — namerané: **oba predvolene case-INsensitive**

**Preniesť nameraný fakt cez hranicu, na ktorej sa nemeral, je tá istá chyba
ako odvodenie vydané za meranie.**

---

## Ako písať validačné query, ktoré neklamú

- **Porovnanie reťazcov urob explicitným.** Normalizuj obe strany, alebo vynúť collation:
  `COLLATE utf8mb4_0900_as_cs` / `COLLATE Latin1_General_CS_AS`.
  *(`lower()` na oboch stranách zabije index — v teste to nevadí, v produkcii áno.)*
- **Pri diakritike sa rozhodni vedome**, či chceš `Kovac` = `Kováč`. Nenechaj to na default,
  lebo default je v každom prostredí iný.
- **`ORDER BY` vždy explicitne**, a nikdy `LIMIT 1` / `TOP 1` bez neho.
  Na SQL Serveri `OFFSET…FETCH` bez `ORDER BY` **neprejde vôbec** — to je dobrá správa,
  chyba sa prejaví. Na MySQL prejde a vráti ľubovoľný riadok.
- **Identifikátory drž konzistentne malé.** MySQL rozlišuje veľkosť názvov tabuliek podľa
  súborového systému *(na Linuxe áno, na macOS nie)* — to je zdroj „u mňa to ide".
- **Dáta si test vyrobí a upraceme sám**, cez API ak sa dá *(prežije zmenu schémy)*.
  Unikátny kľúč na beh, **žiadne reálne osobné údaje**.
- **Čítaj až po commite.** Pri Spring testoch s `@Transactional` sa dáta na konci vracajú —
  validácia zvonku vtedy nenájde nič a vyzerá to ako chyba aplikácie.

## Prevádzkové poznámky

- Obraz SQL Servera je **amd64-only**. Na Apple Silicon beží pod emuláciou
  (`--platform linux/amd64`). **Emulácia mení výkon, nie sémantiku dialektu** —
  collation, zaokrúhľovanie a `UNIQUE` odtiaľ merať môžeš; časy nie.
- **Azure SQL Database nie je to isté ako SQL Server v kontajneri.** Collation databázy
  sa pri založení dá nastaviť inak než default. **Zmeraj cieľovú databázu, nie obraz.**
- Klienti bez inštalácie: `docker exec` do kontajnera. `mysql` klient **vždy**
  s `--default-character-set=utf8mb4`.

## Anti-vzory

- **Merať porovnanie na dvoch literáloch.** Meriaš klienta, nie stĺpec.
- **Veriť sonde, ktorá si neoverila vlastné kódovanie.**
- **„MySQL je accent-insensitive" ako fakt v teste.** Je to vlastnosť konkrétnej collation
  konkrétneho stĺpca a dá sa prebiť per-query.
- **Peňažná kontrola nad `FLOAT`** bez toho, aby si typ overil.
- **Validácia cez ten istý `GET`, ktorý zápis vytvoril** — to nie je nezávislý orákul.
- **Prenášať rozdiely z inej dvojice enginov.**

## Súvisiace

`sql-validation-mssql-pg` (iná dvojica, iné rozdiely) · `check-api-contract` ·
`test-layers-money-critical` (peňažná matematika) · `characterization-tests` (nezávislý orákul)

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Dokázala sonda najprv, že sama neklame — HEX('Kováč') sedí a meria sa na stĺpci s výslovnou collation, nie na dvoch literáloch?
