# Soubor: scripts/autoload/PlayerData.gd
extends Node

var selected_class: ClassData = null
var selected_subclass: SubclassData = null
var master_deck: Array[CardData] = []
var current_hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var draw_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []
signal energy_changed(new_energy_amount)
var current_energy: int = 3
var max_energy: int = 3
var max_hp: int = 50
var current_hp: int = 50

var path_taken: Array[MapNodeResource] = []

func get_current_node() -> MapNodeResource:
	if not path_taken.is_empty():
		return path_taken.back()
	return null

func start_new_run_state():
	current_hp = max_hp
	path_taken.clear()

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

# --- ZMĚNA ZDE ---
# Funkce nyní vrací počet karet, které se jí podařilo dobrat.
# Už sama nemíchá balíček, to bude řídit BattleScene.
func draw_cards(amount: int) -> int:
	var cards_drawn_count = 0
	for _i in range(amount):
		if draw_pile.is_empty():
			# Pokud je dobírací balíček prázdný, přestaneme dobírat.
			# BattleScene se postará o zamíchání a zavolá nás znovu.
			break
		
		var drawn_card = draw_pile.pop_front()
		if drawn_card is CardData:
			current_hand.append(drawn_card)
			cards_drawn_count += 1
			
	return cards_drawn_count
