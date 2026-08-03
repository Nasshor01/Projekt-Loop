# -*- coding: utf-8 -*-
"""Generate artifact behavior scripts + catalog .tres for the remake."""
from pathlib import Path
import textwrap

ROOT = Path(r"D:\Games\projekt-loop-v2")
BEH = ROOT / "data" / "artifacts" / "behaviors"
CAT = ROOT / "data" / "artifacts" / "catalog"
ICON = "res://art/icons/Artifacts NEW"

# rarity folder, id, display name, description, icon filename, stackable, max_stacks, in_pool
# type: 0 common, 1 uncommon, 2 rare, 3 legendary, 4 cursed, 5 boss
ARTIFACTS = [
    ("common", "forbidden_apple", "Forbidden Apple", "+7 Max HP. Stacks.", "Forbidden Apple.png", True, 10, True, 0),
    ("uncommon", "runic_cube_of_binding", "Runic Cube of Binding", "Movement cards: +1 Block and 1 Weak to a random enemy. Doubled on grid edge.", "Runic Cube of Binding.png", False, 1, True, 1),
    ("uncommon", "tablet_of_forgotten_oaths", "Tablet of Forgotten Oaths", "At combat start seal 1 card: cost -1 and +2 Block when played. Max 1 sealed.", "Tablet of Forgotten Oaths.png", False, 1, True, 1),
    ("uncommon", "embercleaver", "Embercleaver", "Attacks apply 1 Burn. Burn death: 4 damage to adjacent enemies.", "Embercleaver.png", False, 1, True, 1),
    ("uncommon", "charm_of_fortune", "Charm of Fortune", "Shop prices -12%. 8% chance free. After combat 15% chance +25% gold.", "Charm of Fortune.png", False, 1, True, 1),
    ("uncommon", "fractured_bulwark", "Fractured Bulwark", "Unblocked damage: +1 card end of turn (1x/turn). 1x/combat delay one hit.", "Fractured Bulwark.png", False, 1, True, 1),
    ("uncommon", "spiral_bulwark", "Spiral Bulwark", "Gain 2 Thorns. Thorns damage grants +1 Block (max 3x/turn).", "Spiral Bulwark.png", False, 1, True, 1),
    ("rare", "arcane_prism", "Arcane Prism", "Start of turn: random Strength/Dexterity/Focus. If 2+ different statuses: +1 Energy.", "Arcane Prism.png", False, 1, True, 2),
    ("rare", "plague_mace_core", "Plague Mace Core", "Melee attacks +1 Poison. At 5+ Poison: +2 damage each their turn and you gain 1 Energy.", "Plague Mace Core.png", False, 1, True, 2),
    ("rare", "hellchain_reaver", "Hellchain Reaver", "Melee attacks: +2 Strength this turn. After first attack, next attack costs 1 less.", "Hellchain Reaver.png", False, 1, True, 2),
    ("rare", "frostbite_executioner", "Frostbite Executioner", "Attacks apply 1 Chill. At 3+ Chill: +50% damage and apply 1 Weak.", "Frostbite Executioner.png", False, 1, True, 2),
    ("rare", "molten_heart", "Molten Heart", "Start of turn +1 Strength. Causing Burn heals 1 HP.", "Molten Heart.png", False, 1, True, 2),
    ("rare", "frostbitten_heart", "Frostbitten Heart", "Attacks apply 1 Chill. At 3+ Chill: +4 damage and heal 2 HP.", "Frostbitten Heart.png", False, 1, True, 2),
    ("rare", "infernal_dragonheart", "Infernal Dragonheart", "On Burn: move 1 toward enemy. If adjacent after move: +1 Burn.", "Infernal Dragonheart.png", False, 1, True, 2),
    ("rare", "plague_dragonheart", "Plague Dragonheart", "Poison on already-poisoned spreads to their row. 1x/combat at 8+: double all Poison.", "Plague Dragonheart.png", False, 1, True, 2),
    ("rare", "crown_of_dominion", "Crown of Dominion", "Random owned cell: cards cost -1 while standing there. 3 charges then auto-relocates.", "Crown of Dominion.png", False, 1, True, 2),
    ("rare", "crimson_chalice", "Crimson Chalice", "Start of turn: may lose 3 HP to discard 1 random and draw 2. Won't kill you.", "Crimson Chalice.png", False, 1, True, 2),
    ("rare", "tome_of_echoes", "Tome of Echoes", "Cards costing 2+ go to bottom of draw pile. 1x/combat: draw 2 discard 1.", "Tome of Echoes.png", False, 1, True, 2),
    ("rare", "aether_crystal", "Aether Crystal", "Retain up to 2 unused Energy. Spend all Energy: +1 card end of turn.", "Aether Crystal.png", False, 1, True, 2),
    ("rare", "all_seeing_eye", "All-Seeing Eye", "See enemy move previews. 1x/combat: forbid one enemy move next turn.", "All-Seeing Eye.png", False, 1, True, 2),
    ("rare", "belt_of_the_iron_will", "Belt of the Iron Will", "End turn on edge: +2 Block. End turn center: +1 card next turn.", "Belt of the Iron Will.png", False, 1, True, 2),
    ("rare", "alchemists_tools", "Alchemist's Tools", "Start of turn: may discard 1 for a random temp alchemist card (exhaust end of turn).", "Alchemist's Tools.png", False, 1, True, 2),
    ("rare", "verdant_scale", "Verdant Scale", "On move: +1 Block per step. End next to 2+ enemies: apply 1 Weak.", "Verdant Scale.png", False, 1, True, 2),
    ("rare", "phoenix_feather", "Phoenix Feather", "Once per run on lethal: revive to 50% Max HP and +2 Strength, then burn out.", "Phoenix Feather.png", False, 1, True, 2),
    ("cursed", "bloodbound_amulet", "Bloodbound Amulet", "Lose HP: +1 Strength and +1 Thorns. Kill: heal 50% of HP lost this combat.", "Bloodbound Amulet.png", False, 1, True, 4),
    ("cursed", "bloodrage_cleaver", "Bloodrage Cleaver", "Per 5 HP lost this combat: +1 Strength. Kill: +1 Energy and next attack costs 1 less.", "Bloodrage Cleaver.png", False, 1, True, 4),
    ("cursed", "voidheart", "Voidheart", "Combat start: +3 Strength and +3 Dexterity. Each turn: -1 Max HP (combat).", "Voidheart.png", False, 1, True, 4),
    ("cursed", "void_dragonheart", "Void Dragonheart", "Start turn: +1 Strength per enemy at range 3+. Lose 1 HP per adjacent enemy.", "Void Dragonheart.png", False, 1, True, 4),
    ("cursed", "ring_of_the_living_grove", "Ring of the Living Grove", "Each turn: root on random player-half cell (max 3). On root +1 card, else -1 HP.", "Ring of the Living Grove.png", False, 1, True, 4),
    ("legendary", "plaguebone_axe", "Plaguebone Axe", "Attacks +2 Poison. At 8+ Poison: ignore Block and +3 damage.", "Plaguebone Axe.png", False, 1, True, 3),
    ("legendary", "time_crystal", "Time Crystal", "Every 3rd combat turn: gain an extra turn.", "Time Crystal.png", False, 1, True, 3),
    ("legendary", "gilded_dragonheart", "Gilded Dragonheart", "Random row/col: attacks there cost -1 and apply Weak. Auto-rerolls.", "Gilded Dragonheart.png", False, 1, True, 3),
    ("legendary", "blade_of_infinity", "Blade of Infinity", "Exhausted Attack cards return to bottom of draw pile instead of permanent exhaust.", "Blade of Infinity.png", False, 1, True, 3),
    ("boss", "throne_fragment", "Throne Fragment", "2 random Thrones: cost -1 and +1 card end turn. 3 charges then auto-move.", "Throne Fragment.png", False, 1, True, 5),
    ("boss", "oathbreaker_seal", "Oathbreaker Seal", "On acquire: 2 random deck cards permanently cost -1 and Retain.", "Oathbreaker Seal.png", False, 1, True, 5),
    ("boss", "heart_of_the_loop", "Heart of the Loop", "+1 Energy each combat. Every 4th turn echo a random attack. At <=25% HP skip enemy turn 1x.", "Heart of the Loop.png", False, 1, True, 5),
]

BEHAVIORS = {}

BEHAVIORS["forbidden_apple"] = '''
extends ArtifactBehavior

func get_max_hp_bonus() -> int:
	return 7 * stacks
'''

BEHAVIORS["charm_of_fortune"] = '''
extends ArtifactBehavior

func modify_shop_price(price: int, _item = null) -> int:
	var p := int(round(float(price) * 0.88))
	if randf() < 0.08:
		notify_triggered("Charm of Fortune: free!")
		return 0
	return p

func modify_gold_reward(gold: int) -> int:
	if randf() < 0.15:
		notify_triggered("Charm of Fortune: +25% gold")
		return int(round(float(gold) * 1.25))
	return gold
'''

BEHAVIORS["phoenix_feather"] = '''
extends ArtifactBehavior

func before_death(_ctx: Dictionary) -> bool:
	if ArtifactManager.get_run_flag("phoenix_feather_used", false):
		return false
	ArtifactManager.set_run_flag("phoenix_feather_used", true)
	var target_hp := int(PlayerData.max_hp * 0.5)
	PlayerData.current_hp = maxi(1, target_hp)
	var u := player_unit()
	if u:
		u.current_health = PlayerData.current_hp
		ArtifactManager.apply_status_to_unit(u, "strength", 2, 99)
		if u.has_method("_update_stats_and_emit_signal"):
			u._update_stats_and_emit_signal()
	PlayerData.emit_signal("health_changed", PlayerData.current_hp, PlayerData.max_hp)
	notify_triggered("Phoenix Feather revived you!")
	# Remove self from run
	if data:
		PlayerData.remove_artifact(data)
	return true
'''

BEHAVIORS["aether_crystal"] = '''
extends ArtifactBehavior

func on_turn_end(ctx: Dictionary) -> void:
	var energy := int(PlayerData.current_energy)
	var spent_all: bool = energy == 0 and int(ctx.get("attacks_this_turn", ArtifactManager.attacks_this_turn)) >= 0
	# Retain up to 2
	var retain := mini(2, energy)
	if retain > 0:
		PlayerData.set_meta("aether_retained_energy", retain)
		PlayerData.current_energy = 0
	# Spent all energy this turn heuristic: retained 0 and had max>0
	if energy == 0:
		PlayerData.draw_cards(1)
		notify_triggered("Aether Crystal: +1 card")

func on_turn_start(_ctx: Dictionary) -> void:
	if PlayerData.has_meta("aether_retained_energy"):
		var r := int(PlayerData.get_meta("aether_retained_energy"))
		PlayerData.remove_meta("aether_retained_energy")
		if r > 0:
			PlayerData.gain_energy(r)
'''

BEHAVIORS["crimson_chalice"] = '''
extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	if PlayerData.current_hp <= 3:
		return
	# Auto-activate for now (no UI prompt yet)
	var u := player_unit()
	if u and u.has_method("take_damage"):
		u.take_damage(3, true, false, false)
	if not PlayerData.current_hand.is_empty():
		var c = PlayerData.current_hand.pick_random()
		PlayerData.current_hand.erase(c)
		PlayerData.add_card_to_discard_pile(c)
	PlayerData.draw_cards(2)
	notify_triggered("Crimson Chalice")
'''

BEHAVIORS["tablet_of_forgotten_oaths"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	if PlayerData.master_deck.is_empty() and PlayerData.draw_pile.is_empty():
		return
	var pool: Array = []
	pool.append_array(PlayerData.draw_pile)
	pool.append_array(PlayerData.discard_pile)
	pool.append_array(PlayerData.current_hand)
	if pool.is_empty():
		pool.append_array(PlayerData.master_deck)
	if pool.is_empty():
		return
	var card: CardData = pool.pick_random()
	runtime["sealed_card_id"] = card.card_id
	card.set_meta("tablet_sealed", true)
	notify_triggered("Sealed: %s" % card.card_name)

func modify_card_cost(card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	if card and card.get_meta("tablet_sealed", false):
		return maxi(0, cost - 1)
	return cost

func on_card_played(ctx: Dictionary) -> void:
	var card: CardData = ctx.get("card")
	if card and card.get_meta("tablet_sealed", false):
		var u := player_unit()
		if u and u.has_method("add_block"):
			u.add_block(2)
'''

BEHAVIORS["alchemists_tools"] = '''
extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	# Auto: discard 1 if hand not empty, grant temp draw+1 marker via status
	if PlayerData.current_hand.is_empty():
		return
	var c = PlayerData.current_hand.pick_random()
	PlayerData.current_hand.erase(c)
	PlayerData.add_card_to_discard_pile(c)
	# Temp effect: draw 1 / block 3 / heal 3 / energy+1 rotated
	var roll := randi() % 4
	match roll:
		0:
			PlayerData.draw_cards(1)
		1:
			var u := player_unit()
			if u: u.add_block(3)
		2:
			var u2 := player_unit()
			if u2: u2.heal(3)
		3:
			PlayerData.gain_energy(1)
	notify_triggered("Alchemist's Tools")
'''

BEHAVIORS["embercleaver"] = '''
extends ArtifactBehavior

func on_damage_dealt(_ctx: Dictionary) -> void:
	var target = _ctx.get("target")
	if target and target.has_method("apply_status"):
		target.apply_status("burning", 1, 3)
		ArtifactManager.on_status_applied(target, "burning", 1, 3)

func on_enemy_death(ctx: Dictionary) -> void:
	var enemy = ctx.get("dead_enemy")
	if enemy == null or not ("active_statuses" in enemy):
		return
	if not enemy.active_statuses.has("burning"):
		return
	var cell: Vector2i = enemy.grid_position if "grid_position" in enemy else Vector2i.ZERO
	for e in ArtifactManager.get_enemies():
		if e == enemy:
			continue
		if not ("grid_position" in e):
			continue
		var d: Vector2i = e.grid_position - cell
		if abs(d.x) + abs(d.y) == 1:
			e.take_damage(4, true, false, false)
	notify_triggered("Embercleaver explosion")
'''

BEHAVIORS["fractured_bulwark"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["drew_this_turn"] = false
	runtime["delay_used"] = false

func on_turn_start(_ctx: Dictionary) -> void:
	runtime["drew_this_turn"] = false
	if runtime.get("delayed_damage", 0) > 0:
		var dmg := int(runtime["delayed_damage"])
		runtime["delayed_damage"] = 0
		var u := player_unit()
		if u:
			u.take_damage(dmg, true, false, false)

func on_unblocked_damage(ctx: Dictionary) -> void:
	if not runtime.get("drew_this_turn", false):
		runtime["drew_this_turn"] = true
		runtime["pending_draw"] = true

func on_turn_end(_ctx: Dictionary) -> void:
	if runtime.get("pending_draw", false):
		runtime["pending_draw"] = false
		PlayerData.draw_cards(1)
'''

BEHAVIORS["spiral_bulwark"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	var u := player_unit()
	ArtifactManager.apply_status_to_unit(u, "thorns", 2, 99)

func on_turn_start(_ctx: Dictionary) -> void:
	runtime["thorns_block_count"] = 0

func on_thorns_damage(_ctx: Dictionary) -> void:
	var n := int(runtime.get("thorns_block_count", 0))
	if n >= 3:
		return
	runtime["thorns_block_count"] = n + 1
	var u := player_unit()
	if u:
		u.add_block(1)
'''

BEHAVIORS["runic_cube_of_binding"] = '''
extends ArtifactBehavior

func on_card_played(ctx: Dictionary) -> void:
	var card: CardData = ctx.get("card")
	if card == null:
		return
	var is_move := card.has_method("has_tag") and card.has_tag(CardData.CardTag.MOVE)
	if not is_move:
		return
	var block := 1
	var weak := 1
	var u := player_unit()
	if u and "grid_position" in u and ArtifactManager.is_edge_cell(u.grid_position):
		block *= 2
		weak *= 2
	if u:
		u.add_block(block)
	var enemies := ArtifactManager.get_enemies()
	if enemies.size() > 0:
		var t = enemies[randi() % enemies.size()]
		ArtifactManager.apply_status_to_unit(t, "weakness", weak, 2)
'''

BEHAVIORS["arcane_prism"] = '''
extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null:
		return
	var opts := ["strength", "dexterity", "focus"]
	var pick: String = opts[randi() % opts.size()]
	ArtifactManager.apply_status_to_unit(u, pick, 1, 99)
	var distinct := 0
	for s in opts:
		if u.active_statuses.has(s):
			distinct += 1
	if distinct >= 2:
		PlayerData.gain_energy(1)
		notify_triggered("Arcane Prism: +1 Energy")
'''

BEHAVIORS["plague_mace_core"] = '''
extends ArtifactBehavior

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target and target.has_method("apply_status"):
		target.apply_status("poison", 1, 99)
		ArtifactManager.on_status_applied(target, "poison", 1, 99)

func on_turn_start(_ctx: Dictionary) -> void:
	for e in ArtifactManager.get_enemies():
		if status_value(e, "poison") >= 5:
			e.take_damage(2, true, false, false)
			PlayerData.gain_energy(1)
'''

BEHAVIORS["hellchain_reaver"] = '''
extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	runtime["gave_str"] = false

func on_card_played(ctx: Dictionary) -> void:
	if not ctx.get("is_attack", false):
		return
	var u := player_unit()
	ArtifactManager.apply_status_to_unit(u, "strength", 2, 1)
	runtime["discount_next"] = int(ctx.get("attacks_this_turn", 1)) >= 1

func modify_card_cost(card: CardData, cost: int, ctx: Dictionary = {}) -> int:
	if runtime.get("discount_next", false) and ArtifactManager._card_is_attack(card) and ArtifactManager.attacks_this_turn >= 1:
		return maxi(0, cost - 1)
	return cost
'''

BEHAVIORS["frostbite_executioner"] = '''
extends ArtifactBehavior

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target == null:
		return
	target.apply_status("chilled", 1, 3)
	ArtifactManager.on_status_applied(target, "chilled", 1, 3)
	if status_value(target, "chilled") >= 3:
		ArtifactManager.apply_status_to_unit(target, "weakness", 1, 2)

func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var target = ctx.get("target")
	if target and status_value(target, "chilled") >= 3:
		return int(damage * 1.5)
	return damage
'''

BEHAVIORS["molten_heart"] = '''
extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	ArtifactManager.apply_status_to_unit(player_unit(), "strength", 1, 99)

func on_status_applied(ctx: Dictionary) -> void:
	if ctx.get("status_id") == "burning":
		var u := player_unit()
		if u:
			u.heal(1)
'''

BEHAVIORS["frostbitten_heart"] = '''
extends ArtifactBehavior

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target == null:
		return
	target.apply_status("chilled", 1, 3)
	if status_value(target, "chilled") >= 3:
		var u := player_unit()
		if u:
			u.heal(2)

func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var target = ctx.get("target")
	if target and status_value(target, "chilled") >= 3:
		return damage + 4
	return damage
'''

BEHAVIORS["infernal_dragonheart"] = '''
extends ArtifactBehavior

func on_status_applied(ctx: Dictionary) -> void:
	if ctx.get("status_id") != "burning":
		return
	var enemy = ctx.get("unit")
	var u := player_unit()
	if u == null or enemy == null:
		return
	if not ("grid_position" in u and "grid_position" in enemy):
		return
	var from: Vector2i = u.grid_position
	var to: Vector2i = enemy.grid_position
	var step := Vector2i(
		clampi(to.x - from.x, -1, 1),
		clampi(to.y - from.y, -1, 1)
	)
	if step == Vector2i.ZERO:
		return
	var dest := from + step
	var scene = Engine.get_main_loop().root.get_tree().current_scene
	if scene and scene.has_method("force_move_unit_to_cell"):
		scene.force_move_unit_to_cell(u, dest)
	else:
		u.grid_position = dest
	ArtifactManager.on_unit_moved(u, from, dest, 1)
	var d: Vector2i = dest - to
	if abs(d.x) + abs(d.y) == 1:
		enemy.apply_status("burning", 1, 3)
'''

BEHAVIORS["plague_dragonheart"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["doubled"] = false

func on_status_applied(ctx: Dictionary) -> void:
	if ctx.get("status_id") != "poison":
		return
	var unit = ctx.get("unit")
	if unit == null:
		return
	# Spread to row if already had poison before this apply (value > applied)
	var val := status_value(unit, "poison")
	if val > int(ctx.get("status_value", 1)):
		var y: int = unit.grid_position.y if "grid_position" in unit else 0
		var amount := int(ctx.get("status_value", 1))
		for e in ArtifactManager.get_enemies():
			if e == unit:
				continue
			if "grid_position" in e and e.grid_position.y == y:
				e.apply_status("poison", amount, 99)
	if not runtime.get("doubled", false):
		for e in ArtifactManager.get_enemies():
			if status_value(e, "poison") >= 8:
				runtime["doubled"] = true
				for e2 in ArtifactManager.get_enemies():
					var p := status_value(e2, "poison")
					if p > 0:
						e2.active_statuses["poison"].value = p * 2
				notify_triggered("Plague Dragonheart: poison doubled")
				break
'''

BEHAVIORS["crown_of_dominion"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	_relocate()

func _relocate() -> void:
	var cell := ArtifactManager.pick_random_player_half_cell()
	runtime["cell"] = cell
	runtime["charges"] = 3
	ArtifactManager.grid_zones["crown_of_dominion"] = {"cells": [cell], "charges": 3}
	notify_triggered("Crown cell %s" % str(cell))

func modify_card_cost(_card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	var u := player_unit()
	if u == null or not ("grid_position" in u):
		return cost
	if u.grid_position != runtime.get("cell", Vector2i(-99, -99)):
		return cost
	if int(runtime.get("charges", 0)) <= 0:
		return cost
	return maxi(0, cost - 1)

func on_card_played(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null or u.grid_position != runtime.get("cell", Vector2i(-99, -99)):
		return
	runtime["charges"] = int(runtime.get("charges", 0)) - 1
	if int(runtime["charges"]) <= 0:
		_relocate()
'''

BEHAVIORS["tome_of_echoes"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["used_draw"] = false

func on_card_played(ctx: Dictionary) -> void:
	var card: CardData = ctx.get("card")
	var cost := int(ctx.get("card_cost", card.cost if card else 0))
	if card == null or cost < 2:
		return
	# Mark for bottom-deck instead of discard — BattleScene checks meta
	card.set_meta("tome_to_bottom", true)

func on_turn_start(_ctx: Dictionary) -> void:
	if runtime.get("used_draw", false):
		return
	runtime["used_draw"] = true
	PlayerData.draw_cards(2)
	if not PlayerData.current_hand.is_empty():
		var c = PlayerData.current_hand.pick_random()
		PlayerData.current_hand.erase(c)
		PlayerData.add_card_to_discard_pile(c)
'''

BEHAVIORS["all_seeing_eye"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["used"] = false
	ArtifactManager.set_run_flag("all_seeing_eye_preview", true)

func on_combat_end(_ctx: Dictionary) -> void:
	ArtifactManager.set_run_flag("all_seeing_eye_preview", false)
'''

BEHAVIORS["belt_of_the_iron_will"] = '''
extends ArtifactBehavior

func on_turn_end(ctx: Dictionary) -> void:
	var cell: Vector2i = ctx.get("player_cell", Vector2i.ZERO)
	var u := player_unit()
	if u == null:
		return
	if ArtifactManager.is_edge_cell(cell):
		u.add_block(2)
	else:
		runtime["draw_next"] = true

func on_turn_start(_ctx: Dictionary) -> void:
	if runtime.get("draw_next", false):
		runtime["draw_next"] = false
		PlayerData.draw_cards(1)
'''

BEHAVIORS["verdant_scale"] = '''
extends ArtifactBehavior

func on_unit_moved(ctx: Dictionary) -> void:
	if not ctx.get("is_player", false):
		return
	var steps := int(ctx.get("steps", 1))
	var u := player_unit()
	if u:
		u.add_block(maxi(1, steps))

func on_turn_end(ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null or not ("grid_position" in u):
		return
	var cell: Vector2i = u.grid_position
	var adj := 0
	var near: Array = []
	for e in ArtifactManager.get_enemies():
		if not ("grid_position" in e):
			continue
		var d: Vector2i = e.grid_position - cell
		if abs(d.x) + abs(d.y) == 1:
			adj += 1
			near.append(e)
	if adj >= 2:
		for e in near:
			ArtifactManager.apply_status_to_unit(e, "weakness", 1, 2)
'''

BEHAVIORS["bloodbound_amulet"] = '''
extends ArtifactBehavior

func on_unblocked_damage(_ctx: Dictionary) -> void:
	var u := player_unit()
	ArtifactManager.apply_status_to_unit(u, "strength", 1, 99)
	ArtifactManager.apply_status_to_unit(u, "thorns", 1, 99)

func on_enemy_death(_ctx: Dictionary) -> void:
	var heal_amt := int(ArtifactManager.hp_lost_this_combat * 0.5)
	if heal_amt <= 0:
		return
	var u := player_unit()
	if u:
		# Temporary max HP style heal — heal up to heal_amt even above current max visually via heal
		u.heal(heal_amt)
	notify_triggered("Bloodbound heal %d" % heal_amt)
'''

BEHAVIORS["bloodrage_cleaver"] = '''
extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	var bonus := int(ArtifactManager.hp_lost_this_combat / 5)
	runtime["str_bonus"] = bonus
	if bonus > 0:
		ArtifactManager.apply_status_to_unit(player_unit(), "strength", bonus, 1)

func on_enemy_death(_ctx: Dictionary) -> void:
	PlayerData.gain_energy(1)
	runtime["discount_next"] = true
	notify_triggered("Bloodrage Cleaver")

func modify_card_cost(card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	if runtime.get("discount_next", false) and ArtifactManager._card_is_attack(card):
		runtime["discount_next"] = false
		return maxi(0, cost - 1)
	return cost
'''

BEHAVIORS["voidheart"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	var u := player_unit()
	ArtifactManager.apply_status_to_unit(u, "strength", 3, 99)
	ArtifactManager.apply_status_to_unit(u, "dexterity", 3, 99)
	runtime["max_hp_penalty"] = 0

func on_turn_start(_ctx: Dictionary) -> void:
	runtime["max_hp_penalty"] = int(runtime.get("max_hp_penalty", 0)) + 1
	# Combat-only max HP drain via meta
	PlayerData.set_meta("voidheart_max_hp_penalty", runtime["max_hp_penalty"])
	var u := player_unit()
	if u:
		u.current_health = mini(u.current_health, maxi(1, PlayerData.max_hp - runtime["max_hp_penalty"]))
		PlayerData.current_hp = u.current_health

func on_combat_end(_ctx: Dictionary) -> void:
	if PlayerData.has_meta("voidheart_max_hp_penalty"):
		PlayerData.remove_meta("voidheart_max_hp_penalty")
'''

BEHAVIORS["void_dragonheart"] = '''
extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null or not ("grid_position" in u):
		return
	var cell: Vector2i = u.grid_position
	var far := 0
	var near := 0
	for e in ArtifactManager.get_enemies():
		if not ("grid_position" in e):
			continue
		var d: Vector2i = e.grid_position - cell
		var dist := abs(d.x) + abs(d.y)
		if dist >= 3:
			far += 1
		if dist == 1:
			near += 1
	if far > 0:
		ArtifactManager.apply_status_to_unit(u, "strength", far, 1)
	if near > 0:
		u.take_damage(near, true, false, false)
'''

BEHAVIORS["ring_of_the_living_grove"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["roots"] = []

func on_turn_start(_ctx: Dictionary) -> void:
	var roots: Array = runtime.get("roots", [])
	var cell := ArtifactManager.pick_random_player_half_cell(roots)
	roots.append(cell)
	if roots.size() > 3:
		roots.pop_front()
	runtime["roots"] = roots
	ArtifactManager.grid_zones["ring_of_the_living_grove"] = {"cells": roots.duplicate()}

func on_turn_end(ctx: Dictionary) -> void:
	var cell: Vector2i = ctx.get("player_cell", Vector2i(-1, -1))
	var roots: Array = runtime.get("roots", [])
	if roots.has(cell):
		PlayerData.draw_cards(1)
	else:
		var u := player_unit()
		if u:
			# Unblockable 1 HP
			u.current_health = maxi(0, u.current_health - 1)
			PlayerData.current_hp = u.current_health
			if u.has_method("_update_stats_and_emit_signal"):
				u._update_stats_and_emit_signal()
'''

BEHAVIORS["plaguebone_axe"] = '''
extends ArtifactBehavior

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target:
		target.apply_status("poison", 2, 99)
		ArtifactManager.on_status_applied(target, "poison", 2, 99)

func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var target = ctx.get("target")
	if target and status_value(target, "poison") >= 8:
		# Ignore block is handled via flag for BattleScene; add damage here
		ctx["ignore_block"] = true
		return damage + 3
	return damage
'''

BEHAVIORS["time_crystal"] = '''
extends ArtifactBehavior

func on_turn_start(ctx: Dictionary) -> void:
	var turn := int(ctx.get("combat_turn", ArtifactManager.combat_turn))
	if turn > 0 and turn % 3 == 0:
		ArtifactManager.request_extra_turn()
		notify_triggered("Time Crystal: extra turn")
'''

BEHAVIORS["gilded_dragonheart"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	_reroll()
	runtime["hits"] = 0

func _reroll() -> void:
	if randf() < 0.5:
		runtime["axis"] = "row"
		runtime["index"] = randi() % 5
	else:
		runtime["axis"] = "col"
		runtime["index"] = randi() % 8
	notify_triggered("Gilded line %s %d" % [runtime["axis"], runtime["index"]])

func _on_line(cell: Vector2i) -> bool:
	if runtime.get("axis") == "row":
		return cell.y == int(runtime.get("index", -1))
	return cell.x == int(runtime.get("index", -1))

func modify_card_cost(card: CardData, cost: int, ctx: Dictionary = {}) -> int:
	# Cost reduction applied when targeting — approximate: if any enemy on line
	for e in ArtifactManager.get_enemies():
		if "grid_position" in e and _on_line(e.grid_position) and ArtifactManager._card_is_attack(card):
			return maxi(0, cost - 1)
	return cost

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target == null or not ("grid_position" in target):
		return
	if not _on_line(target.grid_position):
		return
	ArtifactManager.apply_status_to_unit(target, "weakness", 1, 2)
	runtime["hits"] = int(runtime.get("hits", 0)) + 1
	if int(runtime["hits"]) >= 3:
		runtime["hits"] = 0
		_reroll()

func on_turn_start(ctx: Dictionary) -> void:
	var turn := int(ctx.get("combat_turn", 0))
	if turn > 0 and turn % 3 == 0:
		_reroll()
'''

BEHAVIORS["blade_of_infinity"] = '''
extends ArtifactBehavior

func on_exhaust(ctx: Dictionary) -> void:
	var card: CardData = ctx.get("card")
	if card == null:
		return
	if not ArtifactManager._card_is_attack(card):
		return
	# Return to bottom of draw pile
	PlayerData.exhaust_pile.erase(card)
	PlayerData.draw_pile.append(card)
	notify_triggered("Blade of Infinity recycled attack")
'''

BEHAVIORS["throne_fragment"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	_place()

func _place() -> void:
	var a := ArtifactManager.pick_random_player_half_cell()
	var b := ArtifactManager.pick_random_player_half_cell([a])
	runtime["cells"] = [a, b]
	runtime["charges"] = {str(a): 3, str(b): 3}
	ArtifactManager.grid_zones["throne_fragment"] = {"cells": [a, b]}

func modify_card_cost(_card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	var u := player_unit()
	if u == null:
		return cost
	var cells: Array = runtime.get("cells", [])
	if cells.has(u.grid_position):
		return maxi(0, cost - 1)
	return cost

func on_card_played(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null:
		return
	var key := str(u.grid_position)
	var charges: Dictionary = runtime.get("charges", {})
	if not charges.has(key):
		return
	charges[key] = int(charges[key]) - 1
	if int(charges[key]) <= 0:
		_place()

func on_turn_end(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u and runtime.get("cells", []).has(u.grid_position):
		PlayerData.draw_cards(1)
'''

BEHAVIORS["oathbreaker_seal"] = '''
extends ArtifactBehavior

func on_acquired(_ctx: Dictionary = {}) -> void:
	var deck: Array = PlayerData.master_deck.duplicate()
	if deck.size() < 1:
		return
	deck.shuffle()
	var n := mini(2, deck.size())
	for i in range(n):
		var card: CardData = deck[i]
		card.cost = maxi(0, card.cost - 1)
		if card.has_method("has_tag") == false or true:
			card.set_meta("oathbreaker_retain", true)
	notify_triggered("Oathbreaker Seal marked %d cards" % n)
'''

BEHAVIORS["heart_of_the_loop"] = '''
extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	PlayerData.gain_energy(1)
	runtime["panic_used"] = false
	runtime["attacks"] = []

func on_card_played(ctx: Dictionary) -> void:
	if ctx.get("is_attack", false):
		var arr: Array = runtime.get("attacks", [])
		arr.append(ctx.get("card"))
		runtime["attacks"] = arr

func on_turn_end(ctx: Dictionary) -> void:
	var turn := int(ctx.get("combat_turn", ArtifactManager.combat_turn))
	if turn > 0 and turn % 4 == 0:
		var arr: Array = runtime.get("attacks", [])
		if arr.size() > 0:
			notify_triggered("Heart of the Loop: echo attack")
			# Echo is visual/log for now; full replay needs BattleScene support
	runtime["attacks"] = []

func on_unblocked_damage(_ctx: Dictionary) -> void:
	if runtime.get("panic_used", false):
		return
	if PlayerData.max_hp <= 0:
		return
	var pct := float(PlayerData.current_hp) / float(PlayerData.max_hp)
	if pct <= 0.25:
		runtime["panic_used"] = true
		ArtifactManager.set_run_flag("skip_next_enemy_turn", true)
		notify_triggered("Heart of the Loop: skip enemy turn")
'''

def write_behavior(aid: str, body: str):
    path = BEH / f"{aid}.gd"
    content = "class_name ArtifactBehavior_%s\n" % "".join(p.capitalize() for p in aid.split("_"))
    # Godot doesn't need class_name for every behavior; avoid collisions — just extends
    content = body.strip() + "\n"
    if not content.startswith("extends"):
        content = "extends ArtifactBehavior\n\n" + content
    path.write_text(content, encoding="utf-8")

def write_tres(folder, aid, name, desc, icon, stackable, max_stacks, in_pool, atype):
    folder_path = CAT / folder
    folder_path.mkdir(parents=True, exist_ok=True)
    icon_path = f"{ICON}/{icon}"
    beh_path = f"res://data/artifacts/behaviors/{aid}.gd"
    # Escape for tres
    tres = f'''[gd_resource type="Resource" script_class="ArtifactsData" load_steps=3 format=3]

[ext_resource type="Script" path="res://data/artifacts/ArtifactsData.gd" id="1"]
[ext_resource type="Texture2D" path="{icon_path}" id="2"]

[resource]
script = ExtResource("1")
artifact_id = "{aid}"
artifact_name = "{name}"
description = "{desc}"
texture = ExtResource("2")
behavior_script = "{beh_path}"
artifact_type = {atype}
trigger_type = 14
effect_type = 28
primary_value = 0
secondary_value = 0
percentage_based = false
uses_per_combat = -1
current_uses = 0
is_stackable = {str(stackable).lower()}
max_stacks = {max_stacks}
current_stacks = 1
synergy_set_id = ""
condition_type = ""
condition_value = 0
custom_effect_id = ""
effect_description = ""
in_live_pool = {str(in_pool).lower()}
'''
    (folder_path / f"{aid}.tres").write_text(tres, encoding="utf-8")

def main():
    BEH.mkdir(parents=True, exist_ok=True)
    missing = []
    for folder, aid, name, desc, icon, stackable, max_stacks, in_pool, atype in ARTIFACTS:
        body = BEHAVIORS.get(aid)
        if not body:
            missing.append(aid)
            body = "extends ArtifactBehavior\n# TODO stub\n"
        write_behavior(aid, body)
        write_tres(folder, aid, name, desc, icon, stackable, max_stacks, in_pool, atype)
    print(f"Generated {len(ARTIFACTS)} artifacts")
    if missing:
        print("Missing bodies (stubs):", missing)

    # Build pools
    live = [a for a in ARTIFACTS if a[7]]
    by_rarity = {}
    for a in live:
        by_rarity.setdefault(a[0], []).append(a)

    def pool_file(path: Path, entries):
        lines = ['[gd_resource type="Resource" script_class="ArtifactPool" load_steps=%d format=3]' % (2 + len(entries)), '']
        lines.append('[ext_resource type="Script" path="res://data/artifacts/ArtifactPool.gd" id="1"]')
        for i, a in enumerate(entries):
            folder, aid = a[0], a[1]
            lines.append(f'[ext_resource type="Resource" path="res://data/artifacts/catalog/{folder}/{aid}.tres" id="a{i}"]')
        lines.append('')
        lines.append('[resource]')
        lines.append('script = ExtResource("1")')
        arr = ", ".join(f'ExtResource("a{i}")' for i in range(len(entries)))
        lines.append(f'artifacts = Array[Resource]([{arr}])')
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    shop = [a for a in live if a[0] in ("common", "uncommon", "rare")]
    elite = [a for a in live if a[0] in ("uncommon", "rare", "cursed")]
    treasure = [a for a in live if a[0] in ("rare", "legendary", "cursed")]
    boss = [a for a in live if a[0] in ("legendary", "boss")]
    event = [a for a in live if a[0] in ("uncommon", "rare")]

    pool_dir = ROOT / "data" / "artifacts" / "pool"
    pool_dir.mkdir(parents=True, exist_ok=True)
    pool_file(ROOT / "data" / "artifacts" / "basic_artifact_pool.tres", shop)
    pool_file(pool_dir / "shop_pool.tres", shop)
    pool_file(pool_dir / "elite_reward_pool.tres", elite)
    pool_file(pool_dir / "treasure_room_pool.tres", treasure)
    pool_file(pool_dir / "boss_reward_pool.tres", boss)
    pool_file(pool_dir / "event_reward_pool.tres", event)
    print("Pools written")

if __name__ == "__main__":
    main()
