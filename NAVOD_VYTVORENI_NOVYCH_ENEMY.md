# 📋 NÁVOD: Jak vytvořit nové enemy s pokročilými AI

## ✅ Co už je hotové:
- ✅ Všechny AI skripty (AssassinAI, MageAI, DruidAI, MonkAI, HealerAI)
- ✅ Elementární efekty (Burning, Chilled, Frozen, Shocked)
- ✅ Systém pro zpracování speciálních akcí

## 🎯 Co teď musíš udělat:

### **KROK 1: Vytvořit UnitData soubory pro nové enemy**

V Godot editoru:

1. **Pravý klik** na složku `data/units/`
2. **New Resource** → vyber `UnitData`
3. Pojmenuj soubor (např. `assassin_unit.tres`, `mage_unit.tres`)

### **KROK 2: Nastavit vlastnosti UnitData**

Pro každý nový enemy nastav:

#### **Assassin:**
```
unit_id = "assassin"
unit_name = "Assassin"
description = "Rychlý zabiják s dodge a double attack"
faction = 1 (ENEMY)
max_health = 20
attack_damage = 4
movement_range = 5  (rychlejší pohyb)
attack_range = 1
initiative = 14
sprite_texture = [tvoje textura]
ai_script = res://scripts/ai/AssassinAI.gd
```

#### **Mage:**
```
unit_id = "mage"
unit_name = "Mage"
description = "Kouzelník s elementálním poškozením a meteoritem"
faction = 1 (ENEMY)
max_health = 30
attack_damage = 6
movement_range = 2
attack_range = 5  (bojuje z dálky)
initiative = 10
sprite_texture = [tvoje textura]
ai_script = res://scripts/ai/MageAI.gd
```

#### **Druid:**
```
unit_id = "druid"
unit_name = "Druid"
description = "Přírodní mág, spawnuje spirity"
faction = 1 (ENEMY)
max_health = 35
attack_damage = 5
movement_range = 3
attack_range = 2
initiative = 11
sprite_texture = [tvoje textura]
ai_script = res://scripts/ai/DruidAI.gd
```

#### **Monk:**
```
unit_id = "monk"
unit_name = "Monk"
description = "Mniš, buffuje spojence místo útoku"
faction = 1 (ENEMY)
max_health = 40
attack_damage = 0  (neútočí!)
movement_range = 3
attack_range = 1
initiative = 12
sprite_texture = [tvoje textura]
ai_script = res://scripts/ai/MonkAI.gd
```

#### **Healer/Cleric:**
```
unit_id = "healer"
unit_name = "Cleric"
description = "Léčitel s holy damage"
faction = 1 (ENEMY)
max_health = 25
attack_damage = 4
movement_range = 2
attack_range = 2
initiative = 10
sprite_texture = [tvoje textura]
ai_script = res://scripts/ai/HealerAI.gd
```

### **KROK 3: Vytvořit EncounterData pro nové kombinace**

1. **Pravý klik** na složku `data/encounters/`
2. **New Resource** → vyber `EncounterData`
3. Pojmenuj (např. `assassin_encounter.tres`)

4. **Nastav:**
   - `encounter_type = 0` (NORMAL) nebo `1` (ELITE)
   - `xp_reward = 15` (nebo jiná hodnota)
   - V `enemies` přidej `EncounterEntry`:
     - `unit_data` = odkaz na tvůj nový UnitData
     - `grid_position` = pozice na gridu (např. `Vector2i(5, 3)`)

### **KROK 4: Otestovat v hře**

1. Spusť hru
2. Vytvoř test encounter s novým enemy
3. Otestuj, jestli AI funguje správně

---

## 📝 Příklad: Vytvoření Assassina

### V Godot editoru:

1. **Vytvoř UnitData:**
   - `data/units/assassin_unit.tres`
   - Nastav všechny vlastnosti podle výše
   - **DŮLEŽITÉ:** V `ai_script` vyber `res://scripts/ai/AssassinAI.gd`

2. **Vytvoř EncounterData:**
   - `data/encounters/assassin_test.tres`
   - Přidej Assassina do `enemies` pole

3. **Otestuj:**
   - Spusť hru a vytvoř encounter s Assassinem
   - Měl by:
     - ✅ Rychle se pohybovat (5 polí)
     - ✅ Mít 25% šanci na double attack
     - ✅ Mít 35% šanci na dodge

---

## 🔧 Tipy:

- **Textury:** Pokud nemáš textury, můžeš použít existující (např. `Goblin.png`) jako placeholder
- **Balance:** Uprav `max_health` a `attack_damage` podle obtížnosti
- **Iniciativa:** Vyšší iniciativa = dříve v tahu
- **Attack Range:** 
  - `1` = melee
  - `2-3` = střední vzdálenost
  - `4+` = dlouhá vzdálenost

---

## ⚠️ Poznámky:

- **Druid spawn:** Spawn spiritů ještě není plně implementován (potřebuje UnitData pro spirit)
- **Mage meteorit:** Funguje, ale můžeš přidat vizuální efekt
- **Monk buff:** Buff funguje, ale můžeš přidat vizuální indikátor

---

## 🎮 Rychlý test:

Nejjednodušší způsob, jak otestovat:
1. Vytvoř `assassin_unit.tres` s AssassinAI
2. Uprav existující encounter (např. `first_battle.tres`)
3. Nahraď jednoho goblina za Assassina
4. Spusť hru a otestuj!

---

**Máš otázky? Zkus to a dej vědět, pokud něco nefunguje!** 🚀

