# Card Audit — Projekt Loop

**Source:** All `.tres` files in `res://data/cards/` (including subfolders). Pool resources (`shop_card_pool.tres`, `reward_card_pool.tres`) excluded.

**Generated for dev notes.** Use localized names where available (English from `translations.csv`).

---

## Full card table

| Card Name | Cost | Rarity | Base Effects | Damage Type | Range & Target | Has Condition? | Upgraded Version? |
|-----------|------|--------|---------------|--------------|----------------|----------------|-------------------|
| Adrenaline | 0 | UNCOMMON | GAIN_ENERGY: 1; DRAW_CARDS: 1 | — | NONE · Self | No | Yes |
| Adrenaline+ | 1 | UNCOMMON | GAIN_ENERGY: 2; DRAW_CARDS: 2 | — | NONE | No | No |
| Defend | 1 | BASIC | GAIN_BLOCK: 5 | — | MELEE (1) · Self | No | Yes |
| Defend+ | 0 | BASIC | GAIN_BLOCK: 6 | — | MELEE | No | No |
| Fortify | 2 | UNCOMMON | GAIN_BLOCK: 12 | — | SELF · Self | No | Yes |
| Fortify+ | 4 | UNCOMMON | GAIN_BLOCK: 34 | — | SELF | No | No |
| Heavy Strike | 2 | UNCOMMON | DEAL_DAMAGE: 10 (Normal) | Normal | MELEE (1) · Melee/Single | No | Yes |
| Heavy Strike+ | 1 | UNCOMMON | DEAL_DAMAGE: 15 (Normal) | Normal | MELEE · Melee/Single | No | No |
| Nimble Move | 0 | COMMON | GAIN_EXTRA_MOVE + DRAW | — | MELEE | No | Yes |
| Nimble Move+ | 1 | COMMON | GAIN_EXTRA_MOVE + DRAW | — | MELEE | No | No |
| Quick Step | 1 | UNCOMMON | MODIFY_INITIATIVE: 5 | — | SELF | No | No |
| Quick Strike | 1 | BASIC | DEAL_DAMAGE: 4 (Normal) | Normal | MELEE (1) · Melee/Single | No | Yes |
| Quick Strike+ | 1 | COMMON | DEAL_DAMAGE: 7 (Normal) | Normal | MELEE · Melee/Single | No | No |
| Regroup | 0 | COMMON | DRAW_CARDS: 1 | — | NONE | No | Yes |
| Regroup+ | 0 | COMMON | DRAW_CARDS: 3 | — | NONE | No | No |
| Aura of Devotion | 1 | UNCOMMON | APPLY_STATUS: aura_devotion (2 block/turn) | — | MELEE | No | Yes |
| Aura of Devotion+ | 2 | UNCOMMON | APPLY_STATUS: aura_devotion_plus (4 block/turn) | — | MELEE | No | No |
| Consecration | 2 | COMMON | DEAL_DAMAGE: 3 (Holy) | Holy | GRID_AOE · All Enemies | No | Yes |
| Consecration+ | 2 | COMMON | DEAL_DAMAGE: 6 (Holy) | Holy | GRID_AOE · All Enemies | No | No |
| Consecrated Barrier | 1 | UNCOMMON | GAIN_BLOCK: 6 | — | SELF · Self | Yes (took_damage_last_turn; bonus 4) | No |
| Consecrated Weapon | 2 | UNCOMMON | DEAL_DAMAGE: 9 (Holy); APPLY_STATUS: consecrated_weapon (5) | Holy | MELEE (1) · Melee/Single | No | No |
| Defensive Stance | 1 | COMMON | GAIN_BLOCK: 4; APPLY_STATUS: defensive_stance | — | SELF · Self | No | No |
| Divine Grace | 3 | EPIC | HEAL_TO_FULL; EXHAUST | — | SELF | No | No |
| Divine Judgment | 3 | EPIC | DEAL_DAMAGE: 25 (Holy); EXHAUST | Holy | FULL_BOARD · All Enemies | No | No |
| Divine Justice | 3 | EPIC | DEAL_DAMAGE: 20 (Holy) | Holy | MELEE (1) · Melee/Single | Yes (target_health_above_percent 50; bonus 15) | No |
| Divine Protection | 3 | EPIC | GAIN_BLOCK: 15; HEAL: 10; DEAL_DAMAGE: 12 (Holy) | Holy | FULL_BOARD · All Enemies | No | No |
| Divine Wrath | 3 | RARE | DEAL_DAMAGE: 10 (Holy) | Holy | FULL_BOARD · All Enemies | No | Yes |
| Divine Wrath+ | 4 | RARE | DEAL_DAMAGE: 20 (Holy) | Holy | FULL_BOARD · All Enemies | No | No |
| Excommunication | 2 | UNCOMMON | DEAL_DAMAGE: 10 (Holy); APPLY_STATUS: vulnerable (2) | Holy | MELEE (1) · Melee/Single | No | No |
| Fortification | 2 | RARE | GAIN_BLOCK: 15 (retain) | — | SELF · Self | No | No |
| God's Lightning | 2 | RARE | DEAL_DAMAGE: 18 (Holy); MODIFY_INITIATIVE / gain 2 energy on kill | Holy | MELEE (1) · Melee/Single | No | No |
| God's Wrath | 2 | RARE | DEAL_DAMAGE: 15 (Holy) | Holy | MELEE (1) · Melee/Single | Yes (target_has_debuff; bonus 10) | No |
| Healing Aura | 2 | UNCOMMON | HEAL: 10; HEAL: 5 (all allies) | — | SELF · Self / All Allies | No | No |
| Healing Light | 1 | COMMON | HEAL: 8 | — | SELF · Self | No | No |
| Holy Armor | 1 | UNCOMMON | GAIN_BLOCK: 8 | — | SELF · Self | Yes (block_above 20; bonus 3) | No |
| Holy Blessing | 2 | UNCOMMON | HEAL: 12; GAIN_BLOCK: 3 | — | SELF · Self | No | No |
| Holy Defense | 2 | RARE | GAIN_BLOCK: 10; DEAL_DAMAGE: 10 (Holy) | Holy | MELEE (1) · Melee/Single | No | No |
| Holy Knight | 2 | RARE | GAIN_BLOCK: 6; DEAL_DAMAGE: 8 (Holy); HEAL: 4 | Holy | MELEE (1) · Melee/Single | No | No |
| Holy Shield | 2 | RARE | GAIN_BLOCK: 12 | — | SELF · Self | Yes (health_below_percent 50; bonus 8) | No |
| Holy Strike | 1 | COMMON | DEAL_DAMAGE: 8 (Holy) | Holy | MELEE (1) · Melee/Single | No | No |
| Holy Vengeance | 1 | COMMON | DEAL_DAMAGE: 6 (Holy) | Holy | MELEE (1) · Melee/Single | Yes (damage_per_block; bonus 1) | No |
| Holy Wave | 2 | UNCOMMON | DEAL_DAMAGE: 4 (Holy) | Holy | GRID_AOE (5) · Row | No | Yes |
| Holy Wave+ | 2 | UNCOMMON | DEAL_DAMAGE: 8 (Holy) | Holy | GRID_AOE · Row | No | No |
| Holy Wrath | 2 | RARE | DEAL_DAMAGE: 12 (Holy) | Holy | MELEE (1) · Melee/Single | Yes (block_above 15; bonus 8) | No |
| Impregnable Shield | 2 | EPIC | GAIN_BLOCK: 10; APPLY_STATUS: remove_all_debuffs | — | SELF · Self | No | No |
| Lay on Hands | 3 | RARE | HEAL_TO_FULL; EXHAUST | — | MELEE | No | Yes |
| Lay on Hands+ | 5 | RARE | HEAL_TO_FULL | — | MELEE | No | No |
| Lesser Heal | 1 | COMMON | HEAL: 4 | — | MELEE | No | Yes |
| Lesser Heal+ | 0 | COMMON | HEAL: 6 | — | MELEE | No | No |
| Light Pillar | 2 | UNCOMMON | DEAL_DAMAGE: 6 (Holy) | Holy | GRID_AOE (5) · Column | No | Yes |
| Light Pillar+ | 2 | UNCOMMON | DEAL_DAMAGE: 9 (Holy) | Holy | GRID_AOE · Column | No | No |
| Massive Healing | 2 | RARE | HEAL: 20 | — | SELF · Self | Yes (health_below_percent 30; bonus 30) | No |
| Pious Defense | 1 | COMMON | GAIN_BLOCK: 7 | — | SELF · Self | No | Yes |
| Pious Defense+ | 1 | COMMON | GAIN_BLOCK: 10 | — | SELF | No | No |
| Protective Aura | 1 | COMMON | GAIN_BLOCK: 5; GAIN_BLOCK: 2 (all allies) | — | SELF · Self / All Allies | No | No |
| Protective Hand | 2 | UNCOMMON | GAIN_BLOCK: 8; HEAL: 5 | — | SELF (1) · Self | No | No |
| Purging Burst | 1 | RARE | DEAL_DAMAGE: 3 (Holy) | Holy | GRID_AOE (5) · Grid 2x2 | No | Yes |
| Purging Burst+ | 1 | RARE | DEAL_DAMAGE: 6 (Holy) | Holy | GRID_AOE · Grid 4x4 | No | No |
| Purification | 1 | UNCOMMON | APPLY_STATUS: remove_all_debuffs; GAIN_BLOCK: 5 | — | SELF · Self | No | No |
| Regeneration | 1 | COMMON | APPLY_STATUS: regeneration (3) | — | SELF · Self | No | No |
| Sacred Healing | 2 | RARE | HEAL: 15; APPLY_STATUS: remove_all_debuffs | — | SELF · Self | No | No |
| Shield Bash | 2 | UNCOMMON | DEAL_DAMAGE_FROM_BLOCK | — | MELEE | No | Yes |
| Shield Bash+ | 2 | UNCOMMON | DEAL_DOUBLE_DAMAGE_FROM_BLOCK | — | MELEE | No | No |
| Shield Strike | 1 | COMMON | GAIN_BLOCK: 5; DEAL_DAMAGE: 6 (Normal) | Normal | MELEE (1) · Melee/Single | No | No |
| Smite | 1 | COMMON | DEAL_DAMAGE: 6 (Holy) | Holy | MELEE (1) · Melee/Single | No | Yes |
| Smite+ | 2 | COMMON | DEAL_DAMAGE: 12 (Holy) | Holy | MELEE · Melee/Single | No | No |
| Unbreakable Faith | 3 | EPIC | GAIN_BLOCK: max_hp; EXHAUST | — | SELF · Self | No | No |
| Curse | 1 | BASIC | (no effects) | — | NONE | No | No |
| Curse: Pain | 99 | BASIC | (unplayable) | — | NONE | No | No |
| Curse: Weakness | 0 | BASIC | EXHAUST (on draw: lose 1 energy) | — | NONE | No | No |

---

## Top 5 most powerful cards (Damage-to-Cost + AOE potential)

Ranking favors **AOE** (all enemies / line / area) and **high damage per energy**. Conditional damage is treated as base for comparison.

| Rank | Card | Cost | Base damage | Dmg/Cost | AOE | Why |
|------|------|------|-------------|----------|-----|-----|
| 1 | **Divine Judgment** | 3 | 25 holy | 8.3 | Yes (all enemies) | Highest single-card AOE damage; Exhaust is a fair trade. |
| 2 | **Divine Wrath+** | 4 | 20 holy | 5.0 | Yes (all enemies) | Strong full-board clear; no Exhaust. |
| 3 | **Divine Protection** | 3 | 12 holy | 4.0 | Yes (all enemies) | AOE damage plus 15 block and 10 heal — best value package. |
| 4 | **Divine Wrath** | 3 | 10 holy | 3.3 | Yes (all enemies) | Same AOE as above, lower damage; has upgraded version. |
| 5 | **Consecration+** | 2 | 6 holy | 3.0 | Yes (all enemies) | Cheapest AOE holy damage; excellent for clearing adds. |

**Honorable mentions (single-target / conditional):**

- **God's Lightning** — 18 holy for 2 cost (9.0 ratio), plus 2 energy on kill; no AOE.
- **Heavy Strike+** — 15 normal for 1 cost (15.0 ratio); single target, no AOE.
- **Holy Vengeance** — 6 + 1 per block (Holy); can scale very high with block; single target.

---

## Legend

- **Rarity:** BASIC, COMMON, UNCOMMON, RARE, EPIC, LEGENDARY  
- **Damage types:** Normal, Holy, Fire, Ice, Lightning, Poison, Arcane  
- **Range:** NONE, SELF, MELEE, RANGED_FIXED, RANGED_LINE, GRID_AOE, FULL_BOARD  
- **Effect types:** DEAL_DAMAGE, GAIN_BLOCK, HEAL_UNIT, HEAL_TO_FULL, APPLY_STATUS, EXHAUST, DRAW_CARDS, GAIN_ENERGY, etc.  
- **Has Condition:** Yes = at least one effect with `has_condition` (e.g. target_health_above_percent, block_above, damage_per_block).  
- **Upgraded Version?:** Yes = card has `upgraded_version` reference to another `.tres`.
