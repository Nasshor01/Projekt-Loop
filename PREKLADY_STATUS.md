# Status překladů

## ✅ Co bylo dokončeno

### 1. Základní systém
- ✅ Vytvořen `translations.csv` s překlady
- ✅ Vytvořen `TranslationHelper.gd` pro pomocné funkce
- ✅ Nastaveno v `project.godot`

### 2. UI texty
- ✅ MainMenu - tlačítka převedena na anglické (NEW GAME, LOAD RUN, HOW TO PLAY, EXIT)
- ✅ MainMenu.gd - přidána funkce `_update_ui_texts()` pro překlady
- ✅ HowToPlay - tlačítka převedena na anglické
- ✅ HowToPlay.gd - připraveno pro překlady

### 3. CardData dynamické texty
- ✅ `generate_compact_description()` - převedeno na `tr()`
- ✅ `_get_status_display_description()` - převedeno na `TranslationHelper.tr_format()`
- ✅ `_get_condition_description()` - převedeno na `tr()`
- ✅ `_format_conditional_effect()` - převedeno na `tr()`
- ✅ `_get_target_description()` - převedeno na `tr()`

### 4. Překladové klíče
- ✅ Základní UI klíče
- ✅ Status efekty
- ✅ Card efekty (damage, block, heal, etc.)
- ✅ Podmíněné efekty
- ✅ Typy poškození
- ✅ Typy nepřátel
- ✅ Vzácnost karet

## ⏳ Co zbývá udělat

### 1. Karty (.tres soubory)
- [ ] Všechny Paladin karty - změnit `card_name` a `card_description` na anglické
- [ ] Všechny Everyone karty - změnit `card_name` a `card_description` na anglické
- [ ] Curse karty - změnit `card_name` a `card_description` na anglické
- [ ] Přidat klíče do `translations.csv` pro každou kartu

### 2. Další UI texty
- [ ] GameOver screen
- [ ] EndOfRunScreen
- [ ] GlobalUI (zlato, patro, NG+)
- [ ] BattleScene UI texty
- [ ] UnitInfoPanel texty
- [ ] Shop UI texty
- [ ] RewardScene texty
- [ ] EventScene texty

### 3. HowToPlay text
- [ ] Rozdělit dlouhý text na menší části
- [ ] Přidat klíče do `translations.csv`
- [ ] Vytvořit funkci, která sestaví text pomocí `tr()`

### 4. Dynamické texty v kódu
- [ ] Floating texty (poškození, léčení, blok)
- [ ] Debug zprávy (pokud se zobrazují hráči)
- [ ] Chybové zprávy
- [ ] Event texty
- [ ] Artifact popisy
- [ ] Skill popisy

### 5. Testování
- [ ] Otestovat všechny překlady v hře
- [ ] Zkontrolovat, že všechny texty jsou přeložené
- [ ] Zkontrolovat formátování (parametry v textu)

## 📝 Jak převést kartu

### Příklad: holy_strike.tres

**1. Změň .tres soubor:**
```
card_name = "Holy Strike"
card_description = "Deal 8 holy damage."
```

**2. Přidej do translations.csv:**
```csv
"card.holy_strike","Holy Strike","Svatý Úder"
"card.holy_strike.desc","Deal 8 holy damage.","Způsob 8 svatého poškození."
```

**Poznámka:** Popisy karet se automaticky generují z efektů pomocí `generate_compact_description()`, takže pokud má karta správně nastavené efekty, popis bude automaticky přeložený!

## 🎯 Priorita

1. **VYSOKÁ**: Převedení karet na anglické názvy a popisy
2. **STŘEDNÍ**: UI texty (GameOver, BattleScene, atd.)
3. **NÍZKÁ**: HowToPlay dlouhý text (může být později)
4. **NÍZKÁ**: Debug zprávy (pokud se zobrazují)

