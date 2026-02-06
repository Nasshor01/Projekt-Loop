# Systém typů nepřátel a efektivity poškození

## ✅ Co bylo implementováno

### 1. Enum pro typy jednotek
V `UnitData.gd` byly přidány typy jednotek:
- **HUMAN** - Lidské bytosti
- **UNDEAD** - Nemrtví (skeleton, zombie, atd.)
- **DEMON** - Démoni
- **BEAST** - Zvířata
- **ELEMENTAL** - Elementální bytosti
- **CONSTRUCT** - Golemové, mechanické bytosti
- **SPIRIT** - Duchové, přízraky
- **DRAGON** - Draci
- **OTHER** - Ostatní/nespecifikované

### 2. Enum pro typy poškození
V `CardEffectData.gd` byly přidány typy poškození:
- **NORMAL** - Běžné fyzické poškození
- **HOLY** - Svaté poškození (silné proti UNDEAD, DEMON)
- **FIRE** - Ohnivé poškození
- **ICE** - Ledové poškození
- **LIGHTNING** - Bleskové poškození
- **POISON** - Jedovaté poškození
- **ARCANE** - Tajemné/arčanské poškození

### 3. Systém efektivity poškození
- **HOLY damage vs UNDEAD:** +50% poškození (1.5x)
- **HOLY damage vs DEMON:** +50% poškození (1.5x)
- **HOLY damage vs SPIRIT:** +25% poškození (1.25x)
- Ostatní kombinace: normální poškození (1.0x)

### 4. Vizuální feedback
Efektivní poškození se zobrazuje zlatou barvou s ✨ symbolem.

## 📋 Co je potřeba udělat

### 1. Nastavit typy u existujících nepřátel
V Godot editoru otevři tyto soubory a nastav `unit_type`:

**Nemrtví (UNDEAD):**
- `data/units/skeleton.tres` → `unit_type = UNDEAD`
- `data/units/skeleton_archer.tres` → `unit_type = UNDEAD`
- (ostatní skeleton varianty)

**Démoni (DEMON):**
- `data/units/Boss_demonGirl.tres` → `unit_type = DEMON`

**Lidé (HUMAN):**
- `data/units/goblin_unit.tres` → `unit_type = HUMAN` (nebo možná BEAST?)
- `data/units/Orc_unit.tres` → `unit_type = HUMAN` (nebo možná BEAST?)

**Zvířata (BEAST):**
- `data/units/DarkBeast_unit.tres` → `unit_type = BEAST`
- `data/units/elite_beast.tres` → `unit_type = BEAST`

### 2. Nastavit damage_type u holy karet
Všechny Paladin karty se svatým poškozením musí mít nastavený `damage_type = HOLY` u efektu DEAL_DAMAGE:

**Karty k nastavení:**
- `holy_strike.tres`
- `holy_vengeance.tres`
- `holy_wrath.tres`
- `holy_defense.tres`
- `holy_knight.tres`
- `divine_justice.tres`
- `divine_judgment.tres`
- `divine_protection.tres`
- `gods_wrath.tres`
- `gods_lightning.tres`
- `excommunication.tres`
- (všechny ostatní se "svaté poškození" v popise)

**Jak na to:**
1. Otevři kartu v Godot editoru
2. Najdi efekt typu DEAL_DAMAGE
3. Nastav `damage_type = HOLY`

### 3. Fallback detekce
Pokud není nastaven `damage_type`, systém automaticky detekuje holy damage z `card_description` (obsahuje "svatého poškození" nebo "svaté poškození").

## 🎯 Jak to funguje

1. **Při aplikaci poškození** se zkontroluje typ poškození (z efektu nebo z popisu karty)
2. **Pokud je poškození HOLY** a cíl je UNDEAD/DEMON/SPIRIT, aplikuje se multiplikátor efektivity
3. **Vizuální feedback** - efektivní poškození se zobrazí zlatou barvou s ✨ symbolem

## 💡 Budoucí rozšíření

- Fire damage vs ICE (efektivní)
- Lightning vs CONSTRUCT (efektivní)
- Poison vs LIVING (efektivní)
- A další kombinace podle potřeby

## ⚠️ Poznámky

- Typy nepřátel se nastavují v `.tres` souborech v Godot editoru
- Damage type se nastavuje u každého DEAL_DAMAGE efektu
- Fallback detekce funguje, ale doporučuje se explicitně nastavit `damage_type`

