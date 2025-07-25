# Projekt: Loop

Vítejte v repozitáři mé hry **Loop**, single-player (s plánovaným co-op módem) hry žánru **deck-building roguelike RPG**. Tento projekt vyvíjím v **Godot Engine** s cílem vytvořit hluboký a znovuhratelný zážitek inspirovaný klasikami jako *Slay the Spire*. Hráč si vybere svou postavu, postupuje po náhodně generované mapě a bojuje s nepřáteli pomocí balíčku karet, který si postupně vylepšuje.

Největší technickou předností projektu je jeho **data-driven design**. Veškerý herní obsah – karty, jednotky, nepřátelé, souboje a jejich vlastnosti – je definován jako externí datové soubory. To mi umožňuje extrémně snadno a rychle přidávat nový obsah a ladit balanc hry bez zásahů do kódu.

## Klíčové mechaniky (Současný stav)

Hra již nyní obsahuje robustní základ, na kterém stavím další funkce:

* **🎲 Procedurálně generovaná mapa:** Každá hra je jedinečná díky náhodně generované mapě s různými cestami a typy uzlů (souboje, elity, boss, odpočinek, poklad, obchod, náhodné události).

* **⚔️ Taktický bojový systém:** Souboje probíhají na přehledné mřížce. Hráč každý tah dobírá karty a využívá energii k jejich zahrání. Nepřátelé jsou řízeni vlastní umělou inteligencí.

* **🃏 Dynamický systém karet:** Jádrem hry je propracovaný systém karet a balíčků. Hráč začíná se základním balíčkem a postupně jej vylepšuje. Karty mají definovanou cenu, efekty a jsou rozděleny na obecné a třídní.

* **🛡️ Systém tříd a jednotek:** Hra je postavena na systému unikátních herních tříd. Aktuálně je nejvíce rozpracován **Paladin** se specifickou sadou karet. Nepřátelských jednotek je již nyní celá řada, od goblinů po silné bossy.

* **🔄 Herní smyčka:** Základní cyklus hry (Mapa -> Souboj -> Odměna) je plně funkční a poskytuje základ pro kompletní herní zážitek.

## Aktuální Roadmapa (srpen – prosinec 2025)

Mám jasně daný plán, jak hru posunout od funkčního prototypu k plnohodnotnému zážitku. **Prioritou číslo jedna je dokončení single-player módu.**

### Fáze 1: Vylepšení Hratelnosti a Základů (srpen – polovina října)
**Cíl:** Mít plně hratelný "run" s klíčovými komfortními funkcemi a taktickou hloubkou.
- **Bojiště 2.0:** Vylepšení bojiště o vizualizaci plošných útoků (AoE), taktické překážky a vizuální zpětnou vazbu (plovoucí čísla poškození/léčení).
- **Systém ukládání a načítání:** Možnost uložit a načíst rozehranou hru.
- **Základy Meta-progrese:** Přidání permanentní měny ("Střepy Věčnosti"), kterou hráč získává po každém průchodu hrou.

### Fáze 2: Obsahová Exploze (polovina října – listopad)
**Cíl:** Naplnit hru obsahem pro zajištění vysoké znovuhratelnosti.
- **Druhá hratelná třída:** Implementace kompletní nové třídy (např. **Mág -> Elementalista**) s unikátními kartami a herním stylem.
- **Nové Karty a Artefakty:** Rozšíření počtu karet a přidání prvních ~15-20 artefaktů, které zásadně mění hru.
- **Nové Nepřátelské Frakce:** Vytvoření první tematické skupiny nepřátel ("Zrezivělá Pevnost") s 15-20 novými jednotkami.

### Fáze 3: Leštění a Příprava na Veřejnost (prosinec)
**Cíl:** Přeměnit funkční prototyp na hru, která působí jako ucelený a profesionální produkt.
- **Vizuální a Zvukový "Juice":** Přidání základních zvukových efektů, hudby a jednoduchých animací pro lepší pocit z hraní.
- **Hlavní Menu:** Vytvoření hlavní nabídky a sjednocení uživatelského rozhraní.
- **Příprava Dema:** Vytvoření a odladění demoverze (první akt) pro budoucí prezentaci, například na **Steam Next Festu**.

## Vzdálenější Budoucnost: Kooperativní Mód
Po dokončení single-playeru je mou velkou ambicí vytvořit unikátní kooperativní mód pro dva hráče, který bude postaven na sdíleném riziku a speciálních mechanikách, jako je **Fúze Artefaktů**.
