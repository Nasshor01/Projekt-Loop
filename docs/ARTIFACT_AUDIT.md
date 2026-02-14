# Audit artefaktů – kontrola implementace

## Přehled artefaktů a stav implementace

### ✅ Zdravé jablko (Healthy Apple)
- **Konfigurace:** PASSIVE, MODIFY_MAX_HP, +5 (stackovatelné 1–10×)
- **Implementace:** `PlayerData.apply_passive_skills()` → `ArtifactManager.get_max_hp_bonus()` → `get_passive_bonus(MODIFY_MAX_HP)`
- **Stav:** ✅ Funguje správně

---

### ✅ Mana Krystal
- **Konfigurace:** START_OF_TURN, GAIN_ENERGY, +1 (stackovatelné 1–2×)
- **Implementace:** `BattleScene._start_player_initiative_turn()` → `ArtifactManager.on_turn_start()` → `ArtifactEffect` GAIN_ENERGY → `PlayerData.gain_energy()`
- **Stav:** ✅ Funguje správně

---

### ✅ Bojovníkův náramek
- **Konfigurace:** START_OF_TURN, GAIN_BLOCK, +3 (stackovatelné 1–3×)
- **Implementace:** Stejný řetězec jako Mana Krystal, `ArtifactEffect` GAIN_BLOCK → `target_unit.add_block()`
- **Stav:** ✅ Funguje správně

---

### ✅ Berserkerova zuřivost
- **Konfigurace:** CONDITIONAL, MODIFY_CARD_DAMAGE, +3 při `health_below` 50 %
- **Implementace:** `DamageCalculator.get_final_damage()` a `CardData` → `ArtifactManager.get_card_damage_bonus(context)` → `get_conditional_bonus(MODIFY_CARD_DAMAGE, context)` – context obsahuje `current_hp`, `max_hp`
- **Stav:** ✅ Funguje správně

---

### ✅ Štít odražení
- **Konfigurace:** ON_DAMAGE_TAKEN, THORNS_DAMAGE, 4
- **Implementace:** `Unit.take_damage()` → `ArtifactManager.on_damage_taken(amount, attacker)` → context s `attacker` → `ArtifactEffect` THORNS_DAMAGE útočí na `attacker`
- **Stav:** ✅ Funguje správně

---

### ✅ Fénixovo pero (OPRAVENO)
- **Konfigurace:** CONDITIONAL, HEAL_HP, 50 % max HP (percentage_based), `health_below` 25 %, 1× za souboj
- **Implementace:** `Unit.take_damage()` → `ArtifactManager.check_conditional_artifacts()` → `ArtifactEffect` HEAL_HP
- **Oprava:** ArtifactEffect.HEAL_HP nyní pro `percentage_based` + `health_below` léčí na primary_value % max HP (ne přičítá).

---

### ✅ Srdce draka (OPRAVENO)
- **Konfigurace:** START_OF_TURN, custom `dragon_heart_combo`, blok = max HP (první 2 tahy), secondary_value = -10 (Max HP -10)
- **Implementace bloku:** ✅ `ArtifactManager.handle_custom_effect("dragon_heart_combo")` – blok funguje
- **Oprava:** V `PlayerData.add_artifact()` se při získání Srdce draka aplikuje `change_max_hp(secondary_value)` jednorázově (meta flag).

---

### ✅ Časový krystal (OPRAVENO)
- **Konfigurace:** CONDITIONAL, custom `extra_turn`, `turn_number` % 3 == 0
- **Implementace:**
  1. `check_conditional_artifacts_with_context` se nikdy nevolá s `turn_number` v kontextu.
  2. `check_conditional_artifacts()` se volá pouze z `Unit.take_damage()` (když hráč utrpí poškození) – context bez `turn_number`.
  3. Custom efekt `extra_turn` vrací jen `true`, nevolá `BattleScene.start_extra_turn()`.
- **Oprava:**
  1. V `_on_hand_discard_animation_finished` se volá `check_conditional_artifacts_with_context` s `turn_number` v kontextu.
  2. ArtifactManager emituje signál `extra_turn_requested`, BattleScene ho poslouchá a volá `start_extra_turn()`.
  3. Pokud se extra tah aktivuje, nepřechází se na TurnManager.next_turn().

---

### ✅ Oko pravdy
- **Konfigurace:** PASSIVE, CRITICAL_CHANCE, 25 %
- **Implementace:** `PlayerData.apply_passive_skills()` → `ArtifactManager.get_critical_chance()` → použito v `Unit.attack()` a `BattleScene` při počítání poškození karet
- **Stav:** ✅ Funguje správně

---

### ✅ Meč nekonečna
- **Konfigurace:** ON_ENEMY_DEATH, custom `scaling_damage`, +1 poškození za zabitého
- **Implementace:** `BattleScene._on_unit_died()` → `ArtifactManager.on_enemy_death()` → `handle_custom_effect("scaling_damage")` → `PlayerData.global_card_damage_bonus += bonus`. Reset po bossovi v `GameManager.battle_finished()`.
- **Stav:** ✅ Funguje správně

---

### ✅ Záhadná kostka
- **Konfigurace:** START_OF_TURN, custom `random_energy` – 50 % +2 energie, 50 % -1 energie
- **Implementace:** `ArtifactManager.handle_custom_effect("random_energy")` – správně implementováno
- **Stav:** ✅ Funguje správně

---

## Shrnutí

| Artefakt        | Stav | Poznámka                          |
|-----------------|------|-----------------------------------|
| Zdravé jablko   | ✅   | OK                                |
| Mana Krystal    | ✅   | OK                                |
| Bojovníkův nár. | ✅   | OK                                |
| Berserkerova z. | ✅   | OK                                |
| Štít odražení   | ✅   | OK                                |
| Fénixovo pero   | ✅   | Opraveno – léčí na 50 % HP |
| Srdce draka     | ✅   | Opraveno – -10 Max HP při získání |
| Časový krystal  | ✅   | Opraveno – extra tah každý 3. tah |
| Oko pravdy      | ✅   | OK                                |
| Meč nekonečna   | ✅   | OK                                |
| Záhadná kostka  | ✅   | OK                                |
