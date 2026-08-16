# Soubor: res://scripts/autoload/EventManager.gd (JEN LOGIKA, ŽÁDNÉ NAČÍTÁNÍ)
extends Node

const RARITY_WEIGHT := {
	EventData.EventRarity.COMMON: 10.0,
	EventData.EventRarity.UNCOMMON: 4.0,
	EventData.EventRarity.RARE: 1.5,
	EventData.EventRarity.LEGENDARY: 0.4,
}

var event_history: Array[String] = []
var combat_buffs: Array[String] = []
var upgrade_all_used_this_run: bool = false

func _ready():
	print("EventManager: Inicializace...")

func _filter_events_for_floor(events: Array, floor_num: int) -> Array:
	"""Vyfiltruje eventy vhodné pro dané patro"""
	var available_events: Array = []
	
	for event in events:
		if not event:
			continue
			
		# Filtruj podle patra
		if floor_num < event.min_floor or floor_num > event.max_floor:
			continue
		
		# Filtruj podle historie (once_per_run)
		if event.once_per_run and event_history.has(event.event_id):
			continue
		
		available_events.append(event)
	
	return available_events

# Public wrapper pro externí volání
func filter_events_for_floor(events: Array, floor_num: int) -> Array:
	"""Public wrapper pro _filter_events_for_floor"""
	return _filter_events_for_floor(events, floor_num)

func pick_event_for_floor(events: Array, floor_num: int) -> EventData:
	var available_events: Array = _filter_events_for_floor(events, floor_num)
	if available_events.is_empty():
		return null
	var chosen: EventData = _pick_weighted(available_events)
	mark_event_as_used(chosen)
	return chosen

func _pick_weighted(events: Array) -> EventData:
	if events.is_empty():
		return null
	var total := 0.0
	var weights: Array[float] = []
	for event in events:
		var rarity: EventData.EventRarity = event.rarity
		var weight: float = float(RARITY_WEIGHT.get(rarity, 4.0))
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return events.pick_random()
	var roll := randf() * total
	for i in events.size():
		roll -= weights[i]
		if roll <= 0.0:
			return events[i]
	return events[events.size() - 1]

func mark_event_as_used(event: EventData):
	"""Označí event jako použitý (pro once_per_run)"""
	if event and event.once_per_run and event.event_id != "":
		event_history.append(event.event_id)
		print("EventManager: Event označen jako použitý: %s" % event.event_id)

func mark_upgrade_all_used() -> void:
	upgrade_all_used_this_run = true

func add_combat_buff(buff_id: String):
	"""Přidá buff pro příští souboj"""
	combat_buffs.append(buff_id)
	print("EventManager: Combat buff přidán: %s" % buff_id)

func get_and_clear_combat_buffs() -> Array[String]:
	"""Získá a vyčistí combat buffy"""
	var buffs = combat_buffs.duplicate()
	combat_buffs.clear()
	return buffs

func start_new_run():
	"""Reset pro nový run"""
	event_history.clear()
	combat_buffs.clear()
	upgrade_all_used_this_run = false
	print("EventManager: Reset pro nový run")

func _debug_available_events(events: Array, floor_num: int):
	"""Debug informace o dostupných eventech"""
	print("EventManager: DEBUG - Celkem eventů: %d pro patro %d" % [events.size(), floor_num])
	for event in events:
		if event:
			print("  Event: %s, patro: %d-%d, použit: %s" % [
				event.event_name,
				event.min_floor,
				event.max_floor,
				str(event_history.has(event.event_id))
			])
		else:
			print("  Event: NULL!")

# Public wrapper pro externí volání
func debug_available_events(events: Array, floor_num: int):
	"""Public wrapper pro _debug_available_events"""
	_debug_available_events(events, floor_num)
