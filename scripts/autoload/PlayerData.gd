# Soubor: scripts/autoload/PlayerData.gd
extends Node

# --- OPRAVENÁ DEFINICE SIGNÁLU ---
signal energy_changed(new_energy_amount)
signal artifacts_changed
signal gold_changed(new_amount) # Překlep "chaged" opraven na "changed"
signal health_changed(new_hp, new_max_hp)

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


var path_taken: Array[MapNodeResource] = []

func get_current_node() -> MapNodeResource:
	if not path_taken.is_empty():
		return path_taken.back()
	return null

func start_new_run_state():
	current_hp = max_hp
	path_taken.clear()
	artifacts.clear()
	emit_signal("artifacts_changed")
	
	gold = 100
	emit_signal("gold_changed", gold)
	
	# PŘIDÁNO: Na začátku běhu informujeme o stavu zdraví
	emit_signal("health_changed", current_hp, max_hp)

func initialize_player(p_class: ClassData, p_subclass: SubclassData):
	if not p_class or not p_subclass:
		printerr("PlayerData: Chyba inicializace!")
		return
	selected_class = p_class
	selected_subclass = p_subclass
	master_deck.clear()
	for entry in selected_subclass.starting_deck:
		if entry is DeckEntry and is_instance_valid(entry.card):
			for i in range(entry.count):
				master_deck.append(entry.card)
	
	reset_battle_stats()

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
