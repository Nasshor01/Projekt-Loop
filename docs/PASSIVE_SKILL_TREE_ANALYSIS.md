# Analýza pasivního stromu dovedností

## Přehled

Pasivní strom je definován v `data/skills/` (PassiveEffectData, PassiveSkillNode, SkillTreeGenerator) a aplikuje se v `PlayerData.apply_passive_skills()`. Aktuálně existuje **Paladin** strom s třemi větvemi (Defense, Offense, Utility) a společným finálním uzlem.

---

## 1. Všechny možné typy upgradů (EffectType)

Tyto typy efektů může strom teoreticky používat. V závorce je stav v kódu (implementováno / jen log / legacy).

### Základní staty
| Efekt | Popis | Použití ve stromu |
|-------|--------|--------------------|
| **ADD_MAX_HP** | +X maximálního zdraví | ✅ Paladin (starter, vitalita, iron_skin, iron_will, unbreakable, immovable_fortress) |
| **ADD_STARTING_GOLD** | +X zlata na začátku souboje | ✅ Paladin (blessed_gold, sacred_wisdom, golden_touch, divine_prosperity, blessed_recovery, divine_wealth) |
| **ADD_MAX_ENERGY** | +X maximální energie | ✅ Paladin (swift_justice, battle_fervor, holy_strike, consecrated_blade, divine_retribution, holy_avenger) |
| **GRANT_REVIVE** | Možnost oživení | ❌ Ve stromu ne |
| **ADD_CARD_DAMAGE** | +X poškození všech karet | ✅ Paladin (righteous_anger, holy_power, divine_wrath, smiting_power, wrathful_strike, righteous_fury, divine_retribution, holy_avenger) |
| **ADD_RETAINED_BLOCK** | +X startovního bloku na začátek souboje | ✅ Paladin (shield_training, defensive_stance, fortress, shield_mastery, guardian_spirit, divine_protection, sacred_thorns, immovable_fortress) |

### Paladin / obranné
| Efekt | Popis | Použití ve stromu |
|-------|--------|--------------------|
| **CRITICAL_CHANCE_BONUS** | +X% šance na kritický zásah | ❌ |
| **HEAL_END_OF_TURN** | Vyléčení o X HP na konci tahu | ❌ |
| **AURA_ENHANCEMENT** | +X% síla aur | ✅ Paladin – Mistrovství aur (50%) |
| **AVATAR_STARTING_BLOCK** | Na začátku souboje blok = X× max HP | ✅ Paladin – Avatár světla (2×) |
| **THORNS_DAMAGE** | X poškození útočníkovi při zásahu | ✅ sacred_thorns (2) – v kódu jen ADD_RETAINED_BLOCK, THORNS je v popisu; v PlayerData se THORNS_DAMAGE aplikuje |
| **DOUBLE_HEALING** | +X% síla léčení | ❌ |
| **ENERGY_ON_KILL** | +X energie za zabití | ❌ |
| **BLOCK_ON_CARD_PLAY** | +X bloku za každou zahrátou kartu | ❌ |

### Card Management
| Efekt | Popis | Použití ve stromu |
|-------|--------|--------------------|
| **CARD_UNLOCK** | Odemknutí karty (string_value = card_id) | ❌ |
| **DRAW_CARD_FIRST_TURN** | +X karty v prvním kole | ✅ Paladin (divine_insight, divine_favor, blessed_hand, divine_wealth) |
| **CONDITIONAL_DRAW** | Líznutí za podmínky (string_value = condition) | ❌ |
| **HAND_SIZE_BONUS** | +X k velikosti ruky | ❌ |

### Resource Management
| Efekt | Popis | Použití ve stromu |
|-------|--------|--------------------|
| **STARTING_RESOURCE** | Začátek s resource (combo/essence/potions) | ❌ |
| **STARTING_TRAP** | Začátek s X pastmi | ❌ |
| **STARTING_POTIONS** | Začátek s X lektvary | ❌ |

### Combat
| Efekt | Popis | Použití ve stromu |
|-------|--------|--------------------|
| **TARGET_BONUS_DAMAGE** | +X% poškození proti označenému cíli | ❌ |
| **CARD_COST_REDUCTION_TARGET** | Karty proti cíli −X energie | ❌ |
| **FIRST_ATTACK_FREE** | Prvních X útoků zdarma | ❌ |
| **SPELL_BLOCK** | +X bloku za sešlání kouzla | ❌ |

### Pasivní vylepšení (enhancements)
| Efekt | Popis | Použití ve stromu |
|-------|--------|--------------------|
| **PASSIVE_ENHANCEMENT** | +X k pasivní schopnosti (string_value = passive_id) | ❌ |
| **PASSIVE_RESONANCE_BONUS** | +X% k pasivní rezonanci | ❌ |
| **PASSIVE_USE_COUNT** | +X použití pasivní schopnosti za kolo | ❌ |
| **PASSIVE_TRIGGER_THRESHOLD** | Změna prahu aktivace pasivní (string_value = passive_id, value = %) | ❌ |

### Postura (Fighter)
| Efekt | Popis | Použití ve stromu |
|-------|--------|--------------------|
| **POSTURE_BONUS** | +X% v daném postoji | ❌ |
| **POSTURE_COST_REDUCTION** | −X cena přepnutí postoje | ❌ |

### DoT / Summoning / Lifesteal / Support / Elemental
| Efekt | Popis | Použití ve stromu |
|-------|--------|--------------------|
| **POISON_DAMAGE_BONUS** | +X poškození jedy | ❌ |
| **SUMMON_HEALTH_BONUS** | +X HP vyvolaným jednotkám | ❌ |
| **ENEMY_TO_CARD_CONVERSION** | X% zabitých nepřátel → karty | ❌ |
| **LIFESTEAL_PERCENTAGE** | X% lifesteal | ❌ |
| **OVERHEAL_TO_TEMP_HP** | X% přebytečné léčení → dočasné HP | ❌ |
| **ALLIED_DAMAGE_LIFESTEAL** | X% lifesteal z poškození spojenců | ❌ |
| **CONDITIONAL_BLOCK** | Blok za podmínky | ❌ |
| **STARTING_TEMP_HP** | Začátek s X dočasným HP | ❌ |
| **ALLIED_DEFENSE_BONUS** | +X% obrana spojenců | ❌ |
| **FORCE_ENEMY_MOVEMENT** | X× donutit nepřítele k pohybu | ❌ |
| **FIRST_SPELL_ELEMENT_FREE** | První kouzlo každého živlu zdarma | ❌ |

### Legacy (v kódu zatím jen log / neimplementováno)
| Efekt | Popis | Stav v PlayerData |
|-------|--------|--------------------|
| **MOVEMENT_BONUS** | +X pohyb | ⚠️ Jen log „ještě není implementován“ |
| **CARD_COST_REDUCTION** | Všechny karty −X energie | ⚠️ Jen log |
| **DRAW_EXTRA_CARDS** | +X karty navíc | ⚠️ Jen log |
| **STATUS_IMMUNITY** | Imunita na statusy | ⚠️ Jen log |
| **AREA_DAMAGE_BONUS** | +X% AoE poškození | ⚠️ Jen log |

---

## 2. Paladin strom – uzly po větvích

### Tier 0 – Starter
| ID | Název | Efekt(y) |
|----|--------|----------|
| paladin_start | Svatý Závazek | +5 max HP |

### Větev Defense (obrana)
**Tier 1:** Výcvik se štítem (+3 blok), Vitalita (+8 HP), Železná kůže (+6 HP), Obranný postoj (+2 blok)  
**Tier 2:** Pevnost (+8 blok, NOTABLE), Železná vůle (+10 HP), Nezlomný (+12 HP), Mistrovství se štítem (+5 blok), Ochranný duch (+4 blok)  
**Tier 3 (KEYSTONE):** Božská ochrana (+15 blok), Svaté trny (+10 blok + 2 thorns), Nepohnutelná pevnost (+20 HP, +5 blok)

### Větev Offense (útok)
**Tier 1:** Spravedlivý hněv (+1 dmg), Rychlá spravedlnost (+1 energie), Svatá síla (+1 dmg), Bojové nadšení (+1 energie)  
**Tier 2:** Božský hněv (+2 dmg, NOTABLE), Svatý úder (+2 energie), Síla trestu (+2 dmg), Požehnaná čepel (+1 energie), Hněvivý úder (+1 dmg)  
**Tier 3 (KEYSTONE):** Spravedlivá zuřivost (+3 dmg), Božská odplata (+4 dmg, +1 energie), Svatý mstitel (+3 dmg, +2 energie)

### Větev Utility (zlato / karty)
**Tier 1:** Požehnané zlato (+10 zlata), Božský vhled (+1 karta 1. kolo), Svatá moudrost (+5 zlata)  
**Tier 2:** Božská přízeň (+1 karta 1. kolo, NOTABLE), Zlatý dotek (+15 zlata), Požehnaná ruka (+1 karta 1. kolo), Božský blahobyt (+12 zlata)  
**Tier 3 (KEYSTONE):** Požehnané uzdravení (+20 zlata), Božské bohatství (+25 zlata, +1 karta 1. kolo)

### Main (společný konec)
**Tier 4 (MASTERY):** Mistrovství aur – aury +50%  
**Tier 5 (KEYSTONE):** Avatár světla – na začátku souboje blok = 2× max HP (podmínka: všechny ostatní uzly odemčeny)

---

## 3. Typy uzlů (NodeType)

- **STARTER** – startovní uzel (1×)
- **BASIC** – běžný uzel (malý)
- **NOTABLE** – významný (větší) – např. Pevnost, Božský hněv, Božská přízeň
- **KEYSTONE** – klíčový (Tier 3 + Avatar)
- **MASTERY** – Mistrovství aur (Tier 4)

---

## 4. Shrnutí – co je v Paladin stromu reálně použito

**Efekty skutečně v stromu:**  
ADD_MAX_HP, ADD_STARTING_GOLD, ADD_MAX_ENERGY, ADD_CARD_DAMAGE, ADD_RETAINED_BLOCK, DRAW_CARD_FIRST_TURN, AURA_ENHANCEMENT, AVATAR_STARTING_BLOCK.  
(U Svatých trnů je v generátoru jen ADD_RETAINED_BLOCK; THORNS_DAMAGE by musel být přidán druhým efektem, pokud má platit i „2 poškození útočníkovi“.)

**Efekty připravené v kódu, ale v tomto stromu nevyužité:**  
GRANT_REVIVE, CRITICAL_CHANCE_BONUS, HEAL_END_OF_TURN, THORNS_DAMAGE, DOUBLE_HEALING, ENERGY_ON_KILL, BLOCK_ON_CARD_PLAY, CARD_UNLOCK, CONDITIONAL_DRAW, HAND_SIZE_BONUS, STARTING_RESOURCE/TRAP/POTIONS, TARGET_BONUS_DAMAGE, CARD_COST_REDUCTION_TARGET, FIRST_ATTACK_FREE, SPELL_BLOCK, všechny PASSIVE_* enhancementy, POSTURE_*, POISON_DAMAGE_BONUS, SUMMON_*, ENEMY_TO_CARD_CONVERSION, LIFESTEAL/OVERHEAL/ALLIED_*, CONDITIONAL_BLOCK, STARTING_TEMP_HP, ALLIED_DEFENSE_BONUS, FORCE_ENEMY_MOVEMENT, FIRST_SPELL_ELEMENT_FREE.

**Legacy (zatím jen log):** MOVEMENT_BONUS, CARD_COST_REDUCTION, DRAW_EXTRA_CARDS, STATUS_IMMUNITY, AREA_DAMAGE_BONUS.

Soubor s výčtem efektů a formátováním popisů: `data/skills/PassiveEffectData.gd`. Generování Paladin stromu: `data/skills/SkillTreeGenerator.gd` (funkce `generate_paladin_tree()`).
