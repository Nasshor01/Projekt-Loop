# Implementace Nových Efektů v PlayerData.gd

## 📋 Přehled

Rozšířil jsem `PassiveEffectData.gd` o **28 nových typů efektů**. Nyní je potřeba implementovat jejich aplikaci v `PlayerData.gd` a dalších relevantních souborech.

## 🎯 Kategorie efektů a kde je implementovat

### 1. Card Management efekty

#### `CARD_UNLOCK`
**Kde implementovat:** `CardPool.gd` nebo `RewardManager.gd`
**Logika:** Při načítání poolu odměn přidat kartu s ID z `string_value`
```gdscript
# Příklad v apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.CARD_UNLOCK:
    var card_id = effect_data.string_value
    # Přidat kartu do poolu odměn
    RewardManager.unlock_card(card_id)
```

#### `DRAW_CARD_FIRST_TURN`
**Kde implementovat:** `BattleScene.gd` nebo `DeckManager.gd`
**Logika:** V prvním kole souboje líznout extra karty
```gdscript
# V PlayerData.gd přidat:
var first_turn_draw_bonus: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.DRAW_CARD_FIRST_TURN:
    first_turn_draw_bonus += effect_data.value
```

#### `CONDITIONAL_DRAW`
**Kde implementovat:** `BattleScene.gd` nebo `DeckManager.gd`
**Logika:** Líznutí karty za podmínky (např. <50% HP)
```gdscript
# V PlayerData.gd:
var conditional_draw_conditions: Array[Dictionary] = []

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.CONDITIONAL_DRAW:
    conditional_draw_conditions.append({
        "condition": effect_data.string_value,
        "draw_count": effect_data.value
    })
```

#### `HAND_SIZE_BONUS`
**Kde implementovat:** `DeckManager.gd` nebo `BattleScene.gd`
**Logika:** Zvýšit maximální velikost ruky
```gdscript
# V PlayerData.gd přidat:
var max_hand_size_bonus: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.HAND_SIZE_BONUS:
    max_hand_size_bonus += effect_data.value
```

---

### 2. Resource Management efekty

#### `STARTING_RESOURCE`
**Kde implementovat:** `BattleScene.gd` - na začátku souboje
**Logika:** Začátek souboje s resource (kombo body, essence, lektvary)
```gdscript
# V PlayerData.gd přidat:
var starting_combo_points: int = 0
var starting_essence: int = 0
var starting_potions: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.STARTING_RESOURCE:
    var resource_type = effect_data.string_value.to_lower()
    match resource_type:
        "combo", "combo_points":
            starting_combo_points += effect_data.value
        "essence":
            starting_essence += effect_data.value
        "potions":
            starting_potions += effect_data.value
```

#### `STARTING_TRAP`
**Kde implementovat:** `BattleScene.gd` - na začátku souboje
**Logika:** Začátek souboje s pastí na bojišti
```gdscript
# V PlayerData.gd přidat:
var starting_traps: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.STARTING_TRAP:
    starting_traps += effect_data.value
```

#### `STARTING_POTIONS`
**Kde implementovat:** `BattleScene.gd` - na začátku souboje
**Logika:** Začátek souboje s lektvary v ruce
```gdscript
# Použít stejnou logiku jako STARTING_RESOURCE s "potions"
```

---

### 3. Combat Bonuses

#### `TARGET_BONUS_DAMAGE`
**Kde implementovat:** `BattleScene.gd` - při výpočtu poškození
**Logika:** Bonusové poškození proti označenému cíli
```gdscript
# V PlayerData.gd přidat:
var target_bonus_damage_percent: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.TARGET_BONUS_DAMAGE:
    target_bonus_damage_percent += effect_data.value
```

#### `CARD_COST_REDUCTION_TARGET`
**Kde implementovat:** `CardData.gd` nebo `BattleScene.gd` - při výpočtu ceny karty
**Logika:** Snížení ceny karty proti označenému cíli
```gdscript
# V PlayerData.gd přidat:
var target_card_cost_reduction: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.CARD_COST_REDUCTION_TARGET:
    target_card_cost_reduction += effect_data.value
```

#### `FIRST_ATTACK_FREE`
**Kde implementovat:** `BattleScene.gd` - při hraní první karty
**Logika:** První útok zdarma
```gdscript
# V PlayerData.gd přidat:
var first_attack_free_count: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.FIRST_ATTACK_FREE:
    first_attack_free_count += effect_data.value
```

#### `SPELL_BLOCK`
**Kde implementovat:** `BattleScene.gd` - při sešlání kouzla
**Logika:** Blok za každé sešlání kouzla
```gdscript
# V PlayerData.gd přidat:
var spell_block_amount: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.SPELL_BLOCK:
    spell_block_amount += effect_data.value
```

---

### 4. Passive Enhancements

#### `PASSIVE_ENHANCEMENT`
**Kde implementovat:** `UnitData.gd` nebo `PassiveAbilityManager.gd`
**Logika:** Vylepšení konkrétní pasivní schopnosti
```gdscript
# V PlayerData.gd přidat:
var passive_enhancements: Dictionary = {}  # {passive_id: bonus_value}

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.PASSIVE_ENHANCEMENT:
    var passive_id = effect_data.string_value
    if not passive_enhancements.has(passive_id):
        passive_enhancements[passive_id] = 0
    passive_enhancements[passive_id] += effect_data.value
```

#### `PASSIVE_RESONANCE_BONUS`
**Kde implementovat:** `UnitData.gd` - při výpočtu rezonance
**Logika:** Bonus k pasivní rezonanci
```gdscript
# V PlayerData.gd přidat:
var passive_resonance_bonus_percent: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.PASSIVE_RESONANCE_BONUS:
    passive_resonance_bonus_percent += effect_data.value
```

#### `PASSIVE_USE_COUNT`
**Kde implementovat:** `UnitData.gd` - při použití pasivní schopnosti
**Logika:** Počet použití pasivní schopnosti za kolo
```gdscript
# V PlayerData.gd přidat:
var passive_use_count_bonus: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.PASSIVE_USE_COUNT:
    passive_use_count_bonus += effect_data.value
```

#### `PASSIVE_TRIGGER_THRESHOLD`
**Kde implementovat:** `UnitData.gd` - při kontrole aktivace pasivní schopnosti
**Logika:** Změna prahu aktivace
```gdscript
# V PlayerData.gd přidat:
var passive_threshold_overrides: Dictionary = {}  # {passive_id: new_threshold}

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.PASSIVE_TRIGGER_THRESHOLD:
    var passive_id = effect_data.string_value
    passive_threshold_overrides[passive_id] = effect_data.value
```

---

### 5. Posture System (Fighter)

#### `POSTURE_BONUS`
**Kde implementovat:** `FighterUnit.gd` nebo `BattleScene.gd`
**Logika:** Bonus v určitém postoji
```gdscript
# V PlayerData.gd přidat:
var posture_bonuses: Dictionary = {}  # {posture_type: bonus_percent}

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.POSTURE_BONUS:
    var posture = effect_data.string_value.to_lower()
    if not posture_bonuses.has(posture):
        posture_bonuses[posture] = 0
    posture_bonuses[posture] += effect_data.value
```

#### `POSTURE_COST_REDUCTION`
**Kde implementovat:** `FighterUnit.gd` - při přepnutí postoje
**Logika:** Snížení ceny přepnutí postoje
```gdscript
# V PlayerData.gd přidat:
var posture_switch_cost_reduction: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.POSTURE_COST_REDUCTION:
    posture_switch_cost_reduction += effect_data.value
```

---

### 6. DoT/Status

#### `POISON_DAMAGE_BONUS`
**Kde implementovat:** `StatusEffectManager.gd` nebo `BattleScene.gd`
**Logika:** Bonus k jedům
```gdscript
# V PlayerData.gd přidat:
var poison_damage_bonus: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.POISON_DAMAGE_BONUS:
    poison_damage_bonus += effect_data.value
```

---

### 7. Summoning (Nekromant)

#### `SUMMON_HEALTH_BONUS`
**Kde implementovat:** `SummonManager.gd` nebo `BattleScene.gd`
**Logika:** Bonus HP pro vyvolané jednotky
```gdscript
# V PlayerData.gd přidat:
var summon_health_bonus: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.SUMMON_HEALTH_BONUS:
    summon_health_bonus += effect_data.value
```

#### `ENEMY_TO_CARD_CONVERSION`
**Kde implementovat:** `BattleScene.gd` - při zabití nepřítele
**Logika:** Převod zabitých nepřátel na karty
```gdscript
# V PlayerData.gd přidat:
var enemy_to_card_conversion_percent: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.ENEMY_TO_CARD_CONVERSION:
    enemy_to_card_conversion_percent += effect_data.value
```

---

### 8. Lifesteal (Vrah Duší)

#### `LIFESTEAL_PERCENTAGE`
**Kde implementovat:** `BattleScene.gd` - při způsobení poškození
**Logika:** Procentuální lifesteal
```gdscript
# V PlayerData.gd přidat:
var lifesteal_percentage: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.LIFESTEAL_PERCENTAGE:
    lifesteal_percentage += effect_data.value
```

#### `OVERHEAL_TO_TEMP_HP`
**Kde implementovat:** `BattleScene.gd` - při léčení
**Logika:** Přebytečné léčení → dočasné HP
```gdscript
# V PlayerData.gd přidat:
var overheal_to_temp_hp_percent: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.OVERHEAL_TO_TEMP_HP:
    overheal_to_temp_hp_percent += effect_data.value
```

#### `ALLIED_DAMAGE_LIFESTEAL`
**Kde implementovat:** `BattleScene.gd` - při poškození spojenců
**Logika:** Lifesteal z poškození spojenců
```gdscript
# V PlayerData.gd přidat:
var allied_damage_lifesteal_percent: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.ALLIED_DAMAGE_LIFESTEAL:
    allied_damage_lifesteal_percent += effect_data.value
```

---

### 9. Conditional Effects

#### `CONDITIONAL_BLOCK`
**Kde implementovat:** `BattleScene.gd` - při kontrole podmínek
**Logika:** Blok za podmínky
```gdscript
# V PlayerData.gd přidat:
var conditional_block_effects: Array[Dictionary] = []

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.CONDITIONAL_BLOCK:
    conditional_block_effects.append({
        "condition": effect_data.string_value,
        "block_amount": effect_data.value
    })
```

#### `STARTING_TEMP_HP`
**Kde implementovat:** `BattleScene.gd` - na začátku souboje
**Logika:** Začátek s dočasným HP
```gdscript
# V PlayerData.gd přidat:
var starting_temp_hp: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.STARTING_TEMP_HP:
    starting_temp_hp += effect_data.value
```

---

### 10. Support (Ochránce)

#### `ALLIED_DEFENSE_BONUS`
**Kde implementovat:** `BattleScene.gd` - při výpočtu obrany spojenců
**Logika:** Bonus k obraně spojenců
```gdscript
# V PlayerData.gd přidat:
var allied_defense_bonus_percent: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.ALLIED_DEFENSE_BONUS:
    allied_defense_bonus_percent += effect_data.value
```

#### `FORCE_ENEMY_MOVEMENT`
**Kde implementovat:** `BattleScene.gd` - při použití schopnosti
**Logika:** Donutit nepřátele k pohybu
```gdscript
# V PlayerData.gd přidat:
var force_enemy_movement_uses: int = 0

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.FORCE_ENEMY_MOVEMENT:
    force_enemy_movement_uses += effect_data.value
```

---

### 11. Elemental (Elementalista)

#### `FIRST_SPELL_ELEMENT_FREE`
**Kde implementovat:** `BattleScene.gd` - při sešlání prvního kouzla živlu
**Logika:** První kouzlo každého živlu zdarma
```gdscript
# V PlayerData.gd přidat:
var first_spell_element_free: bool = false
var used_free_elements: Array[String] = []  # ["fire", "ice", "lightning"]

# V apply_passive_skills():
if effect_data.effect_type == PassiveEffectData.EffectType.FIRST_SPELL_ELEMENT_FREE:
    first_spell_element_free = true
```

---

## 🔧 Implementační poznámky

### Priorita implementace:
1. **Vysoká:** Základní efekty (HP, Energy, Block, Damage)
2. **Střední:** Card Management, Resource Management
3. **Nízká:** Speciální mechaniky (Posture, Summoning, Lifesteal)

### Důležité:
- Některé efekty vyžadují změny v jiných souborech (BattleScene, DeckManager, atd.)
- Některé efekty jsou runtime (aplikují se během souboje), jiné jsou statické (aplikují se na začátku)
- Conditional efekty vyžadují systém pro kontrolu podmínek

### Další kroky:
1. Přidat nové proměnné do `PlayerData.gd`
2. Implementovat aplikaci efektů v `apply_passive_skills()`
3. Implementovat runtime logiku v relevantních souborech
4. Testovat každý efekt zvlášť

