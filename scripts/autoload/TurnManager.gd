# res://scripts/autoload/TurnManager.gd
# Správce tahového systému založeného na iniciativě
extends Node

# Signály pro komunikaci s BattleScene
signal round_started(round_number: int)
signal turn_started(unit: Unit)
signal combat_ended(player_won: bool)

# Interní stav
var _combatants: Array[Unit] = []
var _turn_order: Array[Unit] = []
var _current_turn_index: int = 0
var _round_number: int = 0
var _is_combat_active: bool = false
var _initiative_modifiers: Dictionary = {}

func start_combat(all_units: Array[Unit]):
	"""Inicializuje souboj se všemi jednotkami"""
	print("=== TurnManager: START COMBAT ===")
	
	reset()
	_combatants = all_units.duplicate()
	_is_combat_active = true
	
	print("TurnManager: Zaregistrováno %d jednotek" % _combatants.size())
	# Zahaj první kolo
	_start_new_round()

func _calculate_turn_order():
	"""Vypočítá pořadí tahů podle iniciativy (sestupně)"""
	_turn_order.clear()
	_turn_order = _combatants.duplicate()
	
	# Seřaď podle iniciativy (vyšší = dřív)
	_turn_order.sort_custom(func(a: Unit, b: Unit):
		
		# ZÁKLADNÍ INICIATIVA (neměnná)
		var base_init_a = a.unit_data.initiative if a.unit_data else 0
		var base_init_b = b.unit_data.initiative if b.unit_data else 0
		
		# DOČASNÝ BONUS (z karet z minulého kola)
		var mod_a = _initiative_modifiers.get(a.get_instance_id(), 0)
		var mod_b = _initiative_modifiers.get(b.get_instance_id(), 0)
		
		# CELKOVÁ INICIATIVA (pro toto kolo)
		var init_a = base_init_a + mod_a
		var init_b = base_init_b + mod_b
		
		# Remíza - hráč má prioritu
		if init_a == init_b:
			var is_a_player = a.unit_data.faction == UnitData.Faction.PLAYER
			# var is_b_player = b.unit_data.faction == UnitData.Faction.PLAYER # Není potřeba
			return is_a_player  # Hráč má přednost
		
		return init_a > init_b  # Vyšší iniciativa je dřív
	)
	
	print("TurnManager: Pořadí tahů pro kolo %d:" % _round_number)
	for i in range(_turn_order.size()):
		var unit = _turn_order[i]
		var base_init = unit.unit_data.initiative if unit.unit_data else 0
		var mod = _initiative_modifiers.get(unit.get_instance_id(), 0)
		print("  %d. %s (Základ: %d, Bonus: %d, Celkem: %d)" % [i + 1, unit.unit_data.unit_name, base_init, mod, base_init + mod])

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

func register_unit(unit: Unit):
	"""Přidá jednotku během souboje (např. vyvolání)"""
	if not _combatants.has(unit):
		_combatants.append(unit)
		print("TurnManager: Zaregistrována nová jednotka: %s" % unit.unit_data.unit_name)
		
		# Přidej do aktuálního kola na konec
		_turn_order.append(unit)

func unregister_unit(unit: Unit):
	"""Odebere jednotku ze souboje (smrt)"""
	if _combatants.has(unit):
		_combatants.erase(unit)
	
	if _turn_order.has(unit):
		# Pokud mazáme jednotku před aktuálním indexem, posuneme index
		var unit_index = _turn_order.find(unit)
		if unit_index < _current_turn_index:
			_current_turn_index -= 1
		
		_turn_order.erase(unit)
	
	print("TurnManager: Jednotka %s vyřazena ze souboje" % unit.unit_data.unit_name)
	
	# Zkontroluj podmínky konce
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

func get_initiative_modifier_for_unit(unit: Unit) -> int:
	"""Vrátí dočasný modifikátor iniciativy pro danou jednotku."""
	if not is_instance_valid(unit):
		return 0
	return _initiative_modifiers.get(unit.get_instance_id(), 0)

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
	_current_turn_index = 0
	_round_number = 0
	_is_combat_active = false
