# Soubor: scripts/autoload/PlayerData.gd
extends Node


# --- Signály ---
signal energy_changed(new_energy_amount)
signal artifacts_changed
signal gold_changed(new_amount)
signal health_changed(new_hp, new_max_hp)
signal player_initialized

# --- Proměnné pro jeden "run" ---
var selected_class: ClassData = null
var selected_subclass: SubclassData = null
var master_deck: Array[CardData] = []
var current_hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var draw_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []
var current_energy: int = 3
var max_energy: int = 3
var max_hp: int = 50
var current_hp: int = 50
var artifacts: Array[ArtifactsData] = []
var gold: int = 0
var floors_cleared: int = 0
var path_taken: Array[MapNodeResource] = []
var active_skill_tree: PassiveSkillTreeData = null
var has_revive: bool = false
var global_card_damage_bonus: int = 0
var starting_retained_block: int = 0

func get_current_node() -> MapNodeResource:
	if not path_taken.is_empty():
		floors_cleared = path_taken.size()
		return path_taken.back()
	return null

func start_new_run_state():
	# 1. Resetujeme balíček na startovní
	master_deck.clear()
	if is_instance_valid(selected_subclass):
		for entry in selected_subclass.starting_deck:
			if entry is DeckEntry and is_instance_valid(entry.card):
				for i in range(entry.count):
					master_deck.append(entry.card)
	
	# 2. Aplikujeme pasivní skilly, které mohou změnit startovní staty
	apply_passive_skills()

	# 3. Připravíme bojové balíčky a zbytek
	reset_battle_stats()
	path_taken.clear()
	artifacts.clear()
	floors_cleared = 0
	
	# 4. Oznámíme UI, jaký je finální stav
	emit_signal("artifacts_changed")
	emit_signal("gold_changed", gold)
	emit_signal("health_changed", current_hp, max_hp)

func start_ng_plus_state():
	current_hp = max_hp
	path_taken.clear()
	floors_cleared = 0
	
	print("--- STAV PRO NG+ ---")
	print("  - Ponecháno zlata: %d" % gold)
	print("  - Ponecháno artefaktů: %d" % artifacts.size())
	print("  - Ponecháno karet v balíčku: %d" % master_deck.size())
	print("--------------------")
	
	reset_battle_stats()
	
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("artifacts_changed")
	emit_signal("gold_changed", gold)

func apply_passive_skills():
	# 1. Resetujeme všechny hodnoty na úplný základ
	max_hp = 50
	gold = 50
	max_energy = 3
	has_revive = false
	global_card_damage_bonus = 0
	starting_retained_block = 0
	
	if not is_instance_valid(active_skill_tree):
		current_hp = max_hp
		return

	var unlocked_ids = SaveManager.meta_progress.unlocked_skill_ids
	
	# 3. Projdeme odemčené skilly a aplikujeme jejich EFEKTY
	for skill_id in unlocked_ids:
		var skill_node = active_skill_tree.get_node_by_id(skill_id)
		if not is_instance_valid(skill_node):
			continue
		
		print("Aplikuji pasivní skill: ", skill_node.skill_name)
		
		# Projdeme všechny efekty definované v uzlu
		for effect_data in skill_node.effects:
			if not is_instance_valid(effect_data):
				continue
			
			# Tady je ta nová, čistá logika s ENUMEM!
			match effect_data.effect_type:
				PassiveEffectData.EffectType.ADD_MAX_HP:
					max_hp += effect_data.value
				PassiveEffectData.EffectType.ADD_STARTING_GOLD:
					gold += effect_data.value
				PassiveEffectData.EffectType.ADD_MAX_ENERGY:
					max_energy += effect_data.value
				PassiveEffectData.EffectType.GRANT_REVIVE:
					if effect_data.value > 0: has_revive = true
				PassiveEffectData.EffectType.ADD_CARD_DAMAGE:
					global_card_damage_bonus += effect_data.value
				PassiveEffectData.EffectType.ADD_RETAINED_BLOCK:
					starting_retained_block += effect_data.value
	
	current_hp = max_hp

func initialize_player(p_class: ClassData, p_subclass: SubclassData):
	if not p_class or not p_subclass:
		printerr("PlayerData: Chyba inicializace! Chybí třída nebo podtřída.")
		return
		
	selected_class = p_class
	selected_subclass = p_subclass
	
	if is_instance_valid(p_subclass.passive_skill_tree):
		active_skill_tree = p_subclass.passive_skill_tree
	else:
		active_skill_tree = null
		print("Varování: Pro podtřídu '%s' nebyl nastaven žádný strom dovedností." % p_subclass.subclass_name)

	# PŘIDEJ TENTO ŘÁDEK NA KONEC FUNKCE
	# Tímto "zakřičíme" na celou hru: "Hráč je připraven!"
	emit_signal("player_initialized")

func reset_battle_stats():
	draw_pile.clear()
	discard_pile.clear()
	current_hand.clear()
	exhaust_pile.clear()
	draw_pile.assign(master_deck)
	draw_pile.shuffle()

func reset_energy():
	current_energy = max_energy
	
	for artifact in artifacts:
		if artifact.effect_id == "extra_energy_per_turn":
			current_energy += artifact.value
			print("Artefakt '%s' přidal hráči %d energii." % [artifact.artifact_name, artifact.value])
	
	emit_signal("energy_changed", current_energy)

func spend_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		emit_signal("energy_changed", current_energy)
		return true
	return false

func gain_energy(amount: int):
	current_energy += amount
	emit_signal("energy_changed", current_energy)

func add_card_to_discard_pile(card: CardData):
	if card is CardData:
		discard_pile.append(card)

func add_card_to_exhaust_pile(card: CardData):
	if card is CardData:
		exhaust_pile.append(card)

func discard_hand():
	if current_hand.is_empty():
		return
	for card in current_hand:
		add_card_to_discard_pile(card)
	current_hand.clear()

func reshuffle_discard_into_draw_pile():
	if not discard_pile.is_empty():
		draw_pile.assign(discard_pile)
		discard_pile.clear()
		draw_pile.shuffle()

func draw_new_hand(hand_size: int = 5):
	current_hand.clear()
	draw_cards(hand_size)

func draw_cards(amount: int) -> int:
	var cards_drawn_count = 0
	for _i in range(amount):
		if draw_pile.is_empty():
			break
		
		var drawn_card = draw_pile.pop_front()
		if drawn_card is CardData:
			current_hand.append(drawn_card)
			cards_drawn_count += 1
			
	return cards_drawn_count


func add_artifact(artifact_data: ArtifactsData):
	if not artifacts.has(artifact_data):
		artifacts.append(artifact_data)
		emit_signal("artifacts_changed")

func remove_artifact(artifact_data: ArtifactsData):
	if artifacts.has(artifact_data):
		artifacts.erase(artifact_data)
		emit_signal("artifacts_changed")

# --- Funkce pro zlato nyní volají správný signál ---
func add_gold(amount: int):
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_signal("gold_changed", gold)
		return true
	return false

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	emit_signal("health_changed", current_hp, max_hp)

func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)
	emit_signal("health_changed", current_hp, max_hp)
