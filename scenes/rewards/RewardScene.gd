# Soubor: scripts/RewardScene.gd
# POPIS: Kompletní oprava. Řeší pád hry a přidává kartu do balíčku hráče.
extends Control

# Seznam všech možných karet, které se mohou objevit jako odměna
# (Vytvoříte si je v editoru jako CardData.tres)
const CARD_REWARD_POOL = [
	preload("res://data/cards/everyone/fortify.tres"),
	preload("res://data/cards/everyone/heavy_strike.tres"),
	preload("res://data/cards/paladin/shield_bash.tres"),
	preload("res://data/cards/everyone/adrenaline.tres")
]

@onready var card_container = $CardContainer # Ujisti se, že tento uzel ve scéně existuje

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")
const NUM_CARD_CHOICES = 3 # Počet karet, ze kterých se vybírá

func _ready():
	# --- OPRAVA CHYBY "Read-only state" ---
	# 1. Vytvoříme upravitelnou kopii pole karet.
	var available_cards = CARD_REWARD_POOL.duplicate()
	# 2. Zamícháme tuto kopii, ne konstantu.
	available_cards.shuffle()
	
	# Vybereme definovaný počet karet z vrchu zamíchaného balíčku.
	var card_choices = available_cards.slice(0, NUM_CARD_CHOICES)
	
	for card_data in card_choices:
		var card_ui = CardUIScene.instantiate()
		card_container.add_child(card_ui)
		card_ui.load_card(card_data)
		# Po kliknutí se karta přidá do balíčku a přejde se dál
		card_ui.gui_input.connect(_on_card_selected.bind(card_data))

func _on_card_selected(event: InputEvent, card_to_add: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("Karta vybrána: ", card_to_add.card_name)
		
		# --- OPRAVA NEPŘIDÁVÁNÍ KARET ---
		# Zde je klíčová logika: Přidáme vybranou kartu do hlavního balíčku hráče.
		PlayerData.master_deck.append(card_to_add)
		
		# Řekneme GameManageru, že jsme si vybrali a můžeme se vrátit na mapu.
		GameManager.reward_chosen()
