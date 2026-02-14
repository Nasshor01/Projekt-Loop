# Paladin – výpis skillů a propojení (strom dovedností)

Zdroj: `SkillTreeGenerator.gd` → `generate_paladin_tree()` + `setup_connections_paladin_tiered()`.

**Pravidlo stromu:** Každý uzel kromě starteru musí mít alespoň jeden **rodič** (někdo na něj vede). Žádný uzel nesmí být slepý (bez příchozí hrany). Jedna čára = jedno propojení A → B.

---

## 1. Přehled uzlů (co teď máme)

### Tier 0 – Starter
| id | Název (CZ) | Vede do (napojeno na) | Přichází z |
|----|------------|------------------------|------------|
| `paladin_start` | Svatý Závazek | blessed_gold, divine_insight, sacred_step | — (start) |

### Tier 1 – Utility
| id | Název (CZ) | Vede do (napojeno na) | Přichází z |
|----|------------|------------------------|------------|
| `blessed_gold` | Požehnané zlato | paladin_hp_1, paladin_block_1 | paladin_start |
| `divine_insight` | Božský vhled | iron_skin, defensive_stance, holy_light_heal | paladin_start |
| `sacred_step` | Svatý krok | fortress, iron_will | paladin_start |

### Tier 2 – Defense
| id | Název (CZ) | Vede do (napojeno na) | Přichází z |
|----|------------|------------------------|------------|
| `paladin_hp_1` | Vitalita | holy_strike, righteous_fury | blessed_gold |
| `paladin_block_1` | Výcvik se štítem | holy_strike, consecrated_blade | blessed_gold |
| `iron_skin` | Železná kůže | righteous_fury, consecrated_blade | divine_insight |
| `defensive_stance` | Obranný postoj | consecrated_blade, aura_synergy | divine_insight |
| `holy_light_heal` | Světlo uzdravení | holy_strike, aura_synergy | divine_insight |
| `fortress` | Pevnost (Notable) | consecrated_blade, aura_synergy, righteous_fury | sacred_step |
| `iron_will` | Železná vůle | holy_strike, aura_synergy | sacred_step |

### Tier 3 – Synergy
| id | Název (CZ) | Vede do (napojeno na) | Přichází z |
|----|------------|------------------------|------------|
| `holy_strike` | Svatý úder | divine_protection, sacred_thorns | paladin_hp_1, paladin_block_1, holy_light_heal, iron_will |
| `righteous_fury` | Spravedlivá zuřivost | sacred_thorns, immovable_fortress | paladin_hp_1, iron_skin, fortress |
| `consecrated_blade` | Požehnaná čepel | immovable_fortress, sacred_thorns | paladin_block_1, iron_skin, defensive_stance, fortress |
| `aura_synergy` | Synergie aur | divine_protection, immovable_fortress | defensive_stance, holy_light_heal, fortress, iron_will |

### Tier 4 – Keystones
| id | Název (CZ) | Vede do (napojeno na) | Přichází z |
|----|------------|------------------------|------------|
| `divine_protection` | Božská ochrana | avatar_of_light | holy_strike, aura_synergy |
| `sacred_thorns` | Svaté trny | avatar_of_light | holy_strike, righteous_fury, consecrated_blade |
| `immovable_fortress` | Nepohnutelná pevnost | avatar_of_light | righteous_fury, consecrated_blade, aura_synergy |
| `avatar_of_light` | Avatár světla | — (konec cesty) | divine_protection, sacred_thorns, immovable_fortress |

---

## 2. Audit: efekt → hodnota → kde se aplikuje (logika a odkaz na funkčnost)

| id | Efekt (EffectType) | Hodnota | Kde se aplikuje |
|----|--------------------|--------|------------------|
| paladin_start | ADD_MAX_HP | 5 | PlayerData.apply_passive_skills → max_hp |
| blessed_gold | ADD_STARTING_GOLD | 8 | PlayerData.apply_passive_skills → gold (start run) |
| divine_insight | DRAW_CARD_FIRST_TURN | 1 | PlayerData.first_turn_draw_bonus → BattleScene / líznutí v 1. kole |
| sacred_step | MOVEMENT_BONUS | 1 | PlayerData.movement_bonus → Unit.get_current_movement_range() (hráč) |
| paladin_hp_1 | ADD_MAX_HP | 8 | PlayerData.apply_passive_skills → max_hp |
| paladin_block_1 | ADD_RETAINED_BLOCK | 3 | PlayerData.starting_retained_block → začátek souboje |
| iron_skin | ADD_MAX_HP | 6 | PlayerData.apply_passive_skills → max_hp |
| defensive_stance | ADD_RETAINED_BLOCK | 2 | PlayerData.starting_retained_block |
| holy_light_heal | HEAL_END_OF_TURN | 1 | PlayerData.heal_end_of_turn → BattleScene (konec tahu hráče) |
| fortress | ADD_RETAINED_BLOCK | 8 | PlayerData.starting_retained_block |
| iron_will | ADD_MAX_HP | 10 | PlayerData.apply_passive_skills → max_hp |
| holy_strike | ADD_MAX_ENERGY | 1 | PlayerData.apply_passive_skills → max_energy |
| righteous_fury | **ADD_HOLY_DAMAGE** | **3** | PlayerData.holy_damage_bonus → DamageCalculator.get_final_damage (pouze když damage_type == HOLY) |
| consecrated_blade | ENERGY_ON_KILL | 1 | PlayerData.energy_on_kill → BattleScene (po zabití nepřítele) |
| aura_synergy | AURA_ENHANCEMENT | 25 | PlayerData.aura_enhancement → síla aur (např. Aura of Devotion) |
| divine_protection | ADD_RETAINED_BLOCK | 12 | PlayerData.starting_retained_block |
| sacred_thorns | THORNS_DAMAGE | 2 | PlayerData.thorns_damage → BattleScene (když nepřítel zasáhne hráče) |
| immovable_fortress | ADD_MAX_HP + ADD_RETAINED_BLOCK | 15 + 5 | max_hp a starting_retained_block |
| avatar_of_light | AVATAR_STARTING_BLOCK | 2 | PlayerData.avatar_starting_block_multiplier → apply_avatar_starting_block (blok = 2× max_hp) |

**Poznámka:** V aktuálním generátoru **žádný uzel nepoužívá ADD_CARD_DAMAGE**. Righteous Fury je **ADD_HOLY_DAMAGE, 3** (bonus jen k Svatému poškození).  
**Důležité:** V `PassiveEffectData.gd` je **ADD_HOLY_DAMAGE záměrně na konci enumu** – přidání nového efektu doprostřed by posunulo čísla a uložené .tres by zobrazovaly špatné texty (blok jako „holy dmg“, aura jako „heal“, atd.). Nové typy efektů přidávej vždy na konec enumu.

---

## 3. Seznam všech ID (pro kopírování)

```
paladin_start
blessed_gold
divine_insight
sacred_step
paladin_hp_1
paladin_block_1
iron_skin
defensive_stance
holy_light_heal
fortress
iron_will
holy_strike
righteous_fury
consecrated_blade
aura_synergy
divine_protection
sacred_thorns
immovable_fortress
avatar_of_light
```

**Celkem: 20 uzlů.** Všechny mají alespoň jednu příchozí hranu (kromě `paladin_start`). Žádný uzel v tomto výpisu není slepý.

---

## 4. Jak chceš propojení – vyplň (co má být na co napojené)

Strom má být **jasná hierarchie**: Starter → Tier 1 → Tier 2 → Tier 3 → Tier 4. Pro každý uzel napiš **pouze ty uzly, na které z něj má vést čára** („vede do“).

Formát: pro každý uzel jeden řádek  
`id_uzlu` → `id1`, `id2`, …

**Příklad (zjednodušený strom):**
```
paladin_start → blessed_gold, divine_insight, sacred_step
blessed_gold → paladin_hp_1, paladin_block_1
divine_insight → defensive_stance, holy_light_heal
sacred_step → iron_will, fortress
...
avatar_of_light → (nic, finální uzel)
```

Až mi napíšeš přesně, co má být na co napojené (nebo doplníš tuto sekci), upravím `setup_connections_paladin_tiered()` v `SkillTreeGenerator.gd` tak, aby to odpovídalo tvému stromu a žádný uzel nebyl slepý.

---

## 5. Poznámka k „slepým“ uzlům na obrázku

Na scéně můžeš vidět jiné názvy (např. holy_wrath, smite, sacred_healing) – to bývá, když scéna nebo třída Paladin používá **jiný zdroj stromu** než generátor (např. starý soubor `paladin_tree2.tres`). Ten má úplně jinou sadu uzlů (righteous_anger, swift_justice, aura_mastery, …).

**Doporučení:** Mít jeden zdroj pravdy. Buď:
- **A)** Používat strom z generátoru: v editoru v Builderu nastav **Fallback Tree** na nic (nebo na resource vygenerovaný z generátoru), zaškrtni **Build tree now** – scéna se naplní těmito 20 uzly a jejich propojením.  
- **B)** Nebo chceš strom z `paladin_tree2.tres`: pak potřebujeme výpis uzlů z toho .tres a propojení upravit tam / sjednotit s generátorem.

Když mi napíšeš, který zdroj chceš (generátor vs. paladin_tree2) a jak má který uzel být napojený, doladíme to na čistý strom bez slepých uzlů.

---

## 6. Jak opravit nesoulad čar (čáry neodpovídají tabulce)

**Příčina:** Scéna nebo Paladin používá starý uložený Resource (`.tres`) s jinými propojeními než má aktuální kód v `setup_connections_paladin_tiered()`.

**Krok za krokem:**

1. **Smazání starého Resourcu (volitelné):**  
   V souborovém systému Godotu můžeš smazat `paladin_tree2.tres` nebo jiný starý strom, který už nechceš používat. (Pozor: `Paladin.tres` na něj odkazuje – viz krok 4.)

2. **Editor – vynucení generování z kódu:**  
   - Otevři scénu s pasivním stromem (např. `passive_skill_tree_manual.tscn`).  
   - U uzlu **SkillTreeBuilder** nech v Inspektoru pole **Fallback Tree** prázdné (`[empty]`).  
   - Zaškrtni **Build tree now**. Builder zavolá `SkillTreeGenerator.generate_paladin_tree()` s aktuálními propojeními.

3. **Ruční kontrola ID:**  
   U uzlů bez čar zkontroluj v Inspektoru **Skill ID** – musí být přesně podle tabulky (např. `iron_will`, malými písmeny, bez mezer).

4. **Běh hry:**  
   - Buď v `Paladin.tres` odkaz **passive_skill_tree** nastav na nový strom uložený z Builderu (**Save tree now** → pak v Paladin přiřaď ten soubor),  
   - nebo v `Paladin.tres` pole **passive_skill_tree** vyprázdni – hra pak pro Paladina použije strom z generátoru (fallback v kódu).

**Po správném resetu musí platit:**
- Z `paladin_start` vedou **přesně 3 čáry** do: `blessed_gold`, `divine_insight`, `sacred_step`.
- Do `avatar_of_light` vedou čáry ze **všech tří Keystonů**: `divine_protection`, `sacred_thorns`, `immovable_fortress`.
