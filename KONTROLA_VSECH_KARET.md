# Kontrola všech karet - systematický přehled

## 🔍 Postup kontroly
1. ✅ Opravit aura_of_devotion (změněno z GAIN_ENERGY na APPLY_STATUS)
2. ✅ Opravit popis nimble_move
3. ⏳ Projít všechny karty se svatým poškozením a nastavit damage_type = HOLY
4. ⏳ Zkontrolovat všechny efekty, jestli jsou správně nastavené
5. ⏳ Zkontrolovat, jestli všechny karty mají správné target_type a area_of_effect_type

## 📋 Karty se svatým poškozením (potřebují damage_type = 1)

### Paladin karty:
- [ ] holy_strike.tres - NEMÁ damage_type
- [x] smite.tres - MÁ damage_type = 1 ✅
- [ ] smite_upgraded.tres - ZKONTROLOVAT
- [ ] holy_vengeance.tres - NEMÁ damage_type
- [ ] holy_wrath.tres - NEMÁ damage_type  
- [ ] holy_defense.tres - NEMÁ damage_type
- [ ] holy_knight.tres - NEMÁ damage_type
- [ ] consecrated_weapon.tres - NEMÁ damage_type (má 2 efekty - 1 poškození, 1 status)
- [x] divine_justice.tres - MÁ damage_type = 1 ✅
- [x] divine_judgment.tres - ZKONTROLOVAT
- [x] divine_protection.tres - ZKONTROLOVAT
- [ ] excommunication.tres - NEMÁ damage_type
- [ ] gods_wrath.tres - NEMÁ damage_type
- [ ] gods_lightning.tres - ZKONTROLOVAT
- [ ] divine_wrath.tres - ZKONTROLOVAT
- [ ] holy_wave.tres - ZKONTROLOVAT
- [ ] holy_wave_upgraded.tres - ZKONTROLOVAT

## 🔧 Postup oprav

### Krok 1: Přidat damage_type = 1 u všech holy karet s DEAL_DAMAGE efektem
### Krok 2: Zkontrolovat všechny ostatní efekty
### Krok 3: Zkontrolovat target_type a area_of_effect_type

