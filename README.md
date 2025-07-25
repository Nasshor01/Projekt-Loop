# Projekt: Loop

Vítejte v repozitáři mé hry **Loop**, single-player (s plánovaným co-op módem) hry žánru **deck-building roguelike RPG**. Tento projekt vyvíjím v **Godot Engine** s cílem vytvořit hluboký a znovuhratelný zážitek inspirovaný klasikami jako *Slay the Spire*. Hráč si vybere svou postavu, postupuje po náhodně generované mapě a bojuje s nepřáteli pomocí balíčku karet, který si postupně vylepšuje.

Největší technickou předností projektu je jeho **data-driven design**. Veškerý herní obsah – karty, jednotky, nepřátelé, souboje a jejich vlastnosti – je definován jako externí datové soubory. To mi umožňuje extrémně snadno a rychle přidávat nový obsah a ladit balanc hry bez zásahů do kódu.

## Klíčové mechaniky (Současný stav)

Hra již nyní obsahuje robustní základ, na kterém stavím další funkce:

* **🎲 Procedurálně generovaná mapa:** Každá hra je jedinečná díky náhodně generované mapě s různými cestami a typy uzlů (souboje, elity, boss, odpočinek, poklad, obchod, náhodné události).

* **⚔️ Tahový bojový systém:** Souboje probíhají na přehledné mřížce. Hráč každý tah dobírá karty a využívá energii k jejich zahrání. Nepřátelé jsou řízeni vlastní umělou inteligencí.

* **🃏 Dynamický systém karet:** Jádrem hry je propracovaný systém karet a balíčků. Hráč začíná se základním balíčkem a postupně jej vylepšuje. Karty mají definovanou cenu, efekty a jsou rozděleny na obecné a třídní.

* **🛡️ Systém tříd a jednotek:** Hra je postavena na systému unikátních herních tříd. Aktuálně je nejvíce rozpracován **Paladin** se specifickou sadou karet. Nepřátelských jednotek je již nyní celá řada, od goblinů po silné bossy.

* **🔄 Herní smyčka:** Základní cyklus hry (Mapa -> Souboj -> Odměna) je plně funkční a poskytuje základ pro kompletní herní zážitek.

## Budoucí vize a ambice

Mým hlavním cílem je vytvořit hru s vysokou znovuhratelností a strategickou hloubkou. **Prioritou číslo jedna je dokončení plnohodnotného single-player zážitku.** Jakmile bude tato část hotová a odladěná, zaměřím se na další ambiciózní cíle.

### Plánovaný Kooperativní Mód (Co-op)

Nejzajímavější budoucí vizí je unikátní kooperativní mód pro dva hráče. Nechci jít cestou, kdy dva hráči jen bojují bok po boku. Můj koncept je postaven na sdíleném riziku a unikátních synergických mechanikách:

* **Zvýšená obtížnost:** V co-op módu budou nepřátelé výrazně silnější (například 2.5x), aby byla spolupráce a strategie naprosto klíčová.
* **Fúze Artefaktů:** Každý hráč bude sbírat své vlastní artefakty. Pokud se ale stane, že **oba hráči získají stejný artefakt**, dojde k jeho **fúzi**. Původní artefakty zmizí a místo nich oba hráči získají jeden **společný, extrémně silný artefakt**, který bude násobně (např. 2.5x) silnější než jeho původní verze a navíc získá bonusové vlastnosti. To povede k unikátním strategickým rozhodnutím a budování společných synergii.

### Další plánovaný obsah a vylepšení

Souběžně s prací na hlavních režimech budu hru rozšiřovat o:
* **Nové herní třídy:** Warrior, Rogue, Mage a další.
* **Rozšíření bojového systému:** Přidání status efektů (jed, zranitelnost, síla...), pasivních relikvií a jednorázových elixírů.
* **Nový obsah:** Více nepřátel, bossů, karet a náhodných událostí na mapě.
* **Vylepšení kvality:** Kompletní UI, hlavní menu, systém ukládání a načítání, a samozřejmě zvukové efekty a hudba.
