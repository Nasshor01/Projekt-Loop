# Systém překladů (i18n)

## 📋 Přehled

Hra je nyní primárně v **angličtině** s podporou překladu do **češtiny**.

## 🔧 Jak to funguje

### 1. CSV soubor s překlady
Všechny překlady jsou v `translations.csv` ve formátu:
```csv
keys,en,cs
"ui.main_menu.new_game","New Game","Nová hra"
```

### 2. Použití v kódu
V GDScript použij `tr()` funkci:
```gdscript
# Místo:
label.text = "Nová hra"

# Použij:
label.text = tr("ui.main_menu.new_game")
```

### 3. Překlady s parametry
Pro texty s proměnnými použij `TranslationHelper.tr_format()`:
```gdscript
# Místo:
label.text = "Na začátku tahu: +2 blok"

# Použij:
label.text = TranslationHelper.tr_format("status.aura_devotion", {"value": 2})
```

## 📝 Postup převodu

### Karty (.tres soubory)
1. Změň `card_name` na anglický název
2. Změň `card_description` na anglický popis
3. Přidej klíče do `translations.csv`:
   ```csv
   "card.holy_strike","Holy Strike","Svatý Úder"
   "card.holy_strike.desc","Deal 8 holy damage.","Způsob 8 svatého poškození."
   ```

### UI texty (v .tscn a .gd)
1. Najdi všechny texty v Label, Button, atd.
2. Nahraď je `tr()` voláním
3. Přidej klíče do `translations.csv`

### Dynamické texty (v kódu)
1. Najdi všechny string literály
2. Nahraď je `tr()` nebo `TranslationHelper.tr_format()`
3. Přidej klíče do `translations.csv`

## 🎯 Klíče překladů

### Struktura klíčů:
- `ui.*` - UI elementy (tlačítka, labely)
- `card.*` - Názvy karet
- `card.*.desc` - Popisy karet
- `status.*` - Status efekty
- `damage.*` - Typy poškození
- `enemy.type.*` - Typy nepřátel
- `card.rarity.*` - Vzácnost karet
- `card.effect.*` - Efekty karet
- `card.condition.*` - Podmíněné efekty

## ⚙️ Nastavení jazyka

Výchozí jazyk je **angličtina** (en).

Pro změnu jazyka v kódu:
```gdscript
TranslationServer.set_locale("cs")  # Čeština
TranslationServer.set_locale("en")  # Angličtina
```

## 📋 TODO

- [ ] Převést všechny karty na anglické názvy
- [ ] Převést všechny UI texty
- [ ] Převést všechny dynamické texty v kódu
- [ ] Přidat všechny klíče do translations.csv
- [ ] Otestovat překlady v hře

## 💡 Tipy

1. **Klíče by měly být popisné**: `ui.main_menu.new_game` místo `nm1`
2. **Používej hierarchii**: `card.paladin.holy_strike` místo `hstrike`
3. **Parametry v překladech**: Použij `{value}` pro čísla, `{name}` pro názvy
4. **Konzistence**: Všechny podobné texty by měly mít podobnou strukturu klíčů

