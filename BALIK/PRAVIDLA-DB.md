# Pravidlá pre prácu s databázou

> ⚠️ **Tu sú DVA rôzne enginy:** lokálne **MySQL**, ale dev/QA/prod **Azure SQL Server**.
> Tá istá validačná query môže na oboch znamenať niečo iné — a **nič nespadne**.
> Zvonku sa to nedá odlíšiť od fungujúceho testu.

---

## 1. 🔴 Čo NEPRENÁŠAJ z iných projektov

V mojich starších poznámkach sú namerané rozdiely **MSSQL ↔ PostgreSQL**.
**Tento projekt je MySQL ↔ SQL Server. Nie je to to isté.**

Konkrétne **NEPLATIA** tu tieto dva, hoci sa často opakujú:
- ❌ *„NULL ordering je opačný"* — to je MSSQL↔PG
- ❌ *„jeden engine je case-sensitive, druhý nie"* — obidva sú predvolene case-insensitive

**Preniesť nameraný fakt cez hranicu, na ktorej sa nemeral, je tá istá chyba
ako odvodenie vydané za meranie.**

---

## 2. Rozdiely — NAMERANÉ, nie prečítané

> Zmerané 2026-09-09 na **MySQL 9.7.2** (`utf8mb4_0900_ai_ci`) a **SQL Server 2022**
> (`SQL_Latin1_General_CP1_CI_AS`), na stĺpcoch s výslovnou collation.
> Sonda: `sql-validation-mysql-mssql` skill.
> ⚠️ **Ale zmeraj to na SVOJICH inštanciách** — collation je vlastnosť databázy a stĺpca,
> nie produktu, a Azure SQL sa pri založení dá nastaviť inak než default obrazu.

| | MySQL | SQL Server | bolí to? |
| --- | :---: | :---: | --- |
| `'abc' = 'ABC'` | rovnaké | rovnaké | nie — obidva case-insensitive |
| **`'Kovac' = 'Kováč'`** | **ROVNAKÉ** | **RÔZNE** | 🔴 **áno** |
| `'abc' = 'abc  '` | **RÔZNE** | **ROVNAKÉ** | 🔴 áno |
| `NULL` v `UNIQUE` stĺpci | **koľkokoľvek** | **presne jeden** | 🔴 áno |
| `NULL` v `ORDER BY ASC` | prvé | prvé | nie — zhodné |
| `ROUND(2.5)` na `DECIMAL` | 3 | 3 | nie |
| **`ROUND(2.5)` na `FLOAT`** | **2** | **3** | 🔴 **áno** |
| `ROUND(0.5)` na `FLOAT` | **0** | **1** | 🔴 áno |
| `OFFSET` bez `ORDER BY` | prejde | **odmietnuté** | áno |

### 🔴 Diakritika je tu najdrahšia

```sql
SELECT * FROM zakaznik WHERE priezvisko = 'Kovac';
```

Lokálne nájde **`Kováč`**. V QA **nenájde nič**. Pri slovenských dátach to nie je
okrajový prípad — je to väčšina mien, adries a názvov.

**Dôsledok, ktorý nikto nečaká:** test na duplicitné priezviská **prejde v oboch
prostrediach** — lokálne preto, že duplicitu našiel, v QA preto, že ju nenašiel.
Zelená v oboch prípadoch, opačný význam.

### 🔴 `ROUND` na `FLOAT` je generátor peňažných chýb

MySQL zaokrúhľuje bankársky (`2.5 → 2`, `0.5 → 0`), SQL Server od nuly (`3`, `1`).
**Ten istý peňažný stĺpec, tá istá query, iný cent** — presne v polovici hraničných prípadov.
Na `DECIMAL` sa oba správajú rovnako.

→ **Pri peniazoch najprv zisti TYP stĺpca, nie engine.**

### `UNIQUE` + `NULL`

MySQL dovolí `NULL` koľkokoľvek, SQL Server **presne jeden** — druhý skončí
`Violation of UNIQUE KEY constraint`. Kód, ktorý sa spolieha na „viac NULLov je OK",
lokálne prejde a **v QA spadne**.

---

## 2b. 🔴 SONDA SAMA MÔŽE KLAMAŤ — namerané pri stavbe tohto pravidla

Prvý beh sondy nad MySQL vrátil **dve nesprávne hodnoty**:

| test | prvý beh | po oprave |
| --- | --- | --- |
| `'Kovac' = 'Kováč'` | 0 *(vyzerá accent-sensitive)* | **1** |
| `'abc' = 'abc  '` | 1 *(vyzerá PAD SPACE)* | **0** |

Dva dôvody, oba tiché:
1. **Literál používa collation SPOJENIA, nie databázy.** Porovnanie dvoch literálov
   nemeria stĺpec, ale klienta.
2. **Klient bez `--default-character-set=utf8mb4` znetvorí diakritiku** skôr,
   než sa porovnanie vôbec vykoná.

> **Meraj na STĹPCOCH s výslovnou collation, nikdy na dvoch literáloch.**
> A najprv over `HEX('Kováč')` = `4B6F76C3A1C48D`. Ak nesedí, celý výstup je na zahodenie.

## 3. Nemeraj z dokumentácie — zmeraj to

**Collation nie je vlastnosť „MySQL" ani „SQL Server".** Je to vlastnosť servera,
databázy a **stĺpca**, a dá sa prebiť per-query.

→ Veta *„SQL Server je case-insensitive"* je **nepoužiteľná ako fakt**.
Použiteľné je len to, čo vráti **tvoja** inštancia.

**Predtým, než napíšeš prvú validačnú query, spusti tú istú sondu na oboch
a porovnaj vedľa seba.** Každý riadok, kde sa líšia, je miesto, kde tá istá query
znamená niečo iné.

---

## 4. Ako písať validačné query, ktoré neklamú

- **Porovnanie reťazcov urob explicitným.** Nespoliehaj sa na default —
  normalizuj obe strany (`lower()`), alebo vynúť collation cez `COLLATE`.
- **Identifikátory drž konzistentne malé** alebo kvótuj.
- **Dáta si test vyrobí a upraceme sám** — cez API, ak sa dá *(prežije zmenu schémy)*.
  Cez SQL len keď cez API nejde. Unikátny kľúč na beh, **žiadne reálne osobné údaje.**
- **Čítaj až po commite.** Kontrola v tej istej transakcii vidí stav, ktorý nikdy nemusí nastať.
  Pri Spring testoch s `@Transactional` sa dáta na konci vracajú — validácia zvonku
  vtedy nenájde nič a vyzerá to ako chyba aplikácie.

---

## 5. 🔴 Nezávislý orákul

**Validácia cez ten istý `GET` endpoint, ktorý zápis vytvoril, NIE JE nezávislý orákul** —
porovnáva dva výstupy toho istého kódu.

Databáza je **silnejší pozorovací bod**: ukáže, čo naozaj zostalo, nie čo o tom povedalo API.
**Ale nie je to sudca správnosti hodnoty** — je to len iné miesto, kde vidno výstup toho istého kódu.

---

## 6. Peniaze v databáze

**Najprv zisti TYP stĺpca, nie engine.**
`float` / `double` v peňažnom stĺpci je **nález sám o sebe**, aj keby testy prechádzali —
zaokrúhľovanie sa riadi typom a líši sa presne v polovici hraničných prípadov.

---

## 7. Bezpečnosť

- **Connection string patrí do secret store**, nie do YAML a nie do repozitára.
- **Ak prostredie nie je anonymizované, výpis z databázy v logu testu je šírenie tých dát.**
  Toto nie je formalita — je to zmluvná povinnosť s lehotou na nahlásenie.


---

# Doplnené z overených postupov

### 5.1 Čo v databáze orákul JE: DDL (nie obsah tabuliek)

Constrainty v schéme QA/prod **Azure SQL** (`NOT NULL`, dĺžka, `UNIQUE`, `CHECK`, typ stĺpca) napísal človek mimo behu aplikácie — **proti nim sa dá súdiť aj bez doménového orákula.** Ku každej charakterizácii postav dve odpovede vedľa seba: **pripúšťa to schéma?** · **prijala to služba?**

Zhoda = OK · *pripúšťa + odmietla* = **schéma klame** · *zakazuje + prijala* = **chýba validácia** — a s `catch`-om, ktorý vráti náhradnú hodnotu, to zvonku vyzerá ako `200` s prázdnym telom.

⚠️ **Najprv over, že DDL nevzniká z `ddl-auto` ani z migrácie odvodenej z JPA entít.** Vtedy je to výstup toho istého kódu — mapa, nie sudca (PRAVIDLA-QA §3). Čítaj schému Azure SQL, nie lokálneho MySQL.

*Prečo tu: Doménový orákul neexistuje, ale Azure SQL Server schéma áno — je to jediný sudca správnosti, ktorý v tomto projekte je zadarmo a nie je výstupom toho istého kódu.*
