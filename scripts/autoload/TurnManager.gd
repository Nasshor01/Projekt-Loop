# res://scripts/autoload/TurnManager.gd
# Správce tahového systému založeného na iniciativě
extends Node

# Signály pro komunikaci s BattleScene
signal round_started(round_number: int)
signal turn_started(unit: Unit)
signal combat_ended(player_won: bool)
signal initiative_modifiers_changed(unit: Unit, total_initiative: int)

# Interní stav
var _combatants: Array[Unit] = []
var _turn_order: Array[Unit] = []
var _current_turn_index: int = 0
var _round_number: int = 0
var _is_combat_active: bool = false
## Pending bonuses applied when the NEXT round is sorted (cleared after sort).
var _initiative_modifiers: Dictionary = {}
## Initiative values locked for the CURRENT round display (instance_id -> int).
var _locked_initiative: Dictionary = {}

func start_combat(all_units: Array[Unit]):
	"""Inicializuje souboj se všemi jednotkami"""
	print("=== TurnManager: START COMBAT ===")
	
	reset()
	_combatants = all_units.duplicate()
	_is_combat_active = true
	
	print("TurnManager: Zaregistrováno %d jednotek" % _combatants.size())
	# Zahaj první kolo
	_start_new_round()

func _effective_initiative(unit: Unit, use_pending_mods: bool) -> int:
	if not is_instance_valid(unit) or not unit.unit_data:
		return 0
	var base: int = unit.unit_data.initiative
	if use_pending_mods:
		return base + int(_initiative_modifiers.get(unit.get_instance_id(), 0))
	return base


func _sort_units_by_initiative(units: Array[Unit], use_pending_mods: bool) -> Array[Unit]:
	var sorted_units: Array[Unit] = units.duplicate()
	sorted_units.sort_custom(func(a: Unit, b: Unit):
		var init_a: int = _effective_initiative(a, use_pending_mods)
		var init_b: int = _effective_initiative(b, use_pending_mods)
		if init_a == init_b:
			var is_a_player = a.unit_data and a.unit_data.faction == UnitData.Faction.PLAYER
			return is_a_player
		return init_a > init_b
	)
	return sorted_units


func _living_combatants() -> Array[Unit]:
	var living: Array[Unit] = []
	for unit in _combatants:
		if is_instance_valid(unit) and unit.current_health > 0:
			living.append(unit)
	return living


func _calculate_turn_order():
	"""Vypočítá pořadí tahů podle iniciativy (sestupně) a zamkne hodnoty pro UI."""
	_turn_order = _sort_units_by_initiative(_living_combatants(), true)
	_locked_initiative.clear()
	for unit in _turn_order:
		_locked_initiative[unit.get_instance_id()] = _effective_initiative(unit, true)

	print("TurnManager: Pořadí tahů pro kolo %d:" % _round_number)
	for i in range(_turn_order.size()):
		var unit = _turn_order[i]
		var base_init = unit.unit_data.initiative if unit.unit_data else 0
		var total = int(_locked_initiative.get(unit.get_instance_id(), base_init))
		var mod = total - base_init
		print("  %d. %s (Základ: %d, Bonus: %d, Celkem: %d)" % [i + 1, unit.unit_data.unit_name, base_init, mod, total])

func _start_new_round():
	"""Zahájí nové kolo"""
	_round_number += 1
	_current_turn_index = 0
	
	print("=== TurnManager: KOLO %d ===" % _round_number)
	
	# 1. Vypočítej pořadí pro toto kolo (bonusy z minulého kola stále platí)
	_calculate_turn_order()
	
	# 2. IHNED PO VÝPOČTU bonusy smaž (aby neplatily pro příští kolo)
	_initiative_modifiers.clear()

	emit_signal("round_started", _round_number)
	
	_start_next_unit_turn()

func _start_next_unit_turn():
	"""Zahájí tah další jednotky v pořadí"""
	if not _is_combat_active:
		return
	
	if _check_combat_end():
		return
	
	# Pokud jsme prošli všechny jednotky, zahaj nové kolo
	if _current_turn_index >= _turn_order.size():
		call_deferred("_start_new_round") # Toto volání zde zůstává
		return
	
	var current_unit = _turn_order[_current_turn_index]
	
	# Ověř že jednotka je stále validní
	if not is_instance_valid(current_unit):
		print("TurnManager: Jednotka na indexu %d není validní, skipping..." % _current_turn_index)
		_current_turn_index += 1
		_start_next_unit_turn()
		return
	
	print("TurnManager: Tah jednotky %s" % current_unit.unit_data.unit_name)
	emit_signal("turn_started", current_unit)

func next_turn():
	"""Přejde na další tah (volá BattleScene po dokončení akce)"""
	if not _is_combat_active:
		return
	
	_current_turn_index += 1
	
	# Malá prodleva pro plynulost
	await get_tree().create_timer(0.2).timeout
	
	_start_next_unit_turn()

func add_unit(unit: Unit) -> void:
	"""Register unit (e.g. Druid spirit). If current turn is enemy, new enemy can act this round."""
	register_unit(unit, true)

func register_unit(unit: Unit, act_this_round: bool = false):
	"""Přidá jednotku během souboje (např. vyvolání). If act_this_round and current turn is same faction, insert after current so unit acts this round."""
	if not is_instance_valid(unit) or not unit.unit_data:
		return
	if not _combatants.has(unit):
		_combatants.append(unit)
		print("TurnManager: Zaregistrována nová jednotka: %s" % unit.unit_data.unit_name)
	
	if _turn_order.has(unit):
		return
	var current = get_current_unit()
	var is_enemy_turn = current and is_instance_valid(current) and current.unit_data and current.unit_data.faction == UnitData.Faction.ENEMY
	var unit_is_enemy = unit.unit_data.faction == UnitData.Faction.ENEMY
	if act_this_round and is_enemy_turn and unit_is_enemy and _current_turn_index >= 0:
		_turn_order.insert(_current_turn_index + 1, unit)
	else:
		_turn_order.append(unit)

func unregister_unit(unit: Unit):
	"""Odebere jednotku ze souboje (smrt)"""
	if _combatants.has(unit):
		_combatants.erase(unit)
	
	if _turn_order.has(unit):
		# Pokud mažeme aktuální nebo dřívější jednotku, posuneme index dozadu,
		# aby následující next_turn() (+1) správně skočil na další živou jednotku.
		var unit_index = _turn_order.find(unit)
		_turn_order.erase(unit)
		if unit_index <= _current_turn_index:
			_current_turn_index = maxi(-1, _current_turn_index - 1)
	
	var unit_label = unit.unit_data.unit_name if is_instance_valid(unit) and unit.unit_data else "?"
	print("TurnManager: Jednotka %s vyřazena ze souboje" % unit_label)
	
	# Zkontroluj podmínky konce (BattleScene pak ještě počká na animaci před odměnami)
	_check_combat_end()

func _check_combat_end() -> bool:
	"""Zkontroluje, zda má souboj skončit"""
	var player_count = 0
	var enemy_count = 0
	
	for unit in _combatants:
		if not is_instance_valid(unit):
			continue
		
		if unit.unit_data.faction == UnitData.Faction.PLAYER:
			player_count += 1
		elif unit.unit_data.faction == UnitData.Faction.ENEMY:
			enemy_count += 1
	
	# Souboj končí, pokud není hráč nebo nejsou nepřátelé
	if player_count == 0:
		_end_combat(false)
		return true
	
	if enemy_count == 0:
		_end_combat(true)
		return true
	
	return false

func _end_combat(player_won: bool):
	"""Ukončí souboj"""
	print("=== TurnManager: KONEC SOUBOJE (Výhra: %s) ===" % str(player_won))
	
	_is_combat_active = false
	emit_signal("combat_ended", player_won)

func get_current_round() -> int:
	return _round_number

func get_current_unit() -> Unit:
	if _current_turn_index < _turn_order.size():
		return _turn_order[_current_turn_index]
	return null

func get_turn_order() -> Array[Unit]:
	"""Vrátí aktuální pořadí tahů (pro UI)"""
	return _turn_order.duplicate()


func get_remaining_turn_order() -> Array[Unit]:
	"""Living units still to act this round, including the current one (left → first)."""
	var remaining: Array[Unit] = []
	if not _is_combat_active:
		return remaining
	for i in range(_current_turn_index, _turn_order.size()):
		var unit: Unit = _turn_order[i]
		if is_instance_valid(unit) and unit.current_health > 0:
			remaining.append(unit)
	return remaining


func get_next_round_preview_order() -> Array[Unit]:
	"""Projected order for next round using base init + pending modifiers."""
	return _sort_units_by_initiative(_living_combatants(), true)


func get_locked_initiative_for_unit(unit: Unit) -> int:
	"""Initiative that sorted the CURRENT round (for remaining-slot labels)."""
	if not is_instance_valid(unit):
		return 0
	var id: int = unit.get_instance_id()
	if _locked_initiative.has(id):
		return int(_locked_initiative[id])
	return _effective_initiative(unit, false)


func get_projected_initiative_for_unit(unit: Unit) -> int:
	"""Initiative for NEXT round preview (base + pending mods)."""
	return _effective_initiative(unit, true)


## Entries for InitiativeBar: {unit, is_preview, initiative, pending_mod}
func get_initiative_bar_entries() -> Array:
	var entries: Array = []
	for unit in get_remaining_turn_order():
		entries.append({
			"unit": unit,
			"is_preview": false,
			"initiative": get_locked_initiative_for_unit(unit),
			"pending_mod": 0,
		})
	for unit in get_next_round_preview_order():
		var pending: int = get_initiative_modifier_for_unit(unit)
		entries.append({
			"unit": unit,
			"is_preview": true,
			"initiative": get_projected_initiative_for_unit(unit),
			"pending_mod": pending,
		})
	return entries


func get_initiative_modifier_for_unit(unit: Unit) -> int:
	"""Vrátí dočasný modifikátor iniciativy pro danou jednotku (pending → next round)."""
	if not is_instance_valid(unit):
		return 0
	return int(_initiative_modifiers.get(unit.get_instance_id(), 0))

func modify_initiative_next_round(unit: Unit, change: int):
	"""
	Upraví iniciativu jednotky POUZE pro příští kolo.
	Ukládá bonus do dočasného slovníku.
	"""
	if not is_instance_valid(unit) or not unit.unit_data:
		return
	
	# Změníme ukládání do dictionary, ne do unit_data
	var unit_id = unit.get_instance_id()
	var current_mod = _initiative_modifiers.get(unit_id, 0)
	_initiative_modifiers[unit_id] = current_mod + change
	
	var base_init = unit.unit_data.initiative if unit.unit_data else 0
	var total_initiative = base_init + _initiative_modifiers[unit_id]
	emit_signal("initiative_modifiers_changed", unit, total_initiative)
	
	print("TurnManager: Iniciativa %s bude v PŘÍŠTÍM KOLE změněna o %d (Nový modifikátor: %d)" % [
		unit.unit_data.unit_name,
		change,
		_initiative_modifiers[unit_id] # Vypíše celkový bonus
	])

func is_combat_active() -> bool:
	return _is_combat_active

func reset():
	"""Reset pro nový souboj"""
	_combatants.clear()
	_turn_order.clear()
	_initiative_modifiers.clear()
	_locked_initiative.clear()
	_current_turn_index = 0
	_round_number = 0
	_is_combat_active = false
