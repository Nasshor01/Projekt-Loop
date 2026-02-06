# 🎯 Návrhy nových nepřátel pro testování AI

## 📊 Přehled AI typů

**Již otestované:**
- ✅ **FighterAI** - Goblin, Skeleton (základní melee)
- ✅ **ArcherAI** - Skeleton Archer (taktický lukostřelec)

**Potřebují otestovat:**
- ❌ **BerserkerAI** - rush mechanika po 5 kolech
- ❌ **AssassinAI** - rychlý pohyb, dodge (35%), double attack (25%)
- ❌ **MageAI** - elementální poškození, meteorit po 10 kolech
- ❌ **DruidAI** - spawnuje spirity (30% šance)
- ❌ **MonkAI** - buffuje spojence (neútočí)
- ❌ **HealerAI** - léčí spojence, holy damage

---

## 🎮 Navržené jednotky pro testování

### 1. **Orc Berserker** (BerserkerAI)
**Soubory:** `data/units/orc_berserker.tres`, `data/encounters/berserker_test.tres`

```gdscript
unit_id = "orc_berserker"
unit_name = "Orc Berserker"
description = "Zuřivý berserker s rush útokem po 5 kolech"
faction = 1 (ENEMY)
unit_type = 1 (HUMAN)
max_health = 40
attack_damage = 8
movement_range = 1  # Omezený pohyb!
attack_range = 1
initiative = 8  # Nízká iniciativa (později v tahu)
sprite_texture = [existující Orc.png nebo jiný sprite]
ai_script = res://scripts/ai/BerserkerAI.gd
```

**Testování:** 
- ✅ Omezený pohyb (1 pole)
- ✅ Rush útok po 5 kolech frustrace
- ✅ 3x damage při rush útoku
- ✅ Permanentní rage mode

---

### 2. **Dark Assassin** (AssassinAI)
**Soubory:** `data/units/dark_assassin.tres`, `data/encounters/assassin_test.tres`

```gdscript
unit_id = "dark_assassin"
unit_name = "Dark Assassin"
description = "Rychlý zabiják s dodge a double attack"
faction = 1 (ENEMY)
unit_type = 1 (HUMAN)
max_health = 20
attack_damage = 4
movement_range = 5  # Rychlý pohyb!
attack_range = 1
initiative = 14  # Vysoká iniciativa
sprite_texture = [existující sprite nebo placeholder]
ai_script = res://scripts/ai/AssassinAI.gd
```

**Testování:**
- ✅ Rychlý pohyb (5 polí)
- ✅ 25% šance na double attack (75% damage za útok)
- ✅ 35% šance na dodge (musí být implementováno v Unit.gd)

---

### 3. **Fire Mage** (MageAI)
**Soubory:** `data/units/fire_mage.tres`, `data/encounters/mage_test.tres`

```gdscript
unit_id = "fire_mage"
unit_name = "Fire Mage"
description = "Kouzelník s elementálním poškozením a meteoritem"
faction = 1 (ENEMY)
unit_type = 1 (HUMAN)
max_health = 30
attack_damage = 6
movement_range = 2
attack_range = 5  # Bojuje z dálky!
initiative = 10
sprite_texture = [existující sprite nebo placeholder]
ai_script = res://scripts/ai/MageAI.gd
```

**Testování:**
- ✅ Elementální poškození (Burning)
- ✅ Meteorit po 10 kolech (2x damage)
- ✅ Udržuje vzdálenost (preferuje 5 polí)
- ✅ Couvá, když je příliš blízko

---

### 4. **Nature Druid** (DruidAI)
**Soubory:** `data/units/nature_druid.tres`, `data/encounters/druid_test.tres`

```gdscript
unit_id = "nature_druid"
unit_name = "Nature Druid"
description = "Přírodní mág, spawnuje spirity na pomoc"
faction = 1 (ENEMY)
unit_type = 1 (HUMAN)
max_health = 35
attack_damage = 5
movement_range = 3
attack_range = 2
initiative = 11
sprite_texture = [existující sprite nebo placeholder]
ai_script = res://scripts/ai/DruidAI.gd
```

**Testování:**
- ✅ 30% šance na spawn spiritu každé kolo
- ✅ 5% šance na spawn ochránce
- ✅ Max 3 spirity najednou
- ✅ Útočí, když nemůže spawnovat

**POZNÁMKA:** Potřebuješ UnitData pro spirit jednotku, pokud ještě nemáš!

---

### 5. **Warrior Monk** (MonkAI)
**Soubory:** `data/units/warrior_monk.tres`, `data/encounters/monk_test.tres`

```gdscript
unit_id = "warrior_monk"
unit_name = "Warrior Monk"
description = "Mniš, buffuje spojence místo útoku"
faction = 1 (ENEMY)
unit_type = 1 (HUMAN)
max_health = 40
attack_damage = 0  # NEÚTOČÍ!
movement_range = 3
attack_range = 1
initiative = 12
sprite_texture = [existující sprite nebo placeholder]
ai_script = res://scripts/ai/MonkAI.gd
```

**Testování:**
- ✅ Neútočí vůbec!
- ✅ Buffuje spojence v dosahu 3 polí
- ✅ +2 damage bonus na 3 kola
- ✅ Přibližuje se ke spojencům

---

### 6. **Cleric** (HealerAI)
**Soubory:** `data/units/cleric.tres`, `data/encounters/healer_test.tres`

```gdscript
unit_id = "cleric"
unit_name = "Cleric"
description = "Léčitel s holy damage proti nemrtvým"
faction = 1 (ENEMY)
unit_type = 1 (HUMAN)
max_health = 25
attack_damage = 4
movement_range = 2
attack_range = 2
initiative = 10
sprite_texture = [existující sprite nebo placeholder]
ai_script = res://scripts/ai/HealerAI.gd
```

**Testování:**
- ✅ Léčí spojence pod 50% HP
- ✅ 8 HP léčení v dosahu 4 polí
- ✅ Holy damage (1.5x proti undead/skeleton)
- ✅ Útočí, když nemá koho léčit

---

## 🔥 Smíšené encountery pro komplexní testování

### **Mix 1: Těžká skupina** (`elite_mix.tres`)
- 1x Orc Berserker (BerserkerAI)
- 1x Fire Mage (MageAI)
- 1x Cleric (HealerAI)

**Co testuje:**
- ✅ Berserker rush po 5 kolech
- ✅ Mage meteorit po 10 kolech
- ✅ Cleric léčí berserkera a mága
- ✅ Koordinace mezi různými AI

---

### **Mix 2: Rychlá skupina** (`assassin_squad.tres`)
- 2x Dark Assassin (AssassinAI)
- 1x Warrior Monk (MonkAI)

**Co testuje:**
- ✅ Rychlý pohyb assassinů (5 polí)
- ✅ Double attack šance (25%)
- ✅ Monk buffuje assassiny (+2 damage)
- ✅ Koordinace mezi podpůrnou a útočnou AI

---

### **Mix 3: Support skupina** (`support_team.tres`)
- 1x Nature Druid (DruidAI)
- 1x Warrior Monk (MonkAI)
- 1x Cleric (HealerAI)
- 1x Goblin (FighterAI) - jako "tank"

**Co testuje:**
- ✅ Druid spawnuje spirity
- ✅ Monk buffuje goblina a druida
- ✅ Cleric léčí zraněné jednotky
- ✅ Komplexní podpůrná strategie

---

### **Mix 4: Všechny AI najednou** (`all_ai_test.tres`)
- 1x Goblin (FighterAI) - základ
- 1x Skeleton Archer (ArcherAI) - lukostřelec
- 1x Dark Assassin (AssassinAI) - rychlý útočník
- 1x Fire Mage (MageAI) - kouzelník
- 1x Warrior Monk (MonkAI) - support

**Co testuje:**
- ✅ Všechny AI typy najednou
- ✅ Koordinace mezi všemi typy
- ✅ Různé iniciativy a priority
- ✅ Komplexní bojovou dynamiku

---

## 📋 Priorita testování

### **Fáze 1: Individuální testy** (nejsnáze)
1. ✅ Orc Berserker - test rush mechaniky
2. ✅ Dark Assassin - test rychlého pohybu a double attack
3. ✅ Fire Mage - test elementálního poškození a meteoritu
4. ✅ Cleric - test léčení a holy damage

### **Fáze 2: Dvojice** (střední obtížnost)
5. ✅ Berserker + Cleric - test léčení během boje
6. ✅ Assassin + Monk - test buffování rychlých jednotek
7. ✅ Druid + Monk - test spawnu + buffování

### **Fáze 3: Komplexní** (nejtěžší)
8. ✅ Všechny AI najednou - finální test koordinace

---

## ⚠️ Důležité poznámky

1. **Druid spawn:** Potřebuješ UnitData pro spirit jednotku, pokud chceš plně otestovat DruidAI
2. **Dodge mechanika:** Assassin má 35% dodge - zkontroluj, jestli je implementováno v Unit.gd
3. **Spirit jednotka:** Pro DruidAI můžeš vytvořit jednoduchý FighterAI spirit jako placeholder
4. **Textury:** Můžeš použít existující sprites jako placeholder (Goblin.png, Skeleton.png, atd.)

---

## 🚀 Rychlý start

1. Začni s **Orc Berserker** - je nejjednodušší na testování (jen rush mechanika)
2. Pak přidej **Dark Assassin** - rychlý a dynamický
3. Pak **Fire Mage** - testuje elementální efekty
4. Nakonec **Cleric** - testuje podpůrné schopnosti

Každý vytvoř jako samostatný encounter pro snadné testování!
