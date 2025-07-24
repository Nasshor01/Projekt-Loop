# Soubor: scripts/autoload/PlayerData.gd
# POPIS: Kompletní verze se správnou resetovací funkcí.
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

# Tato funkce resetuje stav hráče pro nový běh (HP, pozici na mapě atd.)
func start_new_run_state():
	current_hp = max_hp
	path_taken.clear()

# Tato funkce nastavuje startovní balíček. Je oddělená pro přehlednost.
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
	
	# Po inicializaci balíčku hned resetujeme stav pro první souboj.
	reset_battle_stats()

# Tato funkce resetuje jen stav pro souboj (karty v ruce, odhazovací balíček atd.)
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

# ... zbytek souboru (spend_energy, gain_energy atd.) je stejný ...
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

func draw_cards(amount: int):
	for _i in range(amount):
		if draw_pile.is_empty():
			reshuffle_discard_into_draw_pile()
			if draw_pile.is_empty():
				break
		var drawn_card = draw_pile.pop_front()
		if drawn_card is CardData:
			current_hand.append(drawn_card)
