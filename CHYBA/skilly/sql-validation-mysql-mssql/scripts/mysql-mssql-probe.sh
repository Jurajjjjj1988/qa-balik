#!/usr/bin/env bash
# mysql-mssql-probe.sh — zmeraj, ako sa TVOJE inštancie správajú. Nehádaj z dokumentácie.
#
# Časť systému beží na MySQL (typicky lokálne), časť na SQL Serveri (dev/QA/prod).
# Tá istá validačná query dá na oboch iný výsledok — a rozdiel je TICHÝ: nič nespadne,
# len test prestane chytať to, čo si myslíš.
#
# Najdrahší z nich: MySQL je predvolene accent-INsensitive, SQL Server accent-SENSITIVE.
# `WHERE priezvisko = 'Kovac'` teda lokálne nájde `Kováč` a v QA nenájde nič.
#
# 🔴 SONDA SAMA MÔŽE KLAMAŤ. Literál používa collation SPOJENIA, nie databázy, a klient
# bez utf8mb4 znetvorí diakritiku skôr, než sa porovnanie vykoná. Preto tento skript
# NAJPRV dokáže, že jeho vlastné spojenie je v poriadku, a až potom meria — na STĹPCOCH
# s výslovnou collation, nikdy na dvoch literáloch.
#
# Použitie:
#   mysql-mssql-probe.sh mysql  <host> <port> <user> <heslo> [db]
#   mysql-mssql-probe.sh mssql  <host,port> <user> <heslo> [db]
#   mysql-mssql-probe.sh mysql-docker <nazov-kontajnera> <user> <heslo> [db]
#   mysql-mssql-probe.sh mssql-docker <nazov-kontajnera> <user> <heslo> [db]
#
# Exit kódy:  0 = zmerané   1 = chyba spojenia   2 = zlé argumenty
#             3 = SONDA NEDÔVERYHODNÁ (self-check zlyhal, výstup je na zahodenie)
set -uo pipefail

MODE="${1:-}"
case "$MODE" in mysql|mssql|mysql-docker|mssql-docker) ;; *) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;; esac

BLD=$'\033[1m'; OFF=$'\033[0m'; RED=$'\033[31m'; GRN=$'\033[32m'
row() { printf '  %-32s %s\n' "$1" "$2"; }
hdr() { printf '\n%s%s%s\n' "$BLD" "$*" "$OFF"; }

case "$MODE" in
  mysql)        H="${2:-}"; P="${3:-3306}"; U="${4:-}"; W="${5:-}"; D="${6:-}"
                q(){ mysql -h"$H" -P"$P" -u"$U" -p"$W" ${D:+-D"$D"} --default-character-set=utf8mb4 -N -B -e "$1" 2>/dev/null | tr '\t\n' '  ' | sed 's/ *$//'; } ;;
  mysql-docker) C="${2:-}"; U="${3:-}"; W="${4:-}"; D="${5:-}"
                q(){ docker exec -i "$C" mysql -u"$U" -p"$W" ${D:+-D"$D"} --default-character-set=utf8mb4 -N -B -e "$1" 2>/dev/null | tr '\t\n' '  ' | sed 's/ *$//'; } ;;
  mssql)        H="${2:-}"; U="${3:-}"; W="${4:-}"; D="${5:-master}"
                q(){ sqlcmd -S "$H" -U "$U" -P "$W" -d "$D" -C -h -1 -W -Q "SET NOCOUNT ON; $1" 2>/dev/null | grep -v '^$' | tr '\n' ' ' | sed 's/ *$//'; } ;;
  mssql-docker) C="${2:-}"; U="${3:-}"; W="${4:-}"; D="${5:-master}"
                q(){ docker exec "$C" /opt/mssql-tools18/bin/sqlcmd -S localhost -U "$U" -P "$W" -d "$D" -C -h -1 -W -Q "SET NOCOUNT ON; $1" 2>/dev/null | grep -v '^$' | tr '\n' ' ' | sed 's/ *$//'; } ;;
esac
IS_MYSQL=0; case "$MODE" in mysql|mysql-docker) IS_MYSQL=1 ;; esac

# ───────────────────────────────────────────────── 0. SELF-CHECK
hdr "0. Dôveryhodnosť sondy — bez tohto sa zvyšku neverí"
if [ "$IS_MYSQL" = 1 ]; then
  LIVE=$(q "SELECT 1"); HEXV=$(q "SELECT HEX('Kováč')")
else
  LIVE=$(q "SELECT 1"); HEXV=$(q "SELECT CONVERT(VARCHAR(64), CONVERT(VARBINARY(64), N'Kováč'), 2)")
fi
[ "$LIVE" = "1" ] || { echo "${RED}spojenie nefunguje${OFF}"; exit 1; }
if [ "$IS_MYSQL" = 1 ]; then
  EXP="4B6F76C3A1C48D"; row "HEX('Kováč')" "$HEXV"
  if [ "$HEXV" != "$EXP" ]; then
    echo "${RED}  ✗ SONDA NEDÔVERYHODNÁ: čakal som $EXP${OFF}"
    echo "${RED}    Klient znetvoril diakritiku. Celý zvyšok by bol na zahodenie.${OFF}"; exit 3
  fi
  row "" "${GRN}✓ kódovanie klienta je v poriadku${OFF}"
else
  row "UTF-16 HEX N'Kováč'" "$HEXV"; row "" "${GRN}✓ (NVARCHAR, nie VARCHAR — pozri nižšie)${OFF}"
fi

# ───────────────────────────────────────────────── 1. COLLATION
hdr "1. Predvolená collation"
if [ "$IS_MYSQL" = 1 ]; then
  row "databázy"  "$(q "SELECT @@collation_database")"
  row "spojenia"  "$(q "SELECT @@collation_connection")"
else
  row "servera"   "$(q "SELECT CAST(SERVERPROPERTY('Collation') AS VARCHAR(64))")"
  row "databázy"  "$(q "SELECT CAST(DATABASEPROPERTYEX(DB_NAME(),'Collation') AS VARCHAR(64))")"
fi

# ───────────────────────────────────────────────── 2. POROVNANIE NA STĹPCOCH
hdr "2. Porovnanie reťazcov — merané na STĹPCI, nie na literáloch"
if [ "$IS_MYSQL" = 1 ]; then
  MK="CREATE TEMPORARY TABLE _p (d VARCHAR(20)) CHARACTER SET utf8mb4; INSERT INTO _p VALUES ('Kovac');"
  row "veľkosť písmen ignoruje"  "$(q "$MK SELECT d='KOVAC' FROM _p")   (1 = áno)"
  row "diakritiku ignoruje"      "$(q "$MK SELECT d='Kováč' FROM _p")   (1 = áno → 'Kovac' nájde 'Kováč')"
  row "koncové medzery ignoruje" "$(q "CREATE TEMPORARY TABLE _s (v VARCHAR(20)) CHARACTER SET utf8mb4; INSERT INTO _s VALUES ('abc'); SELECT v='abc  ' FROM _s")   (1 = áno)"
else
  row "veľkosť písmen ignoruje"  "$(q "IF OBJECT_ID('tempdb..#p') IS NOT NULL DROP TABLE #p; CREATE TABLE #p (d NVARCHAR(20)); INSERT INTO #p VALUES (N'Kovac'); SELECT CASE WHEN d=N'KOVAC' THEN 1 ELSE 0 END FROM #p")   (1 = áno)"
  row "diakritiku ignoruje"      "$(q "IF OBJECT_ID('tempdb..#p') IS NOT NULL DROP TABLE #p; CREATE TABLE #p (d NVARCHAR(20)); INSERT INTO #p VALUES (N'Kovac'); SELECT CASE WHEN d=N'Kováč' THEN 1 ELSE 0 END FROM #p")   (1 = áno → 'Kovac' nájde 'Kováč')"
  row "koncové medzery ignoruje" "$(q "IF OBJECT_ID('tempdb..#s') IS NOT NULL DROP TABLE #s; CREATE TABLE #s (v NVARCHAR(20)); INSERT INTO #s VALUES (N'abc'); SELECT CASE WHEN v=N'abc  ' THEN 1 ELSE 0 END FROM #s")   (1 = áno)"
fi

# ───────────────────────────────────────────────── 3. UNIQUE + NULL
hdr "3. Koľko NULL znesie UNIQUE stĺpec"
if [ "$IS_MYSQL" = 1 ]; then
  row "vložených NULL" "$(q "CREATE TEMPORARY TABLE _u (c VARCHAR(10) UNIQUE); INSERT INTO _u VALUES (NULL),(NULL),(NULL); SELECT COUNT(*) FROM _u")   (3 = veľa, 1 = len jeden)"
else
  row "vložených NULL" "$(q "IF OBJECT_ID('tempdb..#u') IS NOT NULL DROP TABLE #u; CREATE TABLE #u (c NVARCHAR(10) UNIQUE); BEGIN TRY INSERT INTO #u VALUES (NULL); INSERT INTO #u VALUES (NULL); INSERT INTO #u VALUES (NULL); END TRY BEGIN CATCH END CATCH; SELECT COUNT(*) FROM #u")   (3 = veľa, 1 = len jeden)"
fi

# ───────────────────────────────────────────────── 4. NULL v ORDER BY
hdr "4. Poradie NULL v ORDER BY ASC"
if [ "$IS_MYSQL" = 1 ]; then
  row "poradie" "$(q "CREATE TEMPORARY TABLE _n (v INT); INSERT INTO _n VALUES (2),(NULL),(1); SELECT IFNULL(CAST(v AS CHAR),'NULL') FROM _n ORDER BY v ASC")"
else
  row "poradie" "$(q "IF OBJECT_ID('tempdb..#n') IS NOT NULL DROP TABLE #n; CREATE TABLE #n (v INT); INSERT INTO #n VALUES (2),(NULL),(1); SELECT ISNULL(CAST(v AS VARCHAR(5)),'NULL') FROM #n ORDER BY v ASC")"
fi

# ───────────────────────────────────────────────── 5. ZAOKRÚHĽOVANIE
hdr "5. Zaokrúhľovanie — riadi sa TYPOM, nie enginom  🔴 peniaze"
if [ "$IS_MYSQL" = 1 ]; then
  row "ROUND na DECIMAL 2.5/1.5/0.5" "$(q "SELECT ROUND(2.5), ROUND(1.5), ROUND(0.5)")"
  row "ROUND na DOUBLE  2.5/1.5/0.5" "$(q "SELECT ROUND(CAST(2.5 AS DOUBLE)), ROUND(CAST(1.5 AS DOUBLE)), ROUND(CAST(0.5 AS DOUBLE))")"
else
  row "ROUND na DECIMAL 2.5/1.5/0.5" "$(q "SELECT CAST(ROUND(CAST(2.5 AS DECIMAL(10,1)),0) AS VARCHAR(6)) + ' ' + CAST(ROUND(CAST(1.5 AS DECIMAL(10,1)),0) AS VARCHAR(6)) + ' ' + CAST(ROUND(CAST(0.5 AS DECIMAL(10,1)),0) AS VARCHAR(6))")"
  row "ROUND na FLOAT   2.5/1.5/0.5" "$(q "SELECT CAST(ROUND(CAST(2.5 AS FLOAT),0) AS VARCHAR(6)) + ' ' + CAST(ROUND(CAST(1.5 AS FLOAT),0) AS VARCHAR(6)) + ' ' + CAST(ROUND(CAST(0.5 AS FLOAT),0) AS VARCHAR(6))")"
fi
row "" "porovnaj oba enginy — ak sa FLOAT líši, peňažný stĺpec typu FLOAT je nález"

# ───────────────────────────────────────────────── 6. STRÁNKOVANIE
hdr "6. Stránkovanie bez ORDER BY"
if [ "$IS_MYSQL" = 1 ]; then
  row "LIMIT bez ORDER BY" "$(q "SELECT 'PRESLO' FROM (SELECT 1 AS a UNION SELECT 2) t LIMIT 1")   (prázdne = odmietnuté)"
else
  row "OFFSET/FETCH bez ORDER BY" "$(q "BEGIN TRY EXEC('SELECT * FROM (VALUES(1),(2)) t(a) OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY'); SELECT 'PRESLO' END TRY BEGIN CATCH SELECT 'ODMIETNUTE' END CATCH")"
fi

hdr "Hotovo"
echo "  Spusti to na OBOCH inštanciách a porovnaj vedľa seba."
echo "  Každý riadok, kde sa líšia, je miesto, kde tá istá query znamená niečo iné."
