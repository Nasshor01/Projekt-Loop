# Damage Calculation & Application Audit

This document summarizes how damage is calculated, modified, and applied across the project. It identifies the split between **display numbers** (what the player sees on cards) and **actual damage** (what is subtracted from HP).

---

## 1. EffectType.DEAL_DAMAGE and DEAL_DAMAGE_FROM_BLOCK

### DEAL_DAMAGE

| File | Location | Responsibility |
|------|----------|----------------|
| `scenes/battle/BattleScene.gd` | Lines 996–1082 | **Main execution** – applies damage to targets, handles all bonuses and modifiers |
| `data/cards/CardData.gd` | Lines 153–174 | **UI display** – builds `final_damage` for card description via `generate_compact_description()` |
| `data/cards/CardEffectData.gd` | Lines 7–8, 41 | Enum and effect definition |

### DEAL_DAMAGE_FROM_BLOCK

| File | Location | Responsibility |
|------|----------|----------------|
| `scenes/battle/BattleScene.gd` | Lines 1125–1128 | **Execution** – `target.take_damage(_player_unit_node.current_block)` |
| `data/artifacts/ArtifactsData.gd` | Line 54 | Effect type enum |

**DEAL_DAMAGE_FROM_BLOCK note:** Damage equals `current_block` only. No bonuses (e.g. `PlayerData.global_card_damage_bonus` or `ArtifactManager.get_card_damage_bonus`) are applied.

### DEAL_DOUBLE_DAMAGE_FROM_BLOCK

| File | Location | Responsibility |
|------|----------|----------------|
| `scenes/battle/BattleScene.gd` | Lines 1165–1168 | `target.take_damage(_player_unit_node.current_block * 2)` – no other bonuses applied |

---

## 2. Functions That Modify or Return Damage Values

| File | Function | Purpose |
|------|----------|---------|
| `data/cards/CardData.gd` | `get_damage_bonus()` (113–136) | Returns `PlayerData.global_card_damage_bonus + ArtifactManager.get_card_damage_bonus(context)`. Used for **card UI display** only. |
| `scripts/autoload/PlayerData.gd` | `global_card_damage_bonus` | Passive bonus from skills (e.g. Holy Power) |
| `scripts/autoload/ArtifactManager.gd` | `get_card_damage_bonus(context)` (304–307) | Returns `get_passive_bonus(MODIFY_CARD_DAMAGE) + get_conditional_bonus(MODIFY_CARD_DAMAGE, context)` |
| `data/units/UnitData.gd` | `get_damage_effectiveness(damage_type, target_type)` (60–78) | Returns 1.0, 1.25, or 1.5 for Holy vs Undead/Demon/Spirit |
| `scenes/battle/Unit.gd` | `attack(target, damage_multiplier)` (102–132) | Computes damage for **enemy basic attacks** (not cards): `attack_damage * multiplier + global_card_damage_bonus + ArtifactManager.get_card_damage_bonus` |

---

## 3. Code That Subtracts Health from Units

### Unit.gd (main logic)

| Location | Logic |
|----------|-------|
| **Line 170** | `current_health -= damage_to_deal` – HP reduction |
| **Line 177** | `PlayerData.take_damage(damage_to_deal)` – when target is player |
| **Lines 134–186** | `take_damage(amount)` – full damage flow: Assassin dodge → defensive_stance (×0.5) → block absorption → HP reduction |

### BattleScene.gd

| Location | Logic |
|----------|-------|
| **Line 1064** | `await target.take_damage(damage_to_deal)` – DEAL_DAMAGE |
| **Line 1127** | `target.take_damage(_player_unit_node.current_block)` – DEAL_DAMAGE_FROM_BLOCK |
| **Line 1168** | `target.take_damage(damage)` – DEAL_DOUBLE_DAMAGE_FROM_BLOCK |
| **Line 871** | `_player_unit_node.take_damage(debuff.damage)` – debuff_on_overuse |
| **Line 1524** | `await unit.take_damage(damage)` – Mage Meteor AoE |

### Unit.gd – Burning status

| Location | Logic |
|----------|-------|
| **Lines 299–304** | `take_damage(damage)` with `status_data.value` – no `poison_damage_bonus` applied |

### Other damage sources

| File | Location | Logic |
|------|----------|-------|
| `data/artifacts/ArtifactEffect.gd` | 76–77 | `target_unit.take_damage(artifact_data.get_effective_value())` |
| `data/artifacts/ArtifactEffect.gd` | 92–94 | Thorns: `attacker.take_damage(thorns_damage)` |
| `scripts/autoload/ArtifactManager.gd` | 398–399 | Cursed ring: `player.take_damage(abs(artifact.secondary_value))` |
| `scripts/resources/EventCost.gd` | 46 | `PlayerData.take_damage(hp)` for event costs |

---

## 4. Damage Multipliers (Holy, Vulnerable, etc.)

### Holy damage effectiveness (UnitData.gd, 60–78)

| Target Type | Multiplier |
|-------------|------------|
| UNDEAD | 1.5 |
| DEMON | 1.5 |
| SPIRIT | 1.25 |
| Other | 1.0 |

**Usage:** `BattleScene.gd` lines 1034–1041 – applied only for `DEAL_DAMAGE` when target is `Unit` with `UnitData`.

### Vulnerable status

- **Defined:** `data/cards/CardData.gd` (line 344), applied by cards (e.g. Excommunication)
- **Implemented:** Not used in damage calculation. `Unit.gd` and `BattleScene.gd` do not multiply damage when target has `vulnerable`.
- **Note:** `KONTROLA_KARET_PALADIN.md` says vulnerable “musí být implementován v battle systému” – currently missing.

### Other multipliers

| Source | File | Multiplier | Used for |
|--------|------|------------|----------|
| HealerAI | `scripts/ai/HealerAI.gd` | 1.5 | Holy damage vs Undead (enemy attacks) |
| ArcherAI | `scripts/ai/ArcherAI.gd` | 2.5 (aim), 1.5 (cover) | Enemy attacks |
| BerserkerAI | `scripts/ai/BerserkerAI.gd` | 3.0 | Rush attack |
| AssassinAI | `scripts/ai/AssassinAI.gd` | 0.75 | Double attack |
| MageAI | `scripts/ai/MageAI.gd` | 2.0 | Meteor |
| Unit.gd | Lines 150–151 | 0.5 | `defensive_stance` (damage reduction) |
| BattleScene.gd | Line 1052 | 2× | Critical hit |
| Unit.gd | Line 128 | 2× | Critical hit (enemy attacks on player) |

---

## 5. UI Display vs Actual Damage

### How the card UI gets its numbers

**Flow:** `CardUI.gd` (line 77) → `card_data.get_display_description()` → `generate_compact_description()` in `CardData.gd`.

**`generate_compact_description()` (CardData.gd, 137–311):**

- For `DEAL_DAMAGE`:
  - `damage_bonus = get_damage_bonus()` → `PlayerData.global_card_damage_bonus + ArtifactManager.get_card_damage_bonus(context)`
  - `final_damage = effect_value + damage_bonus` (line 156)
  - Conditional bonuses are described in text, but the shown number is `final_damage` (base + flat bonus only)

### Displayed number (what player sees)

```
Displayed = effect.value + PlayerData.global_card_damage_bonus + ArtifactManager.get_card_damage_bonus(context)
```

- Includes: base damage, global card damage bonus, artifact damage bonus  
- Excludes: conditional bonuses, damage_per_block, consecrated_weapon, damage effectiveness (Holy vs enemy type), critical hit, Vulnerable

### Actual damage (BattleScene.gd DEAL_DAMAGE, 997–1064)

```
Actual = effect.value
       + bonus_value  (conditional_bonus_value if condition met)
       + (current_block * conditional_bonus_value)  [if damage_per_block]
       + consecrated_weapon status value  [if present]
       + PlayerData.global_card_damage_bonus
       + ArtifactManager.get_card_damage_bonus(context)
       × UnitData.get_damage_effectiveness(damage_type, target.unit_type)  [1.0, 1.25, 1.5]
       × (2 if critical hit else 1)
```

Then in `Unit.take_damage()`:

```
HP reduction = min(Actual, current_block)  →  block first
             + max(0, Actual - current_block)  →  remainder to HP
             × (0.5 if defensive_stance else 1)
```

---

## 6. Summary: Display vs Actual

| Factor | In card UI? | In actual damage? |
|--------|-------------|-------------------|
| Base effect value | Yes | Yes |
| `PlayerData.global_card_damage_bonus` | Yes | Yes |
| `ArtifactManager.get_card_damage_bonus` | Yes | Yes |
| Conditional bonus (block_above, target_health_above_percent, etc.) | Shown as text only | Yes |
| `damage_per_block` (e.g. Holy Vengeance) | Shown as “+1 per block” | Yes |
| consecrated_weapon status | No | Yes |
| Holy damage effectiveness (1.25×, 1.5×) | No | Yes |
| Critical hit (2×) | No | Yes |
| Vulnerable status | Shown on target | **Not implemented** |
| defensive_stance (50% reduction) | No | Yes (in take_damage) |
| Block absorption | No | Yes (in take_damage) |

### DEAL_DAMAGE_FROM_BLOCK and DEAL_DOUBLE_DAMAGE_FROM_BLOCK

- UI: Card text does not show a numeric damage value (block is dynamic).
- Actual: `current_block` or `current_block × 2`, no damage bonuses.

---

## 7. File Responsibility Overview

| File | Role |
|------|------|
| `data/cards/CardData.gd` | Card UI damage: `get_damage_bonus()`, `generate_compact_description()` |
| `data/cards/CardEffectData.gd` | Effect type and damage type definitions |
| `data/units/UnitData.gd` | Holy damage effectiveness (1.0 / 1.25 / 1.5) |
| `scenes/battle/BattleScene.gd` | DEAL_DAMAGE / DEAL_DAMAGE_FROM_BLOCK execution and all pre-`take_damage` modifiers |
| `scenes/battle/Unit.gd` | `take_damage()`, block absorption, defensive_stance, HP reduction; enemy `attack()` |
| `scripts/autoload/PlayerData.gd` | `global_card_damage_bonus` |
| `scripts/autoload/ArtifactManager.gd` | `get_card_damage_bonus()`, artifact-related damage logic |
| `scripts/CardUI.gd` | Calls `get_display_description()` for card text |

---

## 8. Potential Inconsistencies

1. **DEAL_DAMAGE_FROM_BLOCK** – No damage bonuses; card damage bonuses do not affect it.
2. **Vulnerable** – Status exists but is not used in damage calculation.
3. **Burning** – Does not use `PlayerData.poison_damage_bonus`.
4. **Holy Vengeance `damage_per_block`** – Conditional path uses `bonus_value`; possible double-count of +1 when `condition_met` is true (default for `damage_per_block`).
5. **Display vs actual** – Player sees base + flat bonuses; actual damage can differ due to target type (Holy effectiveness), critical hit, block, defensive_stance, and consecrated_weapon.
