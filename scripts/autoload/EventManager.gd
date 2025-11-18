# Soubor: res://scripts/autoload/EventManager.gd (JEN LOGIKA, ŽÁDNÉ NAČÍTÁNÍ)
extends Node

var event_history: Array[String] = []
var combat_buffs: Array[String] = []

func _ready():
	print("EventManager: Inicializace...")

func _filter_events_for_floor(events: Array, floor: int) -> Array:
	"""Vyfiltruje eventy vhodné pro dané patro"""
	var available_events: Array = []
	
	for event in events:
		if not event:
			continue
			
		# Filtruj podle patra
		if floor < event.min_floor or floor > event.max_floor:
			continue
		
		# Filtruj podle historie (once_per_run)
		if event.once_per_run and event_history.has(event.event_id):
			continue
		
		available_events.append(event)
	
	return available_events

func mark_event_as_used(event: EventData):
	"""Označí event jako použitý (pro once_per_run)"""
	if event and event.once_per_run and event.event_id != "":
		event_history.append(event.event_id)
		print("EventManager: Event označen jako použitý: %s" % event.event_id)

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
	print("EventManager: Reset pro nový run")

func _debug_available_events(events: Array, floor: int):
	"""Debug informace o dostupných eventech"""
	print("EventManager: DEBUG - Celkem eventů: %d pro patro %d" % [events.size(), floor])
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
