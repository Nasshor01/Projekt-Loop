# Projekt: Loop

Vítejte v repozitáři mé hry **Loop**, single-player (s plánovaným co-op módem) hry žánru **deck-building roguelike RPG**. Tento projekt vyvíjím v **Godot Engine** s cílem vytvořit hluboký a znovuhratelný zážitek inspirovaný klasikami jako *Slay the Spire*. Hráč si vybere svou postavu, postupuje po náhodně generované mapě a bojuje s nepřáteli pomocí balíčku karet, který si postupně vylepšuje.

Největší technickou předností projektu je jeho **data-driven design**. Veškerý herní obsah – karty, jednotky, nepřátelé, souboje a jejich vlastnosti – je definován jako externí datové soubory. To mi umožňuje extrémně snadno a rychle přidávat nový obsah a ladit balanc hry bez zásahů do kódu.

## Klíčové mechaniky (Současný stav)

Hra již nyní obsahuje robustní základ, na kterém stavím další funkce:

* **🎲 Procedurálně generovaná mapa:** Každá hra je jedinečná díky náhodně generované mapě s různými cestami a typy uzlů (souboje, elity, boss, odpočinek, poklad, obchod, náhodné události).

* **⚔️ Taktický soubojový systém (Iniciativa):** Jádro hry. Souboje již neprobíhají na kola (hráč/AI), ale využívají **dynamický iniciativní systém** (inspirovaný *Baldur's Gate* nebo *HoMM*). Pořadí tahů všech jednotek (hráče i nepřátel) je na začátku kola určeno jejich statistikou iniciativy, což otevírá dveře pro nové taktické možnosti a karty ovlivňující rychlost.

* **🗺️ Bojiště 2.0 (Základ implementován):** Souboje probíhají na přehledné mřížce. Základní systém pro **taktické překážky** (kameny, bahno) a vizuální zpětná vazba (plovoucí čísla poškození/léčení) je hotov.

* **🃏 Dynamický systém karet:** Propracovaný systém karet a balíčků. Hráč začíná se základním balíčkem a postupně jej vylepšuje. Karty mají definovanou cenu, efekty a jsou rozděleny na obecné a třídní.

* **🛡️ Systém tříd a jednotek:** Hra je postavena na systému unikátních herních tříd. Aktuálně je plně hratelný **Paladin** se specifickou sadou karet. Nepřátelských jednotek je již nyní celá řada.

* **🔄 Meta-progrese (Základ implementován):** Po každém průchodu hrou hráč získává zkušenosti (XP), zvyšuje úroveň své postavy a získává body, které může investovat do **permanentního stromu pasivních dovedností** (Skill Tree), což zajišťuje pocit postupu i po neúspěšném "runu".

* **💾 Systém ukládání (Částečně implementován):** Hra si již nyní pamatuje základní meta-progres (XP, odemčené skilly). Základ pro ukládání stavu rozehrané hry ("runu") je položen.

### **Roadmapa Vývoje: Projekt "Loop" (Stav: Základní systémy implementovány)**

---

#### **Fáze 1: Vyšperkování Jádra (Core Polish)**

**Cíl:** Přeměnit funkční, ale "hrubé" systémy na plynulý a srozumitelný herní zážitek.

1.  **Iniciativní systém 1.1 (UI/UX):**
    * **Priorita:** Vytvořit vizuální "timeline" (časovou osu), kde hráč jasně uvidí pořadí tahů všech jednotek v aktuálním kole.
    * Implementovat vizuální zvýraznění ("highlight") jednotky, která je právě na tahu.
    * Přidat karty a efekty, které aktivně manipulují s iniciativou (např. "Zrychlení", "Zpomalení", "Ochromení").

2.  **Dokončení Herní Smyčky (Game Loop):**
    * Implementovat přechod po poražení bosse (Akt 1) zpět do hlavního menu.
    * Připravit strukturu pro "Akt 2" (vyšší obtížnost, noví nepřátelé).
    * Plně implementovat načítání uložené hry (nejen meta-progresu, ale i rozehraného "runu" na mapě).

3.  **Vylepšení Meta-progrese:**
    * Navrhnout a implementovat první kompletní **Skill Tree** pro Paladina.
    * Vybalancovat získávání XP za souboje, elity a bossy.
    * Vytvořit UI v hlavním menu pro prohlížení a utrácení skill pointů.

---

#### **Fáze 2: Exploze Obsahu (Content Explosion)**

**Cíl:** Naplnit hotové systémy obsahem a zajistit vysokou znovuhratelnost. Díky data-driven designu lze postupovat rychle.

1.  **Druhá Hratelná Třída (Priorita):**
    * Plně implementovat druhou hratelnou třídu, např. **Trapper** nebo **Vrah Duší** (Soul Reaper), včetně:
        * Unikátní pasivní schopnosti.
        * Sada ~30-40 startovních a odemykatelných karet.
        * Vlastní Skill Tree pro meta-progresi.

2.  **Rozšíření Nepřátel (Frakce):**
    * Vytvořit první ucelenou nepřátelskou frakci (např. "Zrezivělá Pevnost" nebo "Nemrtví").
    * Implementovat **specifické AI** pro různé role nepřátel (Archer, Berserker, Healer, Monk), aby se chovali chytřeji a odlišně.

3.  **Unikátní Bossové:**
    * Přepracovat stávajícího bosse (nebo vytvořit nového) tak, aby měl unikátní mechaniky (nejen více HP a DMG).
    * Například: Boss, který mění terén, vyvolává pomocníky, nebo má fázový souboj.

4.  **Rozšíření Poolu Karet a Artefaktů:**
    * Doplnit pool neutrálních karet a artefaktů (~30-40 artefaktů celkem), aby byly synergie mezi třídami.

---

#### **Fáze 3: Leštění a Příprava na Veřejnost (Polish & Public)**

**Cíl:** Připravit hru na první veřejné demo (např. pro Steam Next Fest).

1.  **Finální UI/UX "Juice":**
    * Sjednotit vizuální styl všech menu (hlavní menu, odměny, obchod, mapa).
    * Přidat klíčové zvukové efekty (zahrání karty, zásah, smrt jednotky, kliknutí na tlačítko).
    * Implementovat základní hudební smyčky (pro mapu, běžný souboj, boss souboj).

2.  **Balancování a Testování:**
    * Intenzivní testování a ladění obtížnosti, cen karet, síly nepřátel a odměn.

3.  **Příprava Dema:**
    * Vytvořit ořezanou verzi hry (např. pouze první Akt s jednou hratelnou třídou) a odladit ji pro veřejné vydání.
## Vzdálenější Budoucnost: Kooperativní Mód
Po dokončení single-playeru je mou velkou ambicí vytvořit unikátní kooperativní mód pro dva hráče, který bude postaven na sdíleném riziku a speciálních mechanikách, jako je **Fúze Artefaktů**.

