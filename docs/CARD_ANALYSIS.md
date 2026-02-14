# Komplexní analýza karet – popis vs. .tres vs. zobrazení

Tento dokument mapuje **všechny karty**, jejich **description** z překladů, **data z .tres** (efekty, damage_type, area, podmínky) a **rozpor mezi popisem a vizuálem/mechanikou**. Žádný kód ani data v projektu zatím nebyly měněny – jde o analýzu pro plán úprav.

---

## 1. Jak to funguje v kódu

### 1.1 Enums (CardEffectData.gd)

**EffectType:**  
`0` DEAL_DAMAGE, `1` DEAL_DAMAGE_FROM_BLOCK, `2` GAIN_BLOCK, `3` DRAW_CARDS, `4` GAIN_ENERGY, `5` APPLY_STATUS, `6` SUMMON_UNIT, `7` HEAL_UNIT, `8` HEAL_TO_FULL, `9` EXHAUST, `10` GAIN_EXTRA_MOVE, `11` DEAL_DOUBLE_DAMAGE_FROM_BLOCK, `12` MODIFY_INITIATIVE_NEXT_ROUND

**TargetType:**  
`0` SELF_UNIT, `1` SELECTED_ENEMY_UNIT, `2` SELECTED_ALLY_UNIT, `3` ALL_ENEMY_UNITS, `4` ALL_ALLY_UNITS, `5` EMPTY_GRID_CELL, `6` ANY_GRID_CELL

**AreaOfEffectType:**  
`0` SINGLE_TARGET, `1` ROW, `2` COLUMN, `3` SQUARE_X_BY_Y, `4` ALL_ON_GRID

**DamageType:**  
`0` NORMAL, `1` HOLY, `2` FIRE, `3` ICE, `4` LIGHTNING, `5` POISON, `6` ARCANE

### 1.2 Zobrazení poškození na kartě (CardData.gd + DamageCalculator.gd)

- **Normální dmg (NORMAL):** Na kartě se zobrazuje `DamageCalculator.get_display_damage(effect.value)` = base + `PlayerData.global_card_damage_bonus` + bonus z artefaktů. Tj. s pasivem +3 dmg uvidíš např. 6 u karty s value 3.
- **Holy dmg (HOLY):** V kódu je záměrně **pouze** `effect.value` (bez bonusu). Komentář: „HOLY: show base value only (effect.value), so display matches .tres; +5/+3 vs Undead/Demon/Spirit in tooltip“.  
  → S pasivem +3 dmg tedy na kartě pořád 3 (ne 6). Bonus se aplikuje až při výpočtu finálního dmg v boji.
- Prefix **„To all:“** se přidá **jen** když `area_of_effect_type == ALL_ON_GRID` (4). **Žádná karta v .tres nemá area_of_effect_type = 4** – všechny „all enemies“ karty mají `area_of_effect_type = 3` (SQUARE) s 1x1 nebo jinak. Proto se „To all:“ na kartách u těchto karet **nikdy neobjeví**.

### 1.3 Jak se v boji berou cíle (BattleScene.gd)

- **target_type == ALL_ENEMY_UNITS (3):** cíle = všichni nepřátelé (`_enemy_units`), bez klikání na mřížku.
- **target_type == ANY_GRID_CELL (6):** cíle = buňky z `get_cells_for_aoe(clicked_cell, area_of_effect_type, aoe_param_x, aoe_param_y)` a na nich nepřátelé.  
  Pro **SQUARE 1x1** tedy hráč klikne na jednu buňku a zásah je **jen ta jedna buňka** (jeden nepřítel). To **není** „to all enemies“.

### 1.4 Ikona „holy“ na kartě

- Ikona holy se zobrazí, když v **.tres** má efekt `damage_type = 1` (HOLY).  
- Text v **translations** (card.xxx.desc) u mnoha karet **neobsahuje** slovo „holy“.  
- Výsledek: hráč vidí holy ikonu, ale v popisu nic o holy – **nesoulad mezi daty a textem**.

---

## 2. Přehled karet podle složek

### 2.1 EVERYONE (neutrální karty)

| card_id | Description (EN) | .tres efekty | damage_type | area | Poznámka |
|--------|------------------|--------------|-------------|------|----------|
| defend | Gain 5 block. | GAIN_BLOCK 5, self | - | - | OK |
| defend_upgraded | (Gain 8 block) | GAIN_BLOCK 8 | - | - | OK |
| heavy_strike | Deal 10 damage. | DEAL_DAMAGE 10, single enemy | NORMAL | single | OK; s +3 dmg zobrazí 13 |
| heavy_strike_upgraded | Deal 15 damage. | DEAL_DAMAGE 15 | NORMAL | single | OK |
| quick_strike | Deal 5 damage. | DEAL_DAMAGE 5 | NORMAL | single | OK |
| quick_strike_upgraded | Deal 8 damage. | DEAL_DAMAGE 8 | NORMAL | single | OK |
| fortify | Gain 6 block. | GAIN_BLOCK 6 | - | - | OK |
| fortify_upgraded | Gain 9 block. | GAIN_BLOCK 9 | - | - | OK |
| nimble_move | Move 1. Draw 1. | (move + DRAW_CARDS 1) | - | - | OK |
| nimble_move_upgraded | Move 2. Draw 1. | (move + DRAW 1) | - | - | OK |
| adrenaline | Gain 2 energy. Draw 2. | GAIN_ENERGY 2, DRAW 2 | - | - | OK |
| adrenaline_upgraded | Gain 2 energy. Draw 3. | GAIN_ENERGY 2, DRAW 3 | - | - | OK |
| regroup | Draw 1 card. | DRAW 1 | - | - | OK |
| regroup_upgraded | Draw 3 cards. | DRAW 3 | - | - | OK |
| quick_step | (move) | (move) | - | - | OK |

U everyone karet není holy; popis a data jsou v souladu.

---

### 2.2 PALADIN – karty s DEAL_DAMAGE (a případně další efekty)

| card_id | Description (EN) | .tres efekty | damage_type | area / target | Problémy |
|--------|------------------|--------------|-------------|---------------|----------|
| **consecration** | **Deal 3 damage to all enemies.** | DEAL_DAMAGE 3, target=**6** (ANY_GRID), area=**3** (SQUARE), **1x1** | **HOLY** | SQUARE 1x1, klik na buňku | 1) Popis říká „to all“, v .tres je ANY_GRID + SQUARE 1x1 → v boji zásah **jen 1 buňka**, ne všichni. 2) Na kartě není „To all:“ (protože není ALL_ON_GRID). 3) Holy ikona je, v popisu „holy“ není. 4) S +3 dmg se na kartě stále zobrazí 3 (holy = base only). |
| consecration_upgraded | Deal 5 damage to all enemies. | DEAL_DAMAGE 5, target=6, area=3, 1x1 | HOLY | stejně | Stejné problémy jako consecration. |
| **divine_wrath** | Deal 3 damage to all enemies. Exhaust. | DEAL_DAMAGE 3 + EXHAUST, target=6, area=3, 1x1 | HOLY | SQUARE 1x1 | Stejné „all“ vs 1 buňka + žádné „To all:“ + holy bez zmínky v textu. |
| divine_wrath_upgraded | Deal 10 damage to all enemies. | DEAL_DAMAGE 10, target=6, area=3, 1x1 | HOLY | SQUARE 1x1 | Stejné. |
| **divine_judgment** | Deal 15 damage to all enemies. Exhaust. | DEAL_DAMAGE 15 + EXHAUST, target=6, area=3, 1x1 | HOLY | SQUARE 1x1 | Stejné „all“ vs 1 buňka + žádné „To all:“. |
| **divine_protection** | Gain 15 block. Heal 10. Deal 7 damage to all enemies. | GAIN_BLOCK 15, HEAL 10, DEAL_DAMAGE 7 (target=6, area=3, 1x1), EXHAUST? | HOLY u dmg | SQUARE 1x1 u dmg | Dmg část: „to all“ vs 1 buňka + žádné „To all:“. |
| smite | Deal 3 damage. | DEAL_DAMAGE 3, single enemy | HOLY | single | Popis neříká „holy“; na kartě je holy ikona. S +3 dmg zobrazí 3 (holy base only). |
| smite_upgraded | Deal 7 damage. | DEAL_DAMAGE 7 | HOLY | single | Stejně. |
| holy_strike | Deal 3 damage. | DEAL_DAMAGE 3 | HOLY | single | Popis jen „Deal 3 damage“ – holy jen v ikoně. |
| holy_defense | Gain 10 block. Deal 5 damage. | GAIN_BLOCK 10, DEAL_DAMAGE 5 | HOLY | single | Popis neuvádí holy. |
| holy_knight | Gain 6 block. Deal 6 damage. Heal 4. | BLOCK 6, DEAL_DAMAGE 6, HEAL 4 | HOLY u dmg | single | Popis neuvádí holy. |
| holy_wrath | Deal 3 damage. If you have >15 block, +3 damage. | DEAL_DAMAGE 3, condition block_above 15, bonus +3 | HOLY | single | Popis neuvádí holy; podmínka v .tres je. |
| holy_vengeance | Deal 1 damage. +1 per block. | DEAL_DAMAGE 1, condition damage_per_block, +1 | HOLY | single | Popis neuvádí holy. |
| gods_lightning | Deal 9 damage. If you kill, +2 energy. | DEAL_DAMAGE 9, MODIFY_INITIATIVE 2 (energy?) | HOLY | single | Popis neuvádí holy. |
| gods_wrath | Deal 10 damage. If enemy has debuff, +10. | DEAL_DAMAGE 10, condition target_has_debuff, +10 | HOLY | single | Popis neuvádí holy. |
| excommunication | Deal 5 damage. Enemy gains Vulnerable 2 turns. | DEAL_DAMAGE 5, APPLY_STATUS vulnerable 2 | HOLY | single | Popis neuvádí holy. |
| divine_justice | Deal 15. If enemy >50% HP, +15. | DEAL_DAMAGE 15, condition target_health_above_percent, +15, + EXHAUST | HOLY | single | Popis neuvádí holy. |
| consecrated_weapon | Deal 4 damage. Next attack +5. | DEAL_DAMAGE 4, APPLY_STATUS consecrated_weapon 5 | HOLY | single | Popis neuvádí holy. |
| shield_strike | Gain 5 block. Deal 6 damage. | GAIN_BLOCK 5, DEAL_DAMAGE 6 | **NORMAL** | single | Jediná paladin „úder“ bez HOLY v datech – záměr? |
| holy_wave | Deal 1 damage to all enemies in a line. | DEAL_DAMAGE 1, target=6, area=**1** (ROW) | HOLY | ROW | Popis „in a line“ odpovídá ROW. Žádné „To all:“ (není ALL_ON_GRID). |
| holy_wave_upgraded | Deal 3 damage to all enemies in a line. | DEAL_DAMAGE 3, ROW | HOLY | ROW | Stejně. |
| light_pillar | Deal 1 damage to all enemies in the column. | DEAL_DAMAGE 1, target=6, area=**2** (COLUMN) | HOLY | COLUMN | Popis „column“ odpovídá. |
| light_pillar_upgraded | Deal 4 damage to all enemies in the column. | DEAL_DAMAGE 4, COLUMN | HOLY | COLUMN | OK. |
| purging_burst | Deal 1 damage to enemies in 2x2 area. | DEAL_DAMAGE 1, target=6, area=3, **2x2** | HOLY | SQUARE 2x2 | Popis odpovídá 2x2. |
| purging_burst_upgraded | Deal 1 damage in 4x4 area. | DEAL_DAMAGE 1, area=3, **4x4** | HOLY | SQUARE 4x4 | Popis odpovídá. |

Shrnutí paladin dmg:  
- „To all enemies“ (celé pole) mají v .tres **target_type=6 + SQUARE 1x1** → v boji jen **1 buňka**. Měly by mít **target_type=3 (ALL_ENEMY_UNITS)** a pro text „To all:“ ideálně **area_of_effect_type=4 (ALL_ON_GRID)**.  
- Většina paladin úderů má **damage_type=HOLY**, ale v **description** to není – buď doplnit „holy“ do textu, nebo sjednotit, kdy holy ikonu zobrazovat.  
- **Zobrazení čísla dmg:** u HOLY se na kartě nepřičítá pasivní +3 dmg (zůstane base) – to je záměr v kódu; pokud chceš na kartě 6, musí se buď změnit logika, nebo tyto karty převést na NORMAL a holy řešit jinak (např. jen tooltip).

---

### 2.3 PALADIN – blok, léčení, statusy, speciální

| card_id | Description (EN) | .tres efekty | Poznámka |
|--------|------------------|--------------|----------|
| divine_grace | Heal to full. Exhaust. | HEAL_TO_FULL, EXHAUST | OK |
| lay_on_hands / + | Heal to full. Exhaust. | HEAL_TO_FULL, EXHAUST | OK |
| healing_light | Heal 8 HP. | HEAL_UNIT 8 | OK |
| lesser_heal / + | Heal 4 / 6 HP. | HEAL 4 / 6 | OK |
| holy_blessing | Heal 12. Gain 3 block. | HEAL 12, GAIN_BLOCK 3 | OK |
| healing_aura | Heal 10. All allies heal 5. | HEAL 10 (self), HEAL 5 (**target_type=28**) | **Bug: target_type=28** není v enumu (max 6). Pro „all allies“ má být **4 (ALL_ALLY_UNITS)**. |
| protective_hand | Gain 8 block. Heal 5. | GAIN_BLOCK 8, HEAL 5 | OK |
| protective_aura | Gain 5 block. All allies gain 2. | GAIN_BLOCK 5 (self), GAIN_BLOCK 2 (**target_type=28**) | **Stejný bug: target_type=28** → mělo by být 4. |
| massive_healing | Heal 20. If <30% HP, heal 30. | HEAL 20, condition health_below_percent 30, bonus 30 | OK (conditional_bonus_value=30 = „heal 30“). |
| sacred_healing | Heal 15. Remove all debuffs. | HEAL 15, APPLY_STATUS string_value=**remove_all_debuffs** | remove_all_debuffs je v BattleScene speciálně ošetřen; v CardData._get_status_display_description pro to není klíč → kompaktní popis může být prázdný/divný. |
| purification | Remove all debuffs. Gain 5 block. | APPLY_STATUS remove_all_debuffs, GAIN_BLOCK 5 | Stejný status bez překladu v _get_status_display_description. |
| impregnable_shield | Gain 10 block. Remove all debuffs. | GAIN_BLOCK 10, APPLY_STATUS remove_all_debuffs | Stejně. |
| regeneration | Regeneration 3 HP/turn for 3 turns. | APPLY_STATUS regeneration 3 | OK |
| defensive_stance | Gain 4 block. Next attack vs you 50% less. | GAIN_BLOCK 4, APPLY_STATUS defensive_stance | OK |
| consecrated_barrier | Gain 6 block. If took damage last turn, +4. | GAIN_BLOCK 6, condition took_damage_last_turn, +4 | OK |
| holy_armor | Gain 8 block. If >20 block, +3. | GAIN_BLOCK 8, condition block_above 20, +3 | OK |
| holy_shield | Gain 12 block. If <50% HP, +8. | GAIN_BLOCK 12, condition health_below_percent 50, +8 | OK |
| pious_defense / + | Gain 7 / 10 block. | GAIN_BLOCK 7 / 10 | OK |
| fortification | Gain 15 block. Doesn't disappear. | GAIN_BLOCK 15 (speciální „permanent“ – nutno ověřit v kódu) | OK |
| unbreakable_faith | Gain 25 block. Exhaust. | GAIN_BLOCK 25, EXHAUST | OK |
| shield_bash | Deal damage = block. | DEAL_DAMAGE_FROM_BLOCK | OK |
| shield_bash_upgraded | Deal double damage = block. | DEAL_DOUBLE_DAMAGE_FROM_BLOCK | OK |
| aura_of_devotion / + | Start of turn: gain 2 / 4 block. | APPLY_STATUS aura_devotion / aura_devotion_plus | OK |

---

### 2.4 CURSE

| card_id | Description (EN) | .tres | Poznámka |
|--------|------------------|-------|----------|
| curse_basic | Useless card. | (žádný efekt nebo speciální) | OK |
| curse_pain | Unplayable. End of turn: 2 damage. | (speciální) | OK |
| curse_weakness | Exhausts. When drawn, -1 energy. | (speciální) | OK |

---

## 3. Shrnutí problémů (pro plán úprav)

### A) „To all enemies“ vs. data a zobrazení

- **Karty:** consecration, consecration+, divine_wrath, divine_wrath+, divine_judgment, divine_protection (dmg část).  
- **Stav:** V .tres mají **target_type=6 (ANY_GRID_CELL)** a **area_of_effect_type=3 (SQUARE) 1x1** → v boji zásah **jen jedna buňka**. Popis říká „to all enemies“.  
- **Možné úpravy:**  
  - Nastavit **target_type = 3 (ALL_ENEMY_UNITS)** a podle potřeby **area_of_effect_type = 4 (ALL_ON_GRID)** aby: 1) v boji opravdu zasáhly všechny nepřátele, 2) na kartě byl prefix „To all:“.

### B) Holy damage – popis vs. ikona vs. zobrazené číslo

- **Stav:** V .tres je u mnoha karet **damage_type=HOLY**; v **description** není slovo „holy“. Na kartě je **holy ikona**.  
- **Zobrazení čísla:** U HOLY se **nepřičítá** global_card_damage_bonus (na kartě vždy base) – proto u Consecration zůstane 3 i s +3 dmg.  
- **Možné úpravy:**  
  - Buď do popisů doplnit, že jde o holy damage (např. „Deal 3 holy damage…“),  
  - nebo sjednotit pravidlo, kdy holy ikonu zobrazovat (např. jen u karet, kde to v popisu je).  
  - Pokud má být na kartě vidět „3+3=6“, pak buď u HOLY také používat `get_display_damage`, nebo tyto karty převést na NORMAL a holy řešit jen v tooltipu / mechanice.

### C) target_type = 28 (neplatná hodnota)

- **Karty:** healing_aura (druhý efekt: Heal 5 all allies), protective_aura (druhý efekt: 2 block all allies).  
- **Stav:** TargetType má hodnoty 0–6; 28 je neplatné.  
- **Úprava:** Změnit na **4 (ALL_ALLY_UNITS)** a v boji ověřit, že „all allies“ se aplikuje správně.

### D) Status „remove_all_debuffs“

- **Karty:** sacred_healing, purification, impregnable_shield.  
- **Stav:** V BattleScene je speciálně ošetřen; v CardData._get_status_display_description pro `remove_all_debuffs` není překlad → kompaktní popis může být neúplný.  
- **Úprava:** Přidat do _get_status_display_description (a případně translations) text pro „Remove all debuffs“.

### E) Konzistence damage_type

- **shield_strike:** má DEAL_DAMAGE s **NORMAL**; ostatní paladin údery mají HOLY. Ověřit, zda je to záměr (např. „fyzický úder štítem“).

---

## 4. Doporučený další krok

1. Rozhodnout:  
   - „To all“ karty: opravit na ALL_ENEMY_UNITS + případně ALL_ON_GRID.  
   - Holy: buď doplnit do popisů, nebo upravit zobrazení ikony/čísla.  
   - target_type 28 → 4 u healing_aura a protective_aura.  
   - remove_all_debuffs: doplnit zobrazení v CardData (+ překlady).  
2. Podle toho udělat konkrétní změny v .tres, CardData.gd, DamageCalculator (jen pokud změníš pravidlo pro holy display) a translations.csv.

Když budeš chtít, můžeme z tohoto plánu vybrat první úpravu a napsat konkrétní diff (soubory + řádky).
