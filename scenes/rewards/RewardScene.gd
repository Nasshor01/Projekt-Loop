# Soubor: scripts/RewardScene.gd (FINÁLNÍ VERZE PRO PANELCONTAINER)
extends PanelContainer # <-- ZMĚNA Z CONTROL NA PANELCONTAINER

# Proměnná, do které GameManager vloží odměnu
var gold_reward: int = 0

const CARD_REWARD_POOL = [
	preload("res://data/cards/everyone/fortify.tres"),
	preload("res://data/cards/everyone/heavy_strike.tres"),
	preload("res://data/cards/paladin/shield_bash.tres"),
	preload("res://data/cards/everyone/adrenaline.tres")
]

# --- AKTUALIZOVANÉ CESTY PODLE NOVÉ STRUKTURY ---
@onready var card_container = $VBoxContainer/CardContainer
@onready var gold_label: Label = $VBoxContainer/GoldRewardDisplay/GoldLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")
const NUM_CARD_CHOICES = 3

func _ready():
	# 1. Přidáme zlato hráči a aktualizujeme text
	PlayerData.add_gold(gold_reward)
	gold_label.text = "Získáno zlata: %d" % gold_reward
	
	# 2. Deaktivujeme tlačítko "Pokračovat", dokud si hráč nevybere kartu
	continue_button.disabled = true
	continue_button.pressed.connect(GameManager.reward_chosen)
	
	# 3. Vygenerujeme karty jako dříve
	var available_cards = CARD_REWARD_POOL.duplicate()
	available_cards.shuffle()
	
	var card_choices = available_cards.slice(0, NUM_CARD_CHOICES)
	
	for card_data in card_choices:
		var card_ui = CardUIScene.instantiate()
		card_container.add_child(card_ui)
		card_ui.load_card(card_data)
		card_ui.gui_input.connect(_on_card_selected.bind(card_data, card_ui))

func _on_card_selected(event: InputEvent, card_to_add: CardData, clicked_card_ui: CardUI):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("Karta vybrána: ", card_to_add.card_name)
		
		# Přidáme kartu do balíčku
		PlayerData.master_deck.append(card_to_add)
		
		# Deaktivujeme všechny karty, aby si hráč nemohl vybrat další
		for card_node in card_container.get_children():
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Vizuálně odlišíme nevybrané karty
			if card_node != clicked_card_ui:
				card_node.modulate = Color(0.5, 0.5, 0.5)

		# Aktivujeme tlačítko pro pokračování
		continue_button.disabled = false
