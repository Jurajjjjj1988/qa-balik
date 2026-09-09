package com.example.catalog;

import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.Arguments;

import java.util.*;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.*;

/**
 * VZOROVÝ TEST — kopíruj tvar, nie obsah.
 *
 * Testovaná trieda má 7 spolupracovníkov v konštruktore, ale telo konštruktora
 * iba priraďuje polia a nevolá nič statické. Preto sa dá vytvoriť so samými null
 * a testovaná metóda ani jedného z nich nepoužije.
 *
 * ┌─ ROZSAH TOHTO SÚBORU ────────────────────────────────────────────────────┐
 * │ Metóda má 12 rozhodovacích vetiev.                                        │
 * │   POKRYTÉ (7):  null uzol · nezhoda id · null rodič · prázdne príznaky ·  │
 * │                 chýbajúci preklad · duplicitný potomok · null v mape      │
 * │   NEZMERANÉ (5): vetvy 8–12 — potrebujú tvar vstupu, ktorý zatiaľ         │
 * │                 nemám doložený z produkčných dát. Zoznam je v             │
 * │                 NALEZY.md, nie tu.                                         │
 * │ ⚠️ NEZMERANÉ ≠ v poriadku. Riadok v matici zostáva otvorený.              │
 * └───────────────────────────────────────────────────────────────────────────┘
 *
 * SONDA (povinná, bez nej sa test neodovzdáva):
 *   Vygutoval som telo populateChildren() na `return node;`
 *   → spadlo 6 zo 7 testov. Beh: <odkaz alebo dátum a čas>
 *   Telo som vrátil a `git diff` pred commitom je čistý.
 *   Obrátený assert NESTAČÍ — na catch-i s náhradnou hodnotou by prešiel.
 */
@Tag("spec")
@DisplayName("Skladanie podkategórií")
class CategoryAssemblerTest {

    private CategoryAssembler assembler;

    @BeforeEach
    void setUp() {
        // Konštruktor prijme null pre všetkých 7 spolupracovníkov — namerané.
        // Spring kontext sa NESPÚŠŤA: nepotrebujeme ho a spomalil by beh.
        assembler = new CategoryAssembler(null, null, null, null, null, null, null);

        // Statický stav prežije test aj naprieč vláknami (async executor).
        // Preto sa nastavuje VŠETKO, čo test potrebuje — nie sa upratuje po ňom.
        // Nikdy nepredpokladaj, že hodnota, ktorú tento test nenastavil, je prázdna.
        ConfigCache.getInstance().put("DEFAULT_LOCALE", "sk-SK");
        ConfigCache.getInstance().put("MAX_DEPTH", "5");
    }

    // ── Vetva 1: null uzol ──────────────────────────────────────────────────

    @Test
    @DisplayName("vráti nový uzol, keď na vstupe žiadny nie je")
    void vytvoriUzolKedZiadnyNaVstupeNie() {
        SourceRow row = row(10L, "Náradie");

        CategoryDto vysledok = assembler.populateChildren(null, row, null, "sk-SK", Map.of());

        // JEDNO tvrdenie = JEDEN dôvod, prečo môže test spadnúť.
        assertThat(vysledok.getId()).isEqualTo(10L);
    }

    // ── Vetva 2: nezhoda identifikátorov ────────────────────────────────────

    @Test
    @DisplayName("začne nový uzol, keď riadok patrí inej kategórii")
    void zacneNovyUzolPriNezhodeId() {
        CategoryDto existujuci = node(10L, "Náradie");
        SourceRow row = row(99L, "Záhrada");

        CategoryDto vysledok = assembler.populateChildren(existujuci, row, null, "sk-SK", Map.of());

        assertThat(vysledok.getId()).isEqualTo(99L);
    }

    // ── Vetvy 3–5: tabuľkovo, lebo sa líšia len vstupom ─────────────────────
    //
    // Jedna testovacia metóda = ~4 vetvy. Príprava vstupu sa amortizuje.
    // Každý riadok má MENO — inak je zlyhanie hlásené ako "[2]" a nikto nevie, čo padlo.

    @ParameterizedTest(name = "{0}")
    @CsvSource({
        "rodič chýba,          , 10, 1",
        "rodič je zadaný,     5, 10, 1",
        "rodič je sám sebou,  10, 10, 0"   // cyklus sa nesmie pridať
    })
    @DisplayName("počet potomkov podľa rodiča")
    void pocetPotomkovPodlaRodica(String pripad, Long rodicId, long uzolId, int ocakavanychPotomkov) {
        CategoryDto rodic = rodicId == null ? null : node(rodicId, "Rodič");
        CategoryDto uzol = node(uzolId, "Uzol");

        assembler.populateChildren(uzol, row(uzolId, "Uzol"), rodic, "sk-SK", Map.of());

        assertThat(rodic == null ? List.of() : rodic.getChildren())
            .as(pripad)
            .hasSize(ocakavanychPotomkov);
    }

    // ── Vetva 6: chýbajúci preklad ──────────────────────────────────────────
    //
    // ORAKUL: ručne spočítaný literál. Ak preklad chýba, kód vracia kľúč —
    // overené prečítaním vetvy, NIE spustením proti produkčným dátam.
    // Keby sa ukázalo, že správanie má byť iné, je to zmena požiadavky, nie chyba testu.

    @Test
    @DisplayName("použije kľúč, keď preklad pre jazyk neexistuje")
    void pouzijeKlucKedPrekladChyba() {
        CategoryDto uzol = node(10L, null);

        CategoryDto vysledok = assembler.populateChildren(uzol, row(10L, null), null, "xx-XX", Map.of());

        assertThat(vysledok.getName()).isEqualTo("category.10.name");
    }

    // ── Vetva 7: duplicitný potomok ─────────────────────────────────────────

    @Test
    @DisplayName("nepridá potomka, ktorý tam už je")
    void nepridaDuplicituPotomka() {
        CategoryDto rodic = node(5L, "Rodič");
        rodic.getChildren().add(node(10L, "Uzol"));
        CategoryDto uzol = node(10L, "Uzol");

        assembler.populateChildren(uzol, row(10L, "Uzol"), rodic, "sk-SK", Map.of());

        assertThat(rodic.getChildren()).hasSize(1);
    }

    // ── Chybová cesta ───────────────────────────────────────────────────────
    //
    // Chybové cesty sú súčasť "hotovo", nie extra.
    // ⚠️ NEASSERTUJ hodnotu, ktorú vracia catch — prázdny zoznam, null či 0 sú
    // zelené aj vtedy, keď pod nimi spadlo všetko. Tvrď ROZLÍŠITEĽNÝ výsledok.

    @Test
    @DisplayName("odmietne riadok bez identifikátora namiesto tichého preskočenia")
    void odmietneRiadokBezIdentifikatora() {
        SourceRow bezId = row(null, "Náradie");

        assertThatThrownBy(() -> assembler.populateChildren(null, bezId, null, "sk-SK", Map.of()))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("categoryId");
    }

    // ── Mapa príznakov: vlastný zdroj, lebo hodnôt je viac ──────────────────

    @ParameterizedTest(name = "{0}")
    @MethodSource("priznakyObrazkov")
    @DisplayName("príznak obrázka podľa mapy")
    void priznakObrazkaPodlaMapy(String pripad, Map<Long, Integer> mapa, boolean ocakavany) {
        CategoryDto uzol = node(10L, "Uzol");

        CategoryDto vysledok = assembler.populateChildren(uzol, row(10L, "Uzol"), null, "sk-SK", mapa);

        assertThat(vysledok.hasImage()).as(pripad).isEqualTo(ocakavany);
    }

    static Stream<Arguments> priznakyObrazkov() {
        Map<Long, Integer> sNull = new HashMap<>();
        sNull.put(10L, null);                       // Map.of() null nedovolí
        return Stream.of(
            Arguments.of("prázdna mapa",     Map.of(),          false),
            Arguments.of("príznak zapnutý",  Map.of(10L, 1),    true),
            Arguments.of("príznak vypnutý",  Map.of(10L, 0),    false),
            Arguments.of("null v mape",      sNull,             false),
            Arguments.of("iné id v mape",    Map.of(99L, 1),    false)
        );
    }

    // ── Pomocníci: krátki a bez logiky ──────────────────────────────────────
    //
    // Pomocník, ktorý vetví, je druhá implementácia — a test potom porovnáva
    // dva výstupy toho istého uvažovania.

    private static CategoryDto node(Long id, String name) {
        CategoryDto d = new CategoryDto();
        d.setId(id);
        d.setName(name);
        d.setChildren(new ArrayList<>());
        return d;
    }

    private static SourceRow row(Long categoryId, String name) {
        SourceRow r = new SourceRow();
        r.setCategoryId(categoryId);
        r.setName(name);
        return r;
    }
}
