# Vzorový test — kopíruj tvar, nie obsah

`CategoryAssemblerTest.java` je vzor. Názvy tried sú vymyslené, **tvar je nameraný**.

## Čo v ňom je a prečo

| prvok | pravidlo |
| --- | --- |
| `new Trieda(null × 7)` | konštruktor len priraďuje polia — Spring kontext netreba |
| `@BeforeEach` nastaví **všetko** | statický stav prežije test aj naprieč vláknami |
| `@Tag("spec")` | `char` by musel mať riadok `ORAKUL:` |
| hlavička s rozsahom | **7 pokrytých, 5 NEZMERANÝCH** — nezmerané ≠ v poriadku |
| komentár SONDA | vygutované telo → 6 zo 7 padlo; obrátený assert **nestačí** |
| `@ParameterizedTest` s menami | zlyhanie hlási prípad, nie `[2]` |
| jedno tvrdenie na test | jeden dôvod, prečo môže spadnúť |
| názov = správanie | nie názov metódy |
| chybová cesta | súčasť „hotovo", nie extra |
| pomocníci bez vetvenia | vetviaci pomocník je druhá implementácia |
| **žiadny Mockito** | `mockStatic` je thread-local pasca |

## Než odovzdáš vlastný test

1. Vyguti telo testovanej metódy → **musí sčervenieť**
2. Telo vráť, prečítaj `git diff`
3. Doplň riadok SONDA s dátumom behu

**Test, ktorý si nevidel padnúť na vygutovanom tele, sa počíta ako 0.**
