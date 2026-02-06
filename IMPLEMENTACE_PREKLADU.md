# Implementace překladů - Postup

## ✅ Co bylo vytvořeno

1. **translations.csv** - CSV soubor s překlady (angličtina + čeština)
2. **TranslationHelper.gd** - Pomocná třída pro překlady s parametry
3. **project.godot** - Nastavení překladů v projektu

## 📋 Co je potřeba udělat

### Fáze 1: Základní UI (Priorita: VYSOKÁ)
- [ ] MainMenu - tlačítka
- [ ] HowToPlay - všechny texty
- [ ] CardUI - základní texty
- [ ] BattleScene - UI texty

### Fáze 2: Karty (Priorita: VYSOKÁ)
- [ ] Všechny Paladin karty - názvy a popisy
- [ ] Všechny Everyone karty - názvy a popisy
- [ ] Curse karty - názvy a popisy
- [ ] CardData.generate_compact_description() - všechny texty

### Fáze 3: Dynamické texty (Priorita: STŘEDNÍ)
- [ ] Status efekty
- [ ] Debug zprávy
- [ ] Chybové zprávy
- [ ] Floating texty

### Fáze 4: Data soubory (Priorita: NÍZKÁ)
- [ ] Event texty
- [ ] Artifact popisy
- [ ] Skill popisy

## 🔧 Jak převést kartu

### Příklad: holy_strike.tres

**PŘED:**
```gdscript
card_name = "Svatý Úder"
card_description = "Způsob 8 svatého poškození."
```

**PO:**
```gdscript
card_name = "Holy Strike"
card_description = "Deal 8 holy damage."
```

**V translations.csv:**
```csv
"card.holy_strike","Holy Strike","Svatý Úder"
"card.holy_strike.desc","Deal 8 holy damage.","Způsob 8 svatého poškození."
```

**V kódu (pokud se zobrazuje):**
```gdscript
# Místo:
label.text = card_data.card_name

# Použij (pokud potřebuješ překlad):
label.text = tr("card." + card_data.card_id)
```

## 🔧 Jak převést UI text

### Příklad: MainMenu.tscn

**PŘED:**
```gdscript
text = "Nová hra"
```

**PO:**
```gdscript
text = tr("ui.main_menu.new_game")
```

**V translations.csv:**
```csv
"ui.main_menu.new_game","New Game","Nová hra"
```

## ⚠️ Důležité poznámky

1. **CardData.card_name a card_description** - Tyto jsou v .tres souborech, takže je musíš změnit přímo v souborech na anglické texty
2. **Dynamické generování** - `generate_compact_description()` musí používat `tr()` pro všechny texty
3. **Parametry** - Pro texty s čísly použij `TranslationHelper.tr_format()`

## 🎯 Priorita

Začni s:
1. MainMenu a základní UI
2. CardData.generate_compact_description()
3. Pak postupně všechny karty

