# ==============================================
# 1. OPRAVA EventManager.gd
# ==============================================
# Soubor: res://scripts/autoload/EventManager.gd

extends Node

var all_events: Array[EventData] = []
var event_history: Array[String] = []
var combat_buffs: Array[String] = []

func _ready():
	print("EventManager: Inicializace...")
	_load_all_events()

func _load_all_events():
	var event_dir_path = "res://data/events/"
	var dir = DirAccess.open(event_dir_path)
	
	if not dir:
		printerr("EventManager: Složka s eventy '%s' nenalezena!" % event_dir_path)
		printerr("EventManager: Vytvářím testovací eventy...")
		_create_test_events()
		return
	
	all_events.clear()
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var event_resource = load(event_dir_path + file_name)
			if event_resource is EventData:
				all_events.append(event_resource)
				print("EventManager: Načten event '%s'" % event_resource.event_name)
		file_name = dir.get_next()
	
	print("EventManager: Načteno %d eventů z disku." % all_events.size())
	
	# Pokud nebyly načteny žádné eventy, vytvoř testovací
	if all_events.is_empty():
		print("EventManager: Žádné eventy nenačteny, vytvářím testovací...")
		_create_test_events()

# TOTO CHYBĚLO - přidáváme funkci get_random_event_for_floor
func get_random_event_for_floor(floor: int) -> EventData:
	"""Získá náhodný event vhodný pro dané patro"""
	var available_events = []
	
	for event in all_events:
		# Filtruj podle patra
		if floor < event.min_floor or floor > event.max_floor:
			continue
		
		# Filtruj podle historie (once_per_run)
		if event.once_per_run and event_history.has(event.event_id):
			continue
		
		available_events.append(event)
	
	if available_events.is_empty():
		print("EventManager: Žádné dostupné eventy pro patro %d, vracím fallback" % floor)
		return _create_fallback_event()
	
	var chosen_event = available_events.pick_random()
	
	# Zaznamenej do historie
	if chosen_event and chosen_event.event_id != "":
		event_history.append(chosen_event.event_id)
	
	return chosen_event

func get_random_event() -> EventData:
	"""Získá náhodný event bez ohledu na patro"""
	return get_random_event_for_floor(0)

func _create_fallback_event() -> EventData:
	"""Vytvoří jednoduchý fallback event"""
	var event = EventData.new()
	event.event_id = "fallback_rest"
	event.event_name = "Moment klidu"
	event.description = "Našel jsi bezpečné místo k odpočinku."
	event.event_type = EventData.EventType.BENEFIT
	event.rarity = EventData.EventRarity.COMMON
	
	var choice1 = EventChoice.new()
	choice1.choice_text = "Odpočinout si (+10 HP)"
	choice1.costs = {}
	choice1.rewards = {"heal": 10}
	choice1.success_chance = 1.0
	
	var choice2 = EventChoice.new()
	choice2.choice_text = "Pokračovat"
	choice2.costs = {}
	choice2.rewards = {}
	choice2.success_chance = 1.0
	
	event.choices = [choice1, choice2]
	return event

func _create_test_events():
	"""Vytvoří testovací eventy pokud nejsou načteny žádné z disku"""
	
	# Event 1: Léčivý pramen
	var event1 = EventData.new()
	event1.event_id = "test_healing_spring"
	event1.event_name = "Léčivý pramen"
	event1.event_type = EventData.EventType.BENEFIT
	event1.rarity = EventData.EventRarity.COMMON
	event1.description = "Nacházíš malou jeskyni s křišťálově čistým pramenem.\nVoda vypadá velmi osvěžující."
	event1.min_floor = 0
	event1.max_floor = 99
	
	var choice1a = EventChoice.new()
	choice1a.choice_text = "Napít se z pramene"
	choice1a.choice_tooltip = "Vyléčí 15 HP"
	choice1a.costs = {}
	choice1a.rewards = {"heal": 15}
	choice1a.success_chance = 1.0
	
	var choice1b = EventChoice.new()
	choice1b.choice_text = "Pokračovat dál"
	choice1b.costs = {}
	choice1b.rewards = {}
	choice1b.success_chance = 1.0
	
	event1.choices = [choice1a, choice1b]
	all_events.append(event1)
	
	# Event 2: Tajemná studna (Risk/Reward)
	var event2 = EventData.new()
	event2.event_id = "test_mysterious_well"
	event2.event_name = "Tajemná studna"
	event2.event_type = EventData.EventType.RISK_REWARD
	event2.rarity = EventData.EventRarity.UNCOMMON
	event2.description = "Stará studna pulzuje podivným světlem.\nSlyšíš šeptání z hlubin..."
	event2.min_floor = 0
	event2.max_floor = 99
	
	var choice2a = EventChoice.new()
	choice2a.choice_text = "Hodit minci a přát si"
	choice2a.choice_tooltip = "60% šance na zisk zlata"
	choice2a.costs = {"gold": 20}
	choice2a.rewards = {"gold": 50}
	choice2a.success_chance = 0.6
	choice2a.failure_penalty = {}
	
	var choice2b = EventChoice.new()
	choice2b.choice_text = "Napít se vody"
	choice2b.choice_tooltip = "Riskantní, ale potenciálně velmi prospěšné"
	choice2b.costs = {"hp": 10}
	choice2b.rewards = {"heal": 999, "max_hp": 5}
	choice2b.success_chance = 0.7
	choice2b.failure_penalty = {"hp": 10}
	
	var choice2c = EventChoice.new()
	choice2c.choice_text = "Odejít"
	choice2c.costs = {}
	choice2c.rewards = {}
	choice2c.success_chance = 1.0
	
	event2.choices = [choice2a, choice2b, choice2c]
	all_events.append(event2)
	
	print("EventManager: Vytvořeno %d testovacích eventů" % all_events.size())

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
