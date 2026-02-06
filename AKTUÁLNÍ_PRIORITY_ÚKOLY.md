# 🎯 AKTUÁLNÍ PRIORITY ÚKOLY - Projekt Loop

**Datum vytvoření:** ${new Date().toLocaleDateString('cs-CZ')}
**Stav projektu:** Základní systémy implementovány, potřeba dokončit a otestovat

---

## 🔴 VYSOKÁ PRIORITA - Dokončení základní herní smyčky

### 1. ✅ TEST: Ověřit a dokončit systém ukládání hry
**Status:** Funkce existují, ale je potřeba otestovat
- [ ] **Testovat uložení hry na mapě:**
  - Zkontrolovat, že tlačítko "Uložit hru" v menu mapy funguje
  - Ověřit, že se uloží všechny klíčové data (HP, balíček, pozice na mapě, seed)
- [ ] **Testovat načítání uložené hry:**
  - Zkontrolovat, že v hlavním menu je možnost "Pokračovat" pokud existuje uložená hra
  - Ověřit, že se hra správně obnoví (pozice na mapě, HP, balíček)
- [ ] **Otestovat edge cases:**
  - Co se stane, když hráč uloží, pak začne novou hru a pak chce načíst starou?

**Kde testovat:**
- `scripts/autoload/SaveManager.gd` - funkce `save_run()` a `load_run()`
- `scenes/ui/MainMenu.gd` - zkontrolovat, jestli je tam tlačítko/volba "Pokračovat"

---

### 2. ✅ TEST a VYLEPŠIT: Přechod po poražení bosse
**Status:** EndOfRunScreen existuje, ale je potřeba otestovat flow
- [ ] **Otestovat konec runu:**
  - Zvítězit nad bossem a zkontrolovat, že se zobrazí EndOfRunScreen
  - Zkontrolovat, že XP se správně přidají do meta-progrese
  - Otestovat tlačítko "Main Menu" - mělo by vrátit do hlavního menu
- [ ] **Otestovat loop level systém:**
  - Zkontrolovat, že po vítězství se loop_level zvýší
  - Otestovat, že "Další běh (NG+)" správně zvýší loop_level a začne nový run s vyšší obtížností

**Kde zkontrolovat:**
- `scenes/ui/EndOfRunScreen.gd`
- `scripts/autoload/GameManager.gd` - funkce `start_new_game_plus()`

---

### 3. 🔧 VYLEPŠIT: Vizuální zpětná vazba (FloatingText)
**Status:** Základní implementace existuje, ale je potřeba vylepšit
- [ ] **Zkontrolovat, že FloatingText funguje pro všechny typy poškození:**
  - Fyzické poškození
  - Svaté poškození
  - Léčení
  - Blok
- [ ] **Vylepšit vizualizaci:**
  - Různé barvy pro různé typy (červená = poškození, zelená = léčení, modrá = blok)
  - Možná větší čísla pro větší hodnoty
- [ ] **Testovat v různých situacích:**
  - AoE poškození (více jednotek najednou)
  - DoT efekty (poškození v čase)
  - Status efekty

**Kde vylepšit:**
- `scenes/ui/FloatingText.gd`
- `scenes/battle/Unit.gd` - funkce, které vytváří FloatingText instance

---

### 4. 🔧 VYLEPŠIT: Vizualizace AoE efektů
**Status:** Částečně implementováno, stále co vylepšovat
- [ ] **Testovat současnou implementaci:**
  - Zkontrolovat, že při kliknutí na kartu s AoE se zvýrazní zasažená políčka
  - Ověřit, že vizualizace zmizí po použití karty nebo zrušení
- [ ] **Vylepšit vizualizaci:**
  - Přidat animaci (pulzování, blikání)
  - Různé barvy pro různé typy AoE (poškození, léčení, buff)
  - Možná ukázat předpokládané poškození na každém políčku

**Kde vylepšit:**
- `scenes/battle/BattleGrid.gd` - funkce pro AoE highlight
- `scenes/battle/BattleScene.gd` - logika při výběru karty

---

### 5. ✅ TEST: Meta-progrese a Skill Tree
**Status:** Základní systém implementován, potřeba otestovat
- [ ] **Testovat získávání XP:**
  - Dokončit souboj a zkontrolovat, že se XP přidají
  - Dokončit bossa a zkontrolovat, že se přidá více XP
  - Zkontrolovat, že se správně zvyšuje level a přidávají skill points
- [ ] **Testovat Skill Tree:**
  - Zkontrolovat, že je přístupný z hlavního menu
  - Otestovat alokaci skill pointů
  - Ověřit, že se skilly správně ukládají a načítají
- [ ] **Testovat odemykání karet:**
  - Pokud má uzel v skill tree odemknout kartu, zkontrolovat, že se to stane
  - Ověřit, že odemčené karty se objevují v reward scene a obchodě

**Kde testovat:**
- `scenes/ui/PassiveSkillTree.gd`
- `scripts/autoload/PlayerData.gd` - systém odemčených karet
- `scripts/autoload/SaveManager.gd` - ukládání meta-progrese

---

## 🟡 STŘEDNÍ PRIORITA - Obsah a gameplay

### 6. 🎨 ROZŠÍŘIT: Více typů překážek na bojišti
**Status:** Kámen a bahno existují, je místo pro více
- [ ] **Implementovat nové typy terénu podle `battlegrid překážky.md`:**
  - Výbušné sudy (explodují při zásahu)
  - Zničitelné barikády (mají HP, blokují pohyb)
  - Magické oltáře (dávají bonus při postavení na ně)
  - Pasti s bodáky (poškozují při vstupu)
- [ ] **Přidat terény s buffy/debuffy:**
  - Vysoká tráva (skrytí)
  - Svěcená půda (léčení)
  - Jedovatá bažina (poison)
  - Prokletá země (vulnerable)

**Kde implementovat:**
- `data/terrain/` - vytvořit nové TerrainData resource soubory
- `scenes/battle/BattleGrid.gd` - logika pro nové typy terénu

---

### 7. 🃏 TEST a VYLEPŠIT: Balanc karet
**Status:** Paladin má ~50 karet, je potřeba otestovat balanc
- [ ] **Projít všechny Paladin karty a zkontrolovat:**
  - Jsou karty vyvážené? (energie vs efekt)
  - Jsou všechny karty použitelné, nebo jsou některé příliš slabé/silné?
  - Fungují všechny efekty správně?
- [ ] **Hrát několik runů a otestovat:**
  - Je možné vyhrát s různými buildy?
  - Jsou některé karty vždy lepší než jiné?
  - Je progrese pocitově dobrá (začátek -> střed -> konec)?

**Kde testovat:**
- `data/cards/paladin/` - všechny karty
- Hrát hru a sbírat feedback

---

### 8. 🤖 TEST: AI nepřátel
**Status:** Nové AI skripty byly přidány, je potřeba otestovat
- [ ] **Otestovat nové AI role:**
  - AssassinAI - funguje správně?
  - DruidAI - funguje správně?
  - HealerAI - léčí spojence?
  - MageAI - používá správně kouzla?
  - MonkAI - funguje správně?
- [ ] **Otestovat chování AI:**
  - Obcházejí překážky správně?
  - Používají karty inteligentně?
  - Jsou dostatečně výzvou, ale ne příliš obtížní?

**Kde testovat:**
- `scripts/ai/` - všechny AI skripty
- Vytvořit encountery s různými AI typy a otestovat v hře

---

### 9. 🎮 VYLEPŠIT: UI/UX hlavního menu
**Status:** Základní menu existuje, je místo pro vylepšení
- [ ] **Přidat do hlavního menu:**
  - Tlačítko "Pokračovat" (pokud existuje uložená hra)
  - Zobrazení aktuálního levelu a skill pointů
  - Možná jednoduchá statistika (nejvyšší loop level, celkové XP)
- [ ] **Vylepšit vizuál:**
  - Zkontrolovat, že všechny tlačítka fungují
  - Možná přidat jednoduché animace
  - Zkontrolovat, že menu vypadá konzistentně

**Kde vylepšit:**
- `scenes/ui/MainMenu.gd`
- `scenes/ui/MainMenu.tscn`

---

## 🟢 NÍZKÁ PRIORITA - Rozšíření obsahu

### 10. 📝 DOKUMENTACE: Vytvořit průvodce pro testování
- [ ] Vytvořit checklist pro testování každého nového feature
- [ ] Dokumentovat známé bugy
- [ ] Vytvořit průvodce pro přidávání nových karet/artefaktů/nepřátel

---

### 11. 🎨 PŘIDAT: Více artefaktů
**Status:** Podle PLAN_PŘIDÁVÁNÍ_OBSAHU.md je cíl 50-80 artefaktů
- [ ] Zkontrolovat, kolik artefaktů aktuálně existuje
- [ ] Vytvořit nové artefakty podle plánu
- [ ] Otestovat, že všechny fungují správně

---

### 12. 👹 PŘIDAT: Více nepřátel a encounterů
**Status:** Existuje několik typů nepřátel, je místo pro více
- [ ] Zkontrolovat, kolik typů nepřátel existuje
- [ ] Vytvořit nové nepřátelské jednotky podle plánu
- [ ] Vytvořit nové encountery s různými kombinacemi nepřátel
- [ ] Otestovat, že jsou vyvážené

---

## 📋 QUICK WINS - Rychlé úkoly, které přinesou okamžitý výsledek

### ✅ Testovat základní flow hry
1. Spustit hru
2. Vybrat Paladina
3. Projít mapu od začátku do konce (boss)
4. Zaznamenat všechny bugy a problémy
5. Otestovat uložení a načítání

### ✅ Projít všechny karty a zkontrolovat, že fungují
- Spustit hru s dev konzolí
- Použít každou kartu alespoň jednou
- Zkontrolovat, že všechny efekty fungují správně

### ✅ Zkontrolovat balanc poškození/zdraví
- Jsou nepřátelé příliš silní/slabí?
- Je progrese plynulá?
- Jsou bossové výzva, ale ne nemožní?

---

## 🎯 DOPORUČENÝ POŘADÍ PRÁCE

1. **PRVNÍ TÝDEN: Testování a opravy**
   - Úkoly #1, #2, #5 (testování základních systémů)
   - Opravit nalezené bugy
   - Quick wins - otestovat celý flow

2. **DRUHÝ TÝDEN: Vylepšení feedbacku**
   - Úkoly #3, #4 (vizuální zpětná vazba)
   - Úkol #9 (UI hlavního menu)

3. **TŘETÍ TÝDEN: Obsah a balanc**
   - Úkoly #6, #7, #8 (nové překážky, balanc karet, testování AI)

4. **ČTVRTÝ TÝDEN: Rozšíření obsahu**
   - Úkoly #11, #12 (více artefaktů a nepřátel)

---

## 💡 NÁPADY PRO BUDOUCNOST

- Systém achievementů
- Daily challenges
- Více hratelných tříd (Berserker, Elementalista, atd.)
- Rozšířený Skill Tree s více uzly
- Systém synergií artefaktů
- Unikátní boss mechaniky (fázové souboje, vyvolávání pomocníků)

---

**Poznámka:** Tento dokument by měl být aktualizován průběžně, když se dokončují úkoly nebo se objevují nové priority.

