# Vylepšení karet - Automatické generování popisů a vizuální rozlišení

## ✅ Co bylo implementováno

### 1. Automatický generátor stručných popisů
- **Nová funkce `generate_compact_description()`** v `CardData.gd`
- Automaticky generuje stručné popisy z efektů karty
- Formát: `[Hodnota] [Typ efektu] [Cíl]`
- Příklady:
  - `8 svatého dmg` (místo "Způsob 8 svatého poškození.")
  - `+15 blok` (místo "Získej 15 bloku.")
  - `+10 HP` (místo "Vyléč se za 10 HP.")

### 2. Vizuální rozlišení karet podle rarity
- **Nová funkce `_update_rarity_colors()`** v `CardUI.gd`
- Karty mají nyní barevné pozadí podle rarity:
  - **COMMON** (Běžné): Bílá
  - **UNCOMMON** (Neobvyklé): Světle zelená
  - **RARE** (Vzácné): Světle modrá
  - **EPIC** (Epické): Světle fialová
  - **LEGENDARY** (Legendární): Zlatá
  - **BASIC** (Základní): Šedá

### 3. Stručnější formátování
- Poškození: `8 dmg` nebo `8 svatého dmg` (místo "Způsob 8 poškození")
- Blok: `+15 blok` (místo "Získej 15 bloku")
- Léčení: `+10 HP` nebo `Plné HP` (místo "Vyléč se za 10 HP")
- Karty: `+2 karty` (místo "Líznutí 2 karet")
- Energie: `+1 energie` (místo "Získáš 1 energii")

## 📋 Jak to funguje

1. **Automatické generování:** Funkce `generate_compact_description()` projde všechny efekty karty a vytvoří stručný popis
2. **Fallback:** Pokud automatické generování selže, použije se původní `card_description`
3. **Barevné rozlišení:** Barva pozadí karty se automaticky nastaví podle rarity při každém update

## 🎯 Výhody

- ✅ **Stručnější popisy** - karty jsou nyní čitelnější
- ✅ **Vizuální rozlišení** - karty mají barvy podle rarity
- ✅ **Automatické** - nemusíš ručně přepisovat každou kartu
- ✅ **Konzistentní formát** - všechny karty používají stejný styl

## 📝 Poznámky

- **Svaté poškození:** Zjišťuje se z původního `card_description` (dočasné řešení)
- **Podmíněné efekty:** Nejsou zatím plně podporovány v kompaktním popise
- **Status efekty:** Základní podpora, může být rozšířeno

## 🔄 Další možné vylepšení

1. **Ikony pro typy efektů** - přidat malé ikonky vedle hodnot (⚔️ poškození, 🛡️ blok, ❤️ léčení)
2. **Lepší podpora podmíněných efektů** - zobrazovat podmínky stručněji
3. **Barevné zvýraznění hodnot** - různé barvy pro různé typy efektů v popisu
4. **Animace při hover** - zvýraznění karty při najetí myší

## 🧪 Testování

Doporučuji otestovat:
- [ ] Zobrazují se karty správně?
- [ ] Jsou popisy stručné a čitelné?
- [ ] Funguje barevné rozlišení podle rarity?
- [ ] Zobrazují se správně všechny typy efektů?

