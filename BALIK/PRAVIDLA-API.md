# Pravidlá pre API testy

> Destilované z overených postupov. Každé pravidlo sa dá použiť **bez doménového orákula** —
> teda aj keď nikto nevie, aká hodnota je správna.


---

## Trieda chyby je súčasť kontraktu — `500` za vstup klienta je defekt

`4xx` hovorí „oprav to ty", `5xx` hovorí „chyba je naša, skús znova". **`500` za neplatný vstup prikazuje klientovi opakovať request, ktorý nemôže nikdy prejsť** — a validačnú chybu pochová do grafu výpadkov, kde ju triedia ako incident.

Pošli na endpoint zámerne neplatný vstup (chýbajúce povinné pole, text namiesto čísla, prekročená dĺžka, pokazený dátum) a **rozlíš tri výsledky:** `4xx` = správne · `5xx` = defekt · `2xx` s prázdnym telom = prehltnutá chyba *(druhá polovica tej istej triedy, `PRAVIDLA-QA.md` §2)*.

Defektom kontraktu je aj **výnimka frameworku, ktorá dorazí ku klientovi** — `ConstraintViolationException`, `NullPointerException`, stack trace v tele — **bez ohľadu na stavový kód vedľa nej**; navyše je to únik vnútra služby von.

Ani jedno nepotrebuje doménového orákula: tvrdíš **tvar odpovede**, nie správnu hodnotu. **Meraj z odpovede, nie z prečítaného kódu**, a nález zapíš do `NALEZY.md` — nie do testu ako požehnané správanie.

*Prečo tu: 296 miest s prehltnutou chybou je jeden smer; nezachytená výnimka je druhý. Ani jeden nepotrebuje na dôkaz doménového experta.*

---

## 11. Hranica sa neskúša len po okrajoch — validačné vrstvy sú dve

Povolený rozsah čítaj z `@Size` / `@Pattern` a z typu stĺpca, nie z jedného skúšobného volania.
Ku každej hranici pridaj **aspoň tri hodnoty zvnútra** — pri rozsahu `1–20` napríklad `1, 5, 9, 11`.
Bean Validation vráti `400`, ale hlbšia vrstva (regex v službe, constraint v DB) hodí `500`,
takže kto skúša len `min−1 / min / max / max+1`, nájde prvú vrstvu a druhú prehliadne.
Je to opačná polovica triedy „`catch` vráti náhradnú hodnotu": **stavový kód klame v oboch smeroch.**
⚠️ **ZMERANÉ na `spring-petclinic-rest`, NIE v tomto estate** — tu je to hypotéza na overenie, nie fakt.

*Prečo tu: Spring Boot: Bean Validation vracia 400, hlbšia vrstva (DB constraint, regex v službe) hádže 500. Estate má 296 miest, kde sa chyba prekrúca — toto je jej opačná polovica.*

---

## Kontrakt sa dokazuje v OBOCH smeroch — rozpor je nález aj bez orákula

Ku každému poľu polož vedľa seba spec a službu: **platné → odmietnuté** = spec klame (klient vygenerovaný zo Swaggeru posiela to, čo služba neberie); **neplatné → prijaté** = chýba validácia.
Dokazuješ **nezhodu**, nie ktorá strana má pravdu — preto nález píš ako „spec a služba si protirečia", nikdy ako „hodnota je zlá".
⚠️ Špecifikácia generovaná z kódu je mapa toho istého kódu → smer „spec klame" v ňom neplatí.
Smer „neplatné → prijaté" platí aj tam — ale tu sa **prejaví ako `200` s prázdnym telom**, nie ako `400`.
Preto bunky „prijaté/odmietnuté" urči **efektom na druhom pozorovacom bode**, nikdy stavovým kódom.

*Prečo tu: Doménový orákul neexistuje — toto je jediný typ tvrdenia o správnosti, ktorý sa dá bez neho dokázať. 417 endpointov, časť s publikovaným kontraktom.*

---

## Rež na dvoch osiach — po umiestnení aj po zámere

Rez po repozitári nájde objem; rozpor nájde len rez po **zámere**: vyber pojem (kontrola role · `catch`, ktorý vracia náhradnú hodnotu · dátumový výraz · zaokrúhlenie sumy · porovnanie reťazca), zgrepuj ho naprieč **všetkými** repozitármi do jedného zoznamu a čítaj ten zoznam vedľa seba.

Grepuj **výskyt pojmu, nie deklaráciu** — nezabalená kópia má najostrejšie rozdiely. Autorizačné predikáty tu žijú pod rôznymi lokálnymi menami, takže hľadať jedno meno znamená nenájsť nič a vyhlásiť to za čisté.

Vždy vypíš **menovateľ**: cez čo si grepoval a čo si vylúčil. Nula výskytov = **DIERA**, nie PASS.

Rozdiel nájdený čítaním je **kandidát do `NALEZY.md`**, nie nález — dokáže ho až spustený request.

*Prečo tu: 403 zo 417 endpointov nemá kontrolu oprávnení na vstupnom bode; autorizačné predikáty pod rôznymi lokálnymi menami sa dajú porovnať len rezom po zámere naprieč repozitármi.*

---

## Pole, ktoré prechádza hranicu repozitára, grepni cez celý estate

Cez hranicu 22 repozitárov nekontroluje kompilátor nič: producent zmení pole, konzument
v inom repe parsuje starý tvar, **oba commity sú samy osebe správne** — a von ide `200`
s prázdnym telom (viď „prehltnutá chyba"), nie `5xx`.
**Pri každej zmene DTO, JSON payloadu, exportu alebo DB stĺpca** grepni presný názov poľa
(aj alias z `@JsonProperty`) cez **všetky** repozitáre a každý zásah over zvlášť — tvrdením
o **hodnote poľa u konzumenta**, nie o stavovom kóde. **Nula zásahov = DIERA**, nie čisto.

*Prečo tu: 296 miest (24 %), kde catch vracia náhradnú hodnotu, × 22 repozitárov × 417 endpointov — presne táto kombinácia premení švíkovú chybu na tichú zelenú.*

---

## Klon v ostatných repozitároch — defekt nezatváraj, kým ho tam nepohľadáš

- Potvrdený defekt zatvor až po grepe tej istej deklarácie (konštanta, validácia, query, mapper) **vo všetkých repozitároch v `~/work`**, nie len v tom, kde si ho našiel.
- **Vypíš rozsah grepu** — cez čo, s vylúčením čoho. Bez neho je „nikde inde to nie je" nerozlíšiteľné od „hľadal som zle"; **nula zásahov hlás ako DIERU**, nie ako čisto.
- Že sa kópie rozišli, je **ODVODENÉ**, kým ich nepoložíš vedľa seba. Rozdiely ulož do meraní, opravu si vyžiada každý repozitár zvlášť.
- Kópia, ktorá je dnes identická, nie je defekt — je miesto, kde sa budúce opravy rozídu. **Zapíš ju do `NALEZY.md` aj tak.**

*Prečo tu: 22 samostatných repozitárov, jeden človek, odovzdanie o 2 mesiace — oprava v jednom repe nechá 21 nedotknutých a nikto to nezbadá.*

---

# Tvar chybovej odpovede je merateľný invariant

- **Zmeraj tvar:** na povolených endpointoch vyvolaj chybu (chýbajúci povinný parameter, zlý typ) a zapíš **stavový kód · `Content-Type` · názvy polí v tele**. Len cez allowlist — časť `GET` endpointov mení stav.
- **Dva endpointy tej istej služby s rôznym tvarom sú nález, ktorý nepotrebuje doménový orákul.** Najprv ale over, či odpoveď vyrobil náš `@ControllerAdvice`, alebo predvolený handler Springu/gateway — inak obviníš framework namiesto kódu.
- **`200` s prázdnym telom nie je tvar, je to prehltnutá chyba.** Rataj ju vo vlastnom stĺpci; endpoint, ktorý si nezmeral, je **DIERA**, nie zhoda.
- **Až keď tvar poznáš,** napíš **jednu spoločnú kontrolu chybovej cesty** pre celý rozsah endpointov namiesto jednej na každý zvlášť. Bez toho sa chybová cesta pri 417 endpointoch pokryť nedá.

*Prečo tu: 417 endpointov, 22 repozitárov, jeden človek. Bez jednotného tvaru sa chybová cesta nedá pokryť inak než po jednom.*

---

## Stránkovanie — invariant, ktorý nepotrebuje doménový orákul

- **Stránkuj len nad výsekom, ktorý si test vyrobil sám** (filter na vlastný kľúč behu). Nad cudzími dátami vyrobí duplikát a dieru nočný sync alebo paralelný test — bez chyby v našom kóde, a to je falošná červená.
- **Tvrdenie:** zjednotenie strán `0..n` sa presne rovná množine ID, ktoré si vytvoril. Žiadne dvakrát, žiadne nechýba. *(Množinu poznáš — to je orákul, nie porovnanie dvoch výstupov toho istého kódu.)*
- **Najprv assertni, že prvá strana nie je prázdna.** Prehltnutý `catch` vráti `200` s prázdnym telom a porovnanie prázdna s prázdnom prejde vákuovo — rovnaká trieda ako `allMatch` nad prázdnou kolekciou.
- Vyžaduj `ORDER BY` nad jednoznačným kľúčom — viď `PRAVIDLA-DB.md` §2.4.

*Prečo tu: Testovacie dáta nie sú naše a cez noc ich prepisuje sync. Bez zúženia na vlastný výsek vyrobíš falošnú červenú, po ktorej suite prestanú veriť.*
